// Audio-Matnga — Windows ilovasi.
//
// macOS versiyasidagi dictate.swift ning ekvivalenti. U bitta faylda
// `// MARK:` bo'limlariga bo'lingan — bu yerda ham shunday tuzilma
// saqlangan, ikkala platformani solishtirish oson bo'lishi uchun.
//
// Oqim: Ctrl+Alt+D -> AudioCapture -> Ctrl+Alt+D -> Engine -> Inserter

#include <windows.h>
#include <shellapi.h>

#include <memory>
#include <string>

#include "../core/audio_capture.h"
#include "../core/config.h"
#include "../core/engine.h"
#include "../core/samples.h"
#include "../core/util.h"
#include "autostart.h"
#include "inserter.h"
#include "overlay.h"
#include "settings_window.h"

namespace rubai {
namespace {

// ---------------------------------------------------------------- doimiylar

constexpr wchar_t kWindowClass[] = L"AudioMatngaHiddenWindow";
constexpr wchar_t kMutexName[]   = L"Global\\AudioMatngaSingleInstance";
constexpr wchar_t kAppName[]     = L"Audio-Matnga";

constexpr UINT WM_RUBAI_TRAY   = WM_APP + 1;
constexpr UINT WM_RUBAI_RESULT = WM_APP + 2;

constexpr int kHotkeyId = 1;

enum MenuId : UINT {
    kMenuDictate  = 100,
    kMenuSettings = 101,
    kMenuLog      = 102,
    kMenuQuit     = 103,
};

// Explorer qayta ishga tushganda tray ikonasi yo'qoladi va uni qayta
// qo'shish kerak. Windows buni shu xabar bilan bildiradi.
UINT g_taskbarCreated = 0;

// Ikkinchi nusxa ishlab turgan nusxaga "Sozlamalarni ko'rsat" deyish uchun.
// RegisterWindowMessage tizim bo'ylab yagona raqam beradi, shuning uchun
// ikkala jarayon ham bir xil qiymatni oladi.
UINT g_showSettings = 0;

// ------------------------------------------------------------------ ilova

class App {
public:
    bool init(HINSTANCE instance);
    void run();
    void shutdown();

private:
    static LRESULT CALLBACK wndProc(HWND, UINT, WPARAM, LPARAM);
    LRESULT handle(HWND, UINT, WPARAM, LPARAM);

    bool createWindow(HINSTANCE instance);
    bool addTrayIcon();
    void removeTrayIcon();
    void updateTrayTip(const std::wstring& text);
    void showMenu();

    bool registerHotkey();
    void toggleDictation();
    void startRecording();
    void stopAndTranscribe();

    void onResult(const TranscribeResult& r);
    void notify(const std::wstring& title, const std::wstring& text, DWORD icon);

    HINSTANCE instance_ = nullptr;
    HWND hwnd_ = nullptr;
    NOTIFYICONDATAW tray_{};
    bool trayAdded_ = false;

    void applySettings(const Settings& s);

    Settings settings_;
    AudioCapture capture_;
    Overlay overlay_;
    SettingsWindow settingsWindow_;
    bool recording_ = false;
    bool busy_ = false;      // transkripsiya ketmoqda

