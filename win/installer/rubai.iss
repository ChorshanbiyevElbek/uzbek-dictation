; Audio-Matnga — Windows o'rnatuvchisi (Inno Setup 6).
;
; Model (785 MB) o'rnatuvchi ichiga QO'SHILMAYDI — u o'rnatish paytida
; yuklab olinadi. Sabablari:
;   1) 800 MB .exe ni tarqatish qiyin, har yangilanishda qayta yuklanadi;
;   2) o'rnatish paytida yuklash administrator huquqi ostida ketadi, ya'ni
;      model Program Files ichiga tushadi va ilova keyin ruxsat so'ramaydi;
;   3) o'rnatuvchining o'zi ~30 MB bo'lib qoladi.
;
; Build: iscc rubai.iss  (SourceDir = build natijasi)

#define AppName        "Audio-Matnga"
#define AppVersion     "1.0.0"
; set-identity.ps1 quyidagi ikki qatorni almashtiradi.
#define AppPublisher   "ChorshanbiyevElbek"
#define AppExe         "AudioMatnga.exe"
#define AppUrl         "https://github.com/ChorshanbiyevElbek/uzbek-dictation"

; Model manzili, hajmi va SHA256 — ISCC ga /D bilan berish mumkin:
;   iscc /DModelUrl=https://.../ggml-rubaistt.bin /DModelSize=... /DModelSha256=... rubai.iss
; build.ps1 -BundleModel bilan chaqirilganda hajm va hash avtomatik uzatiladi.
;
; Standart manzil yangi egasining release'iga ishora qiladi. Release
; yaratilgunga qadar u ham 404 beradi — shuning uchun oflayn variantni
; (-BundleModel) chiqarish tavsiya etiladi.
; Modelni noldan yasash: win/tools/convert_model.ps1
#ifndef ModelUrl
  #define ModelUrl     "https://github.com/ChorshanbiyevElbek/uzbek-dictation/releases/download/v1.0/ggml-rubaistt.bin"
#endif
#ifndef ModelSha256
  #define ModelSha256  "1b02df434902015e1464611a7748927e42fcb55c49791c85239cf713c8edc1a3"
#endif
#ifndef ModelSize
  #define ModelSize    823369796
#endif

