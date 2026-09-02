#include <windows.h>

#include "settings_window.h"

#include <commctrl.h>

#include <string>
#include <vector>

#include "../core/audio_capture.h"
#include "../core/util.h"
#include "autostart.h"

namespace rubai {

namespace {

constexpr wchar_t kClassName[] = L"AudioMatngaSettings";

enum CtrlId : int {
    kIdHotkey = 200,
    kIdMic,
    kIdMicWarning,
    kIdInsertMode,
    kIdAutoStart,
    kIdUseGpu,
    kIdSave,
    kIdCancel,
    kIdReset,
};

// Oyna o'lchamlari 96 DPI da; DPI bo'yicha masshtablanadi.
constexpr int kWinW = 460;
constexpr int kWinH = 400;

// HOTKEY boshqaruvi HOTKEYF_* bayroqlarini beradi, RegisterHotKey esa
// MOD_* kutadi — ular boshqacha qiymatlar.
UINT hotkeyFlagsToMod(BYTE flags) {
    UINT m = 0;
    if (flags & HOTKEYF_CONTROL) m |= MOD_CONTROL;
    if (flags & HOTKEYF_ALT)     m |= MOD_ALT;
    if (flags & HOTKEYF_SHIFT)   m |= MOD_SHIFT;
    return m;
}

BYTE modToHotkeyFlags(UINT mod) {
    BYTE f = 0;
    if (mod & MOD_CONTROL) f |= HOTKEYF_CONTROL;
    if (mod & MOD_ALT)     f |= HOTKEYF_ALT;
    if (mod & MOD_SHIFT)   f |= HOTKEYF_SHIFT;
    return f;
}

// Tugma nomini virtual key code'dan olamiz — sozlamalar faylida
// va menyuda ko'rsatish uchun.
std::wstring keyLabel(UINT vk) {
    const UINT scan = MapVirtualKeyW(vk, MAPVK_VK_TO_VSC);
    wchar_t name[64] = {};
    if (scan && GetKeyNameTextW((LONG)(scan << 16), name, 64) > 0) return name;
    if (vk >= 'A' && vk <= 'Z') return std::wstring(1, (wchar_t)vk);
    return L"Key" + std::to_wstring(vk);
}

// Oynani ishonchli tarzda oldinga chiqaradi.
//
// SetForegroundWindow yolg'iz o'zi YETARLI EMAS: Windows fonda ishlayotgan
// jarayonga faol oynani almashtirishni taqiqlaydi (foreground lock).
// Amalda tekshirildi — sozlamalar oynasi yaratilar, lekin boshqa ilova
// ostida ko'rinmay qolar edi.
//
// Yechim: faol oynaning kirish oqimiga vaqtincha ulanamiz — shunda tizim
// bizni "foydalanuvchi bilan ishlayotgan" deb hisoblaydi.
void forceForeground(HWND hwnd) {
    const HWND fg = GetForegroundWindow();
    const DWORD fgThread = fg ? GetWindowThreadProcessId(fg, nullptr) : 0;
    const DWORD myThread = GetCurrentThreadId();
    const bool attach = fgThread != 0 && fgThread != myThread;

    if (attach) AttachThreadInput(fgThread, myThread, TRUE);

    ShowWindow(hwnd, SW_SHOW);
    BringWindowToTop(hwnd);
    SetForegroundWindow(hwnd);
    SetActiveWindow(hwnd);

    if (attach) AttachThreadInput(fgThread, myThread, FALSE);

    // Baribir ochilmasa — vazifalar panelida miltillatib e'tibor tortamiz.
    if (GetForegroundWindow() != hwnd) {
        FLASHWINFO fi{sizeof(fi), hwnd, FLASHW_ALL | FLASHW_TIMERNOFG, 3, 0};
        FlashWindowEx(&fi);
    }
}

}  // namespace

struct SettingsWindow::Impl {
    HWND hwnd = nullptr;
    HINSTANCE instance = nullptr;
    HFONT font = nullptr;
    UINT dpi = 96;

    Settings settings;
    std::vector<MicDevice> mics;
    std::function<void(const Settings&)> onSaved;

    int scale(int v) const { return MulDiv(v, (int)dpi, 96); }

