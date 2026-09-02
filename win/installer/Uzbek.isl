; *** Inno Setup 6.5+ uchun o'zbekcha xabarlar ***
;
; Audio-Matnga loyihasi uchun tarjima qilindi.
; Inno Setup rasmiy tarjimalari orasida o'zbek tili yo'q, shuning uchun
; bu fayl loyiha bilan birga tarqatiladi (win/installer/Uzbek.isl).
;
; Eslatma: xabar oxirida nuqta bo'lmagan bo'lsa, qo'shmang — Inno Setup
; ba'zi xabarlarga nuqtani o'zi qo'shadi.

[LangOptions]
LanguageName=O<0027>zbekcha
LanguageID=$0443
LanguageCodePage=0

[Messages]

; *** Sarlavhalar
SetupAppTitle=O'rnatish
SetupWindowTitle=%1 — o'rnatish
UninstallAppTitle=O'chirish
UninstallAppFullTitle=%1 ni o'chirish

; *** Umumiy
InformationTitle=Ma'lumot
ConfirmTitle=Tasdiqlang
ErrorTitle=Xato

; *** SetupLdr
SetupLdrStartupMessage=%1 o'rnatiladi. Davom etaymizmi?
LdrCannotCreateTemp=Vaqtinchalik fayl yaratilmadi. O'rnatish to'xtatildi
LdrCannotExecTemp=Vaqtinchalik papkadagi faylni ishga tushirib bo'lmadi. O'rnatish to'xtatildi
HelpTextNote=

; *** Ishga tushishdagi xatolar
LastErrorMessage=%1.%n%nXato %2: %3
SetupFileMissing=O'rnatish papkasida %1 fayli yo'q. Muammoni bartaraf eting yoki dasturning yangi nusxasini oling.
SetupFileCorrupt=O'rnatish fayllari buzilgan. Dasturning yangi nusxasini oling.
SetupFileCorruptOrWrongVer=O'rnatish fayllari buzilgan yoki bu o'rnatuvchi versiyasiga mos emas. Muammoni bartaraf eting yoki dasturning yangi nusxasini oling.
InvalidParameter=Buyruq qatorida noto'g'ri parametr berildi:%n%n%1
SetupAlreadyRunning=O'rnatuvchi allaqachon ishlab turibdi.
WindowsVersionNotSupported=Bu dastur kompyuteringizdagi Windows versiyasini qo'llab-quvvatlamaydi.
WindowsServicePackRequired=Bu dastur uchun %1 Service Pack %2 yoki undan yangisi kerak.
NotOnThisPlatform=Bu dastur %1 da ishlamaydi.
OnlyOnThisPlatform=Bu dastur %1 da ishga tushirilishi kerak.
OnlyOnTheseArchitectures=Bu dasturni faqat quyidagi protsessor arxitekturalari uchun mo'ljallangan Windows versiyalariga o'rnatish mumkin:%n%n%1
WinVersionTooLowError=Bu dastur uchun %1 %2 yoki undan yangi versiya kerak.
WinVersionTooHighError=Bu dasturni %1 %2 yoki undan yangi versiyaga o'rnatib bo'lmaydi.
AdminPrivilegesRequired=Bu dasturni o'rnatish uchun administrator sifatida kirishingiz kerak.
PowerUserPrivilegesRequired=Bu dasturni o'rnatish uchun administrator yoki Power Users guruhi a'zosi sifatida kirishingiz kerak.
SetupAppRunningError=%1 hozir ishlab turibdi.%n%nUning barcha oynalarini yoping va davom etish uchun OK ni bosing, chiqish uchun Bekor qilishni bosing.
UninstallAppRunningError=%1 hozir ishlab turibdi.%n%nUning barcha oynalarini yoping va davom etish uchun OK ni bosing, chiqish uchun Bekor qilishni bosing.

