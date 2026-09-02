# rubaiSTT modelini HuggingFace'dan yuklab, whisper.cpp ggml q8_0 formatiga
# o'giradi — Windows uchun. scripts/convert_model.sh (macOS) ning muqobili.
#
# Nima uchun kerak: tayyor ggml-rubaistt.bin faqat GitHub release'da bor edi,
# u release endi mavjud emas (404). Modelni qaytadan yasashning yagona yo'li —
# HuggingFace'dagi asl vaznlardan konversiya qilish.
#
#   powershell -ExecutionPolicy Bypass -File win\tools\convert_model.ps1
#
# Talab qiladi: Python 3.10+, ~12 GB bo'sh joy, ~4 GB internet trafigi.
# Natija (standart): %LOCALAPPDATA%\Audio-Matnga\models\ggml-rubaistt.bin
# Ilova bu yo'lni o'zi qidiradi (win/core/engine.cpp: findModel).

param(
    # build.ps1 dagi -WorkDir bilan bir xil bo'lishi kerak — whisper.cpp shu yerda.
    [string]$WorkDir = "",
    # Tayyor .bin qayerga yozilsin.
    [string]$OutDir  = "$env:LOCALAPPDATA\Audio-Matnga\models",
    [string]$ModelId = "islomov/rubaistt_v2_medium",
    # f16 ni q8_0 ga siqmaslik (2x katta, RAM ko'proq, aniqlik deyarli bir xil).
    [switch]$NoQuantize
)

$ErrorActionPreference = 'Stop'

function Step($m) { Write-Host "`n==> $m" -ForegroundColor Cyan }
function Fail($m) { Write-Host "XATO: $m" -ForegroundColor Red; exit 1 }

if (-not $WorkDir) {
    $WorkDir = if (Test-Path 'D:\') { 'D:\rubai' } else { Join-Path $env:LOCALAPPDATA 'rubai-build' }
}

$WhisperSrc = Join-Path $WorkDir 'whisper.cpp'
$WhisperBld = Join-Path $WhisperSrc 'build-vulkan'
$Venv       = Join-Path $WorkDir '.venv'
$Assets     = Join-Path $WorkDir '.assets'
$Converter  = Join-Path $WhisperSrc 'models\convert-h5-to-ggml.py'

# convert_model.sh whisper.cpp allaqachon klonlangan deb hisoblaydi va
# tekshirmaydi — u yerda xato faqat "python: can't open file" bo'lib chiqadi.
if (-not (Test-Path $Converter)) {
    Fail "whisper.cpp topilmadi: $WhisperSrc`nAvval build.ps1 ni ishga tushiring (u klonlaydi), yoki -WorkDir bering."
}

$py = Get-Command python -ErrorAction SilentlyContinue
if (-not $py -or $py.Source -like '*WindowsApps*') {
    Fail "Python topilmadi. winget install Python.Python.3.12"
}

New-Item -ItemType Directory -Force $OutDir | Out-Null

# ------------------------------------------------------------ [1/5] muhit

Step "[1/5] Python muhiti"
if (-not (Test-Path "$Venv\Scripts\python.exe")) {
    & $py.Source -m venv $Venv
    if ($LASTEXITCODE -ne 0) { Fail "venv yaratilmadi" }
}
$vpy = Join-Path $Venv 'Scripts\python.exe'

& $vpy -m pip install --quiet --upgrade pip
# CPU wheel: konversiya uchun GPU kerak emas, CUDA wheel esa ~3 GB ortiq.
& $vpy -m pip install --quiet torch --index-url https://download.pytorch.org/whl/cpu
if ($LASTEXITCODE -ne 0) { Fail "torch o'rnatilmadi" }
& $vpy -m pip install --quiet transformers numpy huggingface_hub
if ($LASTEXITCODE -ne 0) { Fail "transformers/huggingface_hub o'rnatilmadi" }

# ------------------------------------------------------------ [2/5] model

Step "[2/5] Modelni yuklab olish ($ModelId, ~3 GB)"
$snap = & $vpy -c "from huggingface_hub import snapshot_download; print(snapshot_download('$ModelId'))"
if ($LASTEXITCODE -ne 0 -or -not (Test-Path $snap)) { Fail "HuggingFace'dan yuklanmadi" }
Write-Host "  $snap"

# ------------------------------------------------------- [3/5] mel filtrlari

Step "[3/5] mel_filters.npz"
$melDir = Join-Path $Assets 'whisper\assets'
New-Item -ItemType Directory -Force $melDir | Out-Null
$mel = Join-Path $melDir 'mel_filters.npz'
if (-not (Test-Path $mel)) {
    Invoke-WebRequest -UseBasicParsing -OutFile $mel `
        'https://github.com/openai/whisper/raw/main/whisper/assets/mel_filters.npz'
}

# --------------------------------------------------------- [4/5] ggml (f16)

Step "[4/5] ggml'ga o'girish (f16)"
$f16 = Join-Path $OutDir 'ggml-rubaistt-f16.bin'
if (-not (Test-Path $f16)) {
    & $vpy $Converter $snap $Assets $OutDir
    if ($LASTEXITCODE -ne 0) { Fail "konversiya" }
    $raw = Join-Path $OutDir 'ggml-model.bin'
    if (-not (Test-Path $raw)) { Fail "konverter chiqish fayli topilmadi: $raw" }
    Move-Item $raw $f16 -Force
}
Write-Host "  f16: $f16 ($([math]::Round((Get-Item $f16).Length/1MB)) MB)"

# -------------------------------------------------------- [5/5] q8_0 quant

$final = Join-Path $OutDir 'ggml-rubaistt.bin'

if ($NoQuantize) {
    Copy-Item $f16 $final -Force
} else {
    Step "[5/5] q8_0 ga siqish (kamroq RAM)"
    $quant = Join-Path $WhisperBld 'bin\Release\whisper-quantize.exe'
    if (-not (Test-Path $quant)) {
        Fail ("whisper-quantize.exe topilmadi: $quant`n" +
              "build.ps1 ni -WithTools bayrog'i bilan qayta ishga tushiring, " +
              "yoki bu skriptni -NoQuantize bilan chaqiring (model 2x katta bo'ladi).")
    }
    & $quant $f16 $final q8_0
    if ($LASTEXITCODE -ne 0) { Fail "quantize" }
    Remove-Item $f16 -Force
}

Step "TAYYOR"
$sz = (Get-Item $final).Length
Write-Host "  $final  ($([math]::Round($sz/1MB)) MB)" -ForegroundColor Green
Write-Host "  SHA256: $((Get-FileHash $final -Algorithm SHA256).Hash.ToLower())"
Write-Host ""
Write-Host "  Ilova bu yo'lni avtomatik topadi. O'rnatuvchi ichiga joylash uchun:" -ForegroundColor Yellow
Write-Host "    win\build.ps1 -BundleModel `"$final`"" -ForegroundColor Yellow
Write-Host "  (o'rnatuvchi hajmni qat'iy tekshiradi — rubai.iss ModelSize/ModelSha256 ni yangilang)"