    // Natija ishchi oqimdan keladi; UI faqat asosiy oqimda o'zgaradi,
    // shuning uchun natijani shu yerga qo'yib, oynaga xabar yuboramiz.
    std::unique_ptr<TranscribeResult> pending_;
};

App* g_app = nullptr;

// ------------------------------------------------------------------- oyna

bool App::createWindow(HINSTANCE instance) {
    instance_ = instance;

    WNDCLASSEXW wc{};
    wc.cbSize = sizeof(wc);
    wc.lpfnWndProc = &App::wndProc;
    wc.hInstance = instance;
    wc.lpszClassName = kWindowClass;
    if (!RegisterClassExW(&wc)) {
        logWrite(L"XATO: oyna klassi ro'yxatdan o'tmadi");
        return false;
    }

    // Ko'rinmas oyna: faqat xabarlarni qabul qilish uchun (hotkey, tray).
    // HWND_MESSAGE ishlatmaymiz — bunday oynalar tray xabarlarini olmaydi.
    hwnd_ = CreateWindowExW(0, kWindowClass, kAppName, 0,
                            0, 0, 0, 0, nullptr, nullptr, instance, this);
    if (!hwnd_) {
        logWrite(L"XATO: oyna yaratilmadi");
        return false;
    }
    return true;
}

LRESULT CALLBACK App::wndProc(HWND hwnd, UINT msg, WPARAM wp, LPARAM lp) {
    if (msg == WM_NCCREATE) {
        auto* cs = reinterpret_cast<CREATESTRUCTW*>(lp);
        SetWindowLongPtrW(hwnd, GWLP_USERDATA, (LONG_PTR)cs->lpCreateParams);
    }
    auto* self = reinterpret_cast<App*>(GetWindowLongPtrW(hwnd, GWLP_USERDATA));
    if (self) return self->handle(hwnd, msg, wp, lp);
    return DefWindowProcW(hwnd, msg, wp, lp);
}

LRESULT App::handle(HWND hwnd, UINT msg, WPARAM wp, LPARAM lp) {
    if (msg == g_taskbarCreated && g_taskbarCreated != 0) {
        trayAdded_ = false;
        addTrayIcon();
        return 0;
    }

    // Foydalanuvchi ilovani qaytadan ochdi (yorliq yoki Start menyusi orqali).
    // Ikkinchi nusxa ishga tushmaydi — o'rniga shu xabarni yuboradi.
    if (msg == g_showSettings && g_showSettings != 0) {
        settingsWindow_.show(instance_, settings_);
        return 0;
    }

    switch (msg) {
        case WM_HOTKEY:
            if ((int)wp == kHotkeyId) toggleDictation();
            return 0;

        case WM_RUBAI_TRAY:
            // Chap tugma — Sozlamalar. Diktovka hotkey bilan boshqariladi,
            // shuning uchun ikonka sozlash uchun eng qulay joy.
            if (LOWORD(lp) == WM_LBUTTONUP) {
                settingsWindow_.show(instance_, settings_);
            } else if (LOWORD(lp) == WM_RBUTTONUP ||
                       LOWORD(lp) == WM_CONTEXTMENU) {
                showMenu();
            }
            return 0;

        case WM_RUBAI_RESULT:
            if (pending_) {
                onResult(*pending_);
                pending_.reset();
            }
            return 0;

        case WM_COMMAND:
            switch (LOWORD(wp)) {
                case kMenuDictate:  toggleDictation(); return 0;
                case kMenuLog:
                    ShellExecuteW(nullptr, L"open", logPath().c_str(),
                                  nullptr, nullptr, SW_SHOWNORMAL);
                    return 0;
                case kMenuSettings:
                    settingsWindow_.show(instance_, settings_);
                    return 0;
                case kMenuQuit:
                    DestroyWindow(hwnd);
                    return 0;
            }
            return 0;

        case WM_ENDSESSION:
        case WM_DESTROY:
            removeTrayIcon();
            PostQuitMessage(0);
            return 0;
    }
    return DefWindowProcW(hwnd, msg, wp, lp);
}

// ------------------------------------------------------------------- tray

bool App::addTrayIcon() {
    if (trayAdded_) return true;

    tray_ = {};
    tray_.cbSize = sizeof(tray_);
    tray_.hWnd = hwnd_;
    tray_.uID = 1;
    tray_.uFlags = NIF_ICON | NIF_MESSAGE | NIF_TIP;
    tray_.uCallbackMessage = WM_RUBAI_TRAY;
    tray_.hIcon = (HICON)LoadImageW(instance_, MAKEINTRESOURCEW(101), IMAGE_ICON,
                                    GetSystemMetrics(SM_CXSMICON),
                                    GetSystemMetrics(SM_CYSMICON), LR_DEFAULTCOLOR);
    if (!tray_.hIcon) tray_.hIcon = LoadIconW(nullptr, IDI_APPLICATION);
    wcsncpy_s(tray_.szTip, kAppName, _TRUNCATE);

    trayAdded_ = Shell_NotifyIconW(NIM_ADD, &tray_) != FALSE;
    if (trayAdded_) {
        tray_.uVersion = NOTIFYICON_VERSION_4;
        Shell_NotifyIconW(NIM_SETVERSION, &tray_);
    } else {
        logWrite(L"XATO: tray ikonasi qo'shilmadi");
    }
    return trayAdded_;
}

void App::removeTrayIcon() {
    if (!trayAdded_) return;
    Shell_NotifyIconW(NIM_DELETE, &tray_);
    trayAdded_ = false;
}

void App::updateTrayTip(const std::wstring& text) {
    if (!trayAdded_) return;
    tray_.uFlags = NIF_TIP;
    wcsncpy_s(tray_.szTip, text.c_str(), _TRUNCATE);
    Shell_NotifyIconW(NIM_MODIFY, &tray_);
}

void App::notify(const std::wstring& title, const std::wstring& text, DWORD icon) {
    if (!trayAdded_) return;
    NOTIFYICONDATAW n = tray_;
    n.uFlags = NIF_INFO;
    n.dwInfoFlags = icon;
    wcsncpy_s(n.szInfoTitle, title.c_str(), _TRUNCATE);
    wcsncpy_s(n.szInfo, text.c_str(), _TRUNCATE);
    Shell_NotifyIconW(NIM_MODIFY, &n);
}

void App::showMenu() {
    HMENU menu = CreatePopupMenu();
    if (!menu) return;

    const std::wstring hk = settings_.hotkeyDisplay();
    AppendMenuW(menu, MF_STRING | (busy_ ? MF_GRAYED : 0), kMenuDictate,
                (recording_ ? L"Yozishni to'xtatish  (" + hk + L")"
                            : L"Diktovka  (" + hk + L")").c_str());
    AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);
    AppendMenuW(menu, MF_STRING, kMenuSettings, L"Sozlamalar…");
    AppendMenuW(menu, MF_STRING, kMenuLog, L"Log faylini ochish…");
    AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);
    AppendMenuW(menu, MF_STRING, kMenuQuit, L"Chiqish");

