<#
.SYNOPSIS
    Automatiza a deteccao, instalacao e atualizacao dos modulos PowerShell
    mais utilizados por administradores Microsoft 365 / Azure / Entra ID.

.DESCRIPTION
    O script executa o seguinte fluxo:
      1. Valida o ambiente (versao do PowerShell, politica de execucao, TLS).
      2. Verifica e prepara o "PowerShellGet" e o provedor NuGet.
      3. Define a lista de modulos administrativos relevantes.
      4. Para cada modulo: compara a versao local com a versao mais recente
         publicada no PowerShell Gallery (origem oficial).
      5. Pergunta ao usuario o que fazer (por modulo ou todos de uma vez):
         manter, instalar ou atualizar.
      6. Executa a operacao de forma segura (sempre a partir do PSGallery).
      7. Exibe um resumo final do que foi instalado / atualizado / mantido.

.NOTES
    Compatibilidade : Windows PowerShell 5.1+ e PowerShell 7+
    Origem confiavel: somente PSGallery (https://www.powershellgallery.com)
    Privilegios     : recomenda-se executar como Administrador para instalacao
                      em -Scope AllUsers; caso contrario o script usa
                      automaticamente -Scope CurrentUser.

.PARAMETER AutoConfirmAll
    Quando informado, aplica a acao recomendada (instalar/atualizar) a TODOS
    os modulos sem perguntar individualmente.

.EXAMPLE
    .\Manage-AdminModules.ps1

.EXAMPLE
    .\Manage-AdminModules.ps1 -AutoConfirmAll
#>

#Requires -Version 5.1

[CmdletBinding()]
param(
    [switch] $AutoConfirmAll
)

$ErrorActionPreference = 'Stop'

# ============================================================================
#  CONFIGURACAO
# ============================================================================

# Repositorio oficial e confiavel
$TrustedRepository = 'PSGallery'

# Lista dos modulos administrativos relevantes no dia a dia.
# Edite livremente esta lista conforme a necessidade do ambiente.
$AdminModules = @(
    'PackageManagement',
    'PowerShellGet',
    'Microsoft.Graph',
    'Microsoft.Graph.Beta',
    'Microsoft.Entra',
    'Microsoft.Entra.Beta',
    'ExchangeOnlineManagement',
    'Microsoft.Online.SharePoint.PowerShell',
    'PnP.PowerShell',
    'MicrosoftTeams',
    'Az',
    'WindowsAutopilotIntune'
)

# Modulos LEGADOS oficialmente RETIRADOS do PowerShell Gallery pela Microsoft.
# Nao existem mais online (Find-Module falha). O script apenas DETECTA se
# ainda estao instalados localmente e recomenda a remocao, indicando o
# substituto oficial. Referencia: anuncios oficiais Microsoft Entra (2024/2025).
$RetiredModules = @(
    @{ Name = 'AzureAD';        Replacement = 'Microsoft.Graph / Microsoft.Entra'; RetiredOn = 'Out/2025' },
    @{ Name = 'AzureADPreview'; Replacement = 'Microsoft.Graph / Microsoft.Entra'; RetiredOn = 'Out/2025' },
    @{ Name = 'MSOnline';       Replacement = 'Microsoft.Graph / Microsoft.Entra'; RetiredOn = 'Mai/2025' }
)

# ============================================================================
#  FUNCOES DE LOG
# ============================================================================

function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $Message,
        [ValidateSet('INFO', 'OK', 'WARN', 'ERROR', 'STEP')]
        [string] $Level = 'INFO'
    )

    $timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')

    switch ($Level) {
        'INFO'  { $color = 'Gray';   $tag = '[ INFO  ]' }
        'OK'    { $color = 'Green';  $tag = '[  OK   ]' }
        'WARN'  { $color = 'Yellow'; $tag = '[ WARN  ]' }
        'ERROR' { $color = 'Red';    $tag = '[ ERROR ]' }
        'STEP'  { $color = 'Cyan';   $tag = '[ STEP  ]' }
    }

    Write-Host "$timestamp $tag $Message" -ForegroundColor $color
}

function Write-Banner {
    param([string] $Text)
    $line = '=' * 72
    Write-Host ''
    Write-Host $line -ForegroundColor DarkCyan
    Write-Host "  $Text" -ForegroundColor White
    Write-Host $line -ForegroundColor DarkCyan
}

# ============================================================================
#  APRESENTACAO INICIAL (ASCII ART)
# ============================================================================
#
#  O bloco abaixo usa here-string LITERAL (@' ... '@). Em PowerShell, o
#  here-string literal NAO interpreta os caracteres especiais $, ` e \,
#  o que e essencial para preservar a arte ASCII exatamente como desenhada.
# ============================================================================

