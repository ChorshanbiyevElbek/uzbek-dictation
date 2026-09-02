#include <windows.h>

#include "overlay.h"

#include <dwmapi.h>

#include <algorithm>
#include <string>

#include "../core/util.h"

namespace rubai {

namespace {

constexpr wchar_t kClassName[] = L"AudioMatngaOverlay";
constexpr UINT kTimerHide = 1;

constexpr int kBaseWidth   = 340;
constexpr int kBaseHeight  = 64;
constexpr int kProgHeight  = 108;
constexpr int kCorner      = 14;
constexpr int kMarginX     = 18;

// Windows 11 22H2+ da oynaga akril fon berish uchun.
#ifndef DWMWA_SYSTEMBACKDROP_TYPE
#define DWMWA_SYSTEMBACKDROP_TYPE 38
#endif
#ifndef DWMWA_WINDOW_CORNER_PREFERENCE
#define DWMWA_WINDOW_CORNER_PREFERENCE 33
#endif
#ifndef DWMWA_USE_IMMERSIVE_DARK_MODE
#define DWMWA_USE_IMMERSIVE_DARK_MODE 20
#endif

const wchar_t* iconGlyph(OverlayIcon i) {
    switch (i) {
        case OverlayIcon::Recording: return L"\x25CF";   // ● to'ldirilgan doira
        case OverlayIcon::Working:   return L"\x22EF";   // ⋯
        case OverlayIcon::Done:      return L"\x2713";   // ✓
        case OverlayIcon::Warning:   return L"\x26A0";   // ⚠
    }
    return L"";
}

COLORREF iconColor(OverlayIcon i) {
    switch (i) {
        case OverlayIcon::Recording: return RGB(255, 69, 58);
        case OverlayIcon::Working:   return RGB(160, 160, 165);
        case OverlayIcon::Done:      return RGB(48, 209, 88);
        case OverlayIcon::Warning:   return RGB(255, 189, 46);
    }
    return RGB(255, 255, 255);
}

}  // namespace

struct Overlay::Impl {
    HWND hwnd = nullptr;
    HINSTANCE instance = nullptr;
    UINT dpi = 96;

    OverlayIcon icon = OverlayIcon::Recording;
    std::wstring text;
    std::wstring status;
    double progress = -1.0;      // < 0 => progress bar yo'q

    HFONT fontText = nullptr;
    HFONT fontIcon = nullptr;
    HFONT fontSmall = nullptr;

    int scale(int v) const { return MulDiv(v, (int)dpi, 96); }