    POINT pt;
    GetCursorPos(&pt);
    // Menyu tashqarisiga bosilganda yopilishi uchun oyna faol bo'lishi kerak.
    SetForegroundWindow(hwnd_);
    TrackPopupMenu(menu, TPM_RIGHTBUTTON | TPM_BOTTOMALIGN,
                   pt.x, pt.y, 0, hwnd_, nullptr);
    PostMessageW(hwnd_, WM_NULL, 0, 0);
    DestroyMenu(menu);
}

// ---------------------------------------------------------------- hotkey

bool App::registerHotkey() {
    const UINT mods = settings_.modifiers | MOD_NOREPEAT;
    if (RegisterHotKey(hwnd_, kHotkeyId, mods, settings_.vkCode)) {
        logWrite(L"hotkey ro'yxatdan o'tdi: " + settings_.hotkeyDisplay());
        return true;
    }

    logWrite(L"XATO: hotkey band — " + settings_.hotkeyDisplay());
    MessageBoxW(nullptr,
                (L"Diktovka tugmasi (" + settings_.hotkeyDisplay() +
                 L") boshqa dastur tomonidan band qilingan.\n\n"
                 L"Sozlamalar faylidan boshqa tugma tanlang:\n" + settingsPath()).c_str(),
                kAppName, MB_OK | MB_ICONWARNING);
    return false;
}

// ------------------------------------------------------------- diktovka

void App::toggleDictation() {
    if (busy_) return;                 // transkripsiya ketmoqda — kutamiz
    if (recording_) stopAndTranscribe();
    else            startRecording();
}

void App::startRecording() {
    std::wstring error;
    if (!capture_.start(settings_.micDeviceId, error)) {
        logWrite(L"XATO: yozish boshlanmadi — " + error);
        overlay_.show(OverlayIcon::Warning, L"Mikrofon ochilmadi", 4000);
        notify(L"Mikrofon ochilmadi", error, NIIF_ERROR);
        return;
    }
    recording_ = true;
    updateTrayTip(L"Yozilmoqda…  (" + settings_.hotkeyDisplay() + L" — to'xtatish)");
    overlay_.show(OverlayIcon::Recording,
                  L"Yozilmoqda…  (" + settings_.hotkeyDisplay() + L")");
    logWrite(L"yozish boshlandi");
}

