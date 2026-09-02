// Audio namunalarni whisper uchun tayyorlash.
#pragma once

#include <vector>

namespace rubai {

// Audio sifati haqida qaror — foydalanuvchiga aniq xabar berish uchun.
enum class AudioVerdict {
    Ok,          // normal signal
    TooShort,    // 1 soniyadan qisqa
    Silent,      // signal deyarli yo'q — mikrofon jim/ulanmagan
    VeryQuiet,   // juda past, lekin kuchaytirsa bo'ladi
};

struct AudioCheck {
    AudioVerdict verdict = AudioVerdict::Ok;
    float peak = 0.0f;       // eng baland namuna, 0..1
    float seconds = 0.0f;
};

// Signalni tekshiradi. Jim oqimni aniqlash Windows'da muhim: Iriun, OBS,
// VB-Cable kabi virtual mikrofonlar va ulanmagan Bluetooth qurilmalari
// "OK" holatida ko'rinib, aslida raqamli sukunat beradi.
AudioCheck checkSamples(const std::vector<float>& samples);

// macOS versiyasidagi prepareSamples bilan bir xil: eng baland namunani
// 0.95 ga olib chiqadi (maksimal 40x), past mikrofon signali uchun.
std::vector<float> prepareSamples(const std::vector<float>& raw);

}  // namespace rubai