    void build();
    void fillMics();
    void updateMicWarning();
    void save();
    HWND ctrl(int id) const { return GetDlgItem(hwnd, id); }
};

namespace {

SettingsWindow::Impl* implOf(HWND h) {
    return reinterpret_cast<SettingsWindow::Impl*>(GetWindowLongPtrW(h, GWLP_USERDATA));
}

LRESULT CALLBACK settingsProc(HWND hwnd, UINT msg, WPARAM wp, LPARAM lp) {
    if (msg == WM_NCCREATE) {
        auto* cs = reinterpret_cast<CREATESTRUCTW*>(lp);
        SetWindowLongPtrW(hwnd, GWLP_USERDATA, (LONG_PTR)cs->lpCreateParams);
    }
    auto* d = implOf(hwnd);

    switch (msg) {
        case WM_COMMAND:
            if (!d) break;
            switch (LOWORD(wp)) {
                case kIdSave:
                    d->save();
                    ShowWindow(hwnd, SW_HIDE);
                    return 0;
                case kIdCancel:
                    ShowWindow(hwnd, SW_HIDE);
                    return 0;
                case kIdReset:
                    SendMessageW(d->ctrl(kIdHotkey), HKM_SETHOTKEY,
                                 MAKEWORD('D', HOTKEYF_CONTROL | HOTKEYF_ALT), 0);
                    return 0;
                case kIdMic:
                    if (HIWORD(wp) == CBN_SELCHANGE) d->updateMicWarning();
                    return 0;
            }
            break;

        case WM_CLOSE:
            ShowWindow(hwnd, SW_HIDE);
            return 0;

        case WM_CTLCOLORSTATIC: {
            // Yorliqlar va belgilash katakchalari oyna foni bilan bir xil
            // ko'rinishi kerak — aks holda ular kulrang tasma bo'lib chiqadi.
            auto hdc = (HDC)wp;
            SetBkMode(hdc, TRANSPARENT);
            if (d && (HWND)lp == d->ctrl(kIdMicWarning)) {
                SetTextColor(hdc, RGB(176, 92, 0));   // ogohlantirish — to'q sariq
            }
            return (LRESULT)GetSysColorBrush(COLOR_WINDOW);
        }
    }
    return DefWindowProcW(hwnd, msg, wp, lp);
}

}  // namespace

// -------------------------------------------------------------- qurilish

void SettingsWindow::Impl::build() {
    auto S = [&](int v) { return scale(v); };

    auto add = [&](const wchar_t* cls, const wchar_t* text, DWORD style,
                   int x, int y, int w, int h, int id) {
        HWND c = CreateWindowExW(0, cls, text, WS_CHILD | WS_VISIBLE | style,
                                 S(x), S(y), S(w), S(h), hwnd,
                                 (HMENU)(INT_PTR)id, instance, nullptr);
        if (c) SendMessageW(c, WM_SETFONT, (WPARAM)font, TRUE);
        return c;
    };

    // --- Diktovka tugmasi
    add(L"STATIC", L"Diktovka tugmasi", 0, 24, 20, 200, 18, -1);
    add(HOTKEY_CLASSW, L"", 0, 24, 42, 200, 26, kIdHotkey);
    add(L"BUTTON", L"Standart (Ctrl+Alt+D)", BS_PUSHBUTTON, 236, 42, 190, 26, kIdReset);
    add(L"STATIC", L"Kamida bitta modifikator (Ctrl, Alt, Shift) kerak.",
        0, 24, 72, 400, 16, -1);

    // --- Mikrofon
    add(L"STATIC", L"Mikrofon", 0, 24, 106, 200, 18, -1);
    add(L"COMBOBOX", L"", CBS_DROPDOWNLIST | WS_VSCROLL | WS_TABSTOP,
        24, 128, 402, 200, kIdMic);
    add(L"STATIC", L"", SS_LEFT, 24, 160, 402, 52, kIdMicWarning);

    // --- Matn kiritish usuli
    add(L"STATIC", L"Matnni kiritish usuli", 0, 24, 218, 200, 18, -1);
    HWND mode = add(L"COMBOBOX", L"", CBS_DROPDOWNLIST | WS_TABSTOP,
                    24, 240, 402, 120, kIdInsertMode);
    SendMessageW(mode, CB_ADDSTRING, 0,
                 (LPARAM)L"Tez (clipboard orqali qo'yish) — tavsiya etiladi");
    SendMessageW(mode, CB_ADDSTRING, 0,
                 (LPARAM)L"Sekin (belgima-belgi yozish) — qo'yish ishlamasa");

    // --- Bayroqlar
    add(L"BUTTON", L"Kompyuter yonganda avtomatik ishga tushsin",
        BS_AUTOCHECKBOX | WS_TABSTOP, 24, 278, 402, 22, kIdAutoStart);
    add(L"BUTTON", L"Videokartadan foydalanish (tezroq)",
        BS_AUTOCHECKBOX | WS_TABSTOP, 24, 304, 402, 22, kIdUseGpu);

    // --- Tugmalar
    add(L"BUTTON", L"Saqlash", BS_DEFPUSHBUTTON | WS_TABSTOP, 236, 342, 92, 30, kIdSave);
    add(L"BUTTON", L"Bekor qilish", BS_PUSHBUTTON | WS_TABSTOP, 334, 342, 92, 30, kIdCancel);
}

void SettingsWindow::Impl::fillMics() {
    HWND combo = ctrl(kIdMic);
    SendMessageW(combo, CB_RESETCONTENT, 0, 0);

    mics = listMicrophones();

    SendMessageW(combo, CB_ADDSTRING, 0, (LPARAM)L"(tizim standarti)");
    int select = 0;

    for (size_t i = 0; i < mics.size(); i++) {
        std::wstring label = mics[i].name;
        switch (mics[i].kind) {
            case MicKind::Loopback:  label += L"   [mikrofon emas!]"; break;
            case MicKind::Bluetooth: label += L"   [sifat past]"; break;
            case MicKind::Virtual:   label += L"   [virtual]"; break;
            default: break;
        }
        if (mics[i].isDefault) label += L"   (standart)";
        SendMessageW(combo, CB_ADDSTRING, 0, (LPARAM)label.c_str());
        if (!settings.micDeviceId.empty() && mics[i].id == settings.micDeviceId) {
            select = (int)i + 1;
        }
    }

    SendMessageW(combo, CB_SETCURSEL, select, 0);
    updateMicWarning();
}

void SettingsWindow::Impl::updateMicWarning() {
    const int sel = (int)SendMessageW(ctrl(kIdMic), CB_GETCURSEL, 0, 0);
    std::wstring text;

    if (sel > 0 && (size_t)(sel - 1) < mics.size()) {
        text = mics[sel - 1].warning();
    } else if (sel == 0) {
        // Standart qurilma xavfli bo'lishi mumkin — tekshiramiz.
        for (const auto& m : mics) {
            if (m.isDefault && m.kind != MicKind::Normal) {
                text = L"Tizim standarti: " + m.name + L"\n" + m.warning();
                break;
            }
        }
    }
    SetWindowTextW(ctrl(kIdMicWarning), text.c_str());
}

void SettingsWindow::Impl::save() {
    // --- Hotkey
    const WORD hk = (WORD)SendMessageW(ctrl(kIdHotkey), HKM_GETHOTKEY, 0, 0);
    const BYTE vk = LOBYTE(hk);
    const BYTE flags = HIBYTE(hk);
    const UINT mods = hotkeyFlagsToMod(flags);

    if (vk != 0 && mods != 0) {
        settings.vkCode = vk;
        settings.modifiers = mods;
        settings.hotkeyLabel = keyLabel(vk);
    } else {
        MessageBoxW(hwnd,
                    L"Tugma saqlanmadi: kamida bitta modifikator\n"
                    L"(Ctrl, Alt yoki Shift) va bitta tugma kerak.\n\n"
                    L"Oldingi tugma o'zgarishsiz qoldi.",
                    L"Sozlamalar", MB_OK | MB_ICONWARNING);
    }

    // --- Mikrofon
    const int sel = (int)SendMessageW(ctrl(kIdMic), CB_GETCURSEL, 0, 0);
    if (sel > 0 && (size_t)(sel - 1) < mics.size()) {
        settings.micDeviceId = mics[sel - 1].id;
        settings.micDeviceName = mics[sel - 1].name;
    } else {
        settings.micDeviceId.clear();
        settings.micDeviceName.clear();
    }

    // --- Qolgan sozlamalar
    settings.insertMode =
        SendMessageW(ctrl(kIdInsertMode), CB_GETCURSEL, 0, 0) == 1
            ? InsertMode::Type : InsertMode::Paste;

    const bool autoStart = SendMessageW(ctrl(kIdAutoStart), BM_GETCHECK, 0, 0) == BST_CHECKED;
    settings.autoStart = autoStart;
    settings.useGpu = SendMessageW(ctrl(kIdUseGpu), BM_GETCHECK, 0, 0) == BST_CHECKED;

    setAutoStart(autoStart);

    if (!saveSettings(settings)) {
        MessageBoxW(hwnd, L"Sozlamalar saqlanmadi. Diskda joy bormi?",
                    L"Sozlamalar", MB_OK | MB_ICONERROR);
        return;
    }
    logWrite(L"sozlamalar saqlandi: " + settings.hotkeyDisplay());
    if (onSaved) onSaved(settings);
}

// ------------------------------------------------------------------- API

SettingsWindow::SettingsWindow() : d(new Impl) {}

SettingsWindow::~SettingsWindow() {
    if (d->hwnd) DestroyWindow(d->hwnd);
    if (d->font) DeleteObject(d->font);
    delete d;
}

void SettingsWindow::setOnSaved(std::function<void(const Settings&)> cb) {
    d->onSaved = std::move(cb);
}

void SettingsWindow::show(HINSTANCE instance, const Settings& current) {
    d->settings = current;

    if (!d->hwnd) {
        d->instance = instance;

        INITCOMMONCONTROLSEX icc{sizeof(icc), ICC_HOTKEY_CLASS | ICC_STANDARD_CLASSES};
        InitCommonControlsEx(&icc);

        WNDCLASSEXW wc{};
        wc.cbSize = sizeof(wc);
        wc.lpfnWndProc = settingsProc;
        wc.hInstance = instance;
        wc.lpszClassName = kClassName;
        wc.hCursor = LoadCursorW(nullptr, IDC_ARROW);
        wc.hbrBackground = (HBRUSH)(COLOR_WINDOW + 1);
        wc.hIcon = LoadIconW(instance, MAKEINTRESOURCEW(101));
        if (!wc.hIcon) wc.hIcon = LoadIconW(nullptr, IDI_APPLICATION);
        RegisterClassExW(&wc);

        d->hwnd = CreateWindowExW(
            0, kClassName, L"Audio-Matnga — Sozlamalar",
            WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU,
            CW_USEDEFAULT, CW_USEDEFAULT, 100, 100,
            nullptr, nullptr, instance, d);
        if (!d->hwnd) {
            logWrite(L"XATO: sozlamalar oynasi yaratilmadi");
            return;
        }

        d->dpi = GetDpiForWindow(d->hwnd);
        d->font = CreateFontW(-d->scale(13), 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE,
                              DEFAULT_CHARSET, OUT_TT_PRECIS, CLIP_DEFAULT_PRECIS,
                              CLEARTYPE_QUALITY, VARIABLE_PITCH, L"Segoe UI");

        // Mijoz maydoni aynan kerakli o'lchamda bo'lishi uchun ramka
        // qalinligini hisobga olamiz.
        RECT rc{0, 0, d->scale(kWinW), d->scale(kWinH)};
        AdjustWindowRectExForDpi(&rc, WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU,
                                 FALSE, 0, d->dpi);
        SetWindowPos(d->hwnd, nullptr, 0, 0, rc.right - rc.left, rc.bottom - rc.top,
                     SWP_NOMOVE | SWP_NOZORDER);

        d->build();
    }

    // Joriy qiymatlarni qo'yamiz
    SendMessageW(d->ctrl(kIdHotkey), HKM_SETHOTKEY,
                 MAKEWORD(current.vkCode, modToHotkeyFlags(current.modifiers)), 0);
    SendMessageW(d->ctrl(kIdInsertMode), CB_SETCURSEL,
                 current.insertMode == InsertMode::Type ? 1 : 0, 0);
    SendMessageW(d->ctrl(kIdAutoStart), BM_SETCHECK,
                 autoStartEnabled() ? BST_CHECKED : BST_UNCHECKED, 0);
    SendMessageW(d->ctrl(kIdUseGpu), BM_SETCHECK,
                 current.useGpu ? BST_CHECKED : BST_UNCHECKED, 0);

    // Qurilmalar ro'yxatini har safar yangilaymiz — foydalanuvchi oyna
    // ochiq bo'lmagan paytda mikrofon ulagan bo'lishi mumkin.
    d->fillMics();

    // Oynani kursor turgan monitorda markazlashtiramiz
    POINT pt;
    GetCursorPos(&pt);
    HMONITOR mon = MonitorFromPoint(pt, MONITOR_DEFAULTTOPRIMARY);
    MONITORINFO mi{sizeof(mi)};
    GetMonitorInfoW(mon, &mi);
    RECT wr;
    GetWindowRect(d->hwnd, &wr);
    const int w = wr.right - wr.left, h = wr.bottom - wr.top;
    SetWindowPos(d->hwnd, HWND_TOP,
                 mi.rcWork.left + (mi.rcWork.right - mi.rcWork.left - w) / 2,
                 mi.rcWork.top + (mi.rcWork.bottom - mi.rcWork.top - h) / 2,
                 0, 0, SWP_NOSIZE);

    forceForeground(d->hwnd);
}

}  // namespace rubai
