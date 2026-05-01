# Script Gerenciador de Produtos (Interativo) - Versão com Detalhes
$caminhoDados = "produtos_dados.js"
$produtos = @()

if (Test-Path $caminhoDados) {
    $conteudoAtual = Get-Content $caminhoDados -Raw -Encoding UTF8
    if ($conteudoAtual -match 'const listaProdutos = (\[[\s\S]*\]);') {
        try {
            $produtos = $matches[1] | ConvertFrom-Json
        } catch {}
    }
}

$arquivosNaPasta = Get-ChildItem -Path "produtos" -File | Select-Object -ExpandProperty Name
$listaFinal = @()

foreach ($p in $produtos) {
    if ($arquivosNaPasta -contains $p.principal) {
        $listaFinal += $p
    }
}

foreach ($img in $arquivosNaPasta) {
    $existe = $listaFinal | Where-Object { $_.principal -eq $img }
    if (-not $existe) {
        # Verifica se essa imagem ja nao esta nos detalhes de alguem (para nao criar produto novo de imagem de detalhe)
        $ehDetalhe = $false
        foreach ($item in $listaFinal) {
            if ($item.detalhes -contains $img) { $ehDetalhe = $true; break }
        }
        
        if (-not $ehDetalhe) {
            Write-Host "`n--- NOVO PRODUTO DETECTADO: $img ---" -ForegroundColor Yellow
            $nomePadrao = ($img -split '\.')[0] -replace 'Modelo', 'Produto ' -replace 'modelo', 'Produto '
            $nome = Read-Host "Nome do produto (Enter para '$nomePadrao')"
            if ([string]::IsNullOrWhiteSpace($nome)) { $nome = $nomePadrao }
            $precoStr = Read-Host "Preco (Ex: 49.90)"
            $preco = 0.00
            if ($precoStr -match '^\d+([.,]\d+)?$') { $preco = [double]($precoStr -replace ',', '.') }
            
            $listaFinal += [PSCustomObject]@{ 
                nome = $nome
                preco = $preco
                principal = $img
                detalhes = @()
            }
        }
    }
}

while ($true) {
    Clear-Host
    Write-Host "=== GERENCIADOR DE PRODUTOS IDONEOS ===" -ForegroundColor Cyan
    Write-Host "Produtos atuais:"
    for ($i = 0; $i -lt $listaFinal.Count; $i++) {
        $p = $listaFinal[$i]
        $qtdDet = $p.detalhes.Count
        Write-Host ("{0}. {1} - R$ {2:N2} (Det: {3}) [{4}]" -f ($i + 1), $p.nome, $p.preco, $qtdDet, $p.principal)
    }
    
    Write-Host "`nOpcoes: [Numero] Editar | [S] Salvar | [Q] Sair"
    $opcao = Read-Host "Escolha uma opcao"
    
    if ($opcao -eq 'S') {
        $json = $listaFinal | ConvertTo-Json -Depth 4
        $conteudoFinal = "const listaProdutos = $json;"
        [System.IO.File]::WriteAllLines($caminhoDados, $conteudoFinal, (New-Object System.Text.UTF8Encoding($false)))
        Write-Host "Salvo!" -ForegroundColor Green; Start-Sleep 1; break
    }
    elseif ($opcao -eq 'Q') { break }
    elseif ($opcao -match '^\d+$' -and [int]$opcao -le $listaFinal.Count -and [int]$opcao -gt 0) {
        $p = $listaFinal[[int]$opcao - 1]
        Write-Host "`nEditando: $($p.nome)" -ForegroundColor Yellow
        $n = Read-Host "Nome (Enter: $($p.nome))"; if ($n) { $p.nome = $n }
        $pr = Read-Host "Preco (Enter: $($p.preco))"; if ($pr -match '^\d+') { $p.preco = [double]($pr -replace ',', '.') }
        
        Write-Host "`n--- IMAGENS DE DETALHES ---"
        Write-Host "Atuais: $([string]::Join(', ', $p.detalhes))"
        $add = Read-Host "Adicionar arquivos de detalhes (separe por virgula)"
        if ($add) {
            foreach ($f in $add.Split(',').Trim()) {
                if ($arquivosNaPasta -contains $f -and $p.detalhes -notcontains $f) { $p.detalhes += $f }
            }
        }
        $rem = Read-Host "Limpar detalhes? (S/N)"; if ($rem -eq 'S') { $p.detalhes = @() }
    }
}