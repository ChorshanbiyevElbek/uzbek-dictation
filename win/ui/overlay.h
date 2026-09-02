// Suzuvchi holat oynasi (HUD).
//
// macOS versiyasidagi `Overlay` ning ekvivalenti (dictate.swift:143).
// Eng muhim xususiyati: fokusni O'G'IRLAMAYDI — foydalanuvchi yozayotgan
// maydon faol qolishi kerak, aks holda matn noto'g'ri joyga tushadi.
#pragma once

#include <string>

namespace rubai {

enum class OverlayIcon {
    Recording,   // 🔴 yozilmoqda
    Working,     // ⏳ matnga o'girilmoqda
    Done,        // ✅ tayyor
    Warning,     // ⚠️ ogohlantirish
};

class Overlay {
public:
    Overlay();
    ~Overlay();
    Overlay(const Overlay&) = delete;
    Overlay& operator=(const Overlay&) = delete;

    bool create(HINSTANCE instance);

    // Matnli holat ko'rsatadi. autoHideMs > 0 bo'lsa shu vaqtdan keyin
    // o'zi yashiriladi.
    void show(OverlayIcon icon, const std::wstring& text, int autoHideMs = 0);

    // Progress bilan (fayl transkripsiyasi uchun). progress: 0..1
    void showProgress(const std::wstring& title, double progress,
                      const std::wstring& status);

    void hide();

    // Oyna protsedurasi (erkin funksiya) shu tuzilmaga murojaat qiladi,
    // shuning uchun e'lon ochiq; ta'rifi .cpp faylda.
    struct Impl;

private:
    Impl* d;
};

}  // namespace rubai
