# Loyihani GitHub'ga chiqaradi: repozitoriy yaratadi, kodni yuklaydi va
# o'rnatuvchilarni Release'ga asset sifatida qo'yadi.
#
# OLDIN bir marta (brauzer orqali, parol/token menga ko'rsatilmaydi):
#   gh auth login
#
# KEYIN:
#   powershell -ExecutionPolicy Bypass -File win\tools\publish-github.ps1
#
# Nima uchun gh: token hech qayerda faylga yozilmaydi va buyruq tarixiga
# tushmaydi — gh uni Windows Credential Manager'da saqlaydi.

param(
    [string]$RepoName    = 'uzbek-dictation',
    [string]$Tag         = 'v1.0',
    # Repozitoriy ochiq bo'lsinmi. Yopiq qilish uchun: -Visibility private
    [ValidateSet('public','private')]
    [string]$Visibility  = 'public',
    # Faqat Release yangilash (repozitoriy allaqachon bor bo'lsa).
    [switch]$ReleaseOnly,
    # Hech narsa qilmasdan, nima bo'lishini ko'rsatadi.
    [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'

function Step($m) { Write-Host "`n==> $m" -ForegroundColor Cyan }
function Fail($m) { Write-Host "XATO: $m" -ForegroundColor Red; exit 1 }
function Info($m) { Write-Host "    $m" -ForegroundColor DarkGray }

$Root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
Set-Location $Root

# ------------------------------------------------------------- tekshiruvlar

Step "Tekshiruvlar"

if (-not (Get-Command gh -EA SilentlyContinue)) {
    Fail "GitHub CLI topilmadi. winget install GitHub.cli"
}

# Native .exe ning stderr'ini PowerShell 5.1 da ushlash NativeCommandError
# tashlaydi va $ErrorActionPreference='Stop' bilan skript yiqiladi.
# Shuning uchun tekshiruv chaqiruvlari shu yordamchi orqali ketadi.
function Try-Exec([scriptblock]$sb) {
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { & $sb *> $null; return ($LASTEXITCODE -eq 0) }
    finally { $ErrorActionPreference = $prev }
}

if (-not (Try-Exec { gh auth status })) {
    Fail ("GitHub'ga kirilmagan. Avval quyidagini bajaring:`n" +
          "    gh auth login`n" +
          "  (brauzer ochiladi; token faylga yozilmaydi)")
}
$user = (gh api user --jq .login 2>$null)
if (-not $user) { Fail "GitHub foydalanuvchisi aniqlanmadi" }
Info "GitHub foydalanuvchi: $user"

# Diqqat: Select-String da -Recurse YO'Q — fayllarni Get-ChildItem topadi.
function Scan([string[]]$include, [string]$pattern) {
    $f = Get-ChildItem $Root -Recurse -File -Include $include -EA SilentlyContinue |
         Where-Object { $_.FullName -notlike '*\.git\*' -and
                        $_.Name -ne 'set-identity.ps1' -and $_.Name -ne 'publish-github.ps1' }
    if ($f) { Select-String -Path $f.FullName -Pattern $pattern -EA SilentlyContinue }
}

# Placeholder qolgan bo'lsa, nashr qilib bo'lmaydi — .exe ichida
# "GITHUB_USERNAME_PLACEHOLDER" ko'rinib qoladi.
$ph = Scan @('*.iss','*.rc','*.md','*.html') 'GITHUB_USERNAME_PLACEHOLDER'
if ($ph) {
    Write-Host "  Placeholder qolgan fayllar:" -ForegroundColor Yellow
    $ph | ForEach-Object { Info $_.Path.Replace("$Root\", '') }
    Fail ("Avval nomingizni qo'ying:`n" +
          "    powershell -ExecutionPolicy Bypass -File win\tools\set-identity.ps1 -GitHubUser $user`n" +
          "  So'ng QAYTA YIG'ING, aks holda .exe ichida placeholder qoladi.")
}

# Asl muallifning shaxsiy ma'lumoti qolib ketmasin.
$leak = Scan @('*.cpp','*.h','*.html','*.iss','*.rc') '\b9860\s?\d{4}|\b5614\s?6818|\b4231\s?2000|Mirkabilov'
if ($leak) {
    $leak | ForEach-Object { Info $_.Path.Replace("$Root\", '') + ":" + $_.LineNumber }
    Fail "Begona shaxsiy/moliyaviy ma'lumot topildi. Nashr to'xtatildi."
}
Info "Shaxsiy ma'lumot tekshiruvi: toza"

$dist = Join-Path $Root 'dist'
$assets = @()
foreach ($n in @('Audio-Matnga-1.0.0-oflayn-setup.exe', 'Audio-Matnga-1.0.0-setup.exe')) {
    $p = Join-Path $dist $n
    if (Test-Path $p) { $assets += $p; Info ("{0}  ({1:N1} MB)" -f $n, ((Get-Item $p).Length/1MB)) }
}
$model = Join-Path $env:LOCALAPPDATA 'Audio-Matnga\models\ggml-rubaistt.bin'
if (Test-Path $model) { $assets += $model; Info ("ggml-rubaistt.bin  ({0:N0} MB)" -f ((Get-Item $model).Length/1MB)) }

if (-not $assets) { Fail "dist/ bo'sh. Avval win\build.ps1 ni ishga tushiring." }

if ($WhatIf) {
    Step "WhatIf — hech narsa qilinmadi"
    Info "repozitoriy : $user/$RepoName ($Visibility)"
    Info "tag         : $Tag"
    $assets | ForEach-Object { Info "asset       : $(Split-Path $_ -Leaf)" }
    exit 0
}

# ------------------------------------------------------------- repozitoriy

if (-not $ReleaseOnly) {
    Step "Repozitoriy"
    if (-not (Try-Exec { gh repo view "$user/$RepoName" })) {
        gh repo create "$user/$RepoName" --$Visibility `
            --description "O'zbekcha ovozli yozuv — istalgan ilovada tugma bosib gapiring, matn yoziladi. Butunlay oflayn." `
            --homepage "https://github.com/$user/$RepoName"
        if ($LASTEXITCODE -ne 0) { Fail "repozitoriy yaratilmadi" }
        Info "yaratildi: $user/$RepoName"
    } else {
        Info "allaqachon mavjud: $user/$RepoName"
    }

    Step "Kodni yuklash"
    $remote = git remote get-url origin 2>$null
    if (-not $remote) {
        git remote add origin "https://github.com/$user/$RepoName.git"
    }
    git branch -M main
    git push -u origin main
    if ($LASTEXITCODE -ne 0) { Fail "push bajarilmadi" }
    Info "kod yuklandi"
}

# ----------------------------------------------------------------- release

Step "Release ($Tag)"

$notes = @"
## Yuklab olish

**Oddiy foydalanuvchi uchun: ``Audio-Matnga-1.0.0-oflayn-setup.exe`` (749 MB).**
Bitta fayl — ichida hammasi bor, internet kerak emas.

| Fayl | Hajm | Kimga |
|---|---|---|
| ``Audio-Matnga-1.0.0-oflayn-setup.exe`` | 749 MB | **Hammaga** — model ichida |
| ``Audio-Matnga-1.0.0-setup.exe`` | 8.6 MB | Internet barqaror bo'lsa |
| ``ggml-rubaistt.bin`` | 785 MB | Modelni qo'lda qo'yish uchun |

## O'rnatish

1. ``.exe`` ni ishga tushiring
2. Windows «Windows protected your PC» desa — **Batafsil (More info) → Baribir ishga tushirish (Run anyway)**. Ilova raqamli imzoga ega emas.
3. Sozlamalar oynasida **mikrofoningizni tanlang**

## Ishlatish

**Ctrl + Alt + D** bosing → gapiring → yana bosing. Matn kursor turgan joyga yoziladi.

## Talablar

- Windows 10 yoki 11, **64-bit**
- 6 GB RAM (8 GB tavsiya etiladi)
- Videokarta **shart emas** — bo'lmasa protsessorda ishlaydi, aniqlik bir xil
- ~890 MB disk (o'rnatish paytida 1.8 GB bo'sh joy)

## Tezlik

| Rejim | 10 soniyalik diktovka |
|---|---|
| Videokarta (Vulkan) | ~1 soniya |
| Protsessor | ~7 soniya |

Aniqlik: **WER 17%** (Google FLEURS o'zbek to'plami) — ikkala rejimda bir xil.

## Maxfiylik

Ovozingiz kompyuteringizdan chiqmaydi. Ilova ichida birorta tarmoq
kutubxonasi yo'q — texnik jihatdan internetga murojaat qila olmaydi.
Telemetriya, analitika yo'q.

---

Litsenziyalar: ``THIRD-PARTY-NOTICES.txt``.
Model: [rubaiSTT v2 medium](https://huggingface.co/islomov/rubaistt_v2_medium) (Apache-2.0) ·
Inference: [whisper.cpp](https://github.com/ggml-org/whisper.cpp) (MIT)
"@

$notesFile = Join-Path $env:TEMP "audio-matnga-release-notes.md"
Set-Content -Path $notesFile -Value $notes -Encoding UTF8

if (Try-Exec { gh release view $Tag --repo "$user/$RepoName" }) {
    Info "release mavjud — assetlar yangilanmoqda"
    gh release upload $Tag @assets --repo "$user/$RepoName" --clobber
} else {
    Info "yangi release yaratilmoqda (yuklash bir necha daqiqa oladi)"
    gh release create $Tag @assets --repo "$user/$RepoName" `
        --title "Audio-Matnga 1.0.0" --notes-file $notesFile
}
if ($LASTEXITCODE -ne 0) { Fail "release yaratilmadi" }

Remove-Item $notesFile -Force -EA SilentlyContinue

Step "TAYYOR"
Write-Host "  https://github.com/$user/$RepoName/releases/latest" -ForegroundColor Green
Write-Host ""
Write-Host "  Saytni ham chiqarish (ixtiyoriy):" -ForegroundColor Yellow
Write-Host "    GitHub -> Settings -> Pages -> Source: main, papka: /web"
Write-Host "    Natija: https://$user.github.io/$RepoName/"