function Show-Splash {
    [CmdletBinding()]
    param()

    $banner = @'

 __  __          _   _          _____ ______    __  __ ____    __ _____
|  \/  |   /\   | \ | |   /\   / ____|  ____|  |  \/  |___ \  / /| ____|
| \  / |  /  \  |  \| |  /  \ | |  __| |__     | \  / | __) |/ /_| |__
| |\/| | / /\ \ | . ` | / /\ \| | |_ |  __|    | |\/| ||__ <| '_ \___ \
| |  | |/ ____ \| |\  |/ ____ \ |__| | |____   | |  | |___) | (_) |__) |
|_|  |_/_/    \_\_| \_/_/    \_\_____|______|  |_|  |_|____/ \___/____/

          _____  __  __ _____ _   _
    /\   |  __ \|  \/  |_   _| \ | |
   /  \  | |  | | \  / | | | |  \| |
  / /\ \ | |  | | |\/| | | | | . ` |
 / ____ \| |__| | |  | |_| |_| |\  |
/_/    \_\_____/|_|  |_|_____|_| \_|

 __  __  ____  _____  _    _ _      ______  _____
|  \/  |/ __ \|  __ \| |  | | |    |  ____|/ ____|
| \  / | |  | | |  | | |  | | |    | |__  | (___
| |\/| | |  | | |  | | |  | | |    |  __|  \___ \
| |  | | |__| | |__| | |__| | |____| |____ ____) |
|_|  |_|\____/|_____/ \____/|______|______|_____/

'@

    Clear-Host
    Write-Host $banner -ForegroundColor Cyan

    $sub = '       Gerenciador de Modulos PowerShell para Microsoft 365 / Entra ID'
    Write-Host $sub -ForegroundColor White
    Write-Host ('       ' + ('-' * 62)) -ForegroundColor DarkGray
    Write-Host "       Detecta | Instala | Atualiza | Desinstala modulos administrativos" -ForegroundColor Gray
    Write-Host ''
    Start-Sleep -Milliseconds 600
}

# ============================================================================
#  HELPER - DETECCAO ROBUSTA DE MODULO INSTALADO
# ============================================================================
#
#  PROBLEMA CONHECIDO: 'Get-Module -ListAvailable' nem sempre detecta modulos
#  instalados via Install-Module (ex.: PnP.PowerShell), por questoes de:
#    - escopo de instalacao (CurrentUser x AllUsers)
#    - edicao do PowerShell (Desktop 5.1 x Core 7+) e PSModulePath
#    - manifestos que nao expoem RootModule da forma esperada
#
#  SOLUCAO: usar Get-InstalledModule (PowerShellGet - rastreia o que foi
#  instalado de fato) como metodo PRIMARIO, com Get-Module -ListAvailable
#  como FALLBACK. Retorna a versao mais alta encontrada ou $null.
# ============================================================================

function Get-InstalledModuleInfo {
    [CmdletBinding()]
    param([Parameter(Mandatory)] [string] $Name)

    $found = $null

    # --- Metodo 1 (primario): Get-InstalledModule do PowerShellGet ---
    try {
        $byInstall = Get-InstalledModule -Name $Name -AllVersions -ErrorAction SilentlyContinue |
                        Sort-Object Version -Descending |
                        Select-Object -First 1
        if ($byInstall) {
            # Remove sufixo de prerelease (ex.: 1.2.4-nightly) para comparar versoes
            $cleanVersion = ($byInstall.Version -replace '-.*$', '')
            $found = [pscustomobject]@{
                Name       = $byInstall.Name
                Version    = [version]$cleanVersion
                RawVersion = $byInstall.Version
                Source     = 'Get-InstalledModule'
            }
        }
    }
    catch { }

    # --- Metodo 2 (fallback): Get-Module -ListAvailable ---
    if (-not $found) {
        try {
            $byList = Get-Module -ListAvailable -Name $Name -ErrorAction SilentlyContinue |
                        Sort-Object Version -Descending |
                        Select-Object -First 1
            if ($byList) {
                $found = [pscustomobject]@{
                    Name       = $byList.Name
                    Version    = $byList.Version
                    RawVersion = $byList.Version.ToString()
                    Source     = 'Get-Module -ListAvailable'
                }
            }
        }
        catch { }
    }

    return $found
}

# ============================================================================
#  ETAPA 1 - VALIDACAO DO AMBIENTE
# ============================================================================