void App::stopAndTranscribe() {
    recording_ = false;
    std::vector<float> samples = capture_.stop();

    const AudioCheck check = checkSamples(samples);
    logWrite(L"yozish tugadi: " + std::to_wstring((int)(check.seconds * 10) / 10.0) +
             L"s, peak=" + std::to_wstring(check.peak));

    if (check.verdict == AudioVerdict::Silent) {
        updateTrayTip(kAppName);
        overlay_.show(OverlayIcon::Warning, L"Mikrofon jim — signal yo'q", 4000);
        notify(L"Mikrofon jim",
               L"Signal aniqlanmadi. Mikrofon ulanganini va Windows\n"
               L"maxfiylik sozlamalarida ruxsat berilganini tekshiring.",
               NIIF_WARNING);
        return;
    }
    if (check.verdict == AudioVerdict::TooShort) {
        updateTrayTip(kAppName);
        overlay_.show(OverlayIcon::Warning, L"Juda qisqa — kamida 1 soniya gapiring", 3000);
        return;
    }

    busy_ = true;
    updateTrayTip(L"Matnga o'girilmoqda…");
    overlay_.show(OverlayIcon::Working, L"Matnga o'girilmoqda…");

    Engine::instance().transcribeAsync(
        prepareSamples(samples),
        [this](TranscribeResult r) {
            // Bu ishchi oqim — UI'ga tegmaymiz, natijani asosiy oqimga uzatamiz.
            pending_ = std::make_unique<TranscribeResult>(std::move(r));
            PostMessageW(hwnd_, WM_RUBAI_RESULT, 0, 0);
        });
}

void App::onResult(const TranscribeResult& r) {
    busy_ = false;
    updateTrayTip(kAppName);

    if (!r.ok()) {
        logWrite(L"XATO: " + r.error);
        overlay_.show(OverlayIcon::Warning, r.error, 5000);
        notify(L"Xatolik", r.error, NIIF_ERROR);
        return;
    }

    if (r.text.empty()) {
        overlay_.show(OverlayIcon::Warning, L"Ovoz aniqlanmadi — balandroq gapiring", 3500);
        return;
    }

    logWrite(L"natija (" + std::to_wstring(r.text.size()) + L" belgi, " +
             std::to_wstring((int)(r.seconds * 1000)) + L" ms)");

    const InsertResult ins = insertText(r.text, settings_.insertMode);
    if (ins.ok) {
        // Matn joyiga tushdi — overlay'ni darhol yashiramiz, chunki
        // foydalanuvchi natijani o'z oynasida ko'rib turibdi.
        overlay_.hide();
        return;
    }

    // Joylanmadi — sababini aniq aytamiz.
    std::wstring msg = ins.error;
    if (foregroundWindowIsElevated()) {
        msg = L"Faol oyna administrator huquqi bilan ishlayapti —\n"
              L"Windows unga matn yuborishga ruxsat bermaydi.\n"
              L"Matn clipboard'da: Ctrl+V bosing.";
    }
    logWrite(L"matn joylanmadi: " + msg);
    overlay_.show(OverlayIcon::Warning, L"Matn clipboard'da — Ctrl+V bosing", 5000);
    notify(L"Matn joylanmadi", msg, NIIF_WARNING);
}

// -------------------------------------------------- sozlamalarni qo'llash

void App::applySettings(const Settings& s) {
    const bool hotkeyChanged = (s.vkCode != settings_.vkCode) ||
                               (s.modifiers != settings_.modifiers);
    const bool gpuChanged = (s.useGpu != settings_.useGpu);

    settings_ = s;

    if (hotkeyChanged) {
        UnregisterHotKey(hwnd_, kHotkeyId);
        registerHotkey();
    }

    Engine& engine = Engine::instance();
    engine.setIdleUnloadSeconds(settings_.idleUnloadSeconds);

    if (gpuChanged) {
        // GPU rejimi o'zgardi — modelni qayta yuklash kerak, chunki
        // backend yuklash paytida tanlanadi.
        engine.setUseGpu(settings_.useGpu);
        engine.unload();
        engine.preload();
    }
}

