# Script Gerenciador de Produtos (Interativo) - Versão com Exclusão Total
$caminhoDados = "produtos_dados.js"
$produtos = @()

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# 1. Carregar dados existentes
# Verifica se o arquivo de dados existe
if (Test-Path $caminhoDados)
{
    $conteudoAtual = [System.IO.File]::ReadAllText($caminhoDados, [System.Text.Encoding]::UTF8)
    # Captura tanto [] quanto {}
    # Verifica se o conteúdo contém a definição da lista de produtos
    if ($conteudoAtual -match 'const listaProdutos = (\{[\s\S]*\}|\[[\s\S]*?\]);')
    {
        try
        {
            $parsed = $matches[1] | ConvertFrom-Json
            # Garante que é um array
            # Verifica se o objeto parseado é um array
            if ($parsed -is [System.Array])
            {
                $produtos = $parsed
            }
            else
            {
                $produtos = @()
            }
        }
        catch
        {
            $produtos = @()
        }
    }
}

$arquivosPrincipais = Get-ChildItem -Path "produtos" -File | Select-Object -ExpandProperty Name
$arquivosDetalhes = Get-ChildItem -Path "produtos\detalhes" -File | Select-Object -ExpandProperty Name
$listaFinal = @()

# 2. Sincronizar e Auto-Detectar
foreach ($p in $produtos)
{
    # Verifica se o arquivo principal do produto ainda existe
    if ($arquivosPrincipais -contains $p.principal)
    {
        $baseName = ($p.principal -split '\.')[0]
        $detalhesEncontrados = $arquivosDetalhes | Where-Object { $_ -like "${baseName}_detalhe*" }
        
        $todosDetalhes = @()
        # Se o produto já tem detalhes, adiciona à lista
        if ($p.detalhes)
        {
            $todosDetalhes += $p.detalhes
        }
        foreach ($det in $detalhesEncontrados)
        {
            # Adiciona detalhes encontrados que não estão na lista
            if ($todosDetalhes -notcontains $det)
            {
                $todosDetalhes += $det
            }
        }
        
        $detalhesValidos = @()
        foreach ($d in $todosDetalhes)
        {
            # Filtra apenas os detalhes que ainda existem nos arquivos
            if ($arquivosDetalhes -contains $d)
            {
                $detalhesValidos += $d
            }
        }
        
        $p.detalhes = $detalhesValidos
        $listaFinal += $p
    }
}

# 3. Detectar Novos
foreach ($img in $arquivosPrincipais)
{
    $existe = $listaFinal | Where-Object { $_.principal -eq $img }
    # Se o produto não existe na lista, é novo
    if (-not $existe)
    {
        Write-Host "`n--- NOVO PRODUTO DETECTADO: $img ---" -ForegroundColor Yellow
        $nomePadrao = ($img -split '\.')[0] -replace 'Modelo', 'Produto ' -replace 'modelo', 'Produto '
        $nome = Read-Host "Nome do produto (Enter para '$nomePadrao')"
        # Se o nome estiver vazio, usa o padrão
        if ([string]::IsNullOrWhiteSpace($nome))
        {
            $nome = $nomePadrao
        }
        $precoStr = Read-Host "Preco (Ex: 65.00)"
        $preco = 0.00
        # Valida e converte o preço
        if ($precoStr -match '^\d+([.,]\d+)?$')
        {
            $preco = [double]($precoStr -replace ',', '.')
        }
        
        $baseName = ($img -split '\.')[0]
        $detalhesEncontrados = $arquivosDetalhes | Where-Object { $_ -like "${baseName}_detalhe*" }
        
        $listaFinal += [PSCustomObject]@{ 
            nome = $nome
            preco = $preco
            principal = $img
            detalhes = [array]$detalhesEncontrados
            estoque = @{
                PP = 0
                P = 0
                M = 0
                G = 0
                GG = 0
                ExG = 0
            }
        }
    }
}

