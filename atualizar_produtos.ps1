# Script Gerenciador de Produtos (Interativo) - Versão com Exclusão Total
$caminhoDados = "produtos_dados.js"
$produtos = @()

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# 1. Carregar dados existentes
if (Test-Path $caminhoDados) {
    $conteudoAtual = [System.IO.File]::ReadAllText($caminhoDados, [System.Text.Encoding]::UTF8)
    # Captura tanto [] quanto {}
    if ($conteudoAtual -match 'const listaProdutos = (\{[\s\S]*\}|\[[\s\S]*?\]);') {
        try {
            $parsed = $matches[1] | ConvertFrom-Json
            # Garante que é um array
            if ($parsed -is [System.Array]) {
                $produtos = $parsed
            } else {
                $produtos = @()
            }
        } catch {
            $produtos = @()
        }
    }
}

$arquivosPrincipais = Get-ChildItem -Path "produtos" -File | Select-Object -ExpandProperty Name
$arquivosDetalhes = Get-ChildItem -Path "produtos\detalhes" -File | Select-Object -ExpandProperty Name
$listaFinal = @()

# 2. Sincronizar e Auto-Detectar
foreach ($p in $produtos) {
    if ($arquivosPrincipais -contains $p.principal) {
        $baseName = ($p.principal -split '\.')[0]
        $detalhesEncontrados = $arquivosDetalhes | Where-Object { $_ -like "${baseName}_detalhe*" }
        
        $todosDetalhes = @()
        if ($p.detalhes) { $todosDetalhes += $p.detalhes }
        foreach ($det in $detalhesEncontrados) {
            if ($todosDetalhes -notcontains $det) { $todosDetalhes += $det }
        }
        
        $detalhesValidos = @()
        foreach ($d in $todosDetalhes) {
            if ($arquivosDetalhes -contains $d) { $detalhesValidos += $d }
        }
        
        $p.detalhes = $detalhesValidos
        $listaFinal += $p
    }
}

# 3. Detectar Novos
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
        
        $baseName = ($img -split '\.')[0]
        $detalhesEncontrados = $arquivosDetalhes | Where-Object { $_ -like "${baseName}_detalhe*" }
        
        $listaFinal += [PSCustomObject]@{ 
            nome = $nome
            preco = $preco
            principal = $img
            detalhes = [array]$detalhesEncontrados
        }
    }
}

