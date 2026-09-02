// rubai-cli — yadroni tekshirish uchun konsol vositasi.
//
// Ilovaning o'zi emas: core/ dagi kod to'g'ri ishlayotganini tasdiqlaydi
// (model yuklash, transkripsiya, signal tekshiruvi, log).
//
//   rubai-cli <audio.wav> [--cpu] [--model <yo'l>]
//   rubai-cli --mics                 mikrofonlar ro'yxati
//   rubai-cli --record <soniya>      mikrofondan yozib transkripsiya qilish

#include <windows.h>

#include <cstdio>
#include <string>
#include <vector>

#include "../core/audio_capture.h"
#include "../core/engine.h"
#include "../core/samples.h"
#include "../core/util.h"
#include "../core/wav.h"

using namespace rubai;

namespace {

void print(const std::wstring& s) {
    DWORD written = 0;
    HANDLE h = GetStdHandle(STD_OUTPUT_HANDLE);
    std::wstring line = s + L"\n";
    // Konsolga to'g'ridan-to'g'ri UTF-16 yozamiz — o'zbek harflari
    // kod sahifasidan qat'i nazar to'g'ri ko'rinishi uchun.
    if (!WriteConsoleW(h, line.c_str(), (DWORD)line.size(), &written, nullptr)) {
        std::string utf8 = toUtf8(line);
        WriteFile(h, utf8.data(), (DWORD)utf8.size(), &written, nullptr);
    }
}

const wchar_t* verdictText(AudioVerdict v) {
    switch (v) {
        case AudioVerdict::Silent:    return L"MIKROFON JIM — signal yo'q";
        case AudioVerdict::TooShort:  return L"juda qisqa";
        case AudioVerdict::VeryQuiet: return L"juda past, kuchaytiriladi";
        default:                      return L"normal";
    }
}

const wchar_t* kindText(MicKind k) {
    switch (k) {
        case MicKind::Loopback:  return L"[TIZIM OVOZI — mikrofon emas]";
        case MicKind::Bluetooth: return L"[Bluetooth — sifat past]";
        case MicKind::Virtual:   return L"[virtual]";
        default:                 return L"";
    }
}

int listMics() {
    const auto mics = listMicrophones();
    if (mics.empty()) {
        print(L"Kirish qurilmasi topilmadi.");
        return 1;
    }
    print(L"Mikrofonlar (tavsiya tartibida):");
    for (size_t i = 0; i < mics.size(); i++) {
        std::wstring line = L"  [" + std::to_wstring(i) + L"] " + mics[i].name;
        if (mics[i].isDefault) line += L"  (standart)";
        std::wstring k = kindText(mics[i].kind);
        if (!k.empty()) line += L"  " + k;
        print(line);
    }
    return 0;
}

}  // namespace

int wmain(int argc, wchar_t** argv) {
    logInit();

    std::wstring audioPath, modelPath, micId;
    bool useGpu = true;
    int recordSeconds = 0;

    for (int i = 1; i < argc; i++) {
        std::wstring a = argv[i];
        if (a == L"--cpu") {
            useGpu = false;
        } else if (a == L"--mics") {
            return listMics();
        } else if (a == L"--record" && i + 1 < argc) {
            recordSeconds = _wtoi(argv[++i]);
        } else if (a == L"--mic" && i + 1 < argc) {
            micId = argv[++i];
        } else if (a == L"--model" && i + 1 < argc) {
            modelPath = argv[++i];
        } else if (!a.empty() && a[0] != L'-') {
            audioPath = a;
        }
    }

    if (audioPath.empty() && recordSeconds <= 0) {
        print(L"Ishlatish:");
        print(L"  rubai-cli <audio.wav> [--cpu] [--model <yo'l>]");
        print(L"  rubai-cli --mics");
        print(L"  rubai-cli --record <soniya> [--mic <id>]");
        return 2;
    }

    std::vector<float> pcm;
    std::wstring err;

    if (recordSeconds > 0) {
        AudioCapture cap;
        if (!cap.start(micId, err)) {
            print(L"XATO: " + err);
            return 1;
        }
        print(L"Yozilmoqda (" + std::to_wstring(recordSeconds) + L" soniya)...");
        Sleep((DWORD)recordSeconds * 1000);
        pcm = cap.stop();
        if (cap.deviceLost()) print(L"OGOHLANTIRISH: audio oqimi uzildi");
    } else if (!readWav16kMono(audioPath, pcm, err)) {
        print(L"XATO: " + err);
        return 1;
    }

    const AudioCheck check = checkSamples(pcm);
    wchar_t info[256];
    swprintf(info, 256, L"audio: %.1fs, peak=%.4f  (%s)",
             check.seconds, check.peak, verdictText(check.verdict));
    print(info);

    if (check.verdict == AudioVerdict::Silent) {
        print(L"Transkripsiya o'tkazilmadi — audioda ovoz yo'q.");
        return 1;
    }

    Engine& engine = Engine::instance();
    if (!modelPath.empty()) engine.setModelPath(modelPath);
    engine.setUseGpu(useGpu);

    const std::wstring resolved = modelPath.empty() ? Engine::findModel() : modelPath;
    print(L"model: " + (resolved.empty() ? L"TOPILMADI" : resolved));

    const TranscribeResult r = engine.transcribe(prepareSamples(pcm));

    if (!r.ok()) {
        print(L"XATO: " + r.error);
        engine.shutdown();
        return 1;
    }

    swprintf(info, 256, L"backend: %s, %.2fs (%.2fx realtime)",
             engine.backendName().c_str(), r.seconds,
             check.seconds > 0 ? r.seconds / check.seconds : 0.0);
    print(info);
    print(L"");
    print(r.text.empty() ? L"(nutq aniqlanmadi)" : r.text);

    engine.shutdown();
    return 0;
}
