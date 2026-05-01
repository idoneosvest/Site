@echo off
echo Atualizando lista de produtos...
powershell -ExecutionPolicy Bypass -File "%~dp0atualizar_produtos.ps1"
if %errorlevel% neq 0 (
    echo Tentando via Node.js...
    node "%~dp0atualizar_produtos.js"
)
echo.
echo Concluido! Atualize sua pagina no navegador.
pause