; *** Boshlang'ich savollar
PrivilegesRequiredOverrideTitle=O'rnatish rejimini tanlang
PrivilegesRequiredOverrideInstruction=O'rnatish rejimini tanlang
PrivilegesRequiredOverrideText1=%1 ni barcha foydalanuvchilar uchun (administrator huquqi kerak) yoki faqat o'zingiz uchun o'rnatish mumkin.
PrivilegesRequiredOverrideText2=%1 ni faqat o'zingiz uchun yoki barcha foydalanuvchilar uchun (administrator huquqi kerak) o'rnatish mumkin.
PrivilegesRequiredOverrideAllUsers=&Barcha foydalanuvchilar uchun
PrivilegesRequiredOverrideAllUsersRecommended=&Barcha foydalanuvchilar uchun (tavsiya etiladi)
PrivilegesRequiredOverrideCurrentUser=&Faqat men uchun
PrivilegesRequiredOverrideCurrentUserRecommended=&Faqat men uchun (tavsiya etiladi)

; *** Turli xatolar
ErrorCreatingDir="%1" papkasi yaratilmadi
ErrorTooManyFilesInDir="%1" papkasida juda ko'p fayl bor, yangi fayl yaratib bo'lmadi

; *** Umumiy xabarlar
ExitSetupTitle=O'rnatishdan chiqish
ExitSetupMessage=O'rnatish tugallanmadi. Hozir chiqsangiz, dastur o'rnatilmaydi.%n%nO'rnatishni keyinroq qaytadan boshlashingiz mumkin.%n%nChiqaymizmi?
AboutSetupMenuItem=O'rnatuvchi &haqida...
AboutSetupTitle=O'rnatuvchi haqida
AboutSetupMessage=%1, versiya %2%n%3%n%n%1 sahifasi:%n%4
AboutSetupNote=
TranslatorNote=

; *** Tugmalar
ButtonBack=< &Orqaga
ButtonNext=&Keyingi >
ButtonInstall=&O'rnatish
ButtonOK=OK
ButtonCancel=Bekor qilish
ButtonYes=&Ha
ButtonYesToAll=&Hammasiga ha
ButtonNo=&Yo'q
ButtonNoToAll=Ham&masiga yo'q
ButtonFinish=&Tayyor
ButtonBrowse=&Tanlash...
ButtonWizardBrowse=&Tanlash...
ButtonNewFolder=&Yangi papka

; *** Til tanlash
SelectLanguageTitle=O'rnatish tilini tanlang
SelectLanguageLabel=O'rnatish davomida ishlatiladigan tilni tanlang.

; *** Umumiy sehrgar matnlari
ClickNext=Davom etish uchun "Keyingi", chiqish uchun "Bekor qilish" ni bosing.
BeveledLabel=
BrowseDialogTitle=Papkani tanlash
BrowseDialogLabel=Quyidagi ro'yxatdan papkani tanlang va OK ni bosing.
NewFolderName=Yangi papka

; *** "Xush kelibsiz" sahifasi
WelcomeLabel1=[name] o'rnatiladi
WelcomeLabel2=Kompyuteringizga [name/ver] o'rnatiladi.%n%nDavom etishdan oldin boshqa ilovalarni yopishingiz tavsiya etiladi.

; *** Parol sahifasi
WizardPassword=Parol
PasswordLabel1=Bu o'rnatish parol bilan himoyalangan.
PasswordLabel3=Parolni kiriting va "Keyingi" ni bosing. Parolda katta-kichik harf farqlanadi.
PasswordEditLabel=&Parol:
IncorrectPassword=Parol noto'g'ri. Qaytadan urinib ko'ring.

; *** Litsenziya sahifasi
WizardLicense=Litsenziya shartnomasi
LicenseLabel=Davom etishdan oldin quyidagi ma'lumotni o'qing.
LicenseLabel3=Quyidagi litsenziya shartnomasini o'qing. O'rnatishni davom ettirish uchun uni qabul qilishingiz kerak.
LicenseAccepted=Shartnomani &qabul qilaman
LicenseNotAccepted=Shartnomani qabul qilmay&man

