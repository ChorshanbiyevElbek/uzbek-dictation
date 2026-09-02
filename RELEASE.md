# Nashr qilish yo'riqnomasi

Bu loyiha boshqa odamning ochiq repozitoriysidan olingan
(MIT litsenziyasi qayta nashrga ruxsat beradi). Quyidagi qadamlar
birinchi nashrdan **oldin** bajarilishi shart.

---

## 0. Nima allaqachon qilingan

- ✅ Asl muallifning **3 ta bank kartasi va ismi** kod va saytdan
  butunlay olib tashlandi (donat oynasi o'chirildi). Binar tekshirildi —
  iz qolmagan.
- ✅ Yangi `AppId` GUID berildi — eski nashr bilan to'qnashmaydi.
- ✅ `THIRD-PARTY-NOTICES.txt` yaratildi: whisper.cpp (MIT), rubaiSTT
  modeli (Apache-2.0) va modelning **o'zgartirilganligi to'g'risidagi
  bildirishnoma** — Apache-2.0 ning 4(b) bandi buni talab qiladi.
  O'rnatuvchi uni `{app}` ga joylaydi.
- ✅ Asl muallifning MIT copyright qatori `LICENSE` va `.exe` ning
  `LegalCopyright` maydonida **saqlandi** — bu litsenziya talabi,
  o'chirib bo'lmaydi.
- ✅ Boshqa mahsulotni so'ramasdan o'chirib yuboradigan
  `RemoveOldVersion()` olib tashlandi.
- ✅ Administrator huquqisiz o'rnatish varianti qo'shildi
  (`PrivilegesRequiredOverridesAllowed=dialog`).

---

## 1. Ismingizni qo'ying (majburiy)

Hozir `AppPublisher`, `CompanyName` va havolalarda
`GITHUB_USERNAME_PLACEHOLDER` turibdi. Bitta buyruq bilan almashadi:

```powershell
powershell -ExecutionPolicy Bypass -File win\tools\set-identity.ps1 -GitHubUser SIZNING_USERNAME
```

Skript oxirida qolgan izlarni o'zi ko'rsatadi. `LICENSE` va
`LegalCopyright` ataylab tegilmaydi.

## 2. Qayta yig'ing

`set-identity.ps1` dan **keyin** yig'ish shart — aks holda
`.exe` ichida placeholder qolib ketadi.

```powershell
powershell -ExecutionPolicy Bypass -File win\build.ps1 -SkipWhisper -BundleModel "$env:LOCALAPPDATA\Audio-Matnga\models\ggml-rubaistt.bin"
```

## 3. GitHub'ga chiqarish

```powershell
git remote add origin https://github.com/SIZNING_USERNAME/uzbek-dictation.git
git branch -M main
git push -u origin main
```

Keyin **Releases → Draft a new release**, tag `v1.0`, va quyidagilarni
asset sifatida yuklang:

| Fayl | Hajm | Izoh |
|---|---|---|
| `Audio-Matnga-1.0.0-oflayn-setup.exe` | 749 MB | model ichida — **asosiy variant** |
| `ggml-rubaistt.bin` | 785 MB | model alohida (qo'lda qo'yish uchun) |
| `Audio-Matnga-1.0.0-setup.exe` | 8.6 MB | faqat `ModelUrl` ishlagandan keyin |

> GitHub Releases bitta asset uchun **2 GB** gacha ruxsat beradi, shuning
> uchun 749 MB muammo emas. Repozitoriyning **o'ziga** bu fayllarni
> qo'ymang — `dist/` va `*.bin` `.gitignore` da.

## 4. Onlayn o'rnatuvchini yoqish (ixtiyoriy)

`ggml-rubaistt.bin` ni release'ga yuklaganingizdan keyin, uning haqiqiy
havolasini `win/installer/rubai.iss` dagi `ModelUrl` ga yozing.
`ModelSha256` va `ModelSize` allaqachon to'g'ri
(`1b02df43…c8edc1a3`, `823369796`). Keyin oddiy `-setup.exe` ni qayta
yig'ing. Shu bajarilmasa, **faqat oflayn variantni tarqating** — aks
holda foydalanuvchi 404 oladi.

---

## Hal qilinmagan, lekin bilib turish kerak

| Masala | Ta'siri |
|---|---|
| **Kod imzosi yo'q** | Har bir yuklab oluvchi SmartScreen ogohlantirishini ko'radi ("More info → Run anyway"). Yechim — OV/EV sertifikat (yillik to'lov). |
| **O'rnatuvchi oynasi inglizcha** | `Name: "uz"` `compiler:Default.isl` (inglizcha) ga bog'langan. Faqat 5 ta maxsus xabar o'zbekcha. Tuzatish uchun `Uzbek.isl` tarjimasi kerak. |
| **Windows 10 da sinalmagan** | Ilova Windows 11 da sinaldi. Haqiqiy chegara `SetProcessDpiAwarenessContext` importi bo'yicha Windows 10 1703, lekin o'rnatuvchi 1809 talab qiladi va hech qanday Windows 10 mashinada tekshirilmagan. |
| **Avtostart so'ramasdan yoqiladi** | Ilova birinchi ishga tushganda `HKCU\...\Run` ga o'zini yozadi (`config.h`: `autoStart` standart `true`). Imzolanmagan ilova uchun bu antivirus e'tiborini tortadi. |
| **macOS tomoni sinalmagan** | Mac yo'q edi. `setup.sh` whisper.cpp ni tegsiz klonlaydi (Windows `v1.9.2` ga qadalgan) — vaqt o'tishi bilan ikki platforma natijasi ajralib ketishi mumkin. |

---

## Modelni noldan yasash

Agar model yo'qolsa yoki yangilash kerak bo'lsa:

```powershell
powershell -ExecutionPolicy Bypass -File win\build.ps1 -WithTools -NoInstaller
powershell -ExecutionPolicy Bypass -File win\tools\convert_model.ps1
```

Natija HuggingFace'dagi asl vaznlardan **bayt-ma-bayt** aynan o'sha
823 369 796 baytli fayl chiqadi (SHA256 `1b02df43…c8edc1a3`) — ya'ni
konversiya takrorlanadigan.
