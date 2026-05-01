# Script para atualizar a lista de produtos
$arquivos = Get-ChildItem -Path "produtos" -File | Select-Object -ExpandProperty Name
$json = $arquivos | ConvertTo-Json
$conteudo = "const listaProdutos = $json;"
$conteudo | Out-File -FilePath "produtos_dados.js" -Encoding utf8
Write-Host "Arquivo produtos_dados.js atualizado com sucesso!" -ForegroundColor Green