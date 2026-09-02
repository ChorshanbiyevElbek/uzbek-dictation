#include "engine.h"

#include <windows.h>

#include <atomic>
#include <chrono>
#include <condition_variable>
#include <deque>
#include <mutex>
#include <thread>

#include "samples.h"
#include "util.h"
#include "whisper_bridge.h"

namespace rubai {

namespace {

constexpr wchar_t kModelFileName[] = L"ggml-rubaistt.bin";

int defaultThreads() {
    // macOS versiyasi bilan bir xil qoida: yadrolar soni - 2, kamida 4.
    SYSTEM_INFO si{};
    GetSystemInfo(&si);
    int n = (int)si.dwNumberOfProcessors - 2;
    return n < 4 ? 4 : n;
}

// whisper.cpp/ggml xabarlari -> bizning log fayl.
// (Grafik ilovada stderr yo'q, bu xabarlar aks holda yo'qoladi.)
void forwardWhisperLog(const char* msg) {
    if (!msg) return;
    std::wstring w = toWide(msg);
    while (!w.empty() && (w.back() == L'\n' || w.back() == L'\r')) w.pop_back();
    if (!w.empty()) logWrite(L"whisper: " + w);
}

}  // namespace

// Qulflash qoidasi:
//   - `mu` navbat, stopping, preloadQueued va lastUse ni himoya qiladi.
//   - `loaded` atomik: model holatini uzoq davom etadigan yuklash paytida
//     ham to'sqinliksiz o'qish mumkin bo'lishi kerak.
//   - `backend` alohida qisqa qulf ostida — u faqat matn ko'rsatish uchun.
//   - whisper_context'ga FAQAT ishchi oqim tegadi (u global singleton).
struct Engine::Impl {
    struct Job {
        std::vector<float> samples;
        std::function<void(TranscribeResult)> done;
    };

    std::wstring modelPath;             // faqat setModelPath/ishchi oqim, mu ostida
    std::atomic<bool> useGpu{true};
    std::atomic<int>  idleSeconds{180};
    std::atomic<bool> loaded{false};
    // Bir martalik bo'shatish so'rovi (Engine::unload). Idle taymeridan
    // alohida: ilgari unload() idleSeconds ni 10 ga tushirib qo'yardi va
    // uni hech qachon tiklamasdi — natijada butun seans davomida model
    // har 10 soniya bo'sh turishda RAM'dan chiqib ketardi.
    std::atomic<bool> unloadRequested{false};

    mutable std::mutex mu;
    std::condition_variable cv;
    std::deque<Job> queue;
    bool stopping = false;
    bool preloadQueued = false;
    std::chrono::steady_clock::time_point lastUse = std::chrono::steady_clock::now();

    mutable std::mutex backendMu;
    std::wstring backend;

    std::thread worker;

    void run();
    TranscribeResult doTranscribe(const std::vector<float>& samples);
    bool ensureLoaded(std::wstring& errOut);
    void warmUp();
    void unloadFromWorker();

