@echo off
setlocal

cd /d "%~dp0"

for /f "tokens=2" %%v in ('findstr /b /c:"Versiunea " "CHANGELOG.txt"') do (
  set "VERSION=%%v"
  goto :version_found
)

:version_found

if not defined VERSION (
  echo [ERROR] Nu pot extrage versiunea din CHANGELOG.txt
  exit /b 1
)

set "ZIP=RstocMag-%VERSION%.zip"
set "EXE=RstocMag_Setup_%VERSION%.exe"

if not exist "%ZIP%" (
  echo [ERROR] Lipseste fisierul %ZIP%
  exit /b 1
)

if not exist "%EXE%" (
  echo [ERROR] Lipseste fisierul %EXE%
  exit /b 1
)

echo [INFO] Pregatesc release pentru versiunea %VERSION%

git add "CHANGELOG.txt"
if errorlevel 1 (
  echo [ERROR] git add pentru CHANGELOG.txt a esuat
  exit /b 1
)

git diff --cached --quiet
if not errorlevel 1 (
  echo [INFO] Nu exista schimbari de commit-uit.
  echo [INFO] Daca ai facut deja push pe main, workflow-ul poate fi deja pornit.
  goto :after_commit
)

git commit -m "Release %VERSION%"
if errorlevel 1 (
  echo [ERROR] git commit a esuat
  exit /b 1
)

git push origin main
if errorlevel 1 (
  echo [ERROR] git push a esuat
  exit /b 1
)

:after_commit
set "TAG=v%VERSION%"

git ls-remote --tags origin "refs/tags/%TAG%" | findstr /r /c:".*" >nul
if errorlevel 1 (
  git tag "%TAG%"
  if errorlevel 1 (
    echo [ERROR] Nu pot crea tag-ul %TAG%
    exit /b 1
  )

  git push origin "%TAG%"
  if errorlevel 1 (
    echo [ERROR] Nu pot urca tag-ul %TAG%
    exit /b 1
  )
)

gh release view "%TAG%" >nul 2>&1
if not errorlevel 1 (
  echo [INFO] Release %TAG% exista deja. Sar peste creare.
  exit /b 0
)

powershell -NoProfile -Command "$ch = Get-Content -Raw CHANGELOG.txt; $p='(?ms)^Versiunea\s+%VERSION%\r?\n(.*?)(?=^\s*Versiunea\s+\d+\.\d+\.\d+|\z)'; $m=[regex]::Match($ch,$p); if($m.Success){$b='Versiunea %VERSION%' + [Environment]::NewLine + $m.Groups[1].Value.Trim()} else {$b='Versiunea %VERSION%'}; Set-Content -Path release_notes.txt -Value $b -Encoding UTF8"
if errorlevel 1 (
  echo [ERROR] Nu pot genera release_notes.txt
  exit /b 1
)

gh release create "%TAG%" "%ZIP%" "%EXE%" "CHANGELOG.txt" "LICENSE.txt" "LGPL-3.0.txt" "THIRD_PARTY_LICENSES.txt" --title "RstocMag %VERSION%" --notes-file "release_notes.txt"
if errorlevel 1 (
  echo [ERROR] Nu pot crea GitHub release %TAG%
  exit /b 1
)

echo [OK] Release-ul %TAG% a fost publicat fara artefacte in commit.
exit /b 0
