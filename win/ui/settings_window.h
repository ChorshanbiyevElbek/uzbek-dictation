// Sozlamalar oynasi.
//
// macOS versiyasidagi `SettingsWindow` ning ekvivalenti (dictate.swift:482),
// lekin mikrofon tanlash qo'shilgan — Windows'da bu majburiy, chunki
// standart qurilma "Stereo Mix" bo'lib qolsa ilova ovoz o'rniga
// kompyuter ovozini yozadi.
#pragma once

#include <windows.h>

#include <functional>

#include "../core/config.h"

namespace rubai {

class SettingsWindow {
public:
    SettingsWindow();
    ~SettingsWindow();
    SettingsWindow(const SettingsWindow&) = delete;
    SettingsWindow& operator=(const SettingsWindow&) = delete;

    // Sozlamalar saqlanganda chaqiriladi (hotkey qayta ro'yxatdan
    // o'tkazilishi va h.k. uchun).
    void setOnSaved(std::function<void(const Settings&)> cb);

    // Oynani ochadi (allaqachon ochiq bo'lsa oldinga chiqaradi).
    void show(HINSTANCE instance, const Settings& current);

    struct Impl;

private:
    Impl* d;
};

}  // namespace rubai
