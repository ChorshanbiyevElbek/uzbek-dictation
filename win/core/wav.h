// Oddiy WAV o'quvchi — testlar va CLI vositasi uchun.
//
// Ilovaning o'zi audio fayllarni Media Foundation orqali o'qiydi (mp3, mp4,
// m4a va h.k.). Bu yerdagi kod faqat WAV bilan ishlaydi va tashqi bog'liqliksiz
// bo'lgani uchun unit testlarda qulay.
#pragma once

#include <string>
#include <vector>

namespace rubai {

// WAV faylni 16 kHz mono float32 ga o'qiydi.
// PCM 8/16/24/32-bit va IEEE float 32/64-bit formatlarini qo'llab-quvvatlaydi.
// Xato bo'lsa false qaytaradi va `error` ga sabab yoziladi.
bool readWav16kMono(const std::wstring& path,
                    std::vector<float>& out,
                    std::wstring& error);

}  // namespace rubai
