// whisper.cpp ustidan C shim.
//
// macOS versiyasidagi src/whisper_bridge.c dan ko'chirilgan — inference
// parametrlari AYNAN bir xil (til uz, beam search 5, no_speech_thold 0.25).
// Windows uchun qo'shilgani: CPU fallback (rubai_load_ex), xato matni,
// faol backend nomi.

#include "whisper.h"
#include "ggml-backend.h"
#include "whisper_bridge.h"
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

static struct whisper_context *g_ctx = NULL;
static char g_err[256] = "";
static char g_backend[32] = "";

static rubai_log_fn g_log = NULL;

static void set_err(const char *msg) {
    snprintf(g_err, sizeof(g_err), "%s", msg ? msg : "");
}

// ggml/whisper xabarlarini o'z logimizga uzatadi.
static void ggml_log_bridge(enum ggml_log_level level, const char *text, void *ud) {
    (void)level; (void)ud;
    if (g_log && text && text[0] && text[0] != '\n') g_log(text);
}

void rubai_set_log(rubai_log_fn fn) {
    g_log = fn;
    whisper_log_set(ggml_log_bridge, NULL);
    ggml_log_set(ggml_log_bridge, NULL);
}

// Haqiqatda ishlatilgan backendni aniqlaydi. Topilmasa "CPU" qaytaradi.
//
// DIQQAT: bu yerda ggml_backend_reg_count() ni sanash YETARLI EMAS edi.
// ggml-vulkan.dll vulkan-1.dll mavjud bo'lsa ro'yxatdan o'tadi — hatto
// bironta yaroqli qurilma topilmasa ham (drayver Vulkan 1.2 dan past,
// storageBuffer16BitAccess yo'q, videoxotira yetmaydi). Natijada whisper
// modelni protsessorda ishlatib turgan bo'lsa-da, ilova "Vulkan" deb
// yozardi: foydalanuvchi ~8 marta sekin ishlaydi va logda ham sabab
// ko'rinmaydi. Shuning uchun ro'yxatni emas, QURILMALARNI sanaymiz —
// whisper_backend_init_gpu ham aynan shu tekshiruvni bajaradi.
static void detect_backend(int use_gpu) {
    snprintf(g_backend, sizeof(g_backend), "CPU");
    if (!use_gpu) return;

    size_t n = ggml_backend_dev_count();
    for (size_t i = 0; i < n; i++) {
        ggml_backend_dev_t dev = ggml_backend_dev_get(i);
        if (!dev) continue;

        const enum ggml_backend_dev_type t = ggml_backend_dev_type(dev);
        if (t != GGML_BACKEND_DEVICE_TYPE_GPU &&
            t != GGML_BACKEND_DEVICE_TYPE_IGPU) continue;

        ggml_backend_reg_t reg = ggml_backend_dev_backend_reg(dev);
        const char *name = reg ? ggml_backend_reg_name(reg) : ggml_backend_dev_name(dev);
        snprintf(g_backend, sizeof(g_backend), "%s", name ? name : "GPU");

        // Diagnostika: videoxotira yetmasligi eng ko'p uchraydigan sabab.
        size_t freeMem = 0, totalMem = 0;
        ggml_backend_dev_memory(dev, &freeMem, &totalMem);
        if (totalMem) {
            char msg[192];
            snprintf(msg, sizeof(msg),
                     "GPU: %s (%s), xotira %zu/%zu MB bo'sh",
                     ggml_backend_dev_name(dev), g_backend,
                     freeMem / (1024 * 1024), totalMem / (1024 * 1024));
            if (g_log) g_log(msg);
        }
        return;
    }
}

int rubai_load_ex(const char *model_path, int use_gpu) {
    if (g_ctx) return 0;
    if (!model_path || !model_path[0]) {
        set_err("empty model path");
        return 1;
    }

    // Backend DLL'larini yuklaydi (ggml-vulkan.dll, ggml-cpu-*.dll).
    // GGML_BACKEND_DL bilan build qilinganda shart.
    ggml_backend_load_all();

    struct whisper_context_params cp = whisper_context_default_params();
    cp.use_gpu = use_gpu ? true : false;
    cp.flash_attn = true;
    g_ctx = whisper_init_from_file_with_params(model_path, cp);
    if (!g_ctx) {
        set_err("whisper_init_from_file_with_params failed");
        g_backend[0] = '\0';
        return 1;
    }
    detect_backend(use_gpu);
    set_err("");
    return 0;
}

int rubai_load(const char *model_path) {
    return rubai_load_ex(model_path, 1);
}

void rubai_unload(void) {
    if (g_ctx) {
        whisper_free(g_ctx);
        g_ctx = NULL;
    }
    g_backend[0] = '\0';
}

char *rubai_transcribe(const float *samples, int n_samples, int n_threads) {
    if (!g_ctx) { set_err("model not loaded"); return NULL; }
    if (!samples || n_samples <= 0) { set_err("no samples"); return NULL; }

    struct whisper_full_params p =
        whisper_full_default_params(WHISPER_SAMPLING_BEAM_SEARCH);
    p.language          = "uz";          // faqat o'zbek
    p.translate         = false;
    p.beam_search.beam_size = 5;         // maksimal aniqlik
    p.n_threads         = n_threads > 0 ? n_threads : 4;
    p.no_timestamps     = true;
    p.print_progress    = false;
    p.print_realtime    = false;
    p.print_special     = false;
    p.print_timestamps  = false;
    p.suppress_blank    = true;
    p.no_speech_thold   = 0.25f;   // past ovozlarni ham ushlash
    p.logprob_thold     = -1.0f;

    if (whisper_full(g_ctx, p, samples, n_samples) != 0) {
        set_err("whisper_full failed");
        return NULL;
    }

    int ns = whisper_full_n_segments(g_ctx);
    size_t len = 0;
    char *out = malloc(1);
    if (!out) { set_err("out of memory"); return NULL; }
    out[0] = '\0';
    for (int i = 0; i < ns; i++) {
        const char *t = whisper_full_get_segment_text(g_ctx, i);
        if (!t) continue;
        size_t tl = strlen(t);
        char *tmp = realloc(out, len + tl + 1);
        if (!tmp) { free(out); set_err("out of memory"); return NULL; }
        out = tmp;
        memcpy(out + len, t, tl);
        len += tl;
        out[len] = '\0';
    }
    set_err("");
    return out;
}

void rubai_free_str(char *s) { free(s); }

const char *rubai_last_error(void) { return g_err; }

const char *rubai_backend_name(void) { return g_backend; }
