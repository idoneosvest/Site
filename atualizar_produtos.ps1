# Script Gerenciador de Produtos (Interativo) - Versão com Detalhes em Pasta Separada
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

$arquivosPrincipais = Get-ChildItem -Path "produtos" -File | Select-Object -ExpandProperty Name
$arquivosDetalhes = Get-ChildItem -Path "produtos\detalhes" -File | Select-Object -ExpandProperty Name
$listaFinal = @()

# Sincronizar produtos existentes
foreach ($p in $produtos) {
    if ($arquivosPrincipais -contains $p.principal) {
        # Filtra detalhes que ainda existem na subpasta
        $detalhesValidos = @()
        foreach ($d in $p.detalhes) {
            if ($arquivosDetalhes -contains $d) { $detalhesValidos += $d }
        }
        $p.detalhes = $detalhesValidos
        $listaFinal += $p
    }
}

# Adicionar novos produtos (apenas da pasta raiz)
foreach ($img in $arquivosPrincipais) {
    $existe = $listaFinal | Where-Object { $_.principal -eq $img }
    if (-not $existe) {
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

while ($true) {
    Clear-Host
    Write-Host "=== GERENCIADOR DE PRODUTOS IDONEOS (DETALHES EM PASTA) ===" -ForegroundColor Cyan
    Write-Host "Produtos atuais:"
    for ($i = 0; $i -lt $listaFinal.Count; $i++) {
        $p = $listaFinal[$i]
        $qtdDet = $p.detalhes.Count
        Write-Host ("{0}. {1} - R$ {2:N2} (Fotos Detalhe: {3}) [{4}]" -f ($i + 1), $p.nome, $p.preco, $qtdDet, $p.principal)
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
        
        Write-Host "`n--- IMAGENS NA PASTA DETALHES ---"
        Write-Host "Arquivos disponiveis em 'produtos\detalhes\': $([string]::Join(', ', $arquivosDetalhes))"
        Write-Host "Detalhes atuais deste produto: $([string]::Join(', ', $p.detalhes))"
        
        $add = Read-Host "Digite os nomes dos arquivos para adicionar (separe por virgula)"
        if ($add) {
            foreach ($f in $add.Split(',').Trim()) {
                if ($arquivosDetalhes -contains $f -and $p.detalhes -notcontains $f) { $p.detalhes += $f }
                elseif (-not ($arquivosDetalhes -contains $f)) { Write-Host "Erro: Arquivo '$f' nao encontrado na pasta 'detalhes'!" -ForegroundColor Red }
            }
            Start-Sleep 1
        }
        $rem = Read-Host "Limpar detalhes? (S/N)"; if ($rem -eq 'S') { $p.detalhes = @() }
    }
}