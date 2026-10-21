[System.Environment]::SetEnvironmentVariable('JAVA_HOME', 'C:\Program Files\Microsoft\jdk-17.0.20.101-hotspot', 'User')
[System.Environment]::SetEnvironmentVariable('ANDROID_HOME', 'C:\Users\karan\AppData\Local\Android\Sdk', 'User')

$currentPath = [System.Environment]::GetEnvironmentVariable('Path', 'User')
$javaBin = 'C:\Program Files\Microsoft\jdk-17.0.20.101-hotspot\bin'
$sdkTools = 'C:\Users\karan\AppData\Local\Android\Sdk\cmdline-tools\latest\bin'
$sdkPlatformTools = 'C:\Users\karan\AppData\Local\Android\Sdk\platform-tools'

if ($currentPath -notlike "*$javaBin*") {
    $currentPath = "$javaBin;$currentPath"
}
if ($currentPath -notlike "*$sdkTools*") {
    $currentPath = "$sdkTools;$currentPath"
}
if ($currentPath -notlike "*$sdkPlatformTools*") {
    $currentPath = "$sdkPlatformTools;$currentPath"
}
[System.Environment]::SetEnvironmentVariable('Path', $currentPath, 'User')

Write-Output "Environment variables configured successfully."
