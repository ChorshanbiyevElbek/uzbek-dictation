# Nashr qilish yo'riqnomasi

Bu loyiha boshqa odamning ochiq repozitoriysidan olingan
(MIT litsenziyasi qayta nashrga ruxsat beradi). Quyidagi qadamlar
birinchi nashrdan **oldin** bajarilishi shart.

---

## 0. Nima allaqachon qilingan

- âœ… Asl muallifning **3 ta bank kartasi va ismi** kod va saytdan
  butunlay olib tashlandi (donat oynasi o'chirildi). Binar tekshirildi â€”
  iz qolmagan.
- âœ… Yangi `AppId` GUID berildi â€” eski nashr bilan to'qnashmaydi.
- âœ… `THIRD-PARTY-NOTICES.txt` yaratildi: whisper.cpp (MIT), rubaiSTT
  modeli (Apache-2.0) va modelning **o'zgartirilganligi to'g'risidagi
  bildirishnoma** â€” Apache-2.0 ning 4(b) bandi buni talab qiladi.
  O'rnatuvchi uni `{app}` ga joylaydi.
- âœ… Asl muallifning MIT copyright qatori `LICENSE` va `.exe` ning
  `LegalCopyright` maydonida **saqlandi** â€” bu litsenziya talabi,
  o'chirib bo'lmaydi.
- âœ… Boshqa mahsulotni so'ramasdan o'chirib yuboradigan
  `RemoveOldVersion()` olib tashlandi.
- âœ… Administrator huquqisiz o'rnatish varianti qo'shildi
  (`PrivilegesRequiredOverridesAllowed=dialog`).
- âœ… O'rnatuvchi **to'liq o'zbekchaga** o'tkazildi
  (`win/installer/Uzbek.isl`, 296 ta xabar). Ilgari sehrgar inglizcha edi.
- âœ… Nashr etuvchi nomi `ChorshanbiyevElbek` ga o'rnatildi
  (`set-identity.ps1` bajarildi).

---

## 1. Ismingiz qo'yilgan âœ…

`AppPublisher`, `CompanyName` va barcha havolalar
`ChorshanbiyevElbek` ga o'rnatildi. Nomni o'zgartirish kerak bo'lsa:

```powershell
powershell -ExecutionPolicy Bypass -File win\tools\set-identity.ps1 -GitHubUser YANGI_USERNAME
```

`LICENSE` va `LegalCopyright` ataylab tegilmaydi â€” asl muallifning
copyright qatorini saqlash MIT talabi.

## 2. Qayta yig'ing

`set-identity.ps1` dan **keyin** yig'ish shart â€” aks holda
`.exe` ichida placeholder qolib ketadi.

```powershell
powershell -ExecutionPolicy Bypass -File win\build.ps1 -SkipWhisper -BundleModel "$env:LOCALAPPDATA\Audio-Matnga\models\ggml-rubaistt.bin"
```

## 3. GitHub'ga chiqarish

```powershell
gh auth login                                                  # bir marta
powershell -ExecutionPolicy Bypass -File win\tools\publish-github.ps1
```

Skript repozitoriy yaratadi, kodni yuklaydi va Release'ga uchta asset
qo'yadi. Nashrdan oldin placeholder va begona shaxsiy ma'lumot qolgan-
qolmaganini o'zi tekshiradi. Quruq yurgizish: `-WhatIf`.

| Fayl | Hajm | Izoh |
|---|---|---|
| `Audio-Matnga-1.0.0-oflayn-setup.exe` | 749 MB | model ichida â€” **asosiy variant** |
| `ggml-rubaistt.bin` | 785 MB | model alohida (qo'lda qo'yish uchun) |
| `Audio-Matnga-1.0.0-setup.exe` | 8.6 MB | faqat `ModelUrl` ishlagandan keyin |

> GitHub Releases bitta asset uchun **2 GB** gacha ruxsat beradi, shuning
> uchun 749 MB muammo emas. Repozitoriyning **o'ziga** bu fayllarni
> qo'ymang â€” `dist/` va `*.bin` `.gitignore` da.

Saytni ham chiqarish: **Settings â†’ Pages â†’ Source: `main`, papka `/docs`**
â†’ `https://chorshanbiyevelbek.github.io/uzbek-dictation/`

## 4. Onlayn o'rnatuvchini yoqish (ixtiyoriy)

`ggml-rubaistt.bin` ni release'ga yuklaganingizdan keyin, uning haqiqiy
havolasini `win/installer/rubai.iss` dagi `ModelUrl` ga yozing.
`ModelSha256` va `ModelSize` allaqachon to'g'ri
(`1b02df43â€¦c8edc1a3`, `823369796`). Keyin oddiy `-setup.exe` ni qayta
yig'ing. Shu bajarilmasa, **faqat oflayn variantni tarqating** â€” aks
holda foydalanuvchi 404 oladi.

---

## Hal qilinmagan, lekin bilib turish kerak

| Masala | Ta'siri |
|---|---|
| **Kod imzosi yo'q** | Har bir yuklab oluvchi SmartScreen ogohlantirishini ko'radi ("More info â†’ Run anyway"). Yechim â€” OV/EV sertifikat (yillik to'lov). |
| **Windows 10 da sinalmagan** | Ilova Windows 11 da sinaldi. Haqiqiy chegara `SetProcessDpiAwarenessContext` importi bo'yicha Windows 10 1703, lekin o'rnatuvchi 1809 talab qiladi va hech qanday Windows 10 mashinada tekshirilmagan. |
| **Avtostart so'ramasdan yoqiladi** | Ilova birinchi ishga tushganda `HKCU\...\Run` ga o'zini yozadi (`config.h`: `autoStart` standart `true`). Imzolanmagan ilova uchun bu antivirus e'tiborini tortadi. |
| **macOS tomoni sinalmagan** | Mac yo'q edi. `setup.sh` whisper.cpp ni tegsiz klonlaydi (Windows `v1.9.2` ga qadalgan) â€” vaqt o'tishi bilan ikki platforma natijasi ajralib ketishi mumkin. |

---

## Modelni noldan yasash

Agar model yo'qolsa yoki yangilash kerak bo'lsa:

```powershell
powershell -ExecutionPolicy Bypass -File win\build.ps1 -WithTools -NoInstaller
powershell -ExecutionPolicy Bypass -File win\tools\convert_model.ps1
```

Natija HuggingFace'dagi asl vaznlardan **bayt-ma-bayt** aynan o'sha
823 369 796 baytli fayl chiqadi (SHA256 `1b02df43â€¦c8edc1a3`) â€” ya'ni
konversiya takrorlanadigan.