    void rebuildFonts();
    void resizeAndPosition();
    void paint(HDC hdc, const RECT& rc);
};

namespace {

Overlay::Impl* implOf(HWND hwnd) {
    return reinterpret_cast<Overlay::Impl*>(GetWindowLongPtrW(hwnd, GWLP_USERDATA));
}

LRESULT CALLBACK overlayProc(HWND hwnd, UINT msg, WPARAM wp, LPARAM lp) {
    if (msg == WM_NCCREATE) {
        auto* cs = reinterpret_cast<CREATESTRUCTW*>(lp);
        SetWindowLongPtrW(hwnd, GWLP_USERDATA, (LONG_PTR)cs->lpCreateParams);
    }

    auto* d = implOf(hwnd);

    switch (msg) {
        case WM_PAINT: {
            PAINTSTRUCT ps;
            HDC hdc = BeginPaint(hwnd, &ps);
            RECT rc;
            GetClientRect(hwnd, &rc);
            if (d) d->paint(hdc, rc);
            EndPaint(hwnd, &ps);
            return 0;
        }

        case WM_TIMER:
            if (wp == kTimerHide) {
                KillTimer(hwnd, kTimerHide);
                ShowWindow(hwnd, SW_HIDE);
            }
            return 0;

        case WM_DPICHANGED:
            if (d) {
                d->dpi = HIWORD(wp);
                d->rebuildFonts();
                d->resizeAndPosition();
                InvalidateRect(hwnd, nullptr, TRUE);
            }
            return 0;

        // Sichqoncha oynadan o'tib ketsin — u ostidagi ilovaga xalaqit
        // qilmasligi kerak.
        case WM_NCHITTEST:
            return HTTRANSPARENT;

        // Fokusni hech qachon olmaymiz.
        case WM_MOUSEACTIVATE:
            return MA_NOACTIVATE;

        case WM_ERASEBKGND:
            return 1;
    }
    return DefWindowProcW(hwnd, msg, wp, lp);
}

}  // namespace

// ------------------------------------------------------------------ chizish

void Overlay::Impl::rebuildFonts() {
    if (fontText)  { DeleteObject(fontText);  fontText = nullptr; }
    if (fontIcon)  { DeleteObject(fontIcon);  fontIcon = nullptr; }
    if (fontSmall) { DeleteObject(fontSmall); fontSmall = nullptr; }

    auto makeFont = [&](int px, int weight) {
        return CreateFontW(-scale(px), 0, 0, 0, weight, FALSE, FALSE, FALSE,
                           DEFAULT_CHARSET, OUT_TT_PRECIS, CLIP_DEFAULT_PRECIS,
                           CLEARTYPE_QUALITY, VARIABLE_PITCH, L"Segoe UI");
    };
    fontText  = makeFont(15, FW_SEMIBOLD);
    fontIcon  = makeFont(22, FW_NORMAL);
    fontSmall = makeFont(12, FW_NORMAL);
}

void Overlay::Impl::paint(HDC hdc, const RECT& rc) {
    // Fonni o'zimiz chizamiz. DWM akril qo'llanmagan tizimlarda ham
    // oyna qorong'i va o'qilishi oson bo'lishi kerak.
    HBRUSH bg = CreateSolidBrush(RGB(28, 28, 30));
    FillRect(hdc, &rc, bg);
    DeleteObject(bg);

    SetBkMode(hdc, TRANSPARENT);

    const int iconW = scale(28);
    const int left = scale(kMarginX);

    // Ikonka
    HFONT old = (HFONT)SelectObject(hdc, fontIcon);
    SetTextColor(hdc, iconColor(icon));
    RECT ir{left, rc.top, left + iconW, rc.bottom};
    if (progress >= 0.0) ir.bottom = rc.top + scale(38);
    DrawTextW(hdc, iconGlyph(icon), -1, &ir,
              DT_LEFT | DT_VCENTER | DT_SINGLELINE | DT_NOPREFIX);

    // Asosiy matn
    SelectObject(hdc, fontText);
    SetTextColor(hdc, RGB(245, 245, 247));
    RECT tr{left + iconW + scale(8), rc.top, rc.right - scale(kMarginX), rc.bottom};

    if (progress >= 0.0) {
        tr.bottom = rc.top + scale(38);
        DrawTextW(hdc, text.c_str(), -1, &tr,
                  DT_LEFT | DT_VCENTER | DT_SINGLELINE | DT_PATH_ELLIPSIS | DT_NOPREFIX);

        // Progress chizig'i
        const int barX = left;
        const int barW = rc.right - scale(kMarginX) - barX;
        const int barY = rc.top + scale(52);
        const int barH = scale(6);

        HBRUSH track = CreateSolidBrush(RGB(60, 60, 64));
        RECT trk{barX, barY, barX + barW, barY + barH};
        FillRect(hdc, &trk, track);
        DeleteObject(track);

        const int fillW = (int)(barW * std::clamp(progress, 0.0, 1.0));
        if (fillW > 0) {
            HBRUSH fill = CreateSolidBrush(RGB(10, 132, 255));
            RECT f{barX, barY, barX + fillW, barY + barH};
            FillRect(hdc, &f, fill);
            DeleteObject(fill);
        }

        SelectObject(hdc, fontSmall);
        SetTextColor(hdc, RGB(160, 160, 165));
        RECT sr{barX, barY + barH + scale(6), rc.right - scale(kMarginX), rc.bottom};
        DrawTextW(hdc, status.c_str(), -1, &sr,
                  DT_LEFT | DT_TOP | DT_SINGLELINE | DT_END_ELLIPSIS | DT_NOPREFIX);
    } else {
        // DT_VCENTER faqat DT_SINGLELINE bilan ishlaydi. Ko'p qatorli matnni
        // markazlash uchun avval balandligini o'lchab, keyin siljitamiz.
        RECT measure = tr;
        DrawTextW(hdc, text.c_str(), -1, &measure,
                  DT_LEFT | DT_WORDBREAK | DT_NOPREFIX | DT_CALCRECT);
        const int textH = measure.bottom - measure.top;
        const int offset = ((rc.bottom - rc.top) - textH) / 2;
        if (offset > 0) {
            tr.top += offset;
            tr.bottom = tr.top + textH;
        }
        DrawTextW(hdc, text.c_str(), -1, &tr,
                  DT_LEFT | DT_WORDBREAK | DT_NOPREFIX);
    }

    SelectObject(hdc, old);
}

void Overlay::Impl::resizeAndPosition() {
    const int w = scale(kBaseWidth);
    const int h = scale(progress >= 0.0 ? kProgHeight : kBaseHeight);

    // Kursor turgan monitorga joylashtiramiz — ko'p monitorli tizimda
    // foydalanuvchi ishlayotgan ekranda ko'rinsin.
    POINT pt;
    GetCursorPos(&pt);
    HMONITOR mon = MonitorFromPoint(pt, MONITOR_DEFAULTTOPRIMARY);
    MONITORINFO mi{sizeof(mi)};
    GetMonitorInfoW(mon, &mi);

    const int x = mi.rcWork.left + (mi.rcWork.right - mi.rcWork.left - w) / 2;
    const int y = mi.rcWork.bottom - h - scale(120);

    SetWindowPos(hwnd, HWND_TOPMOST, x, y, w, h, SWP_NOACTIVATE);

    HRGN rgn = CreateRoundRectRgn(0, 0, w + 1, h + 1, scale(kCorner), scale(kCorner));
    SetWindowRgn(hwnd, rgn, TRUE);   // egalik oynaga o'tadi
}

// ---------------------------------------------------------------------- API

Overlay::Overlay() : d(new Impl) {}

Overlay::~Overlay() {
    if (d->hwnd) DestroyWindow(d->hwnd);
    if (d->fontText)  DeleteObject(d->fontText);
    if (d->fontIcon)  DeleteObject(d->fontIcon);
    if (d->fontSmall) DeleteObject(d->fontSmall);
    delete d;
}

bool Overlay::create(HINSTANCE instance) {
    d->instance = instance;

    WNDCLASSEXW wc{};
    wc.cbSize = sizeof(wc);
    wc.lpfnWndProc = overlayProc;
    wc.hInstance = instance;
    wc.lpszClassName = kClassName;
    wc.hCursor = LoadCursorW(nullptr, IDC_ARROW);
    RegisterClassExW(&wc);   // takroriy ro'yxatdan o'tish xatosi zararsiz

    // WS_EX_NOACTIVATE — fokusni o'g'irlamaydi (eng muhim bayroq).
    // WS_EX_TOOLWINDOW — Alt+Tab ro'yxatida ko'rinmaydi.
    // WS_EX_TRANSPARENT — sichqoncha bosishlari ostidagi oynaga o'tadi.
    d->hwnd = CreateWindowExW(
        WS_EX_LAYERED | WS_EX_TRANSPARENT | WS_EX_TOOLWINDOW |
            WS_EX_NOACTIVATE | WS_EX_TOPMOST,
        kClassName, L"", WS_POPUP,
        0, 0, kBaseWidth, kBaseHeight,
        nullptr, nullptr, instance, d);

    if (!d->hwnd) {
        logWrite(L"XATO: overlay oynasi yaratilmadi");
        return false;
    }

    d->dpi = GetDpiForWindow(d->hwnd);
    d->rebuildFonts();

    SetLayeredWindowAttributes(d->hwnd, 0, 235, LWA_ALPHA);

    // Windows 11: yumaloq burchak + akril fon. Eski tizimlarda bu
    // chaqiruvlar shunchaki e'tiborsiz qoladi.
    const DWORD corner = 2;      // DWMWCP_ROUND
    DwmSetWindowAttribute(d->hwnd, DWMWA_WINDOW_CORNER_PREFERENCE, &corner, sizeof(corner));
    const DWORD backdrop = 3;    // DWMSBT_TRANSIENTWINDOW (akril)
    DwmSetWindowAttribute(d->hwnd, DWMWA_SYSTEMBACKDROP_TYPE, &backdrop, sizeof(backdrop));
    const BOOL dark = TRUE;
    DwmSetWindowAttribute(d->hwnd, DWMWA_USE_IMMERSIVE_DARK_MODE, &dark, sizeof(dark));

    return true;
}

void Overlay::show(OverlayIcon icon, const std::wstring& text, int autoHideMs) {
    if (!d->hwnd) return;

    d->icon = icon;
    d->text = text;
    d->progress = -1.0;

    KillTimer(d->hwnd, kTimerHide);
    d->resizeAndPosition();
    InvalidateRect(d->hwnd, nullptr, TRUE);

    // SW_SHOWNOACTIVATE — ko'rsatamiz, lekin faollashtirmaymiz.
    ShowWindow(d->hwnd, SW_SHOWNOACTIVATE);
    UpdateWindow(d->hwnd);

    if (autoHideMs > 0) SetTimer(d->hwnd, kTimerHide, (UINT)autoHideMs, nullptr);
}

void Overlay::showProgress(const std::wstring& title, double progress,
                           const std::wstring& status) {
    if (!d->hwnd) return;

    d->icon = OverlayIcon::Working;
    d->text = title;
    d->status = status;
    d->progress = std::clamp(progress, 0.0, 1.0);

    KillTimer(d->hwnd, kTimerHide);
    d->resizeAndPosition();
    InvalidateRect(d->hwnd, nullptr, TRUE);
    ShowWindow(d->hwnd, SW_SHOWNOACTIVATE);
    UpdateWindow(d->hwnd);
}

void Overlay::hide() {
    if (!d->hwnd) return;
    KillTimer(d->hwnd, kTimerHide);
    ShowWindow(d->hwnd, SW_HIDE);
}

}  // namespace rubai
