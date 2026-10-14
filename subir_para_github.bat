@echo off
echo ========================================================
echo   Enviando o Posto Facil para o seu GitHub...
echo ========================================================
echo.

cd /d "%~dp0"
git push -u origin main

echo.
echo ========================================================
echo   Processo finalizado! Pressione qualquer tecla para sair.
echo ========================================================
pause