function Test-Environment {
    [CmdletBinding()]
    param()

    Write-Banner 'ETAPA 1 - Validacao do ambiente'

    # Versao do PowerShell
    $psVersion = $PSVersionTable.PSVersion
    Write-Log "Versao do PowerShell: $psVersion" -Level INFO

    if ($psVersion.Major -lt 5) {
        throw "PowerShell 5.1 ou superior e necessario. Versao atual: $psVersion"
    }

    # Forca TLS 1.2 (necessario para acessar o PSGallery em sistemas antigos)
    try {
        [Net.ServicePointManager]::SecurityProtocol = `
            [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
        Write-Log 'Protocolo TLS 1.2 habilitado para a sessao.' -Level OK
    }
    catch {
        Write-Log "Nao foi possivel ajustar o TLS: $($_.Exception.Message)" -Level WARN
    }

    # Verifica se a sessao esta elevada (Administrador)
    $isAdmin = $false
    try {
        $identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        $isAdmin   = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    catch {
        Write-Log 'Nao foi possivel determinar privilegios de administrador.' -Level WARN
    }

    if ($isAdmin) {
        Write-Log 'Sessao elevada (Administrador). Escopo de instalacao: AllUsers.' -Level OK
        $scope = 'AllUsers'
    }
    else {
        Write-Log 'Sessao NAO elevada. Escopo de instalacao: CurrentUser.' -Level WARN
        $scope = 'CurrentUser'
    }

    # Politica de execucao (apenas informativo)
    $policy = Get-ExecutionPolicy
    Write-Log "Politica de execucao atual: $policy" -Level INFO

    return [pscustomobject]@{
        IsAdmin       = $isAdmin
        InstallScope  = $scope
        PSVersion     = $psVersion
    }
}

# ============================================================================
#  ETAPA 2 - PREPARACAO DO POWERSHELLGET / NUGET / PSGALLERY
# ============================================================================

function Initialize-PackageInfrastructure {
    [CmdletBinding()]
    param(
        [string] $Scope,
        [switch] $AutoConfirm
    )

    Write-Banner 'ETAPA 2 - Preparacao do PowerShellGet e do PSGallery'

    # --- 2.1 Provedor NuGet (necessario para o PowerShellGet operar) ---
    try {
        $nuget = Get-PackageProvider -Name 'NuGet' -ErrorAction SilentlyContinue
        if (-not $nuget -or $nuget.Version -lt [version]'2.8.5.201') {
            Write-Log 'Provedor NuGet ausente ou desatualizado. Instalando...' -Level WARN
            Install-PackageProvider -Name 'NuGet' `
                                     -MinimumVersion 2.8.5.201 `
                                     -Force `
                                     -Scope $Scope `
                                     -ErrorAction Stop | Out-Null
            Write-Log 'Provedor NuGet instalado.' -Level OK
        }
        else {
            Write-Log "Provedor NuGet presente (v$($nuget.Version))." -Level OK
        }
    }
    catch {
        Write-Log "Falha ao preparar o provedor NuGet: $($_.Exception.Message)" -Level WARN
    }

    # --- 2.2 Modulo PowerShellGet ---
    $psGet = Get-InstalledModuleInfo -Name 'PowerShellGet'

    if (-not $psGet) {
        Write-Log 'O modulo PowerShellGet NAO esta instalado.' -Level WARN

        $install = $true
        if (-not $AutoConfirm) {
            $answer  = Read-Host 'Deseja instalar o PowerShellGet agora? (S/N)'
            $install = ($answer.Trim().ToUpper() -eq 'S')
        }

        if ($install) {
            try {
                Install-Module -Name 'PowerShellGet' `
                               -Force `
                               -AllowClobber `
                               -Scope $Scope `
                               -Repository $TrustedRepository `
                               -ErrorAction Stop
                Write-Log 'PowerShellGet instalado com sucesso.' -Level OK
            }
            catch {
                Write-Log "Falha ao instalar o PowerShellGet: $($_.Exception.Message)" -Level ERROR
                throw 'O PowerShellGet e essencial e nao pode ser instalado. Abortando.'
            }
        }
        else {
            throw 'O PowerShellGet e essencial para o restante do script. Abortando.'
        }
    }
    else {
        Write-Log "PowerShellGet presente (v$($psGet.Version))." -Level OK
    }

    # --- 2.3 Confianca no PSGallery ---
    try {
        $repo = Get-PSRepository -Name $TrustedRepository -ErrorAction SilentlyContinue
        if (-not $repo) {
            Write-Log "Repositorio '$TrustedRepository' nao registrado. Registrando..." -Level WARN
            Register-PSRepository -Default -ErrorAction Stop
            $repo = Get-PSRepository -Name $TrustedRepository -ErrorAction Stop
        }

        if ($repo.InstallationPolicy -ne 'Trusted') {
            Set-PSRepository -Name $TrustedRepository `
                             -InstallationPolicy Trusted `
                             -ErrorAction Stop
            Write-Log "Repositorio '$TrustedRepository' marcado como confiavel." -Level OK
        }
        else {
            Write-Log "Repositorio '$TrustedRepository' ja e confiavel." -Level OK
        }
    }
    catch {
        Write-Log "Falha ao configurar o PSGallery: $($_.Exception.Message)" -Level WARN
    }
}

# ============================================================================
#  ETAPA 2.5 - DETECCAO DE MODULOS LEGADOS RETIRADOS
# ============================================================================

