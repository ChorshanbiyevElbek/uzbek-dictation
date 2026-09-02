// Kompyuter yonganda avtomatik ishga tushirish.
//
// macOS versiyasida bu SMAppService / LaunchAgent edi (dictate.swift:589).
// Windows'da registry `Run` kaliti — administrator huquqi kerak emas.
#pragma once

namespace rubai {

bool autoStartEnabled();

// Yoqadi yoki o'chiradi. Muvaffaqiyatda true.
bool setAutoStart(bool enable);

}  // namespace rubai