# 4. Menu de Edicao
while ($true) {
    Clear-Host
    Write-Host "=== GERENCIADOR DE PRODUTOS IDONEOS ===" -ForegroundColor Cyan
    Write-Host "Produtos atuais:"
    for ($i = 0; $i -lt $listaFinal.Count; $i++) {
        $p = $listaFinal[$i]
        $qtdDet = $p.detalhes.Count
        # Alinhamento por colunas: Numero (4), Nome (35), Preco (15)
        $linha = "{0,-4} {1,-35} | R$ {2,-12:N2} | Fotos Detalhe: {3}" -f ($i + 1), $p.nome, $p.preco, $qtdDet
        Write-Host $linha
    }
    
    Write-Host "`nOpcoes: [Numero] Editar | [D] Deletar Produto | [S] Salvar | [Q] Sair"
    $opcao = Read-Host "Escolha uma opcao"
    
    if ($opcao -eq 'S') {
        $json = $listaFinal | ConvertTo-Json -Depth 4
        $conteudoFinal = "const listaProdutos = $json;"
        [System.IO.File]::WriteAllText($caminhoDados, $conteudoFinal, (New-Object System.Text.UTF8Encoding($false)))
        Write-Host "Salvo com sucesso!" -ForegroundColor Green; Start-Sleep 1; break
    }
    elseif ($opcao -eq 'Q') { break }
    elseif ($opcao -eq 'D') {
        $delIdx = Read-Host "Digite o NUMERO do produto que deseja EXCLUIR PERMANENTEMENTE"
        if ($delIdx -match '^\d+$' -and [int]$delIdx -le $listaFinal.Count -and [int]$delIdx -gt 0) {
            $p = $listaFinal[[int]$delIdx - 1]
            Write-Host "`nTEM CERTEZA que deseja excluir '$($p.nome)'?" -ForegroundColor Red
            Write-Host "Isso apagara a foto principal e todas as fotos de detalhes da pasta!" -ForegroundColor Red
            $conf = Read-Host "(S/N)"
            if ($conf -eq 'S') {
                # Remove arquivos físicos
                if (Test-Path "produtos\$($p.principal)") { Remove-Item "produtos\$($p.principal)" -Force }
                foreach ($d in $p.detalhes) {
                    if (Test-Path "produtos\detalhes\$d") { Remove-Item "produtos\detalhes\$d" -Force }
                }
                # Remove da lista
                $listaFinal = $listaFinal | Where-Object { $_.principal -ne $p.principal }
                Write-Host "Produto e arquivos removidos!" -ForegroundColor Green; Start-Sleep 1
            }
        }
    }
    elseif ($opcao -match '^\d+$' -and [int]$opcao -le $listaFinal.Count -and [int]$opcao -gt 0) {
        $p = $listaFinal[[int]$opcao - 1]
        
        while ($true) {
            Clear-Host
            Write-Host "--- EDITANDO: $($p.nome) ---" -ForegroundColor Yellow
            Write-Host "1. Nome: $($p.nome)"
            Write-Host "2. Preco: R$ $($p.preco)"
            Write-Host "3. Imagens de Detalhe:"
            if ($p.detalhes.Count -eq 0) {
                Write-Host "   (Nenhuma foto de detalhe)"
            } else {
                for ($j = 0; $j -lt $p.detalhes.Count; $j++) {
                    Write-Host "   [$($j + 1)] $($p.detalhes[$j])"
                }
            }
            
            Write-Host "`nOpcoes de Edicao:"
            Write-Host "   [N] Mudar Nome"
            Write-Host "   [P] Mudar Preco"
            Write-Host "   [A] Adicionar Foto de Detalhe"
            Write-Host "   [R] Remover uma Foto de Detalhe"
            Write-Host "   [V] Voltar ao Menu Principal"
            
            $subOpcao = Read-Host "Escolha uma acao"
            
            if ($subOpcao -eq 'V') { break }
            elseif ($subOpcao -eq 'N') {
                $n = Read-Host "Novo Nome"; if ($n) { $p.nome = $n }
            }
            elseif ($subOpcao -eq 'P') {
                $pr = Read-Host "Novo Preco"; if ($pr -match '^\d+') { $p.preco = [double]($pr -replace ',', '.') }
            }
            elseif ($subOpcao -eq 'A') {
                Write-Host "`nArquivos disponiveis em 'produtos\detalhes\':"
                $arquivosDetalhes = Get-ChildItem -Path "produtos\detalhes" -File | Select-Object -ExpandProperty Name
                $arquivosDetalhes | ForEach-Object { Write-Host " - $_" }
                $add = Read-Host "`nNome do arquivo para adicionar"
                if ($arquivosDetalhes -contains $add) {
                    if ($p.detalhes -notcontains $add) { $p.detalhes += $add }
                } else {
                    Write-Host "Erro: Arquivo nao encontrado!" -ForegroundColor Red; Start-Sleep 1
                }
            }
            elseif ($subOpcao -eq 'R') {
                if ($p.detalhes.Count -gt 0) {
                    $remIdx = Read-Host "Digite o NUMERO da foto que deseja remover"
                    if ($remIdx -match '^\d+$' -and [int]$remIdx -le $p.detalhes.Count -and [int]$remIdx -gt 0) {
                        $p.detalhes = $p.detalhes | Where-Object { $_ -ne $p.detalhes[[int]$remIdx - 1] }
                        Write-Host "Foto removida!" -ForegroundColor Green; Start-Sleep 1
                    }
                }
            }
        }
    }
}