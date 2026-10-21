#Requires -Version 5.1
<#
.SYNOPSIS
  Android 에뮬레이터 시각·타임존을 한국 표준시(KST, Asia/Seoul)에 맞춥니다.

.DESCRIPTION
  1) 타임존을 Asia/Seoul 로 설정
  2) 호스트(PC) 현재 시각을 에뮬레이터에 기록 (가능하면 root 필요)
  3) 동기화 결과 출력

  사전 조건:
  - adb 가 PATH 에 있거나 Android SDK platform-tools 가 설치되어 있어야 합니다.
  - Google APIs 이미지(루트 가능) 권장. Google Play 이미지는 date 설정이 막힐 수 있습니다.

.EXAMPLE
  .\scripts\sync_emulator_kst.ps1
#>

$ErrorActionPreference = 'Stop'

function Find-Adb {
  $cmd = Get-Command adb -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }

  $candidates = @(
    "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe",
    "$env:ANDROID_HOME\platform-tools\adb.exe",
    "$env:ANDROID_SDK_ROOT\platform-tools\adb.exe"
  )
  foreach ($p in $candidates) {
    if (Test-Path $p) { return $p }
  }
  throw 'adb 를 찾을 수 없습니다. Android SDK platform-tools 를 설치하거나 PATH 에 추가하세요.'
}

$adb = Find-Adb
Write-Host "adb: $adb"

$devices = & $adb devices | Select-Object -Skip 1 | Where-Object { $_ -match 'device$' }
if (-not $devices) {
  throw '연결된 에뮬레이터/기기가 없습니다. 에뮬레이터를 켠 뒤 다시 실행하세요.'
}

Write-Host '=== Before ===' -ForegroundColor Cyan
Write-Host ("PC (local): {0}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz'))
Write-Host ("Emulator  : {0}" -f (& $adb shell date).Trim())

# 1) 타임존 → Asia/Seoul
Write-Host "`nSetting timezone Asia/Seoul ..." -ForegroundColor Yellow
& $adb shell settings put global auto_time_zone 0 2>$null
& $adb shell setprop persist.sys.timezone Asia/Seoul 2>$null
& $adb shell service call alarm 3 s16 Asia/Seoul 2>$null | Out-Null

# 2) 시계 동기화 (root 권장)
Write-Host 'Syncing clock from PC ...' -ForegroundColor Yellow
$rootOut = & $adb root 2>&1 | Out-String
Write-Host $rootOut.Trim()
Start-Sleep -Seconds 1

# Android date 형식: MMddHHmmyyyy.ss  (일부 이미지는 @epoch 지원)
$androidDate = Get-Date -Format 'MMddHHmmyyyy.ss'
try {
  & $adb shell "date $androidDate" | Out-Null
} catch {
  Write-Host 'MMdd 형식 실패 — epoch 초로 재시도' -ForegroundColor DarkYellow
  $epoch = [DateTimeOffset]::Now.ToUnixTimeSeconds()
  & $adb shell "date @$epoch" 2>$null | Out-Null
}

& $adb shell am broadcast -a android.intent.action.TIME_SET 2>$null | Out-Null
& $adb shell am broadcast -a android.intent.action.TIMEZONE_CHANGED 2>$null | Out-Null

Write-Host "`n=== After ===" -ForegroundColor Cyan
Write-Host ("PC (local): {0}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz'))
Write-Host ("Emulator  : {0}" -f (& $adb shell date).Trim())
Write-Host ("TZ prop   : {0}" -f (& $adb shell getprop persist.sys.timezone).Trim())

Write-Host @"

팁:
- 설정 > 날짜 및 시간에서 '자동으로 시간대 설정' 끄기 → '서울' 선택도 함께 확인하세요.
- AVD 실행 시 타임존 고정:
    emulator -avd <AVD이름> -timezone Asia/Seoul
- Google Play 이미지면 root/date 가 실패할 수 있습니다. Google APIs 이미지를 쓰세요.
- 앱은 DateTime.now() 대신 KstDateTime.now() 를 쓰면 기기 TZ와 무관하게 KST로 동작합니다.
"@ -ForegroundColor DarkGray
