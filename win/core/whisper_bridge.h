#ifndef RUBAI_WHISPER_BRIDGE_H
#define RUBAI_WHISPER_BRIDGE_H

#ifdef __cplusplus
extern "C" {
#endif

// Modelni yuklaydi (bir marta). 0 = muvaffaqiyat.
// macOS versiyasi bilan bir xil imzo — o'zgartirilmaydi.
int rubai_load(const char *model_path);

// Windows kengaytmasi: GPU'ni majburan o'chirish mumkin (CPU fallback uchun).
// use_gpu = 0 bo'lsa faqat CPU backend ishlatiladi.
int rubai_load_ex(const char *model_path, int use_gpu);

// Modelni RAM'dan bo'shatadi.
void rubai_unload(void);

// 16kHz mono float32 namunalardan lotin o'zbek matn qaytaradi.
// Qaytgan satrni rubai_free_str bilan bo'shating. NULL = xato.
char *rubai_transcribe(const float *samples, int n_samples, int n_threads);

void rubai_free_str(char *s);

// Oxirgi xatoning qisqa tavsifi (ingliz tilida, log uchun). Hech qachon NULL emas.
const char *rubai_last_error(void);

// Faol backend nomi: "Vulkan", "CUDA", "CPU" yoki "" (yuklanmagan).
// Foydalanuvchiga qaysi rejimda ishlayotganini ko'rsatish uchun.
const char *rubai_backend_name(void);

// whisper.cpp va ggml o'z xabarlarini stderr'ga chiqaradi. Grafik ilovada
// stderr yo'q, shuning uchun ularni o'z logimizga yo'naltiramiz.
// fn = NULL bo'lsa xabarlar butunlay o'chiriladi.
// rubai_load dan OLDIN chaqirilishi kerak.
typedef void (*rubai_log_fn)(const char *msg);
void rubai_set_log(rubai_log_fn fn);

#ifdef __cplusplus
}
#endif

#endif