; *** Ma'lumot sahifalari
WizardInfoBefore=Ma'lumot
InfoBeforeLabel=Davom etishdan oldin quyidagi muhim ma'lumotni o'qing.
InfoBeforeClickLabel=Tayyor bo'lsangiz, "Keyingi" ni bosing.
WizardInfoAfter=Ma'lumot
InfoAfterLabel=Davom etishdan oldin quyidagi muhim ma'lumotni o'qing.
InfoAfterClickLabel=Tayyor bo'lsangiz, "Keyingi" ni bosing.

; *** Foydalanuvchi ma'lumotlari
WizardUserInfo=Foydalanuvchi ma'lumotlari
UserInfoDesc=Ma'lumotlaringizni kiriting.
UserInfoName=&Ism:
UserInfoOrg=&Tashkilot:
UserInfoSerial=&Seriya raqami:
UserInfoNameRequired=Ismni kiritishingiz kerak.

; *** Papkani tanlash
WizardSelectDir=O'rnatish joyini tanlang
SelectDirDesc=[name] qayerga o'rnatilsin?
SelectDirLabel3=[name] quyidagi papkaga o'rnatiladi.
SelectDirBrowseLabel=Davom etish uchun "Keyingi" ni bosing. Boshqa papka tanlash uchun "Tanlash" ni bosing.
DiskSpaceGBLabel=Kamida [gb] GB bo'sh joy kerak.
DiskSpaceMBLabel=Kamida [mb] MB bo'sh joy kerak.
CannotInstallToNetworkDrive=Tarmoq diskiga o'rnatib bo'lmaydi.
CannotInstallToUNCPath=UNC yo'liga o'rnatib bo'lmaydi.
InvalidPath=Disk harfi bilan to'liq yo'l kiriting, masalan:%n%nC:\ILOVA%n%nyoki UNC yo'li:%n%n\\server\papka
InvalidDrive=Siz tanlagan disk yoki tarmoq papkasi mavjud emas yoki ochilmaydi. Boshqasini tanlang.
DiskSpaceWarningTitle=Diskda joy yetarli emas
DiskSpaceWarning=O'rnatish uchun kamida %1 KB bo'sh joy kerak, tanlangan diskda esa atigi %2 KB bor.%n%nBaribir davom etaymizmi?
DirNameTooLong=Papka nomi yoki yo'li juda uzun.
InvalidDirName=Papka nomi noto'g'ri.
BadDirName32=Papka nomida quyidagi belgilar bo'lishi mumkin emas:%n%n%1
DirExistsTitle=Papka mavjud
DirExists=Papka:%n%n%1%n%nallaqachon mavjud. Baribir shu papkaga o'rnataymizmi?
DirDoesntExistTitle=Papka mavjud emas
DirDoesntExist=Papka:%n%n%1%n%nmavjud emas. Uni yaratamizmi?

; *** Komponentlar
WizardSelectComponents=Komponentlarni tanlang
SelectComponentsDesc=Qaysi komponentlar o'rnatilsin?
SelectComponentsLabel2=O'rnatmoqchi bo'lgan komponentlarni belgilang, keraksizlarini olib tashlang. Tayyor bo'lsangiz "Keyingi" ni bosing.
FullInstallation=To'liq o'rnatish
CompactInstallation=Ixcham o'rnatish
CustomInstallation=Tanlab o'rnatish
NoUninstallWarningTitle=Komponentlar mavjud
NoUninstallWarning=Quyidagi komponentlar allaqachon o'rnatilgan:%n%n%1%n%nUlarning belgisini olib tashlash ularni o'chirmaydi.%n%nBaribir davom etaymizmi?
ComponentSize1=%1 KB
ComponentSize2=%1 MB
ComponentsDiskSpaceGBLabel=Tanlangan komponentlar uchun kamida [gb] GB joy kerak.
ComponentsDiskSpaceMBLabel=Tanlangan komponentlar uchun kamida [mb] MB joy kerak.

; *** Qo'shimcha vazifalar
WizardSelectTasks=Qo'shimcha vazifalar
SelectTasksDesc=Qaysi qo'shimcha vazifalar bajarilsin?
SelectTasksLabel2=[name] o'rnatilayotganda bajariladigan qo'shimcha vazifalarni tanlang va "Keyingi" ni bosing.

