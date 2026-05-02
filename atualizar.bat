@echo off
REM Desabilita a exibição de comandos no console (modo silencioso)

REM Exibe mensagem de início da atualização
echo Atualizando lista de produtos...

REM Tenta executar o script PowerShell (versão principal)
REM %~dp0 retorna o diretório completo do arquivo batch
powershell -ExecutionPolicy Bypass -File "%~dp0atualizar_produtos.ps1"

REM Verifica se o PowerShell foi executado com sucesso (errorlevel = 0)
REM Se não funcionou, tenta a versão Node.js como fallback
if %errorlevel% neq 0 (
    echo Tentando via Node.js...
    node "%~dp0atualizar_produtos.js"
)

REM Exibe linha em branco
echo.

REM Exibe mensagem final
echo Concluido! 
echo Caso tenha salvo suas alterações, faça commit e pull e atualize sua página no navegador.

REM Pausa o programa para o usuário poder ver as mensagens
pause