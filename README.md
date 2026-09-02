# 🎙️ Audio-Matnga

**Istalgan joyda o'zbekcha gapiring — matn o'zi yoziladi.**

Telegram, brauzer, Word, Excel — kursor qayerda bo'lsa, o'sha yerga.
Tugmani bosasiz, gapirasiz, yana bosasiz. Tamom.

**Internet kerak emas.** Ovozingiz kompyuteringizdan chiqmaydi — hech qanday
serverga yuborilmaydi. Bepul, reklamasiz, obunasiz.

---

## ⬇️ Yuklab olish

### Windows 10 / 11 (64-bit)

**[⬇️ Audio-Matnga-1.0.0-oflayn-setup.exe (749 MB)](https://github.com/ChorshanbiyevElbek/uzbek-dictation/releases/latest)**

Bitta fayl — ichida hammasi bor. Yuklab oling, ikki marta bosing, tayyor.

> **Nega 749 MB?** Ichida o'zbek tilini taniydigan sun'iy intellekt modeli
> bor (785 MB). Aynan shuning uchun ilova internetsiz ishlaydi.

<details>
<summary>Kichikroq variant (8 MB) — internet barqaror bo'lsa</summary>

**[Audio-Matnga-1.0.0-setup.exe (8 MB)](https://github.com/ChorshanbiyevElbek/uzbek-dictation/releases/latest)**

Modelni o'rnatish paytida yuklab oladi. Internet uzilib qolsa xato beradi —
shuning uchun katta variant ishonchliroq.
</details>

### macOS 13+

macOS versiyasi manbadan yig'iladi — tayyor `.dmg` hozircha yo'q.
Ko'rsatma: [`setup.sh`](setup.sh) va shu hujjatning oxiri.

---

## 🚀 Uch qadamda

**1.** `.exe` faylni ishga tushiring

> Windows «Windows protected your PC» deb ogohlantiradi — bu normal,
> ilova hali raqamli imzoga ega emas.
> **«Batafsil» (More info) → «Baribir ishga tushirish» (Run anyway)** bosing.

**2.** O'rnatishdan keyin Sozlamalar oynasi chiqadi — **mikrofoningizni tanlang**

> Muhim: Windows'da standart mikrofon ba'zan «Stereo Mix» bo'lib qoladi —
> u ovozingizni emas, kompyuter ovozini yozadi. Ilova bunday qurilmalarni
> sariq rangda ogohlantiradi.

**3.** Istalgan joyga yozishni boshlang

| Amal | Tugma |
|---|---|
| Yozishni boshlash / to'xtatish | **Ctrl + Alt + D** |
| Sozlamalar | Tray ikonkasiga **chap tugma** |
| Menyu | Tray ikonkasiga **o'ng tugma** |

Tugmani Sozlamalardan o'zgartirish mumkin.

---

## 💻 Qanday kompyuter kerak

|  | Minimum | Tavsiya |
|---|---|---|
| **Windows** | 10, 64-bit | 10 (22H2) yoki 11 |
| **Protsessor** | istalgan 64-bitli Intel/AMD | AVX2 bilan (2013-yildan keyingi) |
| **Operativ xotira** | 6 GB | **8 GB** |
| **Videokarta** | **shart emas** | Vulkan 1.2 + ~1.5 GB videoxotira |
| **Disk** | ~890 MB | o'rnatishda 1.8 GB bo'sh |

**Videokartasiz ham ishlaydi** — aniqlik aynan bir xil, faqat sekinroq.

| Rejim | 10 soniyalik diktovka |
|---|---|
| Videokarta (RTX 4060) | **~1 soniya** |
| Protsessor (8 oqim) | ~7 soniya |

Batafsil: [win/README.md](win/README.md)

---

## 🎯 Aniqlik

Google FLEURS o'zbek to'plamida o'lchangan (murakkab yangiliklar matnlari):
**WER 17%** — so'zlarning ~83% to'g'ri. Kundalik oddiy gaplarda yuqoriroq.

Aniqlik videokarta va protsessor rejimida **bir xil**.

---

## 🔒 Maxfiylik

Ilovaning ichida birorta tarmoq kutubxonasi yo'q — bu tekshirilgan
(`dumpbin /DEPENDENTS`). Ya'ni ilova texnik jihatdan internetga murojaat
**qila olmaydi**.

- Ovoz faqat operativ xotirada — diskka ham yozilmaydi
- Transkripsiya kompyuteringizda bajariladi
- Telemetriya, analitika, yangilanish tekshiruvi — yo'q
- Logda faqat matn *uzunligi* saqlanadi, matnning o'zi emas

---

## ❓ Muammo bo'lsa

| Muammo | Yechim |
|---|---|
| **Ctrl+Alt+D ishlamayapti** | Boshqa dastur shu tugmani egallagan. Sozlamalardan boshqa tugma tanlang. |
| **Matn yozilmayapti** | Administrator huquqida ishlayotgan oynaga (masalan Task Manager) yozib bo'lmaydi — bu Windows cheklovi. |
| **«Mikrofon jim» deydi** | Sozlamalardan boshqa mikrofon tanlang. Windows sozlamalarida mikrofonga ruxsat berilganini tekshiring. |
| **Juda sekin** | Videokartangiz Vulkan'ni qo'llab-quvvatlamasa protsessorda ishlaydi. Log: `%LOCALAPPDATA%\Audio-Matnga\dictation.log` |
| **SmartScreen bloklayapti** | «Batafsil» → «Baribir ishga tushirish». Ilova imzolanmagan. |

Fayllar qayerda:

```
Sozlamalar  %APPDATA%\Audio-Matnga\settings.ini
Log         %LOCALAPPDATA%\Audio-Matnga\dictation.log
Model       <o'rnatilgan papka>\models\ggml-rubaistt.bin
```

---

## 🛠 Manbadan yig'ish

Windows uchun to'liq ko'rsatma: **[win/README.md](win/README.md)**

Qisqacha:

```powershell
winget install Git.Git Kitware.CMake KhronosGroup.VulkanSDK JRSoftware.InnoSetup
winget install Microsoft.VisualStudio.2022.BuildTools --override `
    "--quiet --wait --add Microsoft.VisualStudio.Workload.VCTools"

powershell -ExecutionPolicy Bypass -File win\build.ps1
```

Modelni o'zi yasash (GitHub release'siz):

```powershell
powershell -ExecutionPolicy Bypass -File win\build.ps1 -WithTools -NoInstaller
powershell -ExecutionPolicy Bypass -File win\tools\convert_model.ps1
```

macOS uchun: `./setup.sh`

Loyihani o'z nomingiz bilan qayta nashr qilish: [RELEASE.md](RELEASE.md)

---

## 📁 Tuzilishi

```
win/          Windows ilovasi (C++20 + Win32, Vulkan)
src/          macOS ilovasi (Swift + C shim, Metal)
docs/         yuklab olish sahifasi (GitHub Pages shu papkani chiqaradi)
scripts/      macOS release skriptlari
assets/       ikonkalar
```

Texnik tafsilotlar: [WINDOWS-PORT-PLAN.md](WINDOWS-PORT-PLAN.md) ·
[AGENTS.md](AGENTS.md)

---

## 📄 Litsenziya va minnatdorchilik

Kod — **MIT**. Asl muallif: **Muhammad Mirqobilov**
([LICENSE](LICENSE)).

Uchinchi tomon komponentlari va ularning litsenziyalari:
[THIRD-PARTY-NOTICES.txt](THIRD-PARTY-NOTICES.txt)

- **[rubaiSTT v2 medium](https://huggingface.co/islomov/rubaistt_v2_medium)**
  — Sardor Islomov (o'zbek STT modeli, Apache-2.0).
  Ilovadagi `ggml-rubaistt.bin` — shu modelning ggml formatiga o'girilgan
  va q8_0 ga kvantlangan nusxasi.
- **[whisper.cpp](https://github.com/ggml-org/whisper.cpp)** — Georgi Gerganov (MIT)
- **[OpenAI Whisper](https://github.com/openai/whisper)** — asl model arxitekturasi

> **Nom haqida:** mahsulot nomi — **Audio-Matnga**. macOS ilovasining bundle
> nomi hozircha `RubaiSTT Dictation.app` bo'lib qolgan: uni o'zgartirsak,
> mavjud Mac foydalanuvchilari Accessibility ruxsatini qaytadan berishga
> majbur bo'ladi.

---

<sub>System-wide Uzbek speech-to-text dictation for Windows and macOS.
Press the hotkey anywhere, speak Uzbek, and the transcribed text is typed
into the focused field. Powered by the rubaiSTT model running locally via
whisper.cpp — Vulkan on Windows, Metal on macOS. Fully offline.</sub>