; *** Boshlash menyusi papkasi
WizardSelectProgramGroup=Boshlash menyusi papkasi
SelectStartMenuFolderDesc=Yorliqlar qayerga joylashtirilsin?
SelectStartMenuFolderLabel3=Yorliqlar Boshlash menyusining quyidagi papkasida yaratiladi.
SelectStartMenuFolderBrowseLabel=Davom etish uchun "Keyingi" ni bosing. Boshqa papka tanlash uchun "Tanlash" ni bosing.
MustEnterGroupName=Papka nomini kiritishingiz kerak.
GroupNameTooLong=Papka nomi yoki yo'li juda uzun.
InvalidGroupName=Papka nomi noto'g'ri.
BadGroupName=Papka nomida quyidagi belgilar bo'lishi mumkin emas:%n%n%1
NoProgramGroupCheck2=Boshlash menyusida papka &yaratilmasin

; *** O'rnatishga tayyor
WizardReady=O'rnatishga tayyor
ReadyLabel1=[name] kompyuteringizga o'rnatishga tayyor.
ReadyLabel2a=O'rnatishni boshlash uchun "O'rnatish" ni bosing. Sozlamalarni ko'rish yoki o'zgartirish uchun "Orqaga" ni bosing.
ReadyLabel2b=O'rnatishni boshlash uchun "O'rnatish" ni bosing.
ReadyMemoUserInfo=Foydalanuvchi ma'lumotlari:
ReadyMemoDir=O'rnatish joyi:
ReadyMemoType=O'rnatish turi:
ReadyMemoComponents=Tanlangan komponentlar:
ReadyMemoGroup=Boshlash menyusi papkasi:
ReadyMemoTasks=Qo'shimcha vazifalar:

; *** Yuklab olish sahifasi
DownloadingLabel2=Fayllar yuklab olinmoqda...
ButtonStopDownload=Yuklashni &to'xtatish
StopDownload=Yuklashni to'xtatishga ishonchingiz komilmi?
ErrorDownloadAborted=Yuklash bekor qilindi
ErrorDownloadFailed=Yuklab olinmadi: %1 %2
ErrorDownloadSizeFailed=Hajmni aniqlab bo'lmadi: %1 %2
ErrorProgress=Noto'g'ri jarayon: %2 dan %1
ErrorFileSize=Fayl hajmi noto'g'ri: kutilgan %1, topilgan %2

; *** Arxivdan chiqarish
ExtractingLabel=Fayllar chiqarilmoqda...
ButtonStopExtraction=Chiqarishni &to'xtatish
StopExtraction=Chiqarishni to'xtatishga ishonchingiz komilmi?
ErrorExtractionAborted=Chiqarish bekor qilindi
ErrorExtractionFailed=Chiqarilmadi: %1

; *** Arxiv xatolari
ArchiveIncorrectPassword=Parol noto'g'ri
ArchiveIsCorrupted=Arxiv buzilgan
ArchiveUnsupportedFormat=Arxiv formati qo'llab-quvvatlanmaydi

; *** Tayyorgarlik
WizardPreparing=O'rnatishga tayyorgarlik
PreparingDesc=[name] o'rnatishga tayyorlanmoqda.
PreviousInstallNotCompleted=Oldingi dasturni o'rnatish yoki o'chirish tugallanmagan. Uni yakunlash uchun kompyuterni qayta ishga tushirishingiz kerak.%n%nQayta ishga tushirgandan so'ng [name] o'rnatishni qaytadan boshlang.
CannotContinue=O'rnatishni davom ettirib bo'lmaydi. Chiqish uchun "Bekor qilish" ni bosing.
ApplicationsFound=Quyidagi ilovalar yangilanishi kerak bo'lgan fayllardan foydalanmoqda. Ularni avtomatik yopishga ruxsat berish tavsiya etiladi.
ApplicationsFound2=Quyidagi ilovalar yangilanishi kerak bo'lgan fayllardan foydalanmoqda. Ularni avtomatik yopishga ruxsat berish tavsiya etiladi. O'rnatish tugagach, ular qaytadan ochiladi.
CloseApplications=Ilovalar &avtomatik yopilsin
DontCloseApplications=Ilovalar &yopilmasin
ErrorCloseApplications=Barcha ilovalarni avtomatik yopib bo'lmadi. Davom etishdan oldin yangilanishi kerak bo'lgan fayllardan foydalanayotgan ilovalarni o'zingiz yoping.
PrepareToInstallNeedsRestart=Kompyuterni qayta ishga tushirish kerak. Keyin [name] o'rnatishni qaytadan boshlang.%n%nHozir qayta ishga tushiraymizmi?

