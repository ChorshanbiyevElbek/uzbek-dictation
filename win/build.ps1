# Audio-Matnga — Windows uchun to'liq build.
#
# Bajaradi: whisper.cpp (Vulkan) -> ilova -> o'rnatuvchi.
#
#   powershell -ExecutionPolicy Bypass -File build.ps1
#   powershell -ExecutionPolicy Bypass -File build.ps1 -SkipWhisper   # whisper.cpp tayyor bo'lsa
#   powershell -ExecutionPolicy Bypass -File build.ps1 -NoInstaller
#
# Talablar (bir marta o'rnatiladi):
#   winget install Kitware.CMake
#   winget install Microsoft.VisualStudio.2022.BuildTools --override "--add Microsoft.VisualStudio.Workload.VCTools"
#   winget install KhronosGroup.VulkanSDK
#   winget install JRSoftware.InnoSetup

param(
    # whisper.cpp va build artefaktlari (katta, ~5 GB). Bo'sh qoldirilsa —
    # D: disk bor bo'lsa D:\rubai, aks holda %LOCALAPPDATA%\rubai-build.
    [string]$WorkDir = "",
    [switch]$SkipWhisper,
    [switch]$NoInstaller,
    # whisper.cpp yordamchi vositalarini ham yig'adi (whisper-cli,
    # whisper-quantize). Modelni o'zi konversiya qiladiganlar uchun.
    [switch]$WithTools,
    # Oflayn o'rnatuvchi: model .exe ichiga joylanadi (~800 MB), internet
    # kerak emas. Ishonchsiz ulanishli foydalanuvchilar uchun.
    [string]$BundleModel = ""
)

$ErrorActionPreference = 'Stop'

# Standart yo'l HAR DOIM %LOCALAPPDATA% ichida — u har bir Windows'da bor,
# administrator huquqi talab qilmaydi va build'dan build'ga o'zgarmaydi.
#
# Ilgari bu yerda qattiq yozilgan 'D:\rubai' turardi (ishlab chiquvchining
# ikkinchi diski). "D: bor bo'lsa D: ni ishlat" degan shart ham yaramaydi:
# D: ko'pincha USB flesh yoki tashqi disk bo'ladi, u ulanganda build joyi
# jimgina o'zgarib ketadi va hammasi noldan qayta yig'iladi — yomoni,
# gigabaytlab artefakt begona diskka yoziladi.
if (-not $WorkDir) {
    $WorkDir = Join-Path $env:LOCALAPPDATA 'rubai-build'
}