[Setup]
; Yangi nashr — yangi AppId. Asl loyihanikini qayta ishlatib bo'lmaydi:
; bir xil ID ikki xil nashrni Windows uchun bitta mahsulot qilib ko'rsatadi
; va ular bir-birini yangilanish deb o'chirib yuborardi.
AppId={{BA5E9086-5E8D-4D1C-8EE3-13F28EE19D4F}
AppName={#AppName}
AppVersion={#AppVersion}
; Busiz Windows "Ilovalar" ro'yxatida "... version 1.0.0" deb ko'rsatadi.
AppVerName={#AppName} {#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL={#AppUrl}
AppSupportURL={#AppUrl}
DefaultDirName={autopf}\Audio-Matnga
DefaultGroupName={#AppName}
UninstallDisplayIcon={app}\{#AppExe}
OutputDir=..\..\dist
#ifdef BundleModel
OutputBaseFilename=Audio-Matnga-{#AppVersion}-oflayn-setup
#else
OutputBaseFilename=Audio-Matnga-{#AppVersion}-setup
#endif
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern

; Model [Files] ro'yxatida yo'q (onlayn variant), shuning uchun Inno uning
; joyini o'zi hisoblay olmaydi va "Ready" sahifasida atigi ~64 MB talab
; qilinadi deb ko'rsatardi. Diskda joy yetmasa xato eng oxirida chiqardi.
#ifndef BundleModel
ExtraDiskSpaceRequired={#ModelSize}
#endif

; 64-bitli ilova; 32-bitli Windows'da o'rnatilmaydi.
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

; Windows 10 64-bit. Ilovaning haqiqiy chegarasi bundan past
; (SetProcessDpiAwarenessContext importi -> Windows 10 1703), lekin
; 1809 dan past buildlarda sinalmagan, shuning uchun shu qoldirilgan.
MinVersion=10.0.17763

; Standart holatda Program Files ga o'rnatiladi (administrator kerak).
; PrivilegesRequiredOverridesAllowed=dialog: administrator huquqi
; bo'lmagan foydalanuvchiga "faqat men uchun" varianti taklif qilinadi va
; ilova {localappdata}\Programs ga tushadi. Busiz ular umuman
; o'rnata olmasdi. {autopf} ikkala rejimda ham to'g'ri hal bo'ladi.
PrivilegesRequired=admin
PrivilegesRequiredOverridesAllowed=dialog

[Languages]
; Uzbek.isl — shu loyiha bilan birga keladi. Inno Setup rasmiy
; tarjimalari orasida o'zbek tili yo'q, shuning uchun ilgari bu yerda
; "compiler:Default.isl" (INGLIZCHA) turardi: [CustomMessages] o'zbekcha
; bo'lsa-da, sehrgarning barcha standart tugma va matnlari inglizcha
; ko'rinardi — oddiy foydalanuvchi uchun asosiy to'siq shu edi.
Name: "uz"; MessagesFile: "Uzbek.isl"

[CustomMessages]
uz.CreateDesktopIcon=Ish stolida yorliq yaratilsin
uz.AutoStart=Kompyuter yonganda avtomatik ishga tushsin
uz.LaunchApp={#AppName} ni ishga tushirish
uz.DownloadingModel=Til modeli yuklab olinmoqda (785 MB)...
uz.ModelFailed=Til modelini yuklab olib bo'lmadi (3 marta urinildi).%n%nBu odatda internet ulanishi uzilganini bildiradi — 785 MB fayl uchun barqaror ulanish kerak.%n%nQO'LDA YUKLAB OLISH (tavsiya etiladi):%n%n1. Quyidagi havolani brauzerda oching yoki yuklab olish menejeriga bering:%n   {#ModelUrl}%n%n2. Yuklangan «ggml-rubaistt.bin» faylini shu o'rnatuvchi (setup.exe) turgan papkaga qo'ying%n%n3. O'rnatuvchini qaytadan ishga tushiring — u faylni o'zi topadi va internetsiz o'rnatadi%n%nTexnik xato: %1

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "Qo'shimcha:"

; Avtostart bu yerda EMAS — ilovaning o'zi birinchi ishga tushganda yoqadi.
;
; Sabab: o'rnatuvchi administrator huquqi bilan ishlaydi, shuning uchun
; undagi HKCU administratorning registr uyasiga ishora qiladi, ilovani
; o'rnatayotgan foydalanuvchinikiga emas. Natijada avtostart noto'g'ri
; profilga yozilib, ishlamas edi. Ilova esa oddiy foydalanuvchi huquqida
; ishlaydi va HKCU'ni to'g'ri topadi.

[Files]
; Ilova va whisper.cpp kutubxonalari.
Source: "{#SourceDir}\AudioMatnga.exe";       DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\whisper.dll";        DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\ggml.dll";           DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\ggml-base.dll";      DestDir: "{app}"; Flags: ignoreversion

; GPU backend (NVIDIA + AMD + Intel).
Source: "{#SourceDir}\ggml-vulkan.dll";    DestDir: "{app}"; Flags: ignoreversion

; CPU backendining barcha variantlari. Ilova ishga tushganda protsessorga
; mos kelganini o'zi tanlaydi — shu sababli 2011 yildan keyingi har qanday
; x64 kompyuterda ishlaydi.
Source: "{#SourceDir}\ggml-cpu-*.dll";     DestDir: "{app}"; Flags: ignoreversion

; Visual C++ runtime.
;
; MSVCP140.dll / VCRUNTIME140.dll toza Windows'da YO'Q — ular Visual C++
; Redistributable bilan keladi. Ularsiz ilova umuman ochilmaydi
; ("VCRUNTIME140.dll topilmadi"). Ishlab chiqish mashinasida bor bo'lgani
; uchun bu xato sinovda ko'rinmaydi.
;
; Ilova yoniga qo'yamiz (Microsoft ruxsat bergan app-local deployment) —
; alohida redistributable o'rnatish va qayta yuklash shart emas.
; build.ps1 ularni Visual Studio redist papkasidan nusxalaydi.
Source: "{#SourceDir}\msvcp140*.dll";      DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\vcruntime140*.dll";  DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\concrt140.dll";      DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist
Source: "{#SourceDir}\vccorlib140.dll";    DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist

; OpenMP runtime — ggml-base.dll va barcha ggml-cpu-*.dll shuni talab qiladi.
; Unutilganda ilova "VCOMP140.DLL topilmadi" deb umuman ochilmaydi.
Source: "{#SourceDir}\vcomp140.dll";       DestDir: "{app}"; Flags: ignoreversion

Source: "..\..\LICENSE";                   DestDir: "{app}"; DestName: "LICENSE.txt"; Flags: ignoreversion

; whisper.cpp (MIT) va rubaiSTT modeli (Apache-2.0) litsenziyalari —
; ikkalasi ham binar bilan birga tarqatilishi SHART.
Source: "..\..\THIRD-PARTY-NOTICES.txt";   DestDir: "{app}"; Flags: ignoreversion

; OFLAYN VARIANT
;
; iscc /DBundleModel=<model faylining yo'li> ... bilan yig'ilsa, model
; o'rnatuvchi ichiga joylanadi va internet umuman kerak bo'lmaydi.
; Natija ~800 MB, lekin ishonchsiz ulanishda yagona ishlaydigan yo'l.
#ifdef BundleModel
Source: "{#BundleModel}"; DestDir: "{app}\models"; \
    DestName: "ggml-rubaistt.bin"; Flags: ignoreversion
#endif

[Dirs]
Name: "{app}\models"

[Icons]
Name: "{group}\{#AppName}";                Filename: "{app}\{#AppExe}"
Name: "{group}\{#AppName} ni o'chirish";   Filename: "{uninstallexe}"
Name: "{autodesktop}\{#AppName}";          Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Run]
; runasoriginaluser — ilova administrator emas, o'rnatayotgan
; FOYDALANUVCHI nomidan ishga tushadi. Busiz sozlamalar va avtostart
; administrator profiliga yozilib qolardi.
Filename: "{app}\{#AppExe}"; Description: "{cm:LaunchApp}"; \
    Flags: nowait postinstall skipifsilent runasoriginaluser; \
    Check: AppWasNotRunning

[UninstallDelete]
; Model o'rnatuvchi bilan kelmagani uchun [Files] uni bilmaydi — qo'lda
; o'chiramiz, aks holda 785 MB fayl diskda qolib ketadi.
Type: files;      Name: "{app}\models\ggml-rubaistt.bin"
Type: dirifempty; Name: "{app}\models"

[Code]
//
// MODEL QAYERDAN OLINADI
//
// Model 785 MB. GitHub'dan yuklab olish O'zbekistonda ishonchsiz — provayder,
// proksi yoki antivirus TLS ulanishini uzib qo'yishi mumkin (WinHTTP 12152:
// "Server javobi buzilgan"). Shuning uchun uch manba ketma-ket tekshiriladi:
//
//   1. Allaqachon o'rnatilgan  — qayta o'rnatish/yangilash holati
//   2. setup.exe YONIDA        — foydalanuvchi modelni brauzer, yuklab olish
//                                menejeri, Telegram yoki fleshka orqali olib,
//                                setup.exe yoniga qo'yishi mumkin
//   3. Internetdan yuklash     — 3 marta urinib ko'riladi
//
// Ikkinchi variant eng muhimi: internet ishonchsiz bo'lsa ham ilova
// o'rnatiladi va model qo'lda olib kelinadi.

var
  DownloadPage: TDownloadWizardPage;
  ModelSource: String;      // ko'chirish uchun manba; bo'sh = ko'chirish shart emas
  AppWasRunning: Boolean;   // yangilashdan oldin ilova ochiq edimi
  SkippedModel: Boolean;    // modelsiz o'rnatishga rozi bo'ldi

// Yangilashdan oldin ilova ishlab turganini eslab qolamiz.
//
// Ilova avtostartda bo'lgani uchun foydalanuvchida u deyarli doim ochiq.
// Windows RestartManager fayllarni almashtirish uchun uni yopadi, lekin
// qaytadan ochmaydi — foydalanuvchi esa ilova yo'qolgan deb o'ylaydi.
// Shuning uchun oxirida o'zimiz qayta ishga tushiramiz.
// OLIB TASHLANDI: RemoveOldVersion().
//
// U asl loyihaning eski "RubaiSTT" o'rnatmasini (AppId {7F3A9C21-...})
// /VERYSILENT bilan, sehrgar ko'rsatilishidan ham OLDIN, foydalanuvchi
// hech narsaga rozilik bermasidan o'chirib tashlardi. Ikki sabab bilan
// bu yerda o'rinsiz:
//   1. Bu — boshqa hisobdan chiqarilgan fork. Begona mahsulotni
//      so'ramasdan o'chirish mumkin emas.
//   2. Foydalanuvchi o'rnatishni bekor qilsa ham, eski ishlaydigan
//      nusxasi (va 785 MB modeli) allaqachon yo'q bo'lgan bo'lardi.
//
// Ikkita yozuv qolishi mumkin — bu README da qo'lda o'chirish qadami
// sifatida hujjatlashtirilgan.

function InitializeSetup(): Boolean;
begin
  Result := True;
  AppWasRunning := CheckForMutexes('Global\AudioMatngaSingleInstance') or
                   CheckForMutexes('Global\RubaiSTTDictationSingleInstance');
end;

// [Run] bo'limi uchun: ilova avval ishlamayotgan bo'lsagina "ishga tushirish"
// katagi ko'rsatiladi. Aks holda ikki marta ishga tushib, ikkinchi nusxa
// Sozlamalar oynasini ochib yuborardi.
function AppWasNotRunning(): Boolean;
begin
  Result := not AppWasRunning;
end;

function OnDownloadProgress(const Url, FileName: String; const Progress, ProgressMax: Int64): Boolean;
begin
  if ProgressMax <> 0 then
    DownloadPage.SetProgress(Progress, ProgressMax);
  Result := True;
end;

// Fayl bor va hajmi to'g'rimi (chala yuklangan fayl o'tib ketmasligi uchun).
function ModelFileValid(const Path: String): Boolean;
var
  Size: Int64;
begin
  Result := False;
  if not FileExists(Path) then
    Exit;
  if not FileSize64(Path, Size) then
    Exit;
  Result := (Size = {#ModelSize});
end;

function ModelAlreadyInstalled(): Boolean;
begin
  Result := ModelFileValid(ExpandConstant('{app}\models\ggml-rubaistt.bin'));
end;

// setup.exe yonidagi model (2-manba).
function LocalModelPath(): String;
begin
  Result := ExpandConstant('{src}\ggml-rubaistt.bin');
end;

// Internetdan yuklash, N marta urinib. Muvaffaqiyatda True.
//
// Uzilish ko'pincha vaqtinchalik bo'ladi, shuning uchun bitta xatodan keyin
// darhol taslim bo'lmaymiz.
function TryDownload(Attempts: Integer; var ErrText: String): Boolean;
var
  I: Integer;
begin
  Result := False;
  ErrText := '';
  for I := 1 to Attempts do
  begin
    try
      if WizardSilent() then
        DownloadTemporaryFile('{#ModelUrl}', 'ggml-rubaistt.bin', '{#ModelSha256}', nil)
      else
      begin
        DownloadPage.Clear;
        DownloadPage.Add('{#ModelUrl}', 'ggml-rubaistt.bin', '{#ModelSha256}');
        DownloadPage.Download;
      end;
      Result := True;
      Exit;
    except
      ErrText := GetExceptionMessage;
    end;
  end;
end;

// Modelni tayyorlaydi. Bo'sh satr = muvaffaqiyat, aks holda xato matni.
function AcquireModel(): String;
var
  ErrText: String;
begin
  Result := '';
  ModelSource := '';

#ifdef BundleModel
  // Oflayn variant: model o'rnatuvchi ichida, [Files] uni o'zi joylaydi.
  Exit;
#endif

  if ModelAlreadyInstalled() then
    Exit;

  // 2-manba: setup.exe yonida
  if ModelFileValid(LocalModelPath()) then
  begin
    ModelSource := LocalModelPath();
    Exit;
  end;

  // 3-manba: internet
  if not WizardSilent() then
    DownloadPage.Show;
  try
    if TryDownload(3, ErrText) then
      ModelSource := ExpandConstant('{tmp}\ggml-rubaistt.bin')
    else
      Result := FmtMessage(ExpandConstant('{cm:ModelFailed}'), [ErrText]);
  finally
    if not WizardSilent() then
      DownloadPage.Hide;
  end;
end;

procedure InitializeWizard;
begin
  DownloadPage := CreateDownloadPage(
    SetupMessage(msgWizardPreparing),
    ExpandConstant('{cm:DownloadingModel}'),
    @OnDownloadProgress);
end;

// Oynali (odatiy) o'rnatish.
function NextButtonClick(CurPageID: Integer): Boolean;
var
  ErrText: String;
begin
  Result := True;
  if CurPageID <> wpReady then
    Exit;

  ErrText := AcquireModel();
  if ErrText <> '' then
  begin
    // Ilgari bu yerda faqat xato ko'rsatilib, Result := False qilinardi —
    // ya'ni model yuklanmasa ILOVANING O'ZI ham o'rnatilmasdi. Model manbasi
    // o'chib ketgach, bu butun o'rnatishni imkonsiz qilib qo'ydi. Endi
    // foydalanuvchi modelsiz davom etishi va faylni keyin qo'yishi mumkin.
    if SuppressibleMsgBox(ErrText + #13#10#13#10 +
         'Ilovani MODELSIZ o''rnatib, faylni keyinroq qo''yishni xohlaysizmi?' + #13#10 +
         '(Model bo''lmasa diktovka ishlamaydi, qolgan hammasi o''rnatiladi.)' + #13#10#13#10 +
         'Ha  — o''rnatishni davom ettirish' + #13#10 +
         'Yo''q — "Ready" sahifasida qolib, qayta urinish',
         mbConfirmation, MB_YESNO, IDNO) = IDYES then
    begin
      SkippedModel := True;
      Result := True;
    end
    else
      Result := False;    // "Ready" sahifasida qolamiz, qayta urinish mumkin
  end;
end;

// Jimgina o'rnatish (/SILENT, /VERYSILENT).
//
// MUHIM: NextButtonClick sehrgar hodisasi — jim rejimda sehrgar ishlamaydi
// va u UMUMAN chaqirilmaydi. PrepareToInstall esa ikkala rejimda ham
// chaqiriladi.
function PrepareToInstall(var NeedsRestart: Boolean): String;
begin
  Result := '';
  if WizardSilent() then
    Result := AcquireModel();
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  Src, Dst: String;
  ResultCode: Integer;
begin
  // Yangilash tugadi — yopib qo'yilgan ilovani qaytadan ishga tushiramiz.
  //
  // ExecAsOriginalUser: o'rnatuvchi administrator huquqida ishlaydi, ilova
  // esa oddiy foydalanuvchi nomidan ishlashi kerak. Aks holda sozlamalar
  // va avtostart administrator profiliga yozilib qolardi.
  if (CurStep = ssDone) and AppWasRunning then
  begin
    ExecAsOriginalUser(ExpandConstant('{app}\{#AppExe}'), '', '',
                       SW_SHOWNORMAL, ewNoWait, ResultCode);
    Exit;
  end;

  if CurStep <> ssPostInstall then
    Exit;

  // Modelsiz o'rnatildi — aynan qaysi faylni qayerga qo'yish kerakligini
  // aytamiz. Ilova bu papkani o'zi qidiradi (core/engine.cpp: findModel).
  if SkippedModel then
  begin
    ForceDirectories(ExpandConstant('{app}\models'));
    SuppressibleMsgBox(
      'Ilova modelsiz o''rnatildi.' + #13#10#13#10 +
      '«ggml-rubaistt.bin» faylini qo''lga kiritganingizda shu papkaga qo''ying:' + #13#10#13#10 +
      ExpandConstant('{app}\models') + #13#10#13#10 +
      'Administrator huquqi kerak bo''lsa, muqobil papka (ruxsat talab qilmaydi):' + #13#10 +
      ExpandConstant('{localappdata}\Audio-Matnga\models') + #13#10#13#10 +
      'Keyin ilovani qaytadan ishga tushiring.',
      mbInformation, MB_OK, IDOK);
    Exit;
  end;

  // Manba bo'sh — model allaqachon joyida, ko'chirish shart emas.
  if ModelSource = '' then
    Exit;

  // Model o'rnatish papkasiga ko'chiriladi.
  //
  // Model Program Files ichida saqlanadi — bu yo'l har doim lotin
  // harflarda. whisper.cpp fayl yo'lini char* sifatida ochadi, shuning
  // uchun foydalanuvchi papkasi (C:\Users\Аброр\...) xavfli bo'lardi.
  Src := ModelSource;
  Dst := ExpandConstant('{app}\models\ggml-rubaistt.bin');

  if not CopyFile(Src, Dst, False) then
    SuppressibleMsgBox(
      'Model o''rnatish papkasiga ko''chirilmadi. Diskda joy yetarlimi?',
      mbCriticalError, MB_OK, IDOK);
end;