; *** O'rnatilmoqda
WizardInstalling=O'rnatilmoqda
InstallingLabel=[name] o'rnatilmoqda, biroz kuting.

; *** Tugallandi
FinishedHeadingLabel=[name] o'rnatildi
FinishedLabelNoIcons=[name] kompyuteringizga o'rnatildi.
FinishedLabel=[name] kompyuteringizga o'rnatildi. Ilovani yorliqlar orqali ishga tushirish mumkin.
ClickFinish=Chiqish uchun "Tayyor" ni bosing.
FinishedRestartLabel=[name] o'rnatishni yakunlash uchun kompyuterni qayta ishga tushirish kerak. Hozir qayta ishga tushiraymizmi?
FinishedRestartMessage=[name] o'rnatishni yakunlash uchun kompyuterni qayta ishga tushirish kerak.%n%nHozir qayta ishga tushiraymizmi?
ShowReadmeCheck=Ha, README faylini ko'rmoqchiman
YesRadio=&Ha, kompyuter hozir qayta ishga tushsin
NoRadio=&Yo'q, keyinroq o'zim qayta ishga tushiraman
RunEntryExec=%1 ni ishga tushirish
RunEntryShellExec=%1 ni ko'rish

; *** Keyingi disk
ChangeDiskTitle=Keyingi disk kerak
SelectDiskLabel2=%1-diskni joylashtiring va OK ni bosing.%n%nAgar bu diskdagi fayllar quyida ko'rsatilgandan boshqa papkada bo'lsa, to'g'ri yo'lni kiriting yoki "Tanlash" ni bosing.
PathLabel=&Yo'l:
FileNotInDir2="%1" fayli "%2" ichida topilmadi. To'g'ri diskni joylashtiring yoki boshqa papkani tanlang.
SelectDirectoryLabel=Keyingi diskning joyini ko'rsating.

; *** O'rnatish bosqichi
SetupAborted=O'rnatish tugallanmadi.%n%nMuammoni bartaraf eting va o'rnatishni qaytadan boshlang.
AbortRetryIgnoreSelectAction=Amalni tanlang
AbortRetryIgnoreRetry=&Qaytadan urinish
AbortRetryIgnoreIgnore=Xatoga e'tibor bermay &davom etish
AbortRetryIgnoreCancel=O'rnatishni bekor qilish
RetryCancelSelectAction=Amalni tanlang
RetryCancelRetry=&Qaytadan urinish
RetryCancelCancel=Bekor qilish

; *** Holat xabarlari
StatusClosingApplications=Ilovalar yopilmoqda...
StatusCreateDirs=Papkalar yaratilmoqda...
StatusExtractFiles=Fayllar chiqarilmoqda...
StatusDownloadFiles=Fayllar yuklab olinmoqda...
StatusCreateIcons=Yorliqlar yaratilmoqda...
StatusCreateIniEntries=INI yozuvlari yaratilmoqda...
StatusCreateRegistryEntries=Registr yozuvlari yaratilmoqda...
StatusRegisterFiles=Fayllar ro'yxatdan o'tkazilmoqda...
StatusSavingUninstall=O'chirish ma'lumotlari saqlanmoqda...
StatusRunProgram=O'rnatish yakunlanmoqda...
StatusRestartingApplications=Ilovalar qayta ishga tushirilmoqda...
StatusRollback=O'zgarishlar qaytarilmoqda...

; *** Turli xatolar
ErrorInternal2=Ichki xato: %1
ErrorFunctionFailedNoCode=%1 bajarilmadi
ErrorFunctionFailed=%1 bajarilmadi; kod %2
ErrorFunctionFailedWithMessage=%1 bajarilmadi; kod %2.%n%3
ErrorExecutingProgram=Faylni ishga tushirib bo'lmadi:%n%1

