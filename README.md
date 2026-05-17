# Manage M365 Admin Modules

> Gerenciador de módulos PowerShell para administradores Microsoft 365 / Entra ID.
> Detecta, instala, atualiza e desinstala os principais módulos administrativos em um único fluxo interativo e seguro.

```
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
```

---

## O que ele resolve

Quem administra Microsoft 365 / Entra ID lida com isso com frequência: máquinas sem os módulos principais instalados, módulos desatualizados, e módulos legados que a Microsoft já retirou ainda ocupando espaço.

Este script centraliza tudo em uma única ferramenta: ele verifica o que está instalado, compara com o PowerShell Gallery, e deixa você instalar, atualizar ou desinstalar o que precisar, sempre a partir da fonte oficial.

---

## Recursos

- Detecção robusta de módulos instalados (usa `Get-InstalledModule` com fallback para `Get-Module -ListAvailable`, contornando o caso conhecido em que o PnP.PowerShell não aparece na listagem).
- Comparação entre a versão local e a mais recente publicada no PowerShell Gallery.
- Instalação e atualização com confirmação por módulo ou em lote.
- Desinstalação por número, somente os legados retirados, ou todos, com dupla confirmação de segurança.
- Detecção de módulos legados retirados (AzureAD, AzureADPreview, MSOnline) com indicação do substituto oficial.
- Validação de ambiente: versão do PowerShell, TLS 1.2, escopo automático (AllUsers se Administrador, senão CurrentUser).
- Todas as operações usam exclusivamente o repositório oficial `PSGallery`.
- Tratamento de erros com `try/catch`; falhas individuais não interrompem o lote.
- Logs coloridos com timestamp, menus numerados e opção de sair em qualquer etapa.
- Modo não interativo com o parâmetro `-AutoConfirmAll`.

---

## Módulos gerenciados

| Categoria | Módulos |
|---|---|
| Base | `PackageManagement`, `PowerShellGet` |
| Microsoft Graph | `Microsoft.Graph`, `Microsoft.Graph.Beta` |
| Microsoft Entra | `Microsoft.Entra`, `Microsoft.Entra.Beta` |
| Exchange / SharePoint / Teams | `ExchangeOnlineManagement`, `Microsoft.Online.SharePoint.PowerShell`, `PnP.PowerShell`, `MicrosoftTeams` |
| Azure | `Az` |
| Intune / Autopilot | `WindowsAutopilotIntune` |
| Legados (detecção/remoção) | `AzureAD`, `AzureADPreview`, `MSOnline` |

A lista é editável no topo do script, nos arrays `$AdminModules` e `$RetiredModules`.

---

## Requisitos

- Windows PowerShell 5.1 ou PowerShell 7+
- Conexão com a internet (acesso ao PowerShell Gallery)
- Recomendado executar como Administrador (instala em escopo `AllUsers`; sem elevação, usa `CurrentUser` automaticamente)

---

## Como usar

1. Faça o download do arquivo `Manage-AdminModules.ps1`.
2. Abra o PowerShell como Administrador.
3. Se necessário, libere a execução na sessão atual:
   ```powershell
   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
   ```
4. Execute:
   ```powershell
   .\Manage-AdminModules.ps1
   ```

Modo não interativo (aplica a ação recomendada a todos os módulos):

```powershell
.\Manage-AdminModules.ps1 -AutoConfirmAll
```

---

## Fluxo de execução

### 1. Validação de ambiente e detecção de legados

Ao iniciar, o script valida o ambiente, prepara o PowerShellGet/PSGallery e detecta módulos legados já retirados pela Microsoft.

