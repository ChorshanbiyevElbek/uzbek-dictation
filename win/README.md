# Audio-Matnga — Windows

O'zbekcha ovozli yozuv. Istalgan ilovada **Ctrl+Alt+D** bosing, gapiring, yana bosing —
matn kursor turgan joyga yoziladi. To'liq oflayn, internetsiz.

macOS versiyasining Windows portlanishi. Bir xil model (`rubaiSTT v2 medium`),
bir xil inference parametrlari.

---

## O'rnatish

Ikkita variant bor:

| Fayl | Hajm | Qachon |
|---|---|---|
| `...-setup.exe` | 8 MB | Internet barqaror bo'lsa — model o'rnatish paytida yuklanadi |
| `...-oflayn-setup.exe` | 749 MB | **Internet sekin yoki uzilib qolsa** — model ichida, ulanish kerak emas |

1. Fayllardan birini yuklab oling va ishga tushiring
2. Birinchi ochilishda Sozlamalar oynasi chiqadi — **mikrofoningizni tanlang**

### ⚠️ Yuklab olish manzillari ishlamaydi

`github.com/MuhammadMirrr/uzbek-dictation` repozitoriysi va uning `v1.0`
release'i **o'chirilgan** — HTTP 404. Shu sababli ishlamaydi:

- saytdagi `.exe` / `.dmg` / `.pkg` yuklab olish tugmalari;
- o'rnatuvchining model yuklashi (`rubai.iss` → `ModelUrl`);
- `setup.sh` dagi `MODEL_URL`;
- `README.md` dagi `git clone`.