; *** Registr xatolari
ErrorRegOpenKey=Registr kalitini ochishda xato:%n%1\%2
ErrorRegCreateKey=Registr kalitini yaratishda xato:%n%1\%2
ErrorRegWriteKey=Registr kalitiga yozishda xato:%n%1\%2

; *** INI xatolari
ErrorIniEntry="%1" faylida INI yozuvini yaratishda xato.

; *** Fayl nusxalash xatolari
FileAbortRetryIgnoreSkipNotRecommended=Bu faylni &o'tkazib yuborish (tavsiya etilmaydi)
FileAbortRetryIgnoreIgnoreNotRecommended=Xatoga e'tibor bermay &davom etish (tavsiya etilmaydi)
SourceIsCorrupted=Manba fayl buzilgan
SourceDoesntExist="%1" manba fayli mavjud emas
SourceVerificationFailed=Manba faylni tekshirib bo'lmadi: %1
VerificationSignatureDoesntExist="%1" imzo fayli mavjud emas
VerificationSignatureInvalid="%1" imzo fayli noto'g'ri
VerificationKeyNotFound="%1" imzo fayli noma'lum kalitdan foydalanadi
VerificationFileNameIncorrect=Fayl nomi noto'g'ri
VerificationFileTagIncorrect=Fayl teg'i noto'g'ri
VerificationFileSizeIncorrect=Fayl hajmi noto'g'ri
VerificationFileHashIncorrect=Fayl xesh qiymati noto'g'ri
ExistingFileReadOnly2=Mavjud faylni almashtirib bo'lmadi, chunki u "faqat o'qish" holatida.
ExistingFileReadOnlyRetry="Faqat o'qish" belgisini &olib tashlab, qaytadan urinish
ExistingFileReadOnlyKeepExisting=Mavjud faylni &qoldirish
ErrorReadingExistingDest=Mavjud faylni o'qishda xato yuz berdi:
FileExistsSelectAction=Amalni tanlang
FileExists2=Fayl allaqachon mavjud.
FileExistsOverwriteExisting=Mavjud faylni &almashtirish
FileExistsKeepExisting=Mavjud faylni &qoldirish
FileExistsOverwriteOrKeepAll=Keyingi to'qnashuvlarda ham &shunday qilinsin
ExistingFileNewerSelectAction=Amalni tanlang
ExistingFileNewer2=Mavjud fayl o'rnatilayotganidan yangiroq.
ExistingFileNewerOverwriteExisting=Mavjud faylni &almashtirish
ExistingFileNewerKeepExisting=Mavjud faylni &qoldirish (tavsiya etiladi)
ExistingFileNewerOverwriteOrKeepAll=Keyingi to'qnashuvlarda ham &shunday qilinsin
ErrorChangingAttr=Mavjud fayl xossalarini o'zgartirishda xato yuz berdi:
ErrorCreatingTemp=Maqsad papkasida fayl yaratishda xato yuz berdi:
ErrorReadingSource=Manba faylni o'qishda xato yuz berdi:
ErrorCopying=Faylni nusxalashda xato yuz berdi:
ErrorDownloading=Faylni yuklab olishda xato yuz berdi:
ErrorExtracting=Arxivdan chiqarishda xato yuz berdi:
ErrorReplacingExistingFile=Mavjud faylni almashtirishda xato yuz berdi:
ErrorRestartReplace=RestartReplace bajarilmadi:
ErrorRenamingTemp=Maqsad papkasidagi fayl nomini o'zgartirishda xato yuz berdi:
ErrorRegisterServer=DLL/OCX ro'yxatdan o'tkazilmadi: %1
ErrorRegSvr32Failed=RegSvr32 %1 kodi bilan tugadi
ErrorRegisterTypeLib=Tip kutubxonasi ro'yxatdan o'tkazilmadi: %1