```text
========================================================================
  ETAPA 1 - Validacao do ambiente
========================================================================
[ INFO  ] Versao do PowerShell: 5.1.26100.8457
[  OK   ] Protocolo TLS 1.2 habilitado para a sessao.
[  OK   ] Sessao elevada (Administrador). Escopo de instalacao: AllUsers.
[ INFO  ] Politica de execucao atual: Bypass

========================================================================
  ETAPA 2 - Preparacao do PowerShellGet e do PSGallery
========================================================================
[  OK   ] Provedor NuGet presente (v3.0.0.1).
[  OK   ] PowerShellGet presente (v2.2.5).
[  OK   ] Repositorio 'PSGallery' ja e confiavel.

========================================================================
  ETAPA 2.5 - Verificacao de modulos legados retirados
========================================================================
[ WARN  ] Modulo RETIRADO detectado: AzureAD (v2.0.2.182)
[ WARN  ]   -> Retirado pela Microsoft em Out/2025. Substituto: Microsoft.Graph / Microsoft.Entra
[ INFO  ]   -> Recomendado remover: Uninstall-Module -Name AzureAD -AllVersions
[  OK   ] Modulo legado 'AzureADPreview' nao instalado (OK).
[ WARN  ] Modulo RETIRADO detectado: MSOnline (v1.1.183.81)
[ WARN  ]   -> Retirado pela Microsoft em Mai/2025. Substituto: Microsoft.Graph / Microsoft.Entra
[ INFO  ]   -> Recomendado remover: Uninstall-Module -Name MSOnline -AllVersions
```

### 2. Menu principal

```text
========================================================================
  MENU PRINCIPAL
========================================================================

  [M] Gerenciar (instalar / atualizar modulos)
  [D] Desinstalar modulos instalados
  [X] Sair (finalizar sem fazer nada)

Escolha (M/D/X): M
```

### 3. Análise de versões (local x PowerShell Gallery)

O script compara cada módulo instalado com a versão mais recente online e classifica como Atualizado, Desatualizado ou Não instalado.

```text
Module                                  LocalVersion     OnlineVersion    State          Action
------                                  ------------     -------------    -----          ------
PackageManagement                       1.4.8.1          1.4.8.1          Atualizado     Manter
PowerShellGet                           2.2.5            2.2.5            Atualizado     Manter
Microsoft.Graph                         2.26.0           2.37.0           Desatualizado  Atualizar
Microsoft.Graph.Beta                    2.24.0           2.37.0           Desatualizado  Atualizar
Microsoft.Entra                         -                1.2.0            Nao instalado  Instalar
Microsoft.Entra.Beta                    -                1.2.0            Nao instalado  Instalar
ExchangeOnlineManagement                3.9.2            3.9.2            Atualizado     Manter
Microsoft.Online.SharePoint.PowerShell  16.0.27215.12000 16.0.27215.12000 Atualizado     Manter
PnP.PowerShell                          3.2.0            3.2.0            Atualizado     Manter
MicrosoftTeams                          7.1.0            7.7.0            Desatualizado  Atualizar
Az                                      -                15.6.1           Nao instalado  Instalar
WindowsAutopilotIntune                  -                5.7              Nao instalado  Instalar
```

### 4. Instalação / atualização

Os módulos pendentes são listados com a ação destacada, e você pode decidir em lote ou individualmente.

```text
Foram encontrados 7 modulo(s) que precisam de acao:

   1. Microsoft.Graph                            [ATUALIZAR]  2.26.0 -> 2.37.0
   2. Microsoft.Graph.Beta                       [ATUALIZAR]  2.24.0 -> 2.37.0
   3. Microsoft.Entra                            [INSTALAR]   - -> 1.2.0
   4. Microsoft.Entra.Beta                       [INSTALAR]   - -> 1.2.0
   5. MicrosoftTeams                             [ATUALIZAR]  7.1.0 -> 7.7.0
   6. Az                                         [INSTALAR]   - -> 15.6.1
   7. WindowsAutopilotIntune                     [INSTALAR]   - -> 5.7

O que deseja fazer?

  [T] Aplicar a TODOS de uma vez (instalar/atualizar tudo)
  [I] Decidir Individualmente (um modulo por vez)
  [X] Sair sem fazer nada (finalizar agora)

Escolha (T/I/X): I
```

Na decisão individual, cada módulo é apresentado com suas versões e as opções:

```text
--------------------------------------------------
Modulo : Microsoft.Graph
Estado : Desatualizado
Local  : 2.26.0
Online : 2.37.0
Acao   : ATUALIZAR

  [S] Sim, atualizar este modulo
  [N] Nao, pular este modulo
  [X] Sair (finalizar sem processar os restantes)

Escolha (S/N/X):
```

### 5. Resumo final

Ao final, uma tabela consolida o estado de cada módulo, seguida dos contadores.

```text
========================================================================
  RESUMO FINAL
========================================================================

Module                                  State          LocalVersion     OnlineVersion    Result
------                                  -----          ------------     -------------    ------
Az                                      Nao instalado  -                15.6.1           Ignorado
Microsoft.Entra                         Nao instalado  -                1.2.0            Ignorado
Microsoft.Entra.Beta                    Nao instalado  -                1.2.0            Ignorado
Microsoft.Graph                         Desatualizado  2.26.0           2.37.0           Ignorado
Microsoft.Graph.Beta                    Desatualizado  2.24.0           2.37.0           Ignorado
MicrosoftTeams                          Desatualizado  7.1.0            7.7.0            Ignorado
WindowsAutopilotIntune                  Nao instalado  -                5.7              Ignorado
ExchangeOnlineManagement                Atualizado     3.9.2            3.9.2            Mantido
Microsoft.Online.SharePoint.PowerShell  Atualizado     16.0.27215.12000 16.0.27215.12000 Mantido
PackageManagement                       Atualizado     1.4.8.1          1.4.8.1          Mantido
PnP.PowerShell                          Atualizado     3.2.0            3.2.0            Mantido
PowerShellGet                           Atualizado     2.2.5            2.2.5            Mantido

Instalados : 0
Atualizados: 0
Mantidos   : 5
Ignorados  : 7
Falhas     : 0

[  OK   ] Processo concluido.
```

---

## Modo desinstalação

Escolhendo `[D]` no menu principal, o script lista os módulos realmente instalados (marcando os retirados) e oferece a remoção por número, somente os legados, ou todos.

```text
========================================================================
  MODO DESINSTALACAO - Remocao de modulos instalados
========================================================================

Modulos instalados detectados (7):

   1. AzureAD                                    v2.0.2.182  [RETIRADO]
   2. ExchangeOnlineManagement                   v3.9.2
   3. Microsoft.Graph                            v2.26.0
   4. MSOnline                                   v1.1.183.81  [RETIRADO]
   5. PackageManagement                          v1.4.8.1
   6. PnP.PowerShell                             v3.2.0
   7. PowerShellGet                              v2.2.5

O que deseja desinstalar?

  [N] Escolher pelo Numero (ex.: 1,3,5)
  [R] Somente os modulos RETIRADOS (legados)
  [T] TODOS os modulos listados (cuidado!)
  [X] Sair sem desinstalar nada

Escolha (N/R/T/X):
```

A desinstalação exige confirmação explícita (digitar `SIM`) antes de remover qualquer módulo.

---

## Sobre os módulos legados retirados

A Microsoft retirou oficialmente os módulos `AzureAD`, `AzureADPreview` e `MSOnline` do PowerShell Gallery:

- MSOnline: retirado entre abril e maio de 2025.
- AzureAD / AzureADPreview: retirados a partir de outubro de 2025.
- Substituto oficial: Microsoft Graph PowerShell SDK (`Microsoft.Graph`) e Microsoft Entra PowerShell (`Microsoft.Entra`).

O script detecta se esses módulos ainda estão instalados, avisa que foram retirados, indica o substituto e permite a remoção pelo modo Desinstalar.

---

## Segurança

- Todas as operações de instalação/atualização usam exclusivamente o repositório oficial `PSGallery`.
- A desinstalação exige dupla confirmação antes de remover qualquer módulo.
- Nenhum dado é coletado ou enviado para terceiros. O script é totalmente local e auditável.

---

## Licença

Distribuído sob a licença MIT. Sinta-se livre para usar, modificar e compartilhar.