// ------------------------------------------------------------------- init

bool App::init(HINSTANCE instance) {
    logInit();
    logWrite(L"--- ilova ishga tushdi ---");

    settings_ = loadSettings();

    if (!createWindow(instance)) return false;
    overlay_.create(instance);
    addTrayIcon();
    registerHotkey();

    settingsWindow_.setOnSaved([this](const Settings& s) { applySettings(s); });

    // Birinchi ishga tushish: avtostartni yoqamiz va sozlamalarni
    // ko'rsatamiz, foydalanuvchi mikrofonini tanlab olsin.
    if (!settings_.didOnboard) {
        settings_.didOnboard = true;
        setAutoStart(settings_.autoStart);
        saveSettings(settings_);
        PostMessageW(hwnd_, WM_COMMAND, kMenuSettings, 0);
    }

    Engine& engine = Engine::instance();
    engine.setUseGpu(settings_.useGpu);
    engine.setIdleUnloadSeconds(settings_.idleUnloadSeconds);

    // Modelni fonda oldindan yuklaymiz va GPU quvurini isitamiz — birinchi
    // diktovka darhol ishlashi uchun.
    engine.preload();

    updateTrayTip(kAppName);
    return true;
}

void App::run() {
    MSG msg;
    while (GetMessageW(&msg, nullptr, 0, 0) > 0) {
        TranslateMessage(&msg);
        DispatchMessageW(&msg);
    }
}

void App::shutdown() {
    if (recording_) capture_.stop();
    UnregisterHotKey(hwnd_, kHotkeyId);
    removeTrayIcon();
    Engine::instance().shutdown();
    logWrite(L"--- ilova yopildi ---");
}

}  // namespace
}  // namespace rubai

int WINAPI wWinMain(HINSTANCE instance, HINSTANCE, PWSTR, int) {
    using namespace rubai;

    g_taskbarCreated = RegisterWindowMessageW(L"TaskbarCreated");
    g_showSettings   = RegisterWindowMessageW(L"AudioMatngaShowSettings");

    // Ikkinchi nusxa ishga tushmasin — ikkita ilova bitta hotkey'ni
    // ushlab, kutilmagan xatti-harakat beradi.
    //
    // Lekin foydalanuvchi yorliqni bosgan bo'lsa, u nimadir bo'lishini
    // kutadi. "Allaqachon ishlayapti" degan xabar boshi berk ko'cha —
    // buning o'rniga ishlab turgan nusxaning Sozlamalar oynasini ochamiz.
    HANDLE mutex = CreateMutexW(nullptr, TRUE, kMutexName);
    if (mutex && GetLastError() == ERROR_ALREADY_EXISTS) {
        HWND existing = FindWindowW(kWindowClass, nullptr);
        if (existing) {
            PostMessageW(existing, g_showSettings, 0, 0);
        } else {
            // Oyna topilmadi (ilova yopilish jarayonida bo'lishi mumkin).
            MessageBoxW(nullptr,
                        L"Audio-Matnga allaqachon ishlayapti.\n"
                        L"Sozlamalar uchun vazifalar panelidagi 🎙 ikonkasini bosing.",
                        kAppName, MB_OK | MB_ICONINFORMATION);
        }
        CloseHandle(mutex);
        return 0;
    }

    // Yuqori DPI monitorlarda oynalar xira ko'rinmasligi uchun.
    SetProcessDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2);

    App app;
    g_app = &app;
    if (!app.init(instance)) {
        MessageBoxW(nullptr, L"Ilova ishga tushmadi. Log faylini tekshiring.",
                    kAppName, MB_OK | MB_ICONERROR);
        return 1;
    }
    app.run();
    app.shutdown();

    if (mutex) CloseHandle(mutex);
    return 0;
}
