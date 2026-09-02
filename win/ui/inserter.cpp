#include "inserter.h"

#include <windows.h>

#include <thread>
#include <vector>

#include "../core/util.h"

namespace rubai {

namespace {

// Clipboard'ni ochish. Boshqa ilova uni band qilgan bo'lishi mumkin,
// shuning uchun bir necha marta urinamiz.
bool openClipboard(HWND owner) {
    for (int i = 0; i < 10; i++) {
        if (OpenClipboard(owner)) return true;
        Sleep(20);
    }
    return false;
}

std::wstring clipboardGetText() {
    if (!openClipboard(nullptr)) return {};
    std::wstring out;
    HANDLE h = GetClipboardData(CF_UNICODETEXT);
    if (h) {
        if (const wchar_t* p = (const wchar_t*)GlobalLock(h)) {
            out = p;
            GlobalUnlock(h);
        }
    }
    CloseClipboard();
    return out;
}

bool clipboardSetText(const std::wstring& text) {
    const size_t bytes = (text.size() + 1) * sizeof(wchar_t);
    HGLOBAL h = GlobalAlloc(GMEM_MOVEABLE, bytes);
    if (!h) return false;

    void* p = GlobalLock(h);
    if (!p) { GlobalFree(h); return false; }
    memcpy(p, text.c_str(), bytes);
    GlobalUnlock(h);

    if (!openClipboard(nullptr)) { GlobalFree(h); return false; }
    EmptyClipboard();
    if (!SetClipboardData(CF_UNICODETEXT, h)) {
        // Muvaffaqiyatsizlikda xotira hali bizniki — bo'shatamiz.
        CloseClipboard();
        GlobalFree(h);
        return false;
    }
    // Muvaffaqiyatdan keyin xotira egaligi tizimga o'tadi — GlobalFree QILMAYMIZ.
    CloseClipboard();
    return true;
}

INPUT keyInput(WORD vk, bool up) {
    INPUT in{};
    in.type = INPUT_KEYBOARD;
    in.ki.wVk = vk;
    in.ki.dwFlags = up ? KEYEVENTF_KEYUP : 0;
    return in;
}

INPUT unicodeInput(wchar_t ch, bool up) {
    INPUT in{};
    in.type = INPUT_KEYBOARD;
    in.ki.wVk = 0;
    in.ki.wScan = ch;
    in.ki.dwFlags = KEYEVENTF_UNICODE | (up ? KEYEVENTF_KEYUP : 0);
    return in;
}

// Foydalanuvchi hotkey uchun bosgan modifikatorlar hali qo'yib
// yuborilmagan bo'lishi mumkin. Ctrl+V yuborishdan oldin ularni
// "qo'yib yuborilgan" holatga keltiramiz, aks holda ilova Ctrl+Alt+V
// yoki Shift+Ctrl+V ko'radi va boshqa amal bajaradi.
void releaseStuckModifiers(std::vector<INPUT>& seq) {
    const WORD mods[] = {VK_LMENU, VK_RMENU, VK_LSHIFT, VK_RSHIFT,
                         VK_LWIN, VK_RWIN};
    for (WORD vk : mods) {
        if (GetAsyncKeyState(vk) & 0x8000) seq.push_back(keyInput(vk, true));
    }
    // Ctrl alohida: uni Ctrl+V uchun BOSILGAN holatda ushlab turamiz,
    // shuning uchun bu yerda qo'yib yubormaymiz.
}

bool sendAll(const std::vector<INPUT>& seq) {
    if (seq.empty()) return true;
    const UINT sent = SendInput((UINT)seq.size(),
                                const_cast<INPUT*>(seq.data()), sizeof(INPUT));
    return sent == seq.size();
}

bool pasteViaCtrlV() {
    std::vector<INPUT> seq;
    releaseStuckModifiers(seq);

    const bool ctrlDown = (GetAsyncKeyState(VK_CONTROL) & 0x8000) != 0;
    if (!ctrlDown) seq.push_back(keyInput(VK_CONTROL, false));
    seq.push_back(keyInput('V', false));
    seq.push_back(keyInput('V', true));
    if (!ctrlDown) seq.push_back(keyInput(VK_CONTROL, true));

    return sendAll(seq);
}

bool typeUnicode(const std::wstring& text) {
    std::vector<INPUT> seq;
    releaseStuckModifiers(seq);
    if (GetAsyncKeyState(VK_CONTROL) & 0x8000) seq.push_back(keyInput(VK_CONTROL, true));
    if (!sendAll(seq)) return false;

    // Katta matnni bo'laklab yuboramiz — SendInput navbati cheklangan
    // va ba'zi ilovalar tez oqimni tashlab yuboradi.
    constexpr size_t kChunk = 32;
    std::vector<INPUT> chunk;
    chunk.reserve(kChunk * 2);

    for (size_t i = 0; i < text.size(); i++) {
        const wchar_t ch = text[i];
        if (ch == L'\r') continue;
        if (ch == L'\n') {
            chunk.push_back(keyInput(VK_RETURN, false));
            chunk.push_back(keyInput(VK_RETURN, true));
        } else {
            chunk.push_back(unicodeInput(ch, false));
            chunk.push_back(unicodeInput(ch, true));
        }
        if (chunk.size() >= kChunk * 2) {
            if (!sendAll(chunk)) return false;
            chunk.clear();
            Sleep(1);
        }
    }
    return sendAll(chunk);
}

}  // namespace

bool foregroundWindowIsElevated() {
    HWND hwnd = GetForegroundWindow();
    if (!hwnd) return false;

    DWORD pid = 0;
    GetWindowThreadProcessId(hwnd, &pid);
    if (!pid) return false;

    HANDLE proc = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pid);
    if (!proc) {
        // Jarayonni ocholmadik — bu odatda uning huquqi bizdan yuqori
        // ekanini bildiradi.
        return true;
    }
    CloseHandle(proc);
    return false;
}

InsertResult insertText(const std::wstring& text, InsertMode mode) {
    InsertResult r;

    if (text.empty()) {
        r.error = L"Matn bo'sh";
        return r;
    }

    if (mode == InsertMode::Type) {
        // Bu rejimda clipboard ishlatilmaydi — foydalanuvchining
        // nusxalangan matni saqlanib qoladi.
        if (typeUnicode(text)) { r.ok = true; return r; }
        r.error = L"Matn kiritilmadi";
        return r;
    }

    const std::wstring previous = clipboardGetText();

    if (!clipboardSetText(text)) {
        r.error = L"Clipboard band — matn qo'yilmadi.\nBir oz kutib qayta urinib ko'ring.";
        return r;
    }
    r.clipboardHasText = true;

    // Clipboard egasi almashishi uchun qisqa pauza. Busiz ba'zi ilovalar
    // eski mazmunni qo'yib yuboradi.
    Sleep(40);

    if (!pasteViaCtrlV()) {
        r.error = L"Matn joylanmadi, lekin u clipboard'da — Ctrl+V bosing.";
        return r;
    }

    // Eski clipboard mazmunini tiklaymiz (macOS versiyasidagidek).
    // Paste yakunlanishi uchun kutamiz — juda erta tiklasak, ilova
    // eski matnni qo'yadi.
    if (!previous.empty()) {
        std::thread([previous] {
            Sleep(700);
            clipboardSetText(previous);
        }).detach();
    }

    r.ok = true;
    return r;
}

}  // namespace rubai