function Test-RetiredModules {
    [CmdletBinding()]
    param([object[]] $RetiredList)

    Write-Banner 'ETAPA 2.5 - Verificacao de modulos legados retirados'

    $foundAny = $false

    foreach ($legacy in $RetiredList) {

        $installed = Get-InstalledModuleInfo -Name $legacy.Name

        if ($installed) {
            $foundAny = $true
            Write-Log ("Modulo RETIRADO detectado: {0} (v{1})" -f $legacy.Name, $installed.RawVersion) -Level WARN
            Write-Log ("  -> Retirado pela Microsoft em {0}. Substituto: {1}" -f `
                        $legacy.RetiredOn, $legacy.Replacement) -Level WARN
            Write-Log ("  -> Recomendado remover: Uninstall-Module -Name {0} -AllVersions" -f $legacy.Name) -Level INFO
        }
        else {
            Write-Log "Modulo legado '$($legacy.Name)' nao instalado (OK)." -Level OK
        }
    }

    if (-not $foundAny) {
        Write-Log 'Nenhum modulo legado retirado encontrado na maquina.' -Level OK
    }
    else {
        Write-Host ''
        Write-Host 'Os modulos acima nao existem mais no PowerShell Gallery e nao'   -ForegroundColor Yellow
        Write-Host 'serao processados. Eles continuam ocupando espaco e podem'       -ForegroundColor Yellow
        Write-Host 'gerar conflitos. Considere remove-los apos migrar seus scripts.' -ForegroundColor Yellow
    }
}

# ============================================================================
#  ETAPA 3 - ANALISE DE MODULOS (LOCAL x ONLINE)
# ============================================================================

function Get-ModuleStatus {
    [CmdletBinding()]
    param([string[]] $ModuleNames)

    Write-Banner 'ETAPA 3 - Analise de versoes (local x PowerShell Gallery)'

    $report = @()

    foreach ($name in $ModuleNames) {

        Write-Log "Analisando: $name" -Level STEP

        # Versao local (deteccao robusta: Get-InstalledModule + fallback)
        $local = Get-InstalledModuleInfo -Name $name
        $localVersion = if ($local) { $local.Version } else { $null }

        # Versao online no PSGallery
        $onlineVersion = $null
        try {
            $online = Find-Module -Name $name `
                                   -Repository $TrustedRepository `
                                   -ErrorAction Stop
            $onlineVersion = $online.Version
        }
        catch {
            Write-Log "Nao foi possivel consultar '$name' no PSGallery: $($_.Exception.Message)" -Level WARN
        }

        # Determina a situacao e a acao recomendada
        if (-not $onlineVersion) {
            $state  = 'Indisponivel'
            $action = 'Ignorar'
        }
        elseif (-not $localVersion) {
            $state  = 'Nao instalado'
            $action = 'Instalar'
        }
        elseif ([version]$localVersion -lt [version]$onlineVersion) {
            $state  = 'Desatualizado'
            $action = 'Atualizar'
        }
        else {
            $state  = 'Atualizado'
            $action = 'Manter'
        }

        $entry = [pscustomobject]@{
            Module        = $name
            LocalVersion  = if ($localVersion)  { $localVersion.ToString() }  else { '-' }
            OnlineVersion = if ($onlineVersion) { $onlineVersion.ToString() } else { '-' }
            State         = $state
            Action        = $action
        }

        $report += $entry

        Write-Log ("  Local: {0} | Online: {1} | Estado: {2}" -f `
                    $entry.LocalVersion, $entry.OnlineVersion, $entry.State) -Level INFO
    }

    # Tabela resumo da analise
    Write-Host ''
    $report | Format-Table -AutoSize Module, LocalVersion, OnlineVersion, State, Action |
        Out-String | Write-Host

    return $report
}

# ============================================================================
#  ETAPA 4 - DECISAO DO USUARIO E EXECUCAO
# ============================================================================

function Invoke-ModuleActions {
    [CmdletBinding()]
    param(
        [object[]] $Report,
        [string]   $Scope,
        [switch]   $AutoConfirm
    )

    Write-Banner 'ETAPA 4 - Instalacao / atualizacao dos modulos'

    # Considera apenas modulos que requerem acao
    $actionable = $Report | Where-Object { $_.Action -in @('Instalar', 'Atualizar') }

    if (-not $actionable -or $actionable.Count -eq 0) {
        Write-Log 'Todos os modulos disponiveis ja estao atualizados. Nada a fazer.' -Level OK
        return $Report
    }

    # ------------------------------------------------------------------
    #  Lista visual dos modulos pendentes (um por linha, com cores)
    # ------------------------------------------------------------------
    Write-Host ''
    Write-Host ("Foram encontrados {0} modulo(s) que precisam de acao:" -f $actionable.Count) -ForegroundColor White
    Write-Host ''

    $idx = 0
    foreach ($pend in $actionable) {
        $idx++

        # Cor conforme a acao: Instalar (Cyan) | Atualizar (Yellow)
        if ($pend.Action -eq 'Instalar') {
            $actionColor = 'Cyan'
            $actionLabel = 'INSTALAR'
        }
        else {
            $actionColor = 'Yellow'
            $actionLabel = 'ATUALIZAR'
        }

        # Numero + nome do modulo
        Write-Host ("  {0,2}. " -f $idx) -ForegroundColor DarkGray -NoNewline
        Write-Host ("{0,-42}" -f $pend.Module) -ForegroundColor White -NoNewline

        # Acao destacada
        Write-Host ("[{0}]" -f $actionLabel) -ForegroundColor $actionColor -NoNewline

        # Versoes (local -> online)
        Write-Host ("  {0} -> {1}" -f $pend.LocalVersion, $pend.OnlineVersion) -ForegroundColor DarkGray
    }

    # ------------------------------------------------------------------
    #  Menu de opcoes (uma abaixo da outra, com cores distintas)
    # ------------------------------------------------------------------
    $applyAll = $AutoConfirm

    if (-not $AutoConfirm) {
        $menuChoice = $null

        while ($menuChoice -notin @('T', 'I', 'X')) {
            Write-Host ''
            Write-Host 'O que deseja fazer?' -ForegroundColor White
            Write-Host ''
            Write-Host '  [T] ' -ForegroundColor Green     -NoNewline
            Write-Host 'Aplicar a TODOS de uma vez (instalar/atualizar tudo)' -ForegroundColor Green
            Write-Host '  [I] ' -ForegroundColor Cyan      -NoNewline
            Write-Host 'Decidir Individualmente (um modulo por vez)'          -ForegroundColor Cyan
            Write-Host '  [X] ' -ForegroundColor Red       -NoNewline
            Write-Host 'Sair sem fazer nada (finalizar agora)'                -ForegroundColor Red
            Write-Host ''

            $menuChoice = (Read-Host 'Escolha (T/I/X)').Trim().ToUpper()

            if ($menuChoice -notin @('T', 'I', 'X')) {
                Write-Host 'Opcao invalida. Digite T, I ou X.' -ForegroundColor Red
            }
        }

        switch ($menuChoice) {
            'T' {
                Write-Log 'Modo selecionado: aplicar a todos.' -Level OK
                $applyAll = $true
            }
            'I' {
                Write-Log 'Modo selecionado: decidir individualmente.' -Level OK
                $applyAll = $false
            }
            'X' {
                Write-Host ''
                Write-Log 'Saida solicitada pelo usuario. Nenhuma alteracao foi feita.' -Level WARN

                # Marca todos como nao processados e retorna sem agir
                foreach ($item in $Report) {
                    if (-not ($item.PSObject.Properties.Name -contains 'Result')) {
                        $resultValue = if ($item.Action -in @('Instalar', 'Atualizar')) { 'Ignorado' } else { 'Mantido' }
                        $item | Add-Member -NotePropertyName 'Result' -NotePropertyValue $resultValue -Force
                    }
                }
                return $Report
            }
        }
    }

    foreach ($item in $Report) {

        if ($item.Action -notin @('Instalar', 'Atualizar')) {
            $item | Add-Member -NotePropertyName 'Result' -NotePropertyValue 'Mantido' -Force
            continue
        }

        # Decisao individual quando nao for "aplicar a todos"
        $proceed = $true
        if (-not $applyAll) {
            $verb = $item.Action.ToUpper()

            Write-Host ''
            Write-Host ('-' * 50) -ForegroundColor DarkGray
            Write-Host ("Modulo : {0}" -f $item.Module)        -ForegroundColor White
            Write-Host ("Estado : {0}" -f $item.State)         -ForegroundColor Gray
            Write-Host ("Local  : {0}" -f $item.LocalVersion)  -ForegroundColor Gray
            Write-Host ("Online : {0}" -f $item.OnlineVersion) -ForegroundColor Gray
            Write-Host ("Acao   : {0}" -f $verb)               -ForegroundColor Cyan
            Write-Host ''
            Write-Host '  [S] ' -ForegroundColor Green -NoNewline
            Write-Host ("Sim, {0} este modulo" -f $verb.ToLower()) -ForegroundColor Green
            Write-Host '  [N] ' -ForegroundColor Yellow -NoNewline
            Write-Host 'Nao, pular este modulo'                    -ForegroundColor Yellow
            Write-Host '  [X] ' -ForegroundColor Red -NoNewline
            Write-Host 'Sair (finalizar sem processar os restantes)' -ForegroundColor Red

            $choice = $null
            while ($choice -notin @('S', 'N', 'X')) {
                $choice = (Read-Host 'Escolha (S/N/X)').Trim().ToUpper()
                if ($choice -notin @('S', 'N', 'X')) {
                    Write-Host 'Opcao invalida. Digite S, N ou X.' -ForegroundColor Red
                }
            }

            if ($choice -eq 'X') {
                Write-Host ''
                Write-Log 'Saida solicitada. Modulos restantes nao serao processados.' -Level WARN

                # Marca o atual e os restantes como ignorados
                foreach ($remaining in $Report) {
                    if (-not ($remaining.PSObject.Properties.Name -contains 'Result')) {
                        $resultValue = if ($remaining.Action -in @('Instalar', 'Atualizar')) { 'Ignorado' } else { 'Mantido' }
                        $remaining | Add-Member -NotePropertyName 'Result' -NotePropertyValue $resultValue -Force
                    }
                }
                return $Report
            }

            $proceed = ($choice -eq 'S')
        }

        if (-not $proceed) {
            Write-Log "Modulo '$($item.Module)' ignorado pelo usuario." -Level INFO
            $item | Add-Member -NotePropertyName 'Result' -NotePropertyValue 'Ignorado' -Force
            continue
        }

        # Execucao segura: sempre a partir do repositorio confiavel
        try {
            if ($item.Action -eq 'Instalar') {
                Write-Log "Instalando '$($item.Module)'..." -Level STEP
                Install-Module -Name $item.Module `
                               -Repository $TrustedRepository `
                               -Scope $Scope `
                               -Force `
                               -AllowClobber `
                               -ErrorAction Stop
                Write-Log "'$($item.Module)' instalado (v$($item.OnlineVersion))." -Level OK
                $item | Add-Member -NotePropertyName 'Result' -NotePropertyValue 'Instalado' -Force
            }
            else {
                Write-Log "Atualizando '$($item.Module)'..." -Level STEP
                try {
                    # Caminho preferencial
                    Update-Module -Name $item.Module -Force -ErrorAction Stop
                }
                catch {
                    # Fallback: alguns modulos antigos nao foram instalados
                    # via PowerShellGet e nao suportam Update-Module.
                    Write-Log "Update-Module falhou, reinstalando via Install-Module..." -Level WARN
                    Install-Module -Name $item.Module `
                                   -Repository $TrustedRepository `
                                   -Scope $Scope `
                                   -Force `
                                   -AllowClobber `
                                   -ErrorAction Stop
                }
                Write-Log "'$($item.Module)' atualizado (v$($item.OnlineVersion))." -Level OK
                $item | Add-Member -NotePropertyName 'Result' -NotePropertyValue 'Atualizado' -Force
            }
        }
        catch {
            Write-Log "Falha ao processar '$($item.Module)': $($_.Exception.Message)" -Level ERROR
            $item | Add-Member -NotePropertyName 'Result' -NotePropertyValue 'Falha' -Force
        }
    }

    return $Report
}

