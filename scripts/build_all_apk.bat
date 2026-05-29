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

:: ============================================================
:: 签名准备：将 docforge-release.jks 放入 android\app\build\
:: 并设置环境变量 ANDROID_KEYSTORE_PASSWORD / ANDROID_KEY_ALIAS / ANDROID_KEY_PASSWORD
:: 若 keystore 不存在则降级 debug 签名（华为走沙箱支付）
:: ============================================================
set KEYSTORE_DIR=android\app\build
set KEYSTORE_FILE=%KEYSTORE_DIR%\docforge-release.jks

if exist "%KEYSTORE_FILE%" (
    echo [签名] release keystore 已就绪，将使用正式签名
    if "%ANDROID_KEYSTORE_PASSWORD%"=="" echo [签名] 警告: ANDROID_KEYSTORE_PASSWORD 未设置
) else (
    echo [签名] 未找到 %KEYSTORE_FILE%，将降级 debug 签名（华为走沙箱）
)

:: 生产 API 地址（可通过命令行覆盖：set API_HOST=http://...）
if "%API_HOST%"=="" set API_HOST=http://61.132.52.22:8084
echo [API] %API_HOST%
echo.

for %%F in (%FLAVORS%) do (
    echo ^>^>^> Building %%F ...
    call flutter build apk --release --flavor %%F --dart-define=CHANNEL=%%F --dart-define=API_HOST=%API_HOST%
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