; *** O'chirish ro'yxatidagi belgilar
UninstallDisplayNameMark=%1 (%2)
UninstallDisplayNameMarks=%1 (%2, %3)
UninstallDisplayNameMark32Bit=32-bit
UninstallDisplayNameMark64Bit=64-bit
UninstallDisplayNameMarkAllUsers=Barcha foydalanuvchilar
UninstallDisplayNameMarkCurrentUser=Joriy foydalanuvchi

; *** O'rnatishdan keyingi xatolar
ErrorOpeningReadme=README faylini ochishda xato yuz berdi.
ErrorRestartingComputer=Kompyuterni qayta ishga tushirib bo'lmadi. Buni o'zingiz bajaring.

; *** O'chirish xabarlari
UninstallNotFound="%1" fayli mavjud emas. O'chirib bo'lmaydi.
UninstallOpenError="%1" faylini ochib bo'lmadi. O'chirib bo'lmaydi
UninstallUnsupportedVer="%1" o'chirish jurnali bu versiyaga tanish bo'lmagan formatda. O'chirib bo'lmaydi
UninstallUnknownEntry=O'chirish jurnalida noma'lum yozuv (%1) uchradi
ConfirmUninstall=%1 va uning barcha komponentlarini butunlay o'chirishga ishonchingiz komilmi?
UninstallOnlyOnWin64=Bu o'rnatmani faqat 64-bitli Windows'da o'chirish mumkin.
OnlyAdminCanUninstall=Bu o'rnatmani faqat administrator huquqiga ega foydalanuvchi o'chira oladi.
UninstallStatusLabel=%1 kompyuteringizdan o'chirilmoqda, biroz kuting.
UninstalledAll=%1 kompyuteringizdan muvaffaqiyatli o'chirildi.
UninstalledMost=%1 o'chirildi.%n%nBa'zi elementlarni o'chirib bo'lmadi. Ularni o'zingiz o'chirishingiz mumkin.
UninstalledAndNeedsRestart=%1 ni o'chirishni yakunlash uchun kompyuterni qayta ishga tushirish kerak.%n%nHozir qayta ishga tushiraymizmi?
UninstallDataCorrupted="%1" fayli buzilgan. O'chirib bo'lmaydi

; *** O'chirish bosqichi
ConfirmDeleteSharedFileTitle=Umumiy fayl o'chirilsinmi?
ConfirmDeleteSharedFile2=Tizim quyidagi umumiy fayl endi hech qaysi dastur tomonidan ishlatilmayotganini ko'rsatmoqda. Uni o'chiraymizmi?%n%nAgar biror dastur hali ham bu fayldan foydalanayotgan bo'lsa va u o'chirilsa, o'sha dastur to'g'ri ishlamasligi mumkin. Ishonchingiz komil bo'lmasa, "Yo'q" ni tanlang. Faylni qoldirish hech qanday zarar keltirmaydi.
SharedFileNameLabel=Fayl nomi:
SharedFileLocationLabel=Joylashuvi:
WizardUninstalling=O'chirish holati
StatusUninstalling=%1 o'chirilmoqda...

; *** O'chirishni bloklash sabablari
ShutdownBlockReasonInstallingApp=%1 o'rnatilmoqda.
ShutdownBlockReasonUninstallingApp=%1 o'chirilmoqda.

[CustomMessages]

NameAndVersion=%1, versiya %2
AdditionalIcons=Qo'shimcha yorliqlar:
CreateDesktopIcon=Ish stolida &yorliq yaratilsin
CreateQuickLaunchIcon=&Tez ishga tushirish yorlig'i yaratilsin
ProgramOnTheWeb=%1 — internetda
UninstallProgram=%1 ni o'chirish
LaunchProgram=%1 ni ishga tushirish
AssocFileExtension=%1 ni %2 fayl kengaytmasi bilan &bog'lash
AssocingFileExtension=%1 %2 kengaytmasi bilan bog'lanmoqda...
AutoStartProgramGroupDescription=Avtomatik ishga tushish:
AutoStartProgram=%1 avtomatik ishga tushsin
AddonHostProgramNotFound=%1 siz tanlagan papkada topilmadi.%n%nBaribir davom etaymizmi?