# ============================================================================
#  MODO ALTERNATIVO - DESINSTALACAO DE MODULOS
# ============================================================================

function Invoke-ModuleUninstall {
    [CmdletBinding()]
    param(
        [string[]] $CandidateModules,
        [object[]] $RetiredList,
        [switch]   $AutoConfirm
    )

    Write-Banner 'MODO DESINSTALACAO - Remocao de modulos instalados'

    # Junta a lista administrativa + os legados retirados como candidatos
    $allNames = @()
    $allNames += $CandidateModules
    $allNames += ($RetiredList | ForEach-Object { $_.Name })
    $allNames  = $allNames | Select-Object -Unique

    # Descobre o que esta REALMENTE instalado
    $installedList = @()
    foreach ($name in $allNames) {
        $info = Get-InstalledModuleInfo -Name $name
        if ($info) {
            $isRetired = [bool]($RetiredList | Where-Object { $_.Name -eq $name })
            $installedList += [pscustomobject]@{
                Module  = $name
                Version = $info.RawVersion
                Retired = $isRetired
            }
        }
    }

    if ($installedList.Count -eq 0) {
        Write-Log 'Nenhum modulo gerenciavel esta instalado nesta maquina.' -Level OK
        return
    }

    # Lista visual dos modulos instalados
    Write-Host ''
    Write-Host ("Modulos instalados detectados ({0}):" -f $installedList.Count) -ForegroundColor White
    Write-Host ''

    $idx = 0
    foreach ($m in $installedList) {
        $idx++
        Write-Host ("  {0,2}. " -f $idx) -ForegroundColor DarkGray -NoNewline
        Write-Host ("{0,-42}" -f $m.Module) -ForegroundColor White -NoNewline
        Write-Host ("v{0}" -f $m.Version) -ForegroundColor DarkGray -NoNewline
        if ($m.Retired) {
            Write-Host '  [RETIRADO]' -ForegroundColor Red
        }
        else {
            Write-Host ''
        }
    }

    # Menu de selecao
    Write-Host ''
    Write-Host 'O que deseja desinstalar?' -ForegroundColor White
    Write-Host ''
    Write-Host '  [N] ' -ForegroundColor Cyan -NoNewline
    Write-Host 'Escolher pelo Numero (ex.: 1,3,5)'         -ForegroundColor Cyan
    Write-Host '  [R] ' -ForegroundColor Yellow -NoNewline
    Write-Host 'Somente os modulos RETIRADOS (legados)'    -ForegroundColor Yellow
    Write-Host '  [T] ' -ForegroundColor Red -NoNewline
    Write-Host 'TODOS os modulos listados (cuidado!)'      -ForegroundColor Red
    Write-Host '  [X] ' -ForegroundColor Green -NoNewline
    Write-Host 'Sair sem desinstalar nada'                 -ForegroundColor Green
    Write-Host ''

    $sel = (Read-Host 'Escolha (N/R/T/X)').Trim().ToUpper()

    $targets = @()
    switch ($sel) {
        'X' {
            Write-Log 'Saida solicitada. Nenhuma desinstalacao realizada.' -Level WARN
            return
        }
        'R' {
            $targets = $installedList | Where-Object { $_.Retired }
            if ($targets.Count -eq 0) {
                Write-Log 'Nenhum modulo retirado instalado. Nada a fazer.' -Level OK
                return
            }
        }
        'T' {
            $targets = $installedList
        }
        'N' {
            $raw = Read-Host 'Digite os numeros separados por virgula (ex.: 1,3,5)'
            $nums = $raw -split '[,\s]+' | Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int]$_ }
            $targets = foreach ($n in $nums) {
                if ($n -ge 1 -and $n -le $installedList.Count) {
                    $installedList[$n - 1]
                }
            }
            if (-not $targets -or @($targets).Count -eq 0) {
                Write-Log 'Nenhum numero valido informado. Cancelando.' -Level WARN
                return
            }
        }
        default {
            Write-Log 'Opcao invalida. Cancelando desinstalacao.' -Level WARN
            return
        }
    }

    $targets = @($targets)

    # Confirmacao final (dupla checagem por seguranca)
    Write-Host ''
    Write-Host 'Os seguintes modulos serao DESINSTALADOS:' -ForegroundColor Red
    foreach ($t in $targets) {
        Write-Host ("  - {0} (v{1})" -f $t.Module, $t.Version) -ForegroundColor Yellow
    }

    $confirm = 'S'
    if (-not $AutoConfirm) {
        Write-Host ''
        $confirm = (Read-Host 'Confirma a desinstalacao? Digite SIM para prosseguir').Trim().ToUpper()
    }

    if ($confirm -ne 'SIM' -and -not $AutoConfirm) {
        Write-Log 'Confirmacao nao recebida (esperado: SIM). Operacao cancelada.' -Level WARN
        return
    }

    # Execucao da desinstalacao
    $removed = 0
    $failed  = 0

    foreach ($t in $targets) {
        try {
            Write-Log "Desinstalando '$($t.Module)' (todas as versoes)..." -Level STEP

            # Remove da sessao atual, se carregado, para evitar arquivos em uso
            Remove-Module -Name $t.Module -Force -ErrorAction SilentlyContinue

            $uninstalledOk = $false

            # Metodo 1: Uninstall-Module (PowerShellGet) - todas as versoes
            try {
                Uninstall-Module -Name $t.Module -AllVersions -Force -ErrorAction Stop
                $uninstalledOk = $true
            }
            catch {
                Write-Log "Uninstall-Module falhou: $($_.Exception.Message)" -Level WARN
            }

            # Loop adicional: alguns modulos exigem varias passagens
            $stillThere = Get-InstalledModuleInfo -Name $t.Module
            $attempts   = 0
            while ($stillThere -and $attempts -lt 5) {
                $attempts++
                try {
                    Uninstall-Module -Name $t.Module -RequiredVersion $stillThere.RawVersion -Force -ErrorAction Stop
                }
                catch {
                    break
                }
                $stillThere = Get-InstalledModuleInfo -Name $t.Module
            }

            $finalCheck = Get-InstalledModuleInfo -Name $t.Module
            if (-not $finalCheck) {
                Write-Log "'$($t.Module)' desinstalado com sucesso." -Level OK
                $removed++
            }
            else {
                Write-Log "'$($t.Module)' ainda presente (v$($finalCheck.RawVersion)). Pode ter sido instalado fora do PowerShellGet (MSI/manual) - remova manualmente." -Level WARN
                $failed++
            }
        }
        catch {
            Write-Log "Falha ao desinstalar '$($t.Module)': $($_.Exception.Message)" -Level ERROR
            $failed++
        }
    }

    Write-Banner 'RESUMO DA DESINSTALACAO'
    Write-Host ''
    Write-Host ("Removidos: {0}" -f $removed) -ForegroundColor Green
    Write-Host ("Falhas   : {0}" -f $failed)  -ForegroundColor Red
    Write-Host ''
    if ($failed -gt 0) {
        Write-Host 'Modulos que falharam podem estar em uso ou instalados via MSI.' -ForegroundColor Yellow
        Write-Host 'Feche todas as janelas do PowerShell e tente novamente como Administrador.' -ForegroundColor Yellow
    }
}