    void setBackend(const std::wstring& b) {
        std::lock_guard<std::mutex> lock(backendMu);
        backend = b;
    }
};

// ---------------------------------------------------------------- yuklash

bool Engine::Impl::ensureLoaded(std::wstring& errOut) {
    if (loaded.load()) return true;

    std::wstring path;
    {
        std::lock_guard<std::mutex> lock(mu);
        path = modelPath;
    }
    if (path.empty()) path = Engine::findModel();
    if (path.empty()) {
        errOut = L"Model fayli topilmadi. Ilovani qayta o'rnating.";
        logWrite(L"XATO: model fayli topilmadi");
        return false;
    }

    // whisper.cpp yo'lni char* sifatida oladi — lotin bo'lmagan foydalanuvchi
    // nomlarida (C:\Users\Аброр\...) qisqa 8.3 yo'lga o'tkaziladi.
    const std::string cpath = pathForC(path);
    if (cpath.empty()) {
        errOut = L"Model yo'lida qo'llab-quvvatlanmaydigan belgilar bor.\n"
                 L"Ilovani lotin harfli papkaga o'rnating.";
        logWrite(L"XATO: model yo'li C uchun tayyorlanmadi: " + path);
        return false;
    }

    const bool wantGpu = useGpu.load();
    logWrite(L"model yuklanmoqda: " + path + (wantGpu ? L" (GPU)" : L" (CPU)"));
    const auto t0 = std::chrono::steady_clock::now();
    int rc = rubai_load_ex(cpath.c_str(), wantGpu ? 1 : 0);

    if (rc != 0 && wantGpu) {
        // GPU'da yuklanmadi — CPU'ga tushamiz. Obunachilarning eski yoki
        // drayveri buzuq GPU'larida ilova baribir ishlashi kerak.
        logWrite(L"GPU'da yuklanmadi (" + toWide(rubai_last_error()) +
                 L") — CPU'ga o'tilmoqda");
        rc = rubai_load_ex(cpath.c_str(), 0);
    }

    if (rc != 0) {
        errOut = L"Model yuklanmadi. Fayl buzilgan bo'lishi mumkin —\n"
                 L"ilovani qayta o'rnating.";
        logWrite(L"XATO: rubai_load = " + std::to_wstring(rc) + L" (" +
                 toWide(rubai_last_error()) + L")");
        return false;
    }

    const double secs = std::chrono::duration<double>(
        std::chrono::steady_clock::now() - t0).count();
    setBackend(toWide(rubai_backend_name()));
    loaded.store(true);
    logWrite(L"model yuklandi: " + toWide(rubai_backend_name()) + L", " +
             std::to_wstring((int)(secs * 1000)) + L" ms");

    warmUp();
    return true;
}

// Vulkan (va qisman CUDA) birinchi inference'da shader/pipeline'larni
// kompilyatsiya qiladi. Uni shu yerda, foydalanuvchi kutmayotgan paytda
// o'tkazamiz — aks holda BIRINCHI diktovka o'nlab soniya davom etadi.
//
// Encoder har doim 30 soniyalik oynada ishlaydi, shuning uchun qisqa
// namuna ham butun quvurni isitadi.
void Engine::Impl::warmUp() {
    const auto t0 = std::chrono::steady_clock::now();

    // Toza sukunat emas — juda past shovqin. Sukunatda whisper erta
    // to'xtashi va quvurning bir qismi isimay qolishi mumkin.
    std::vector<float> dummy(16000);
    for (size_t i = 0; i < dummy.size(); i++) {
        dummy[i] = (float)((i * 2654435761u) % 2001) / 1000.0f * 0.001f - 0.001f;
    }

    char* c = rubai_transcribe(dummy.data(), (int)dummy.size(), defaultThreads());
    if (c) rubai_free_str(c);

    const double secs = std::chrono::duration<double>(
        std::chrono::steady_clock::now() - t0).count();
    logWrite(L"isitish tugadi: " + std::to_wstring((int)(secs * 1000)) + L" ms");
}

void Engine::Impl::unloadFromWorker() {
    if (!loaded.load()) return;
    rubai_unload();
    loaded.store(false);
    setBackend(L"");
}

// ------------------------------------------------------------ transkripsiya

TranscribeResult Engine::Impl::doTranscribe(const std::vector<float>& samples) {
    TranscribeResult r;

    if (samples.empty()) {
        r.error = L"Ovoz yozilmadi";
        return r;
    }

    std::wstring err;
    if (!ensureLoaded(err)) {
        r.error = err;
        return r;
    }

    const auto t0 = std::chrono::steady_clock::now();
    char* c = rubai_transcribe(samples.data(), (int)samples.size(), defaultThreads());
    r.seconds = std::chrono::duration<double>(
        std::chrono::steady_clock::now() - t0).count();

    if (!c) {
        r.error = L"Transkripsiya bajarilmadi";
        logWrite(L"XATO: rubai_transcribe = NULL (" + toWide(rubai_last_error()) + L")");
        return r;
    }

    r.text = toWide(c);
    rubai_free_str(c);

    // Bosh/oxirgi bo'shliqlarni olib tashlaymiz (whisper segmentlari
    // odatda " " bilan boshlanadi).
    const size_t a = r.text.find_first_not_of(L" \t\r\n");
    if (a == std::wstring::npos) {
        r.text.clear();
    } else {
        const size_t b = r.text.find_last_not_of(L" \t\r\n");
        r.text = r.text.substr(a, b - a + 1);
    }
    return r;
}

// ------------------------------------------------------------- ishchi oqim

void Engine::Impl::run() {
    for (;;) {
        Job job;
        bool haveJob = false;

        {
            std::unique_lock<std::mutex> lock(mu);

            // Aniq bo'shatish so'rovi (masalan GPU rejimi o'zgardi) — idle
            // taymerini kutmasdan darhol bajaramiz. Shundan keyin navbatdagi
            // preload modelni yangi backend bilan qayta yuklaydi.
            if (unloadRequested.exchange(false)) {
                unloadFromWorker();
                logWrite(L"model RAM'dan bo'shatildi (so'rov bo'yicha)");
            }

            // Navbat bo'sh bo'lsa: idle vaqtigacha kutamiz, so'ng modelni
            // RAM'dan bo'shatamiz (macOS versiyasidagi 180 s qoidasi).
            while (queue.empty() && !stopping && !preloadQueued) {
                if (!loaded.load()) {
                    cv.wait(lock);
                    continue;
                }
                const auto deadline = lastUse + std::chrono::seconds(idleSeconds.load());
                if (cv.wait_until(lock, deadline) == std::cv_status::timeout &&
                    queue.empty() && !preloadQueued &&
                    std::chrono::steady_clock::now() >= deadline) {
                    unloadFromWorker();
                    logWrite(L"model RAM'dan bo'shatildi (ishlatilmadi)");
                }
            }

            if (stopping && queue.empty()) break;

            if (!queue.empty()) {
                job = std::move(queue.front());
                queue.pop_front();
                haveJob = true;
            }
            preloadQueued = false;
        }

        if (!haveJob) {
            // Oldindan yuklash so'rovi — model va GPU quvurini tayyorlaymiz.
            std::wstring err;
            ensureLoaded(err);
            std::lock_guard<std::mutex> lock(mu);
            lastUse = std::chrono::steady_clock::now();
            continue;
        }

        TranscribeResult r = doTranscribe(job.samples);

        {
            std::lock_guard<std::mutex> lock(mu);
            lastUse = std::chrono::steady_clock::now();
        }
        if (job.done) job.done(std::move(r));
    }

    unloadFromWorker();
}

// ------------------------------------------------------------------- API

Engine::Engine() : d(new Impl) {
    rubai_set_log(forwardWhisperLog);
    d->worker = std::thread([this] { d->run(); });
}

Engine::~Engine() {
    shutdown();
    delete d;
}

Engine& Engine::instance() {
    static Engine e;
    return e;
}

std::wstring Engine::findModel() {
    const std::wstring exe = exeDir();
    const std::wstring local = localAppDataDir();
    const std::wstring candidates[] = {
        exe.empty()   ? std::wstring() : exe + L"\\models\\" + kModelFileName,
        exe.empty()   ? std::wstring() : exe + L"\\" + kModelFileName,
        local.empty() ? std::wstring() : local + L"\\models\\" + kModelFileName,
    };
    for (const auto& p : candidates) {
        if (!p.empty() && fileExists(p)) return p;
    }
    return {};
}

void Engine::setModelPath(const std::wstring& path) {
    std::lock_guard<std::mutex> lock(d->mu);
    d->modelPath = path;
}

void Engine::setUseGpu(bool on) { d->useGpu = on; }

void Engine::setIdleUnloadSeconds(int seconds) {
    d->idleSeconds = seconds < 10 ? 10 : seconds;
}

void Engine::preload() {
    {
        std::lock_guard<std::mutex> lock(d->mu);
        if (d->stopping || d->preloadQueued) return;
        // `loaded` bo'lsa ham, bo'shatish so'rovi kutayotgan bo'lsa navbatga
        // qo'yamiz — aks holda unload()+preload() juftligi hech narsa
        // qilmasdi va model qayta yuklanmay qolardi.
        if (d->loaded.load() && !d->unloadRequested.load()) return;
        d->preloadQueued = true;
    }
    d->cv.notify_one();
}

void Engine::transcribeAsync(std::vector<float> samples,
                             std::function<void(TranscribeResult)> done) {
    {
        std::lock_guard<std::mutex> lock(d->mu);
        if (d->stopping) return;
        d->queue.push_back({std::move(samples), std::move(done)});
        d->lastUse = std::chrono::steady_clock::now();
    }
    d->cv.notify_one();
}

TranscribeResult Engine::transcribe(const std::vector<float>& samples) {
    // Sinxron chaqiruv — ishchi oqimga qo'yib, natijani kutamiz.
    std::mutex m;
    std::condition_variable cv;
    bool ready = false;
    TranscribeResult result;

    transcribeAsync(samples, [&](TranscribeResult r) {
        std::lock_guard<std::mutex> lock(m);
        result = std::move(r);
        ready = true;
        cv.notify_one();
    });

    std::unique_lock<std::mutex> lock(m);
    cv.wait(lock, [&] { return ready; });
    return result;
}

void Engine::unload() {
    // Modelni faqat ishchi oqim bo'shatishi mumkin (whisper_context unga
    // tegishli), shuning uchun bayroq qo'yib uni uyg'otamiz. Foydalanuvchi
    // sozlagan idle vaqtiga tegilmaydi.
    d->unloadRequested = true;
    d->cv.notify_one();
}

bool Engine::isLoaded() const { return d->loaded.load(); }

std::wstring Engine::backendName() const {
    std::lock_guard<std::mutex> lock(d->backendMu);
    return d->backend;
}

void Engine::shutdown() {
    {
        std::lock_guard<std::mutex> lock(d->mu);
        if (d->stopping) return;
        d->stopping = true;
    }
    d->cv.notify_all();
    if (d->worker.joinable()) d->worker.join();
}

}  // namespace rubai
