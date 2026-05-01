# Script Gerenciador de Produtos (Interativo) - Versão UTF-8 Fix
$caminhoDados = "produtos_dados.js"
$produtos = @()

# Força o terminal a usar UTF8 para evitar erros de leitura/escrita
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

if (Test-Path $caminhoDados) {
    # Lê forçando UTF8
    $conteudoAtual = [System.IO.File]::ReadAllText($caminhoDados, [System.Text.Encoding]::UTF8)
    if ($conteudoAtual -match 'const listaProdutos = (\[[\s\S]*\]);') {
        try {
            $produtos = $matches[1] | ConvertFrom-Json
        } catch {}
    }
}

$arquivosPrincipais = Get-ChildItem -Path "produtos" -File | Select-Object -ExpandProperty Name
$arquivosDetalhes = Get-ChildItem -Path "produtos\detalhes" -File | Select-Object -ExpandProperty Name
$listaFinal = @()

foreach ($p in $produtos) {
    if ($arquivosPrincipais -contains $p.principal) {
        $detalhesValidos = @()
        foreach ($d in $p.detalhes) {
            if ($arquivosDetalhes -contains $d) { $detalhesValidos += $d }
        }
        $p.detalhes = $detalhesValidos
        $listaFinal += $p
    }
}

foreach ($img in $arquivosPrincipais) {
    $existe = $listaFinal | Where-Object { $_.principal -eq $img }
    if (-not $existe) {
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
    Write-Host "=== GERENCIADOR DE PRODUTOS IDONEOS (FIX UTF-8) ===" -ForegroundColor Cyan
    Write-Host "Produtos atuais:"
    for ($i = 0; $i -lt $listaFinal.Count; $i++) {
        $p = $listaFinal[$i]
        $qtdDet = $p.detalhes.Count
        Write-Host ("{0}. {1} - R$ {2:N2} (Det: {3})" -f ($i + 1), $p.nome, $p.preco, $qtdDet)
    }
    
    Write-Host "`nOpcoes: [Numero] Editar | [S] Salvar | [Q] Sair"
    $opcao = Read-Host "Escolha uma opcao"
    
    if ($opcao -eq 'S') {
        $json = $listaFinal | ConvertTo-Json -Depth 4
        $conteudoFinal = "const listaProdutos = $json;"
        # Salva forçando UTF8 SEM BOM (formato universal para web)
        [System.IO.File]::WriteAllText($caminhoDados, $conteudoFinal, (New-Object System.Text.UTF8Encoding($false)))
        Write-Host "Salvo com sucesso!" -ForegroundColor Green; Start-Sleep 1; break
    }
    elseif ($opcao -eq 'Q') { break }
    elseif ($opcao -match '^\d+$' -and [int]$opcao -le $listaFinal.Count -and [int]$opcao -gt 0) {
        $p = $listaFinal[[int]$opcao - 1]
        Write-Host "`nEditando: $($p.nome)" -ForegroundColor Yellow
        $n = Read-Host "Novo Nome (Enter para manter)"; if ($n) { $p.nome = $n }
        $pr = Read-Host "Novo Preco (Enter para manter)"; if ($pr -match '^\d+') { $p.preco = [double]($pr -replace ',', '.') }
        
        Write-Host "`nArquivos em 'produtos\detalhes\': $([string]::Join(', ', $arquivosDetalhes))"
        $add = Read-Host "Adicionar detalhes (nomes separados por virgula)"
        if ($add) {
            foreach ($f in $add.Split(',').Trim()) {
                if ($arquivosDetalhes -contains $f -and $p.detalhes -notcontains $f) { $p.detalhes += $f }
            }
        }
        $rem = Read-Host "Limpar detalhes? (S/N)"; if ($rem -eq 'S') { $p.detalhes = @() }
    }
}