# ============================================================================
#  ETAPA 5 - RESUMO FINAL
# ============================================================================

function Show-Summary {
    [CmdletBinding()]
    param([object[]] $Report)

    Write-Banner 'RESUMO FINAL'

    # Garante que todos tenham a propriedade Result
    foreach ($item in $Report) {
        if (-not ($item.PSObject.Properties.Name -contains 'Result')) {
            $item | Add-Member -NotePropertyName 'Result' -NotePropertyValue 'Mantido' -Force
        }
    }

    $Report |
        Sort-Object Result, Module |
        Format-Table -AutoSize Module, State, LocalVersion, OnlineVersion, Result |
        Out-String | Write-Host

    # Contadores
    $installed = @($Report | Where-Object { $_.Result -eq 'Instalado'  }).Count
    $updated   = @($Report | Where-Object { $_.Result -eq 'Atualizado' }).Count
    $kept      = @($Report | Where-Object { $_.Result -eq 'Mantido'    }).Count
    $skipped   = @($Report | Where-Object { $_.Result -eq 'Ignorado'   }).Count
    $failed    = @($Report | Where-Object { $_.Result -eq 'Falha'      }).Count

    Write-Host ''
    Write-Host ("Instalados : {0}" -f $installed) -ForegroundColor Green
    Write-Host ("Atualizados: {0}" -f $updated)   -ForegroundColor Green
    Write-Host ("Mantidos   : {0}" -f $kept)      -ForegroundColor Gray
    Write-Host ("Ignorados  : {0}" -f $skipped)   -ForegroundColor Yellow
    Write-Host ("Falhas     : {0}" -f $failed)    -ForegroundColor Red
    Write-Host ''

    if ($failed -gt 0) {
        Write-Host 'Alguns modulos falharam. Reabra o PowerShell como Administrador e tente novamente.' -ForegroundColor Yellow
    }
}

