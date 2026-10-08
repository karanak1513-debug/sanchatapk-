@echo off
set "JAVA_HOME=C:\Program Files\Microsoft\jdk-17.0.20.101-hotspot"
set "ANDROID_HOME=C:\Users\karan\AppData\Local\Android\Sdk"
set "PATH=%JAVA_HOME%\bin;%ANDROID_HOME%\cmdline-tools\latest\bin;%ANDROID_HOME%\platform-tools;%PATH%"

echo Installing platforms;android-36 and build-tools;36.0.0...
(for /l %%i in (1,1,50) do @echo y) | call "%ANDROID_HOME%\cmdline-tools\latest\bin\sdkmanager.bat" --sdk_root="%ANDROID_HOME%" "platforms;android-36" "build-tools;36.0.0"

echo Accepting Flutter Android licenses...
(for /l %%i in (1,1,50) do @echo y) | call C:\src\flutter\bin\flutter.bat doctor --android-licenses

echo Done.
