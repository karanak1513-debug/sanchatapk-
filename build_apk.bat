@echo off
set "JAVA_HOME=C:\Program Files\Microsoft\jdk-17.0.20.101-hotspot"
set "ANDROID_HOME=C:\Users\karan\AppData\Local\Android\Sdk"
set "PATH=%JAVA_HOME%\bin;%ANDROID_HOME%\cmdline-tools\latest\bin;%ANDROID_HOME%\platform-tools;%PATH%"

echo ========================================================
echo  Compiling Sanchay Production Release APK
echo ========================================================

echo [1/4] Cleaning build cache...
call C:\src\flutter\bin\flutter.bat clean

echo [2/4] Resolving dependencies...
call C:\src\flutter\bin\flutter.bat pub get

echo [3/4] Compiling release APK (com.aistudio.sanchay.savtrkr)...
call C:\src\flutter\bin\flutter.bat build apk --release

if %errorlevel% neq 0 (
    echo [ERROR] Flutter build failed with exit code %errorlevel%
    pause
    exit /b %errorlevel%
)

echo [4/4] Updating distribution artifacts...
if exist "build\app\outputs\flutter-apk\app-release.apk" (
    copy /Y "build\app\outputs\flutter-apk\app-release.apk" "sanchay-release.apk"
    echo Successfully updated sanchay-release.apk!
)

echo ========================================================
echo  BUILD COMPLETE: build\app\outputs\flutter-apk\app-release.apk
echo ========================================================
pause
