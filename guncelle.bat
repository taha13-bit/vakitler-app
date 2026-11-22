@echo off
cd /d "%~dp0"
echo.
echo  Vakitler guncelleniyor. Pencereyi KAPATMA, bitince haber verecek...
echo.
echo ===== %date% %time% > guncelle_log.txt
echo  [1/4] Paketler kuruluyor (npm install)...
echo [1/4] npm install >> guncelle_log.txt
call npm install >> guncelle_log.txt 2>&1
echo  [2/4] iOS projesi guncelleniyor (npx cap sync ios)...
echo [2/4] npx cap sync ios >> guncelle_log.txt
call npx cap sync ios >> guncelle_log.txt 2>&1
echo  [3/4] Degisiklikler kaydediliyor (git commit)...
echo [3/4] git commit >> guncelle_log.txt
git add -A >> guncelle_log.txt 2>&1
git commit -m "Vakitler 3.0: global surum, AdMob, ulke-il-ilce secici" >> guncelle_log.txt 2>&1
echo  [4/4] GitHub'a gonderiliyor (git push)...
echo [4/4] git push >> guncelle_log.txt
git push >> guncelle_log.txt 2>&1
echo ===== BITTI >> guncelle_log.txt
echo.
echo  ============================================
echo   BITTI! Claude'a "bitti" yazabilirsin.
echo  ============================================
echo.
pause
