// Whisper yadrosi — model yuklash, transkripsiya, RAM'ni bo'shatish.
//
// macOS versiyasidagi `Whisper` sinfining ekvivalenti (dictate.swift:35).
// Bitta ishchi oqim (thread) barcha inference chaqiruvlarini navbat bilan
// bajaradi — whisper_context global singleton bo'lgani uchun bu shart.
#pragma once

#include <functional>
#include <string>
#include <vector>

namespace rubai {

struct TranscribeResult {
    std::wstring text;      // muvaffaqiyatda — tanilgan matn
    std::wstring error;     // xato bo'lsa — o'zbekcha xabar
    double seconds = 0.0;   // qancha vaqt ketdi
    bool ok() const { return error.empty(); }
};

class Engine {
public:
    static Engine& instance();

    // Model faylini qidiradi. Tartib:
    //   1) <exe papkasi>\models\ggml-rubaistt.bin   (o'rnatilgan holat)
    //   2) <exe papkasi>\ggml-rubaistt.bin          (portable holat)
    //   3) %LOCALAPPDATA%\Audio-Matnga\models\...       (qo'lda qo'yilgan)
    // Topilmasa bo'sh satr.
    static std::wstring findModel();

    // Model yo'lini majburan belgilash (test va CLI uchun).
    void setModelPath(const std::wstring& path);

    void setUseGpu(bool on);
    void setIdleUnloadSeconds(int seconds);

    // Modelni fonda oldindan yuklaydi va GPU quvurini isitadi.
    //
    // Buni ilova ishga tushganda chaqirish kerak. Aks holda birinchi
    // diktovkada foydalanuvchi model yuklanishini VA Vulkan shader
    // kompilyatsiyasini kutadi — bu sekin kompyuterlarda o'nlab soniya.
    // Bloklamaydi.
    void preload();

    // Transkripsiyani navbatga qo'yadi. `done` ISHCHI OQIMDA chaqiriladi —
    // UI'ga tegishli ish qiluvchi chaqiruvchi uni asosiy oqimga o'tkazishi kerak.
    void transcribeAsync(std::vector<float> samples,
                         std::function<void(TranscribeResult)> done);

    // Sinxron variant (CLI va testlar uchun).
    TranscribeResult transcribe(const std::vector<float>& samples);

    void unload();
    bool isLoaded() const;

    // Faol backend: "Vulkan", "CUDA", "CPU" yoki bo'sh (yuklanmagan).
    std::wstring backendName() const;

    // Ishchi oqimni to'xtatadi. Ilova yopilishida chaqiriladi.
    void shutdown();

private:
    Engine();
    ~Engine();
    Engine(const Engine&) = delete;
    Engine& operator=(const Engine&) = delete;

    struct Impl;
    Impl* d;
};

}  // namespace rubai
