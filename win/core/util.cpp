#include "util.h"

#include <windows.h>
#include <shlobj.h>

#include <cstdio>
#include <mutex>

namespace rubai {

// ---- Matn kodlash --------------------------------------------------------

std::string toUtf8(const std::wstring& w) {
    if (w.empty()) return {};
    int n = WideCharToMultiByte(CP_UTF8, 0, w.c_str(), (int)w.size(),
                                nullptr, 0, nullptr, nullptr);
    if (n <= 0) return {};
    std::string s((size_t)n, '\0');
    WideCharToMultiByte(CP_UTF8, 0, w.c_str(), (int)w.size(),
                        s.data(), n, nullptr, nullptr);
    return s;
}

std::wstring toWide(const std::string& s) {
    if (s.empty()) return {};
    int n = MultiByteToWideChar(CP_UTF8, 0, s.c_str(), (int)s.size(), nullptr, 0);
    if (n <= 0) return {};
    std::wstring w((size_t)n, L'\0');
    MultiByteToWideChar(CP_UTF8, 0, s.c_str(), (int)s.size(), w.data(), n);
    return w;
}

// ---- Yo'llar -------------------------------------------------------------

std::wstring exeDir() {
    std::wstring buf(MAX_PATH, L'\0');
    for (;;) {
        DWORD n = GetModuleFileNameW(nullptr, buf.data(), (DWORD)buf.size());
        if (n == 0) return {};
        if (n < buf.size()) { buf.resize(n); break; }
        buf.resize(buf.size() * 2);      // yo'l uzunroq — buferni kattalashtiramiz
    }
    size_t slash = buf.find_last_of(L'\\');
    return slash == std::wstring::npos ? buf : buf.substr(0, slash);
}

static std::wstring knownFolder(REFKNOWNFOLDERID id) {
    PWSTR p = nullptr;
    if (FAILED(SHGetKnownFolderPath(id, 0, nullptr, &p))) return {};
    std::wstring s = p ? p : L"";
    CoTaskMemFree(p);
    return s;
}

static std::wstring subDir(REFKNOWNFOLDERID id) {
    std::wstring base = knownFolder(id);
    if (base.empty()) return {};
    std::wstring dir = base + L"\\Audio-Matnga";
    ensureDir(dir);
    return dir;
}

std::wstring appDataDir()      { return subDir(FOLDERID_RoamingAppData); }
std::wstring localAppDataDir() { return subDir(FOLDERID_LocalAppData); }

bool fileExists(const std::wstring& path) {
    DWORD a = GetFileAttributesW(path.c_str());
    return a != INVALID_FILE_ATTRIBUTES && !(a & FILE_ATTRIBUTE_DIRECTORY);
}

bool ensureDir(const std::wstring& path) {
    if (path.empty()) return false;
    DWORD a = GetFileAttributesW(path.c_str());
    if (a != INVALID_FILE_ATTRIBUTES) return (a & FILE_ATTRIBUTE_DIRECTORY) != 0;
    // ota-papkalarni ham yaratamiz
    size_t slash = path.find_last_of(L'\\');
    if (slash != std::wstring::npos && slash > 2) ensureDir(path.substr(0, slash));
    return CreateDirectoryW(path.c_str(), nullptr) ||
           GetLastError() == ERROR_ALREADY_EXISTS;
}

static bool isAscii(const std::wstring& s) {
    for (wchar_t c : s) if (c > 127) return false;
    return true;
}

std::string pathForC(const std::wstring& path) {
    if (path.empty()) return {};

    // Oddiy holat: yo'l butunlay ASCII — to'g'ridan-to'g'ri uzatamiz.
    if (isAscii(path)) return toUtf8(path);

    // ASCII bo'lmagan belgi bor: 8.3 qisqa nomga o'girib ko'ramiz.
    DWORD n = GetShortPathNameW(path.c_str(), nullptr, 0);
    if (n > 0) {
        std::wstring shortPath(n, L'\0');
        DWORD got = GetShortPathNameW(path.c_str(), shortPath.data(), n);
        if (got > 0 && got < n) {
            shortPath.resize(got);
            if (isAscii(shortPath)) return toUtf8(shortPath);
        }
    }

    // Qisqa nomlar ham yordam bermadi — chaqiruvchi xatoni ko'rsatishi kerak.
    return {};
}

// ---- Log -----------------------------------------------------------------

namespace {
std::mutex g_logMutex;
std::wstring g_logPath;

std::wstring timestamp() {
    SYSTEMTIME st;
    GetLocalTime(&st);
    wchar_t buf[32];
    swprintf(buf, 32, L"%04d-%02d-%02d %02d:%02d:%02d",
             st.wYear, st.wMonth, st.wDay, st.wHour, st.wMinute, st.wSecond);
    return buf;
}
}  // namespace

std::wstring logPath() { return g_logPath; }

void logInit() {
    std::lock_guard<std::mutex> lock(g_logMutex);
    std::wstring dir = localAppDataDir();
    if (dir.empty()) return;
    g_logPath = dir + L"\\dictation.log";

    // Log 2 MB dan oshsa — bittalik zaxira qilib yangisini boshlaymiz.
    // Cheklovsiz o'sib ketmasligi uchun (obunachilarda oylab ishlaydi).
    WIN32_FILE_ATTRIBUTE_DATA fa{};
    if (GetFileAttributesExW(g_logPath.c_str(), GetFileExInfoStandard, &fa)) {
        ULONGLONG size = ((ULONGLONG)fa.nFileSizeHigh << 32) | fa.nFileSizeLow;
        if (size > 2ull * 1024 * 1024) {
            std::wstring old = g_logPath + L".1";
            DeleteFileW(old.c_str());
            MoveFileW(g_logPath.c_str(), old.c_str());
        }
    }
}

void logWrite(const std::wstring& msg) {
    OutputDebugStringW((L"[rubai] " + msg + L"\n").c_str());

    std::lock_guard<std::mutex> lock(g_logMutex);
    if (g_logPath.empty()) return;

    std::string line = toUtf8(timestamp() + L" " + msg + L"\r\n");
    HANDLE h = CreateFileW(g_logPath.c_str(), FILE_APPEND_DATA,
                           FILE_SHARE_READ | FILE_SHARE_WRITE, nullptr,
                           OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
    if (h == INVALID_HANDLE_VALUE) return;
    DWORD written = 0;
    WriteFile(h, line.data(), (DWORD)line.size(), &written, nullptr);
    CloseHandle(h);
}

}  // namespace rubai