# ============================================================================
#  EXECUCAO PRINCIPAL
# ============================================================================

function Invoke-Main {
    [CmdletBinding()]
    param()

    try {
        # Apresentacao inicial (ASCII art)
        Show-Splash

        Write-Banner 'GERENCIADOR DE MODULOS ADMINISTRATIVOS MICROSOFT'

        # 1. Ambiente
        $env = Test-Environment

        # 2. Infraestrutura de pacotes (PowerShellGet / NuGet / PSGallery)
        Initialize-PackageInfrastructure -Scope $env.InstallScope -AutoConfirm:$AutoConfirmAll

        # 2.5 Deteccao de modulos legados retirados (nao processaveis)
        Test-RetiredModules -RetiredList $RetiredModules

        # ----------------------------------------------------------------
        #  MENU DE MODO DE OPERACAO
        # ----------------------------------------------------------------
        $mode = 'M'   # padrao para execucao automatica (-AutoConfirmAll)

        if (-not $AutoConfirmAll) {
            $mode = $null
            while ($mode -notin @('M', 'D', 'X')) {
                Write-Banner 'MENU PRINCIPAL'
                Write-Host ''
                Write-Host '  [M] ' -ForegroundColor Green -NoNewline
                Write-Host 'Gerenciar (instalar / atualizar modulos)' -ForegroundColor Green
                Write-Host '  [D] ' -ForegroundColor Yellow -NoNewline
                Write-Host 'Desinstalar modulos instalados'           -ForegroundColor Yellow
                Write-Host '  [X] ' -ForegroundColor Red -NoNewline
                Write-Host 'Sair (finalizar sem fazer nada)'          -ForegroundColor Red
                Write-Host ''
                $mode = (Read-Host 'Escolha (M/D/X)').Trim().ToUpper()
                if ($mode -notin @('M', 'D', 'X')) {
                    Write-Host 'Opcao invalida. Digite M, D ou X.' -ForegroundColor Red
                }
            }
        }

        switch ($mode) {

            'X' {
                Write-Log 'Saida solicitada pelo usuario. Nenhuma acao executada.' -Level WARN
            }

            'D' {
                # Modo desinstalacao
                Invoke-ModuleUninstall -CandidateModules $AdminModules `
                                        -RetiredList $RetiredModules `
                                        -AutoConfirm:$AutoConfirmAll
                Write-Log 'Processo concluido.' -Level OK
            }

            'M' {
                # Modo gerenciamento (instalar / atualizar)

                # 3. Analise de versoes
                $report = Get-ModuleStatus -ModuleNames $AdminModules

                # 4. Decisao e execucao
                $report = Invoke-ModuleActions -Report $report `
                                                -Scope $env.InstallScope `
                                                -AutoConfirm:$AutoConfirmAll

                # 5. Resumo final
                Show-Summary -Report $report

                Write-Log 'Processo concluido.' -Level OK
            }
        }
    }
    catch {
        Write-Log "EXECUCAO INTERROMPIDA: $($_.Exception.Message)" -Level ERROR
        Write-Host ''
        Write-Host 'O script foi encerrado devido a um erro. Verifique as mensagens acima.' -ForegroundColor Red
    }
}

# ----------------------------------------------------------------------------
#  PONTO DE ENTRADA
# ----------------------------------------------------------------------------
Invoke-Main
