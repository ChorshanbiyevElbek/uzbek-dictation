# Loyihani yangi egaga moslashtiradi: nashr etuvchi nomi, havolalar va
# macOS bundle identifikatorlari almashtiriladi.
#
#   powershell -ExecutionPolicy Bypass -File win\tools\set-identity.ps1 -GitHubUser elbek-dev
#
# Nima uchun kerak: loyiha boshqa odamning ochiq repozitoriysidan olingan.
# Litsenziya (MIT) qayta nashrga ruxsat beradi, LEKIN nashr etuvchi
# sifatida asl muallifning ismi qolib ketsa, bu ham noto'g'ri atribut,
# ham qo'llab-quvvatlash so'rovlari o'sha odamga borishini anglatadi.
#
# MUHIM: asl muallifning copyright qatori (LICENSE va app.rc dagi
# LegalCopyright) O'ZGARTIRILMAYDI — uni saqlash MIT talabi.

param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[A-Za-z0-9](?:[A-Za-z0-9]|-(?=[A-Za-z0-9])){0,38}$')]
    [string]$GitHubUser,

    # Repozitoriy nomi (GitHub'dagi).
    [string]$RepoName = 'uzbek-dictation',

    # AppPublisher uchun ko'rinadigan nom. Bo'sh bo'lsa — GitHubUser.
    [string]$DisplayName = ''
)

$ErrorActionPreference = 'Stop'
if (-not $DisplayName) { $DisplayName = $GitHubUser }

$Root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$repoUrl = "https://github.com/$GitHubUser/$RepoName"

Write-Host "Yangi egasi : $DisplayName"
Write-Host "Repozitoriy : $repoUrl"
Write-Host ""

# fayl -> (izlanadigan, almashtiriladigan) juftliklari
$edits = @(
    @{ File = 'win\installer\rubai.iss';  From = 'GITHUB_USERNAME_PLACEHOLDER/uzbek-dictation'; To = "$GitHubUser/$RepoName" },
    @{ File = 'win\installer\rubai.iss';  From = '"GITHUB_USERNAME_PLACEHOLDER"';               To = "`"$DisplayName`"" },
    @{ File = 'win\res\app.rc';           From = 'GITHUB_USERNAME_PLACEHOLDER';                 To = $DisplayName },
    @{ File = 'setup.sh';                 From = 'MuhammadMirrr/uzbek-dictation';               To = "$GitHubUser/$RepoName" },
    @{ File = 'README.md';                From = 'GITHUB_USERNAME_PLACEHOLDER/uzbek-dictation'; To = "$GitHubUser/$RepoName" },
    @{ File = 'README.md';                From = 'MuhammadMirrr/uzbek-dictation';               To = "$GitHubUser/$RepoName" },
    @{ File = 'win\README.md';            From = 'MuhammadMirrr/uzbek-dictation';               To = "$GitHubUser/$RepoName" },
    @{ File = 'web\index.html';           From = 'GITHUB_USERNAME_PLACEHOLDER/uzbek-dictation'; To = "$GitHubUser/$RepoName" },
    @{ File = 'web\index.html';           From = 'MuhammadMirrr/uzbek-dictation';               To = "$GitHubUser/$RepoName" },
    @{ File = 'RELEASE.md';               From = 'SIZNING_USERNAME';                            To = $GitHubUser },
    # macOS: bundle ID va LaunchAgent yorlig'i egasi nazorat qiladigan
    # reverse-DNS bo'lishi kerak, aks holda ikki ilova to'qnashadi.
    @{ File = 'src\build.sh';             From = 'com.rubaistt.dictation';                      To = "com.github.$GitHubUser.audiomatnga" },
    @{ File = 'setup.sh';                 From = 'com.rubaistt.dictation';                      To = "com.github.$GitHubUser.audiomatnga" }
)

$total = 0
foreach ($e in $edits) {
    $path = Join-Path $Root $e.File
    if (-not (Test-Path $path)) { Write-Host "  o'tkazildi (yo'q): $($e.File)"; continue }

    # Kodlashni saqlaymiz: .ps1/.iss/.rc CRLF+BOM, qolganlari LF.
    $bytes = [IO.File]::ReadAllBytes($path)
    $hasBom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
    $text = [IO.File]::ReadAllText($path, [Text.UTF8Encoding]::new($false))

    $n = ([regex]::Matches($text, [regex]::Escape($e.From))).Count
    if ($n -eq 0) { continue }

    $text = $text.Replace($e.From, $e.To)
    [IO.File]::WriteAllText($path, $text, [Text.UTF8Encoding]::new($hasBom))
    Write-Host ("  {0,-28} {1} ta almashtirildi" -f $e.File, $n)
    $total += $n
}

Write-Host ""
Write-Host "Jami: $total ta o'zgartirish" -ForegroundColor Green

# Qolgan izlarni ko'rsatamiz — jimgina o'tkazib yubormaslik uchun.
$leftover = Select-String -Path (Join-Path $Root '*') -Include *.cpp,*.h,*.iss,*.rc,*.md,*.sh,*.html,*.ps1 `
    -Recurse -Pattern 'MuhammadMirrr|Mirkabilov|GITHUB_USERNAME_PLACEHOLDER' -EA SilentlyContinue |
    Where-Object { $_.Path -notlike '*set-identity.ps1' }

if ($leftover) {
    Write-Host ""
    Write-Host "OGOHLANTIRISH — qo'lda tekshirish kerak bo'lgan qatorlar:" -ForegroundColor Yellow
    $leftover | ForEach-Object { "  {0}:{1}" -f $_.Path.Replace("$Root\", ''), $_.LineNumber }
    Write-Host "  (LICENSE va LegalCopyright dagi asl copyright ATAYLAB saqlanadi.)"
} else {
    Write-Host "Eski egaga oid iz qolmadi." -ForegroundColor Green
}
