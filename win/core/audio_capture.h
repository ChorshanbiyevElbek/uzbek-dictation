// Mikrofondan yozib olish — WASAPI.
//
// macOS versiyasidagi `Recorder` sinfining ekvivalenti (dictate.swift:79).
// Natija: 16 kHz mono float32 — whisper aynan shuni kutadi.
#pragma once

#include <string>
#include <vector>

namespace rubai {

// Mikrofonning turi. Windows'da qurilmalar ro'yxati chalg'ituvchi bo'ladi:
// "Stereo Mix" mikrofon emas (kompyuter ovozini yozadi), Bluetooth
// quloqchin esa past sifatli. Foydalanuvchini ogohlantirish uchun kerak.
enum class MicKind {
    Normal,
    Loopback,     // Stereo Mix / "What U Hear" — ovoz emas, tizim ovozi
    Bluetooth,    // HFP profil: 8-16 kHz, siqilgan — aniqlik pasayadi
    Virtual,      // Iriun, OBS, VB-Cable — manba ishlamasa jim oqim beradi
};

struct MicDevice {
    std::wstring id;        // WASAPI qurilma ID (sozlamalarda saqlanadi)
    std::wstring name;      // foydalanuvchiga ko'rinadigan nom
    MicKind kind = MicKind::Normal;
    bool isDefault = false;

    // Foydalanuvchi uchun ogohlantirish matni; ogohlantirish yo'q bo'lsa bo'sh.
    std::wstring warning() const;
};

// Tizimdagi faol kirish qurilmalari. Xato bo'lsa bo'sh ro'yxat.
std::vector<MicDevice> listMicrophones();

// Yozib oluvchi. Bir vaqtda faqat bitta yozuv.
class AudioCapture {
public:
    AudioCapture();
    ~AudioCapture();
    AudioCapture(const AudioCapture&) = delete;
    AudioCapture& operator=(const AudioCapture&) = delete;

    // Yozishni boshlaydi. deviceId bo'sh bo'lsa tizim standarti ishlatiladi.
    //
    // Har chaqiruvda WASAPI klienti YANGIDAN yaratiladi. macOS versiyasi ham
    // shunday qiladi (dictate.swift:103) — qurilma almashtirilgandan yoki
    // kompyuter uyqudan uyg'ongandan keyin eski klient qotib qoladi.
    bool start(const std::wstring& deviceId, std::wstring& error);

    // Yozishni to'xtatib, 16 kHz mono float32 namunalarni qaytaradi.
    std::vector<float> stop();

    bool isRecording() const;

    // Yozish davomida oqim uzilganmi (qurilma chiqarib olindi va h.k.).
    bool deviceLost() const;

private:
    struct Impl;
    Impl* d;
};

}  // namespace rubai