$workDrive = Split-Path -Qualifier $WorkDir -EA SilentlyContinue
if ($workDrive -and -not (Test-Path "$workDrive\")) {
    Write-Host "XATO: $workDrive diski yo'q. -WorkDir bilan boshqa yo'l bering." -ForegroundColor Red
    exit 1
}
# Ko'chma diskka yozish — build sekin, disk yechib olinsa build buziladi.
if ($workDrive) {
    $dt = (Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$workDrive'" -EA SilentlyContinue).DriveType
    if ($dt -eq 2) {
        Write-Host "OGOHLANTIRISH: $workDrive ko'chma disk (USB). Build sekin bo'ladi va disk yechilsa uziladi." -ForegroundColor Yellow
    }
}

$Root       = Split-Path $PSScriptRoot -Parent
$WhisperTag = 'v1.9.2'
$WhisperSrc = Join-Path $WorkDir 'whisper.cpp'
$WhisperBld = Join-Path $WhisperSrc 'build-vulkan'
$AppBld     = Join-Path $WorkDir 'app-build'
$DistDir    = Join-Path $Root 'dist'

function Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Fail($msg) { Write-Host "XATO: $msg" -ForegroundColor Red; exit 1 }

# CMake yo'llarni teskari slash bilan qabul qilmaydi: "D:\rubai\..." dagi
# \r, \n, \t escape ketma-ketligi sifatida talqin qilinadi va yo'l buziladi.
function CMakePath($p) { return ($p -replace '\\', '/') }

function Find-Tool($name, $paths) {
    $c = Get-Command $name -ErrorAction SilentlyContinue
    if ($c) { return $c.Source }
    foreach ($p in $paths) { if (Test-Path $p) { return $p } }
    return $null
}

# ---------------------------------------------------------------- vositalar

$cmake = Find-Tool 'cmake' @("$env:ProgramFiles\CMake\bin\cmake.exe")
if (-not $cmake) { Fail "CMake topilmadi. winget install Kitware.CMake" }

# CMakeLists.txt `cmake -E copy_directory_if_different` ishlatadi — u 3.26 dan
# oldin yo'q. Eski CMake'da konfiguratsiya o'tadi, build esa DLL nusxalash
# bosqichida yiqiladi va sabab ko'rinmaydi.
$cmakeVer = [version](( & $cmake --version | Select-Object -First 1) -replace '[^0-9.]', '')
if ($cmakeVer -lt [version]'3.26') {
    Fail "CMake $cmakeVer eski — kamida 3.26 kerak. winget upgrade Kitware.CMake"
}

# git build.ps1 ichida ishlatiladi, lekin tekshirilmagan edi: yo'q bo'lsa
# CommandNotFoundException chiqib, $LASTEXITCODE tekshiruvi umuman ishlamaydi.
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Fail "git topilmadi. winget install Git.Git"
}

# Visual Studio o'rnatilgan joyini topish uchun (VC++ runtime fayllari uchun kerak).
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
if (-not (Test-Path $vswhere)) { $vswhere = $null }

if (-not $env:VULKAN_SDK) {
    $vk = Get-ChildItem 'C:\VulkanSDK' -Directory -EA SilentlyContinue |
          Sort-Object Name -Descending | Select-Object -First 1
    if (-not $vk) { Fail "Vulkan SDK topilmadi. winget install KhronosGroup.VulkanSDK" }
    $env:VULKAN_SDK = $vk.FullName
}
$env:PATH = "$env:VULKAN_SDK\Bin;$env:PATH"
Write-Host "Vulkan SDK: $env:VULKAN_SDK"

New-Item -ItemType Directory -Force $WorkDir | Out-Null

# ------------------------------------------------------------- whisper.cpp

if (-not $SkipWhisper -or -not (Test-Path "$WhisperBld\bin\Release\whisper.dll")) {
    Step "whisper.cpp ($WhisperTag)"
    if (-not (Test-Path $WhisperSrc)) {
        git clone --depth 1 --branch $WhisperTag https://github.com/ggml-org/whisper.cpp.git $WhisperSrc
        if ($LASTEXITCODE -ne 0) { Fail "whisper.cpp klonlanmadi" }
    }

    # GGML_BACKEND_DL + GGML_CPU_ALL_VARIANTS: CPU backendi bir nechta DLL
    # sifatida yig'iladi va ilova ishga tushganda protsessorga mos kelganini
    # tanlaydi. Busiz bitta CPU bazasini tanlashga majbur bo'lardik va eski
    # kompyuterlarda ilova umuman ishga tushmasdi.
    # -WithTools: whisper-cli va whisper-quantize ham yig'iladi. Ular
    # modelni o'zi konversiya qilayotganlar uchun kerak (GitHub release
    # o'chib ketgan) — standart buildda esa keraksiz vaqt sarfi.
    $examples = if ($WithTools) { 'ON' } else { 'OFF' }
    & $cmake -S (CMakePath $WhisperSrc) -B (CMakePath $WhisperBld) `
        -DGGML_VULKAN=ON -DGGML_BACKEND_DL=ON -DGGML_CPU_ALL_VARIANTS=ON `
        -DBUILD_SHARED_LIBS=ON -DGGML_NATIVE=OFF -DGGML_BLAS=OFF `
        "-DWHISPER_BUILD_EXAMPLES=$examples" -DWHISPER_BUILD_TESTS=OFF -DWHISPER_BUILD_SERVER=OFF
    if ($LASTEXITCODE -ne 0) { Fail "whisper.cpp konfiguratsiyasi" }

    & $cmake --build (CMakePath $WhisperBld) --config Release -j
    if ($LASTEXITCODE -ne 0) { Fail "whisper.cpp build" }
} else {
    Step "whisper.cpp — tayyor, o'tkazib yuborildi"
}

# ------------------------------------------------------------------- ilova

Step "Ikonka"
& powershell -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'tools\make_icon.ps1')

Step "Ilova"
& $cmake -S (CMakePath $PSScriptRoot) -B (CMakePath $AppBld) `
    "-DWHISPER_ROOT=$(CMakePath $WhisperSrc)" "-DWHISPER_BUILD=$(CMakePath $WhisperBld)"
if ($LASTEXITCODE -ne 0) { Fail "ilova konfiguratsiyasi" }

& $cmake --build (CMakePath $AppBld) --config Release
if ($LASTEXITCODE -ne 0) { Fail "ilova build" }

$AppOut = Join-Path $AppBld 'Release'

# Kerakli fayllar bor-yo'qligini tekshiramiz — o'rnatuvchi jimgina
# yarim-ishlaydigan paket yig'ib qo'ymasligi uchun.
$required = @('AudioMatnga.exe', 'whisper.dll', 'ggml.dll', 'ggml-base.dll', 'ggml-vulkan.dll')
foreach ($f in $required) {
    if (-not (Test-Path (Join-Path $AppOut $f))) { Fail "$f topilmadi ($AppOut)" }
}
$cpuDlls = @(Get-ChildItem $AppOut -Filter 'ggml-cpu-*.dll')
if ($cpuDlls.Count -lt 2) { Fail "CPU backend DLL'lari yetishmaydi (GGML_CPU_ALL_VARIANTS o'chiqmi?)" }
Write-Host "  CPU variantlari: $($cpuDlls.Count) ta"

# ------------------------------------------------------- Visual C++ runtime
#
# Ilova va whisper.cpp DLL'lari MSVCP140.dll / VCRUNTIME140.dll ga bog'liq.
# Bu fayllar TOZA WINDOWS'DA YO'Q — ular Visual C++ Redistributable bilan
# keladi. Ishlab chiqish mashinasida bor (Build Tools o'rnatgan), shuning
# uchun muammo sezilmaydi; foydalanuvchida esa ilova
# "VCRUNTIME140.dll topilmadi" deb umuman ochilmaydi.
#
# Yechim: ularni ilova yoniga nusxalaymiz (Microsoft ruxsat bergan
# "app-local deployment"). Alohida redistributable o'rnatish shart emas.
#
# api-ms-win-crt-*.dll nusxalanmaydi — ular Windows 10+ tarkibida.

Step "Visual C++ runtime"

$vsRoots = @(@(
    $(if ($vswhere) { & $vswhere -latest -products * -property installationPath 2>$null }),
    'D:\BuildTools',
    "${env:ProgramFiles}\Microsoft Visual Studio\2022\Community",
    "${env:ProgramFiles}\Microsoft Visual Studio\2022\BuildTools",
    "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\BuildTools"
) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -Unique)

# @(...) shart: bitta natija qolganda Select-Object massivni String'ga
# aylantirib yuboradi va keyingi $vsRoots[0] yo'lning BIRINCHI HARFINI
# qaytaradi — dumpbin topilmay, bog'liqlik tekshiruvi jimgina o'chib qoladi.
if (-not $vsRoots) { Fail "Visual Studio / Build Tools topilmadi. winget install Microsoft.VisualStudio.2022.BuildTools" }

# CRT — ilova va whisper.cpp uchun.
# OpenMP — ggml-base.dll va barcha ggml-cpu-*.dll VCOMP140.DLL ni talab qiladi.
#          (Bu unutilgan edi va foydalanuvchi noutbukida ilova
#           "VCOMP140.DLL topilmadi" deb ochilmagan.)
$redistPatterns = @('Microsoft.VC*.CRT', 'Microsoft.VC*.OpenMP')

$copied = 0
$copiedBytes = 0
foreach ($pattern in $redistPatterns) {
    $dir = $null
    foreach ($root in $vsRoots) {
        $found = Get-ChildItem (Join-Path $root 'VC\Redist\MSVC') -Directory -EA SilentlyContinue |
                 Sort-Object Name -Descending |
                 ForEach-Object { Get-ChildItem (Join-Path $_.FullName 'x64') -Directory -Filter $pattern -EA SilentlyContinue } |
                 Select-Object -First 1
        if ($found) { $dir = $found.FullName; break }
    }
    if (-not $dir) {
        # Diqqat: `Fail "a" + "b"` PowerShell'da qo'shish emas — "b" alohida
        # ifoda bo'lib qoladi va Fail'ning exit 1 i tufayli hech qachon
        # ko'rinmaydi. Aynan shu maslahat kerak bo'lgan joyda yo'qolardi.
        Fail ("Redistributable topilmadi: $pattern`n" +
              "Build Tools o'rnatishda 'MSVC ... redistributable MSMs' komponenti kerak.")
    }
    Write-Host "  $dir"
    $files = Get-ChildItem $dir -Filter *.dll
    Copy-Item $files.FullName -Destination $AppOut -Force
    $copied += $files.Count
    $copiedBytes += ($files | Measure-Object Length -Sum).Sum
}
Write-Host "  Nusxalandi: $copied ta fayl ($([math]::Round($copiedBytes/1MB,2)) MB)"

# ------------------------------------------------- bog'liqliklarni tekshirish
#
# Har bir yuboriladigan binarning import qiladigan DLL'lari haqiqatan
# mavjudmi. Bu tekshiruv bo'lmaganida VCOMP140.DLL unutilib, ilova
# foydalanuvchi kompyuterida umuman ochilmadi — ishlab chiqish mashinasida
# esa hamma narsa "ishlayotgandek" ko'rinardi.

Step "Bog'liqliklarni tekshirish"

$dumpbin = Get-ChildItem (Join-Path $vsRoots[0] 'VC\Tools\MSVC') -Recurse -Filter dumpbin.exe -EA SilentlyContinue |
           Where-Object { $_.FullName -like '*Hostx64\x64*' } | Select-Object -First 1

if (-not $dumpbin) {
    Write-Host "  OGOHLANTIRISH: dumpbin topilmadi, tekshiruv o'tkazilmadi" -ForegroundColor Yellow
} else {
    # Windows tarkibidagi tizim kutubxonalari — ular bilan yuborilmaydi.
    $systemDlls = @(
        'kernel32','user32','gdi32','advapi32','shell32','ole32','oleaut32',
        'comctl32','comdlg32','dwmapi','shlwapi','version','winmm','ws2_32',
        'bcrypt','crypt32','ntdll','rpcrt4','combase','psapi','imm32',
        'setupapi','cfgmgr32','powrprof','userenv','secur32','iphlpapi',
        'msvcrt','normaliz','dbghelp','dxgi','d3d12','vulkan-1','propsys'
    )

    $problems = @()
    $binaries = Get-ChildItem $AppOut -File | Where-Object { $_.Extension -in '.exe', '.dll' }

    foreach ($bin in $binaries) {
        $deps = & $dumpbin.FullName /DEPENDENTS $bin.FullName 2>&1 |
                Select-String -Pattern '^\s{4}\S+\.dll' |
                ForEach-Object { $_.ToString().Trim() }

        foreach ($dep in $deps) {
            if ($dep -like 'api-ms-win-*') { continue }          # Windows 10+ tarkibida
            $base = [IO.Path]::GetFileNameWithoutExtension($dep).ToLower()
            if ($systemDlls -contains $base) { continue }
            if (Test-Path (Join-Path $AppOut $dep)) { continue }  # biz bilan ketadi
            $problems += "$($bin.Name)  ->  $dep"
        }
    }

    if ($problems) {
        Write-Host "`n  YETISHMAYOTGAN BOG'LIQLIKLAR:" -ForegroundColor Red
        $problems | Sort-Object -Unique | ForEach-Object { Write-Host "    $_" -ForegroundColor Red }
        Fail "Yuqoridagi DLL'lar paketga kirmagan — foydalanuvchi kompyuterida ilova ochilmaydi."
    }
    Write-Host "  $($binaries.Count) ta binar tekshirildi — yetishmayotgan bog'liqlik yo'q"
}

# --------------------------------------------------------------- o'rnatuvchi

if ($NoInstaller) {
    Step "Tayyor (o'rnatuvchisiz): $AppOut"
    exit 0
}

$iscc = Find-Tool 'iscc' @(
    "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe",
    "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
    "$env:ProgramFiles\Inno Setup 6\ISCC.exe")
if (-not $iscc) { Fail "Inno Setup topilmadi. winget install JRSoftware.InnoSetup" }

Step "O'rnatuvchi"
New-Item -ItemType Directory -Force $DistDir | Out-Null

$isccArgs = @("/DSourceDir=$AppOut")
if ($BundleModel) {
    if (-not (Test-Path $BundleModel)) { Fail "Model topilmadi: $BundleModel" }
    $size = (Get-Item $BundleModel).Length
    # Ilgari bu yerda 823369796 qat'iy talab qilinardi — o'sha bitta release
    # faylidan boshqasi o'tmasdi. Model manbasi o'chgach, o'zi konversiya
    # qilingan (yoki boshqa quant) model ham kerak bo'ldi. Endi haqiqiy hajm
    # va SHA256 o'rnatuvchiga uzatiladi — ikkita nusxa-konstanta o'rniga.
    if ($size -lt 100MB) { Fail "Model juda kichik ($size bayt) — fayl chala bo'lsa kerak" }
    $sha = (Get-FileHash $BundleModel -Algorithm SHA256).Hash.ToLower()
    Write-Host "  Oflayn variant: model ichiga joylanadi ($([math]::Round($size/1MB)) MB)"
    Write-Host "  SHA256: $sha"
    $isccArgs += "/DBundleModel=$BundleModel"
    $isccArgs += "/DModelSize=$size"
    $isccArgs += "/DModelSha256=$sha"
}
$isccArgs += (Join-Path $PSScriptRoot 'installer\rubai.iss')

& $iscc @isccArgs
if ($LASTEXITCODE -ne 0) { Fail "o'rnatuvchi yig'ilmadi" }

# Get-ChildItem -Filter Win32 wildcard'ini ishlatadi: u faqat * va ? ni
# biladi, '[0-9]' esa harfma-harf qidiriladi va HECH QACHON mos kelmaydi.
# Shu sababli oddiy (onlayn) buildda bu qator bo'sh yo'l chop etardi.
$all = @(Get-ChildItem $DistDir -Filter '*-setup.exe' -EA SilentlyContinue)
$setup = $all | Where-Object {
    if ($BundleModel) { $_.Name -like '*oflayn-setup.exe' } else { $_.Name -notlike '*oflayn-setup.exe' }
} | Sort-Object LastWriteTime -Descending | Select-Object -First 1
Step "TAYYOR"
if ($setup) {
    Write-Host "  $($setup.FullName)  ($([math]::Round($setup.Length/1MB,1)) MB)" -ForegroundColor Green
} else {
    Fail "O'rnatuvchi yasaldi deb hisoblandi, lekin $DistDir ichida topilmadi."
}
