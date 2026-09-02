// Matnni faol oynaga kiritish.
//
// macOS versiyasidagi `Inserter` ning ekvivalenti (dictate.swift:350).
// MUHIM FARQ: macOS'da bu Accessibility ruxsatini talab qiladi,
// Windows'da hech qanday ruxsat kerak emas.
#pragma once

#include <string>

#include "../core/config.h"

namespace rubai {

struct InsertResult {
    bool ok = false;
    std::wstring error;      // muvaffaqiyatsizlikda — o'zbekcha sabab
    bool clipboardHasText = false;   // matn hech bo'lmasa clipboard'da
};

// Matnni faol maydonga kiritadi.
//
// Paste rejimi: clipboard + Ctrl+V (tez, uzun matnlar uchun).
// Type rejimi:  belgima-belgi Unicode kiritish (paste'ni bloklaydigan
//               ilovalar — ba'zi bank va o'yin oynalari uchun).
InsertResult insertText(const std::wstring& text, InsertMode mode);

// Faol oyna administrator huquqi bilan ishlayaptimi.
//
// Windows'da past huquqli jarayon yuqori huquqli oynaga tugma yubora
// olmaydi (UIPI) — SendInput jimgina muvaffaqiyatsiz bo'ladi. Buni
// oldindan aniqlab foydalanuvchiga tushunarli xabar beramiz.
bool foregroundWindowIsElevated();

}  // namespace rubai