Model faylining boshqa ochiq nusxasi topilmadi (HuggingFace'da faqat asl
`safetensors` bor, tayyor `ggml` yo'q). Hozircha yagona yo'l — **manbadan
build qilish va modelni o'zi konversiya qilish** (pastga qarang).

### Model yuklab olinmasa

O'rnatuvchi modelni to'rtta manbadan qidiradi (shu tartibda):

1. **Model allaqachon o'rnatilgan** — qayta o'rnatishda qaytadan yuklanmaydi
2. **`ggml-rubaistt.bin` ni `setup.exe` yoniga qo'ying** — o'rnatuvchi uni
   o'zi topadi va internetsiz o'rnatadi
3. **Oflayn o'rnatuvchi** — model uning ichida (`build.ps1 -BundleModel`)
4. **Internetdan yuklash** — `ModelUrl` (hozir 404)

Hech biri chiqmasa, o'rnatuvchi endi **modelsiz o'rnatishni taklif qiladi**
va faylni keyin qayerga qo'yish kerakligini aytadi. Ilova modelni uchta
yo'ldan qidiradi (`core/engine.cpp` → `findModel`):

```
<o'rnatilgan papka>\models\ggml-rubaistt.bin
<o'rnatilgan papka>\ggml-rubaistt.bin
%LOCALAPPDATA%\Audio-Matnga\models\ggml-rubaistt.bin     <- ruxsat kerak emas
```

Ish vaqtida hajm va SHA256 tekshirilmaydi — o'zi konversiya qilingan model
ham ishlaydi.

> **Muhim:** mikrofonni albatta tanlang. Windows'da standart qurilma ba'zan
> "Stereo Mix" bo'lib qoladi — u ovozingizni emas, kompyuter ovozini yozadi.
> Ilova bunday qurilmalarni sariq rangda ogohlantiradi.

### SmartScreen ogohlantirishi

Ilova hozircha kod imzosi sertifikati bilan imzolanmagan, shuning uchun Windows
"Windows protected your PC" deb ogohlantirishi mumkin. Bir martalik yechim:
**"Batafsil ma'lumot" (More info) → "Baribir ishga tushirish" (Run anyway)**.

## Ishlatish

| Amal | Qanday |
|---|---|
| Yozishni boshlash / to'xtatish | **Ctrl+Alt+D** |
| Sozlamalar | Tray ikonkasiga **chap tugma** bilan bosing |
| Menyu (diktovka, log, chiqish) | Tray ikonkasiga **o'ng tugma** |

Tugmani Sozlamalardan o'zgartirish mumkin.

## Talablar

|  | Minimum | Tavsiya etiladi |
|---|---|---|
| **OS** | Windows 10 64-bit (o'rnatuvchi 1809 / build 17763 dan boshlab) | Windows 10 22H2 yoki Windows 11 |
| **Protsessor** | Istalgan 64-bitli x86 (Intel/AMD) | **AVX2** bilan — Intel Haswell (4-avlod Core, 2013+) yoki AMD Ryzen (2017+) |
| **RAM** | 6 GB | **8 GB** yoki ko'proq |
| **Videokarta** | shart emas — protsessorda ishlaydi | **Vulkan 1.2** drayveri + `storageBuffer16BitAccess` + ~1.5 GB bo'sh videoxotira |
| **Disk** | ~890 MB o'rnatilgach | o'rnatish paytida **1.8 GB bo'sh** kerak |
| **Huquq** | o'rnatish uchun administrator (yoki "faqat men uchun" varianti) | — |

Boshqa hech narsa o'rnatish shart emas: Visual C++ runtime ilova bilan
birga keladi, Vulkan esa videokarta drayveri tarkibida bo'ladi.

**32-bitli Windows va 32-bitli protsessorlar qo'llab-quvvatlanmaydi.**

### Videokarta bo'lmasa nima bo'ladi

Ilova o'zi protsessor rejimiga o'tadi — **aniqlik aynan bir xil qoladi**,
faqat sekinroq ishlaydi va ~1.9 GB RAM egallaydi (videokarta rejimida
~120 MB RAM + ~1.5 GB videoxotira).

## Tezlik — o'lchangan (208.3 s audio, FLEURS uz)

| Rejim | Vaqt | Realtime | 10 s diktovka ≈ |
|---|---|---|---|
| Vulkan — RTX 4060 Laptop | 22.3 s | **0.11×** | ~1.1 s |
| Protsessor — i7-13700HX, 22 oqim | 119.3 s | 0.57× | ~5.7 s |
| Protsessor — i7-13700HX, 8 oqim | 149.9 s | 0.72× | ~7.2 s |
| Protsessor — i7-13700HX, 4 oqim | 173.6 s | 0.83× | ~8.3 s |
| Protsessor — i7-13700HX, 2 oqim | 323.6 s | 1.55× | ~15.5 s |

Ilova `yadrolar - 2` (kamida 4) oqim ishlatadi. Yuqoridagi protsessor
raqamlari **kuchli** protsessorniki — eski yoki AVX2 siz protsessorlarda
bundan ham sekin bo'ladi.

## Aniqlik

Google FLEURS o'zbek dev to'plamida o'lchangan (20 namuna, 330 so'z,
yangiliklar uslubidagi murakkab matnlar): **WER 17.0%** — so'zlarning
~83% to'g'ri. Kundalik oddiy gaplarda aniqlik yuqoriroq.

Aniqlik videokarta va protsessor rejimida **bir xil** (ikkalasi ham
17.0% berdi) — backend faqat tezlikka ta'sir qiladi.

---

## Manbadan build qilish

### Talablar (bir marta)

```powershell
winget install Kitware.CMake
winget install KhronosGroup.VulkanSDK
winget install JRSoftware.InnoSetup
winget install Microsoft.VisualStudio.2022.BuildTools --override `
    "--quiet --wait --add Microsoft.VisualStudio.Workload.VCTools --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64"
```

### Build

```powershell
powershell -ExecutionPolicy Bypass -File win\build.ps1
```

whisper.cpp'ni Vulkan bilan yig'adi → ilovani build qiladi → o'rnatuvchi yasaydi.
Natija: `dist\Audio-Matnga-1.0.0-setup.exe`

Foydali bayroqlar:

| Bayroq | Vazifasi |
|---|---|
| `-SkipWhisper` | whisper.cpp allaqachon yig'ilgan bo'lsa o'tkazib yuboradi |
| `-NoInstaller` | faqat `.exe` yasaydi, o'rnatuvchisiz |
| `-WithTools` | `whisper-cli.exe` va `whisper-quantize.exe` ni ham yig'adi (model konversiyasi uchun kerak) |
| `-BundleModel <yo'l>` | oflayn o'rnatuvchi: model `.exe` ichiga joylanadi |
| `-WorkDir <yo'l>` | build artefaktlari papkasi. Standart: `D:\rubai` (agar D: disk bo'lsa), aks holda `%LOCALAPPDATA%\rubai-build` |

### Modelni o'zi yasash

Tayyor `ggml-rubaistt.bin` endi hech qayerdan yuklab olinmaydi, shuning uchun
uni HuggingFace'dagi asl vaznlardan qayta yasash kerak:

```powershell
powershell -ExecutionPolicy Bypass -File win\build.ps1 -WithTools -NoInstaller
powershell -ExecutionPolicy Bypass -File win\tools\convert_model.ps1
```

`convert_model.ps1` — `scripts/convert_model.sh` (macOS) ning Windows muqobili:
torch + transformers o'rnatadi → `islomov/rubaistt_v2_medium` ni yuklaydi (~3 GB)
→ ggml f16 ga o'giradi → `whisper-quantize.exe` bilan q8_0 ga siqadi. Natija
`%LOCALAPPDATA%\Audio-Matnga\models\ggml-rubaistt.bin` — ilova uni o'zi topadi.
Talab: Python 3.10+, ~12 GB bo'sh joy.

Oflayn o'rnatuvchi yasash (hajm va SHA256 avtomatik uzatiladi):

```powershell
powershell -ExecutionPolicy Bypass -File win\build.ps1 -SkipWhisper `
    -BundleModel "$env:LOCALAPPDATA\Audio-Matnga\models\ggml-rubaistt.bin"
```

### Yordamchi vositalar

```powershell
# Yadroni tekshirish
rubai-cli.exe audio.wav --model <yo'l>    # fayldan transkripsiya
rubai-cli.exe --mics                      # mikrofonlar ro'yxati
rubai-cli.exe --record 5                  # 5 soniya yozib transkripsiya

# Aniqlikni o'lchash (FLEURS datasetida)
python win\tools\bench_accuracy.py --cli <whisper-cli.exe> --model <model> -n 20
```

---

## Kod tuzilishi

```
win/
  core/                UI'dan mustaqil yadro
    whisper_bridge.c   whisper.cpp ustidan C shim (macOS bilan bir xil parametrlar)
    engine.cpp         model yuklash, isitish, navbat, RAM'ni bo'shatish
    audio_capture.cpp  WASAPI: mikrofon -> 16 kHz mono float32
    samples.cpp        signal normalizatsiyasi va sifat tekshiruvi
    config.cpp         sozlamalar fayli
    wav.cpp            WAV o'quvchi (testlar uchun)
    util.cpp           kodlash, yo'llar, log
  ui/
    app.cpp            WinMain, tray, hotkey, asosiy oqim
    overlay.cpp        suzuvchi holat oynasi (fokusni o'g'irlamaydi)
    settings_window.cpp
    inserter.cpp       clipboard + Ctrl+V / Unicode yozish
    autostart.cpp      registry Run kaliti
  installer/rubai.iss  Inno Setup
  tools/               ikonka yasash, aniqlik o'lchash
```

Fayllar va papkalar:

| Nima | Qayerda |
|---|---|
| Sozlamalar | `%APPDATA%\Audio-Matnga\settings.ini` |
| Log | `%LOCALAPPDATA%\Audio-Matnga\dictation.log` |
| Model | `<o'rnatilgan papka>\models\ggml-rubaistt.bin` |

---

## macOS versiyasidan farqlar

**Yo'q qilingan murakkabliklar:** Accessibility ruxsati, Gatekeeper, notarize —
Windows'da bularning hech biri kerak emas.

**Qo'shilgan funksiyalar:**

- **Mikrofon tanlash** — Windows'da standart qurilma "Stereo Mix" bo'lib qolishi
  mumkin, u ovoz o'rniga kompyuter ovozini yozadi
- **"Jim oqim" aniqlash** — Iriun, OBS, VB-Cable va ulanmagan Bluetooth
  qurilmalari `OK` holatida ko'rinib, aslida sukunat beradi
- **Bluetooth HFP ogohlantirishi** — quloqchin mikrofoni 8–16 kHz ga tushadi
- **GPU quvurini oldindan isitish** — Vulkan birinchi ishga tushishda shader'larni
  kompilyatsiya qiladi (~12 s). Bu ilova ochilganda fonda bajariladi, aks holda
  foydalanuvchining birinchi diktovkasi juda sekin bo'lardi
- **Kirill/lotin bo'lmagan yo'llar** — model ASCII yo'lda saqlanadi, chunki
  whisper.cpp fayl yo'lini `char*` sifatida ochadi

## Litsenziya

MIT. Model va whisper.cpp o'z litsenziyalari ostida.
