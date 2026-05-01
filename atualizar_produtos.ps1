# Script Gerenciador de Produtos (Interativo) - Versão com Carrossel
$caminhoDados = "produtos_dados.js"
$produtos = @()

# 1. Carregar dados existentes
if (Test-Path $caminhoDados) {
    $conteudoAtual = Get-Content $caminhoDados -Raw -Encoding UTF8
    if ($conteudoAtual -match 'const listaProdutos = (\[[\s\S]*\]);') {
        try {
            # Converte JSON para objeto, lidando com a estrutura de array de imagens
            $produtos = $matches[1] | ConvertFrom-Json
        } catch {}
    }
}

# 2. Sincronizar com a pasta de imagens
$arquivosNaPasta = Get-ChildItem -Path "produtos" -File | Select-Object -ExpandProperty Name
$listaFinal = @()

# Manter produtos cujas imagens principais ainda existem
foreach ($p in $produtos) {
    # Verifica se a imagem principal (primeira do array) existe
    $imgPrincipal = if ($p.imagens -is [array]) { $p.imagens[0] } else { $p.imagens }
    if ($arquivosNaPasta -contains $imgPrincipal) {
        $listaFinal += $p
    }
}

# Adicionar novos arquivos detectados
foreach ($img in $arquivosNaPasta) {
    # Verifica se algum produto ja usa essa imagem como principal
    $existe = $listaFinal | Where-Object { 
        $imgP = if ($_.imagens -is [array]) { $_.imagens[0] } else { $_.imagens }
        $imgP -eq $img 
    }
    
    if (-not $existe) {
        Write-Host "`n--- NOVO PRODUTO DETECTADO: $img ---" -ForegroundColor Yellow
        $nomePadrao = ($img -split '\.')[0] -replace 'Modelo', 'Produto ' -replace 'modelo', 'Produto '
        $nome = Read-Host "Nome do produto (Enter para '$nomePadrao')"
        if ([string]::IsNullOrWhiteSpace($nome)) { $nome = $nomePadrao }
        
        $precoStr = Read-Host "Preco (Ex: 49.90)"
        $preco = 0.00
        if ($precoStr -match '^\d+([.,]\d+)?$') { $preco = [double]($precoStr -replace ',', '.') }
        
        # Cria novo produto com array de imagens
        $listaFinal += [PSCustomObject]@{ 
            imagens = @($img)
            preco = $preco
            nome = $nome 
        }
    }
}

# 3. Menu de Edicao
while ($true) {
    Clear-Host
    Write-Host "=== GERENCIADOR DE PRODUTOS IDONEOS (MODO CARROSSEL) ===" -ForegroundColor Cyan
    Write-Host "Produtos atuais:"
    for ($i = 0; $i -lt $listaFinal.Count; $i++) {
        $p = $listaFinal[$i]
        $imgP = if ($p.imagens -is [array]) { $p.imagens[0] } else { $p.imagens }
        $qtdImg = if ($p.imagens -is [array]) { $p.imagens.Count } else { 1 }
        Write-Host ("{0}. {1} - R$ {2:N2} ({3} fotos) [{4}]" -f ($i + 1), $p.nome, $p.preco, $qtdImg, $imgP)
    }
    
    Write-Host "`nOpcoes:"
    Write-Host "Digite o numero do produto para EDITAR (Nome, Preco ou Fotos)"
    Write-Host "Digite 'S' para SALVAR e SAIR"
    Write-Host "Digite 'Q' para SAIR SEM SALVAR"
    
    $opcao = Read-Host "`nEscolha uma opcao"
    
    if ($opcao -eq 'S') {
        # Garante que imagens seja sempre salvo como array no JSON
        $json = $listaFinal | ConvertTo-Json -Depth 4
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

        Write-Host "`n--- GERENCIAR FOTOS DO CARROSSEL ---" -ForegroundColor Cyan
        Write-Host "Fotos atuais: $([string]::Join(', ', $p.imagens))"
        $addFotos = Read-Host "Deseja adicionar mais fotos? Digite os nomes dos arquivos separados por virgula (ou Enter para pular)"
        if (-not [string]::IsNullOrWhiteSpace($addFotos)) {
            $fotosArray = $addFotos.Split(',').Trim()
            foreach ($f in $fotosArray) {
                if ($arquivosNaPasta -contains $f) {
                    if ($p.imagens -notcontains $f) {
                        $p.imagens += $f
                        Write-Host "Foto '$f' adicionada!" -ForegroundColor Green
                    }
                } else {
                    Write-Host "Aviso: Arquivo '$f' nao encontrado na pasta 'produtos'!" -ForegroundColor Red
                }
            }
            Start-Sleep -Seconds 1
        }
    }
}