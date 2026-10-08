@echo off
set "JAVA_HOME=C:\Program Files\Microsoft\jdk-17.0.20.101-hotspot"
set "ANDROID_HOME=C:\Users\karan\AppData\Local\Android\Sdk"
set "PATH=%JAVA_HOME%\bin;%ANDROID_HOME%\cmdline-tools\latest\bin;%ANDROID_HOME%\platform-tools;%PATH%"

echo Checking Java...
java -version
if %errorlevel% neq 0 exit /b %errorlevel%

echo Checking sdkmanager...
call "%ANDROID_HOME%\cmdline-tools\latest\bin\sdkmanager.bat" --sdk_root="%ANDROID_HOME%" --version
if %errorlevel% neq 0 exit /b %errorlevel%

echo Accepting licenses...
(for /l %%i in (1,1,50) do @echo y) | call "%ANDROID_HOME%\cmdline-tools\latest\bin\sdkmanager.bat" --sdk_root="%ANDROID_HOME%" --licenses

echo Installing platform-tools, build-tools, platforms...
(for /l %%i in (1,1,50) do @echo y) | call "%ANDROID_HOME%\cmdline-tools\latest\bin\sdkmanager.bat" --sdk_root="%ANDROID_HOME%" "platform-tools" "build-tools;34.0.0" "platforms;android-34"

echo Done.
