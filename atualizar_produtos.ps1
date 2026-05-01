# Script Gerenciador de Produtos (Interativo)
$caminhoDados = "produtos_dados.js"
$produtos = @()

# 1. Carregar dados existentes
if (Test-Path $caminhoDados) {
    $conteudoAtual = Get-Content $caminhoDados -Raw -Encoding UTF8
    if ($conteudoAtual -match 'const listaProdutos = (\[[\s\S]*\]);') {
        try {
            $produtos = $matches[1] | ConvertFrom-Json
        } catch {}
    }
}

# 2. Sincronizar com a pasta de imagens (Detectar novos e remover excluidos)
$arquivosNaPasta = Get-ChildItem -Path "produtos" -File | Select-Object -ExpandProperty Name
$listaFinal = @()

# Manter apenas produtos cujas imagens ainda existem
foreach ($p in $produtos) {
    if ($arquivosNaPasta -contains $p.imagem) {
        $listaFinal += $p
    }
}

# Adicionar novos arquivos detectados
foreach ($img in $arquivosNaPasta) {
    $existe = $listaFinal | Where-Object { $_.imagem -eq $img }
    if (-not $existe) {
        Write-Host "`n--- NOVO PRODUTO DETECTADO: $img ---" -ForegroundColor Yellow
        $nomePadrao = ($img -split '\.')[0] -replace 'Modelo', 'Produto ' -replace 'modelo', 'Produto '
        $nome = Read-Host "Nome do produto (Enter para '$nomePadrao')"
        if ([string]::IsNullOrWhiteSpace($nome)) { $nome = $nomePadrao }
        
        $precoStr = Read-Host "Preco (Ex: 49.90)"
        $preco = 0.00
        if ($precoStr -match '^\d+([.,]\d+)?$') { $preco = [double]($precoStr -replace ',', '.') }
        
        $listaFinal += [PSCustomObject]@{ imagem = $img; preco = $preco; nome = $nome }
    }
}

# 3. Menu de Edicao
while ($true) {
    Clear-Host
    Write-Host "=== GERENCIADOR DE PRODUTOS IDONEOS ===" -ForegroundColor Cyan
    Write-Host "Produtos atuais:"
    for ($i = 0; $i -lt $listaFinal.Count; $i++) {
        $p = $listaFinal[$i]
        Write-Host ("{0}. {1} - R$ {2:N2} ({3})" -f ($i + 1), $p.nome, $p.preco, $p.imagem)
    }
    
    Write-Host "`nOpcoes:"
    Write-Host "Digite o numero do produto para ALTERAR o preco/nome"
    Write-Host "Digite 'S' para SALVAR e SAIR"
    Write-Host "Digite 'Q' para SAIR SEM SALVAR"
    
    $opcao = Read-Host "`nEscolha uma opcao"
    
    if ($opcao -eq 'S') {
        $json = $listaFinal | ConvertTo-Json
        $conteudoFinal = "const listaProdutos = $json;"
        [System.IO.File]::WriteAllLines($caminhoDados, $conteudoFinal, (New-Object System.Text.UTF8Encoding($false)))
        Write-Host "Alteracoes salvas com sucesso!" -ForegroundColor Green
        Start-Sleep -Seconds 2
        break
    }
    elseif ($opcao -eq 'Q') {
        break
    }
    elseif ($opcao -match '^\d+$' -and [int]$opcao -le $listaFinal.Count -and [int]$opcao -gt 0) {
        $idx = [int]$opcao - 1
        $p = $listaFinal[$idx]
        
        Write-Host "`nEditando: $($p.nome)" -ForegroundColor Yellow
        $novoNome = Read-Host "Novo nome (Enter para manter: '$($p.nome)')"
        if (-not [string]::IsNullOrWhiteSpace($novoNome)) { $p.nome = $novoNome }
        
        $novoPrecoStr = Read-Host "Novo preco (Enter para manter: R$ $($p.preco))"
        if ($novoPrecoStr -match '^\d+([.,]\d+)?$') {
            $p.preco = [double]($novoPrecoStr -replace ',', '.')
        }
    }
}