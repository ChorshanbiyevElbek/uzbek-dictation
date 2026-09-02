# 3.26 — quyidagi POST_BUILD `cmake -E copy_directory_if_different` ni
# ishlatadi, u 3.26 da qo'shilgan. 3.21 deb yozilganda konfiguratsiya o'tib
# ketardi va build DLL nusxalash bosqichida tushunarsiz xato bilan yiqilardi.
cmake_minimum_required(VERSION 3.26)
project(AudioMatnga LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_C_STANDARD 11)

if(NOT MSVC)
    message(FATAL_ERROR "Bu loyiha MSVC (Visual Studio Build Tools) bilan build qilinadi.")
endif()

# /utf-8 — manba fayllar UTF-8 da (o'zbekcha izohlar va UI matnlari).
# Busiz MSVC ularni tizim kod sahifasida o'qib buzadi.
add_compile_options(/utf-8 /W4 /permissive-)
add_compile_definitions(UNICODE _UNICODE NOMINMAX WIN32_LEAN_AND_MEAN)

# ---------------------------------------------------------------- whisper.cpp
#
# Tashqi whisper.cpp build papkasi. setup skripti uni Vulkan + backend DL +
# barcha CPU variantlari bilan yig'adi (eski protsessorlarda ham ishlashi uchun).
set(WHISPER_ROOT "" CACHE PATH "whisper.cpp manba papkasi")
set(WHISPER_BUILD "" CACHE PATH "whisper.cpp build papkasi (Release)")

if(NOT WHISPER_ROOT OR NOT WHISPER_BUILD)
    message(FATAL_ERROR
        "WHISPER_ROOT va WHISPER_BUILD ko'rsatilishi kerak.\n"
        "Masalan: -DWHISPER_ROOT=D:/whisper.cpp -DWHISPER_BUILD=D:/whisper.cpp/build-vulkan")
endif()

find_library(WHISPER_LIB whisper PATHS "${WHISPER_BUILD}/src/Release" "${WHISPER_BUILD}/Release" REQUIRED)
find_library(GGML_LIB     ggml   PATHS "${WHISPER_BUILD}/ggml/src/Release" "${WHISPER_BUILD}/Release" REQUIRED)
find_library(GGML_BASE_LIB ggml-base PATHS "${WHISPER_BUILD}/ggml/src/Release" "${WHISPER_BUILD}/Release" REQUIRED)

# --------------------------------------------------------------------- core

add_library(rubai_core STATIC
    core/whisper_bridge.c
    core/util.cpp
    core/samples.cpp
    core/config.cpp
    core/engine.cpp
    core/wav.cpp
    core/audio_capture.cpp
)

target_include_directories(rubai_core PUBLIC
    core
    "${WHISPER_ROOT}/include"
    "${WHISPER_ROOT}/ggml/include"
)

target_link_libraries(rubai_core PUBLIC
    "${WHISPER_LIB}" "${GGML_LIB}" "${GGML_BASE_LIB}"
    shell32     # SHGetKnownFolderPath
    ole32       # COM (WASAPI)
    propsys     # PKEY_* qurilma xossalari
)

# ------------------------------------------------------------------- vosita

add_executable(rubai-cli tools/rubai_cli.cpp)
target_link_libraries(rubai-cli PRIVATE rubai_core)

# ------------------------------------------------------------------- ilova

add_executable(AudioMatnga WIN32
    ui/app.cpp
    ui/autostart.cpp
    ui/inserter.cpp
    ui/overlay.cpp
    ui/settings_window.cpp
    res/app.rc
)
target_link_libraries(AudioMatnga PRIVATE rubai_core comctl32 dwmapi)

# Manifest res/app.rc orqali joylanadi. Linker'ning o'z manifestini
# o'chiramiz, aks holda ikkita RT_MANIFEST resursi to'qnashadi (CVT1100).
set_target_properties(AudioMatnga PROPERTIES LINK_FLAGS "/MANIFEST:NO")

add_custom_command(TARGET AudioMatnga POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_directory_if_different
            "${WHISPER_BUILD}/bin/Release" "$<TARGET_FILE_DIR:AudioMatnga>"
    COMMENT "whisper.cpp DLL'lari nusxalanmoqda"
)

# Build'dan keyin whisper.cpp DLL'larini .exe yoniga nusxalaymiz, aks holda
# ilova ishga tushmaydi.
add_custom_command(TARGET rubai-cli POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_directory_if_different
            "${WHISPER_BUILD}/bin/Release" "$<TARGET_FILE_DIR:rubai-cli>"
    COMMENT "whisper.cpp DLL'lari nusxalanmoqda"
)
