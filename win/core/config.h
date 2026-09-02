// Foydalanuvchi sozlamalari — %APPDATA%\Audio-Matnga\settings.ini
//
// macOS versiyasida bu UserDefaults edi. Windows'da oddiy `kalit=qiymat`
// UTF-8 matn fayli ishlatiladi: qo'lda tahrirlash oson, parser xatolari yo'q,
// tashqi kutubxona kerak emas.
#pragma once

#include <string>

namespace rubai {

// Matnni faol oynaga qanday joylash.
enum class InsertMode {
    Paste,   // clipboard + Ctrl+V — tez, uzun matnlar uchun (standart)
    Type,    // belgima-belgi Unicode kiritish — paste'ni bloklaydigan ilovalar uchun
};

struct Settings {
    // Hotkey. Standart: Ctrl+Alt+D (macOS'dagi ⌃⌥D ning ekvivalenti).
    unsigned vkCode = 'D';           // virtual key code
    unsigned modifiers = 0;          // MOD_CONTROL | MOD_ALT (0 = standartni qo'llash)
    std::wstring hotkeyLabel = L"D";

    // Mikrofon. Bo'sh = tizim standarti.
    // MUHIM: Windows'da standart qurilma "Stereo Mix" bo'lib qolishi mumkin —
    // u ovoz o'rniga kompyuter ovozini yozadi. Shuning uchun aniq tanlash bor.
    std::wstring micDeviceId;
    std::wstring micDeviceName;      // faqat ko'rsatish uchun

    InsertMode insertMode = InsertMode::Paste;
    bool autoStart = true;
    bool useGpu = true;              // false = majburan CPU
    int idleUnloadSeconds = 180;     // model RAM'dan bo'shash vaqti
    bool didOnboard = false;         // Welcome oynasi ko'rsatilganmi

    // Ekranda ko'rinishi, masalan "Ctrl+Alt+D"
    std::wstring hotkeyDisplay() const;
};

// Diskdan o'qiydi. Fayl yo'q/buzuq bo'lsa standart qiymatlar qaytadi —
// hech qachon xato bermaydi (obunachi kompyuterida ilova ishga tushmay
// qolmasligi uchun).
Settings loadSettings();

bool saveSettings(const Settings& s);

std::wstring settingsPath();

}  // namespace rubai
