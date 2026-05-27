@echo off
setlocal enabledelayedexpansion

echo === DocForge Release Builder ===
echo Flavors: official xiaomi huawei vivo oppo honor
echo.

set FLAVORS=official xiaomi huawei vivo oppo honor
set SUCCESS=
set FAILED=
set HAS_FAIL=0

set APK_OUT=build\app\outputs\flutter-apk
set DL_DIR=..\..\AIStudio\apps\service\data\docforge\downloads

for %%F in (%FLAVORS%) do (
    echo ^>^>^> Building %%F ...
    call flutter build apk --release --flavor %%F --dart-define=CHANNEL=%%F
    if !errorlevel! equ 0 (
        set SUCCESS=!SUCCESS! %%F
        echo ^>^>^> %%F OK
    ) else (
        set FAILED=!FAILED! %%F
        set HAS_FAIL=1
        echo ^>^>^> %%F FAILED
    )
    echo.
)

echo === Results ===
echo Success:%SUCCESS%
echo Failed: %FAILED%

if %HAS_FAIL% equ 1 exit /b 1

echo.
echo === Copying APKs to download dir ===
if not exist "%DL_DIR%" mkdir "%DL_DIR%"
copy /Y "%APK_OUT%\*.apk" "%DL_DIR%\"
echo Done. Files in %DL_DIR%:
dir /b "%DL_DIR%\*.apk"
