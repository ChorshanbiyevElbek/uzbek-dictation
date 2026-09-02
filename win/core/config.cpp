#include "config.h"

#include <windows.h>

#include <fstream>
#include <sstream>

#include "util.h"

namespace rubai {

namespace {

std::wstring trim(const std::wstring& s) {
    size_t a = s.find_first_not_of(L" \t\r\n");
    if (a == std::wstring::npos) return {};
    size_t b = s.find_last_not_of(L" \t\r\n");
    return s.substr(a, b - a + 1);
}

unsigned defaultModifiers() {
    return MOD_CONTROL | MOD_ALT;   // Ctrl+Alt — macOS'dagi ⌃⌥ ekvivalenti
}

}  // namespace

std::wstring settingsPath() {
    std::wstring dir = appDataDir();
    return dir.empty() ? std::wstring() : dir + L"\\settings.ini";
}

std::wstring Settings::hotkeyDisplay() const {
    unsigned m = modifiers ? modifiers : defaultModifiers();
    std::wstring s;
    if (m & MOD_CONTROL) s += L"Ctrl+";
    if (m & MOD_ALT)     s += L"Alt+";
    if (m & MOD_SHIFT)   s += L"Shift+";
    if (m & MOD_WIN)     s += L"Win+";
    return s + hotkeyLabel;
}

Settings loadSettings() {
    Settings s;
    s.modifiers = defaultModifiers();

    std::wstring path = settingsPath();
    if (path.empty() || !fileExists(path)) return s;

    std::ifstream f(path, std::ios::binary);
    if (!f) return s;
    std::stringstream ss;
    ss << f.rdbuf();
    std::wstring text = toWide(ss.str());

    std::wistringstream lines(text);
    std::wstring line;
    while (std::getline(lines, line)) {
        line = trim(line);
        if (line.empty() || line[0] == L'#') continue;
        size_t eq = line.find(L'=');
        if (eq == std::wstring::npos) continue;
        std::wstring key = trim(line.substr(0, eq));
        std::wstring val = trim(line.substr(eq + 1));

        // Har bir qiymat alohida himoyalangan: bitta buzuq satr butun
        // sozlamani yo'qotmasligi kerak.
        try {
            if      (key == L"hotkey.vk")        s.vkCode = (unsigned)std::stoul(val);
            else if (key == L"hotkey.modifiers") s.modifiers = (unsigned)std::stoul(val);
            else if (key == L"hotkey.label")     s.hotkeyLabel = val;
            else if (key == L"mic.deviceId")     s.micDeviceId = val;
            else if (key == L"mic.deviceName")   s.micDeviceName = val;
            else if (key == L"insertMode")       s.insertMode = (val == L"type")
                                                     ? InsertMode::Type : InsertMode::Paste;
            else if (key == L"autoStart")        s.autoStart = (val == L"1");
            else if (key == L"useGpu")           s.useGpu = (val == L"1");
            else if (key == L"idleUnloadSeconds") s.idleUnloadSeconds = std::stoi(val);
            else if (key == L"didOnboard")       s.didOnboard = (val == L"1");
        } catch (...) {
            // buzuq qiymat — standartda qoldiramiz
        }
    }

    // Ishonchsiz qiymatlarni tuzatamiz
    if (s.modifiers == 0) s.modifiers = defaultModifiers();
    if (s.vkCode == 0) s.vkCode = 'D';
    if (s.hotkeyLabel.empty()) s.hotkeyLabel = L"D";
    if (s.idleUnloadSeconds < 10) s.idleUnloadSeconds = 180;
    return s;
}

bool saveSettings(const Settings& s) {
    std::wstring path = settingsPath();
    if (path.empty()) return false;

    std::wostringstream o;
    o << L"# Audio-Matnga sozlamalari\n"
      << L"# Bu faylni qo'lda tahrirlash mumkin. Ilovani qayta ishga tushiring.\n\n"
      << L"hotkey.vk="          << s.vkCode        << L"\n"
      << L"hotkey.modifiers="   << s.modifiers     << L"\n"
      << L"hotkey.label="       << s.hotkeyLabel   << L"\n"
      << L"mic.deviceId="       << s.micDeviceId   << L"\n"
      << L"mic.deviceName="     << s.micDeviceName << L"\n"
      << L"insertMode="         << (s.insertMode == InsertMode::Type ? L"type" : L"paste") << L"\n"
      << L"autoStart="          << (s.autoStart ? 1 : 0) << L"\n"
      << L"useGpu="             << (s.useGpu ? 1 : 0)    << L"\n"
      << L"idleUnloadSeconds="  << s.idleUnloadSeconds   << L"\n"
      << L"didOnboard="         << (s.didOnboard ? 1 : 0) << L"\n";

    std::string utf8 = toUtf8(o.str());

    // Avval vaqtinchalik faylga yozib, keyin almashtiramiz — yozish paytida
    // ilova yopilsa sozlamalar buzilmasligi uchun.
    std::wstring tmp = path + L".tmp";
    {
        std::ofstream f(tmp, std::ios::binary | std::ios::trunc);
        if (!f) return false;
        f.write(utf8.data(), (std::streamsize)utf8.size());
        if (!f) return false;
    }
    return MoveFileExW(tmp.c_str(), path.c_str(), MOVEFILE_REPLACE_EXISTING) != 0;
}

}  // namespace rubai
