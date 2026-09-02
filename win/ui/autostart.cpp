#include "autostart.h"

#include <windows.h>

#include <string>

#include "../core/util.h"

namespace rubai {

namespace {

constexpr wchar_t kRunKey[]   = L"Software\\Microsoft\\Windows\\CurrentVersion\\Run";
constexpr wchar_t kValueName[] = L"Audio-Matnga";

std::wstring exePath() {
    std::wstring buf(MAX_PATH, L'\0');
    for (;;) {
        const DWORD n = GetModuleFileNameW(nullptr, buf.data(), (DWORD)buf.size());
        if (n == 0) return {};
        if (n < buf.size()) { buf.resize(n); return buf; }
        buf.resize(buf.size() * 2);
    }
}

// Registry qiymati tirnoq ichida bo'lishi kerak — yo'lda bo'shliq bo'lsa
// ("C:\Program Files\...") Windows uni bir necha argumentga bo'lib yuboradi.
std::wstring quotedExePath() {
    const std::wstring p = exePath();
    return p.empty() ? p : L"\"" + p + L"\"";
}

}  // namespace

bool autoStartEnabled() {
    HKEY key = nullptr;
    if (RegOpenKeyExW(HKEY_CURRENT_USER, kRunKey, 0, KEY_QUERY_VALUE, &key) != ERROR_SUCCESS) {
        return false;
    }

    wchar_t value[1024] = {};
    DWORD size = sizeof(value);
    DWORD type = 0;
    const LSTATUS st = RegQueryValueExW(key, kValueName, nullptr, &type,
                                        (LPBYTE)value, &size);
    RegCloseKey(key);

    if (st != ERROR_SUCCESS || type != REG_SZ) return false;

    // Ilova boshqa papkaga ko'chirilgan bo'lishi mumkin — eski yozuv
    // "yoqilgan" deb hisoblanmasin.
    return _wcsicmp(value, quotedExePath().c_str()) == 0;
}

bool setAutoStart(bool enable) {
    HKEY key = nullptr;
    if (RegCreateKeyExW(HKEY_CURRENT_USER, kRunKey, 0, nullptr, 0,
                        KEY_SET_VALUE, nullptr, &key, nullptr) != ERROR_SUCCESS) {
        logWrite(L"XATO: Run kaliti ochilmadi");
        return false;
    }

    LSTATUS st;
    if (enable) {
        const std::wstring value = quotedExePath();
        st = RegSetValueExW(key, kValueName, 0, REG_SZ,
                            (const BYTE*)value.c_str(),
                            (DWORD)((value.size() + 1) * sizeof(wchar_t)));
    } else {
        st = RegDeleteValueW(key, kValueName);
        if (st == ERROR_FILE_NOT_FOUND) st = ERROR_SUCCESS;   // allaqachon o'chirilgan
    }
    RegCloseKey(key);

    if (st != ERROR_SUCCESS) {
        logWrite(L"XATO: avtostart o'zgartirilmadi, kod " + std::to_wstring(st));
        return false;
    }
    logWrite(enable ? L"avtostart yoqildi" : L"avtostart o'chirildi");
    return true;
}

}  // namespace rubai
