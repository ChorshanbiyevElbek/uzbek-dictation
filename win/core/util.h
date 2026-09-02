// Umumiy yordamchilar: matn kodlash, yo'llar, log.
#pragma once

#include <string>
#include <vector>

namespace rubai {

// ---- Matn kodlash --------------------------------------------------------
// Windows'da ichkarida hamma joyda wstring (UTF-16), C kutubxonalari bilan
// muloqotda UTF-8. Bu ikkalasi orasidagi ko'prik.
std::string  toUtf8(const std::wstring& w);
std::wstring toWide(const std::string& s);

// ---- Yo'llar -------------------------------------------------------------

// Ilova .exe joylashgan papka (oxirida \ yo'q).
std::wstring exeDir();

// %APPDATA%\Audio-Matnga — sozlamalar. Papka yaratiladi.
std::wstring appDataDir();

// %LOCALAPPDATA%\Audio-Matnga — log va vaqtinchalik fayllar. Papka yaratiladi.
std::wstring localAppDataDir();

bool fileExists(const std::wstring& path);
bool ensureDir(const std::wstring& path);

// Yo'lni C kutubxonalari (whisper.cpp) uchun tayyorlaydi.
//
// MUHIM: whisper.cpp fayl yo'lini oddiy `char*` sifatida oladi va uni
// Windows'da ANSI kodlashda ochadi. Foydalanuvchi nomi lotin bo'lmasa
// (masalan C:\Users\Аброр\...) model ochilmaydi.
//
// Shuning uchun: yo'lda ASCII bo'lmagan belgi bo'lsa, GetShortPathNameW
// orqali 8.3 qisqa nomga o'giramiz (C:\Users\ABROR~1\...). Qisqa nomlar
// o'chirilgan disklarda bu ishlamaydi — shu sababli model baribir ASCII
// yo'lga (ilova papkasiga) o'rnatiladi, bu faqat zaxira mexanizm.
//
// Bo'sh satr = yo'lni xavfsiz uzatib bo'lmadi.
std::string pathForC(const std::wstring& path);

// ---- Log -----------------------------------------------------------------
// %LOCALAPPDATA%\Audio-Matnga\dictation.log ga yozadi (thread-safe).
// macOS versiyasidagi RubaiLog bilan bir xil vazifa.
void logInit();
void logWrite(const std::wstring& msg);
std::wstring logPath();

}  // namespace rubai