# Funções do Menu
function Show-MainMenu
{
    Clear-Host
    Write-Host "=== GERENCIADOR DE PRODUTOS IDONEOS ===" -ForegroundColor Cyan
    Write-Host "Produtos atuais:"
    for ($i = 0; $i -lt $script:listaFinal.Count; $i++)
    {
        $p = $script:listaFinal[$i]
        $qtdDet = $p.detalhes.Count
        $linha = "{0,-4} {1,-55} | R$ {2,-12:N2} | Fotos Detalhe: {3}" -f ($i + 1), $p.nome, $p.preco, $qtdDet
        Write-Host $linha
    }
    
    Write-Host "`nOpcoes: [Numero] Editar | [D] Deletar Produto | [S] Salvar | [Q] Sair"
    return Read-Host "Escolha uma opcao"
}

function Save-Data
{
    $json = @($script:listaFinal) | ConvertTo-Json -Depth 4
    $conteudoFinal = "const listaProdutos = $json;"
    [System.IO.File]::WriteAllText($script:caminhoDados, $conteudoFinal, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host "Salvo com sucesso!" -ForegroundColor Green; Start-Sleep 1
}

function Delete-Product
{
    $delIdx = Read-Host "Digite o NUMERO do produto que deseja EXCLUIR PERMANENTEMENTE"
    # Valida se o índice é um número válido e dentro do range
    if ($delIdx -match '^\d+$' -and [int]$delIdx -le $script:listaFinal.Count -and [int]$delIdx -gt 0)
    {
        $p = $script:listaFinal[[int]$delIdx - 1]
        Write-Host "`nTEM CERTEZA que deseja excluir '$($p.nome)'?" -ForegroundColor Red
        Write-Host "Isso apagara a foto principal e todas as fotos de detalhes da pasta!" -ForegroundColor Red
        $conf = Read-Host "(S/N)"
        # Se confirmado, deleta os arquivos e remove da lista
        if ($conf -eq 'S')
        {
            # Verifica se o arquivo principal existe e remove
            if (Test-Path "produtos\$($p.principal)")
            {
                Remove-Item "produtos\$($p.principal)" -Force
            }
            foreach ($d in $p.detalhes)
            {
                # Verifica se o arquivo de detalhe existe e remove
                if (Test-Path "produtos\detalhes\$d")
                {
                    Remove-Item "produtos\detalhes\$d" -Force
                }
            }
            $script:listaFinal = $script:listaFinal | Where-Object { $_.principal -ne $p.principal }
            Write-Host "Produto e arquivos removidos!" -ForegroundColor Green; Start-Sleep 1
        }
    }
}

function Edit-Product
{
    param($index)
    $p = $script:listaFinal[$index]
    
    while ($true)
    {
        Clear-Host
        Write-Host "--- EDITANDO: $($p.nome) ---" -ForegroundColor Yellow
        Write-Host "1. Nome: $($p.nome)"
        Write-Host "2. Preco: R$ $($p.preco)"
        Write-Host "3. Imagens de Detalhe:"
        # Verifica se há detalhes
        if ($p.detalhes.Count -eq 0)
        {
            Write-Host "   (Nenhuma foto de detalhe)"
        }
        else
        {
            for ($j = 0; $j -lt $p.detalhes.Count; $j++)
            {
                Write-Host "   [$($j + 1)] $($p.detalhes[$j])"
            }
        }
        Write-Host "4. Estoque: PP:$($p.estoque.PP) P:$($p.estoque.P) M:$($p.estoque.M) G:$($p.estoque.G) GG:$($p.estoque.GG) ExG:$($p.estoque.ExG)"
        
        Write-Host "`nOpcoes de Edicao:"
        Write-Host "   [N] Mudar Nome"
        Write-Host "   [P] Mudar Preco"
        Write-Host "   [E] Editar Estoque"
        Write-Host "   [A] Adicionar Foto de Detalhe"
        Write-Host "   [R] Remover uma Foto de Detalhe"
        Write-Host "   [V] Voltar ao Menu Principal"
        
        $subOpcao = Read-Host "Escolha uma acao"
        
        # Verifica se a opção é voltar
        if ($subOpcao -eq 'V')
        {
            break
        }
        # Verifica se a opção é mudar nome
        elseif ($subOpcao -eq 'N')
        {
            Change-Name $p
        }
        # Verifica se a opção é mudar preço
        elseif ($subOpcao -eq 'P')
        {
            Change-Price $p
        }
        # Verifica se a opção é editar estoque
        elseif ($subOpcao -eq 'E')
        {
            Edit-Stock $p
        }
        # Verifica se a opção é adicionar detalhe
        elseif ($subOpcao -eq 'A')
        {
            Add-Detail $p
        }
        # Verifica se a opção é remover detalhe
        elseif ($subOpcao -eq 'R')
        {
            Remove-Detail $p
        }
    }
}

function Change-Name($p)
{
    $n = Read-Host "Novo Nome"
    # Se o nome não estiver vazio, atualiza
    if ($n)
    {
        $p.nome = $n
    }
}

function Change-Price($p)
{
    $pr = Read-Host "Novo Preco"
    # Valida se o preço é numérico
    if ($pr -match '^\d+')
    {
        $p.preco = [double]($pr -replace ',', '.')
    }
}

function Add-Detail($p)
{
    Write-Host "`nArquivos disponiveis em 'produtos\detalhes\':"
    $arquivosDetalhes = Get-ChildItem -Path "produtos\detalhes" -File | Select-Object -ExpandProperty Name
    $arquivosDetalhes | ForEach-Object { Write-Host " - $_" }
    $add = Read-Host "`nNome do arquivo para adicionar"
    # Verifica se o arquivo existe na lista
    if ($arquivosDetalhes -contains $add)
    {
        # Verifica se já não está na lista do produto
        if ($p.detalhes -notcontains $add)
        {
            $p.detalhes += $add
        }
    }
    else
    {
        Write-Host "Erro: Arquivo nao encontrado!" -ForegroundColor Red; Start-Sleep 1
    }
}

function Remove-Detail($p)
{
    # Verifica se há detalhes para remover
    if ($p.detalhes.Count -gt 0)
    {
        $remIdx = Read-Host "Digite o NUMERO da foto que deseja remover"
        # Valida o índice
        if ($remIdx -match '^\d+$' -and [int]$remIdx -le $p.detalhes.Count -and [int]$remIdx -gt 0)
        {
            $p.detalhes = $p.detalhes | Where-Object { $_ -ne $p.detalhes[[int]$remIdx - 1] }
            Write-Host "Foto removida!" -ForegroundColor Green; Start-Sleep 1
        }
    }
}

function Edit-Stock($p)
{
    while ($true)
    {
        Clear-Host
        Write-Host "--- EDITANDO ESTOQUE: $($p.nome) ---" -ForegroundColor Yellow
        Write-Host "PP: $($p.estoque.PP)"
        Write-Host "P: $($p.estoque.P)"
        Write-Host "M: $($p.estoque.M)"
        Write-Host "G: $($p.estoque.G)"
        Write-Host "GG: $($p.estoque.GG)"
        Write-Host "ExG: $($p.estoque.ExG)"
        Write-Host "`n[Tamanho] Novo valor | [V] Voltar"
        $tam = Read-Host "Tamanho ou V"
        # Verifica se é voltar
        if ($tam -eq 'V')
        {
            break
        }
        # Verifica se o tamanho é válido
        if ($tam -in @('PP','P','M','G','GG','ExG'))
        {
            $val = Read-Host "Novo estoque para $tam"
            # Valida se o valor é numérico
            if ($val -match '^\d+$')
            {
                $p.estoque.$tam = [int]$val
            }
            else
            {
                Write-Host "Valor invalido. Deve ser um numero inteiro." -ForegroundColor Red
                Start-Sleep 1
            }
        }
        else
        {
            Write-Host "Tamanho invalido." -ForegroundColor Red
            Start-Sleep 1
        }
    }
}

# 4. Menu de Edicao
while ($true)
{
    $opcao = Show-MainMenu
    
    # Verifica se a opção é salvar
    if ($opcao -eq 'S')
    {
        Save-Data
        break
    }
    # Verifica se a opção é sair
    elseif ($opcao -eq 'Q')
    {
        break
    }
    # Verifica se a opção é deletar
    elseif ($opcao -eq 'D')
    {
        Delete-Product
    }
    # Verifica se a opção é um número para editar
    elseif ($opcao -match '^\d+$' -and [int]$opcao -le $listaFinal.Count -and [int]$opcao -gt 0)
    {
        Edit-Product ([int]$opcao - 1)
    }
}