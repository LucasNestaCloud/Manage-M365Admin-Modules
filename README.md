# Manage M365 Admin Modules

> Gerenciador de módulos PowerShell para administradores Microsoft 365 / Entra ID
> **Detecta · Instala · Atualiza · Desinstala** os principais módulos administrativos — tudo a partir de uma única ferramenta interativa.

<p align="center">
  <!-- Substitua pelo print da apresentação (Apresentacao.png) -->
  <img src="docs/img/apresentacao.png" alt="Tela de apresentação do script" width="800">
</p>

---

## Por que este script existe?

Todo administrador Microsoft 365 / Entra ID já passou por isso:

- Pegar uma máquina nova ou de outra pessoa e **não ter os módulos principais instalados**.
- Não saber se os módulos que você já tem estão **na última versão**.
- Precisar **limpar módulos legados** (AzureAD, MSOnline) já retirados pela Microsoft.
- Ter que lembrar de cor os nomes corretos dos módulos e os comandos `Install-Module` / `Update-Module` / `Uninstall-Module`.

Este script resolve tudo isso em um fluxo único, seguro e interativo — sempre a partir da fonte oficial (**PowerShell Gallery**).

---

## Recursos

- ✅ **Detecção robusta** de módulos instalados (usa `Get-InstalledModule` com fallback para `Get-Module -ListAvailable`, contornando o bug conhecido em que o PnP.PowerShell "some" da listagem).
- ✅ **Comparação local x online** com a versão mais recente publicada no PowerShell Gallery.
- ✅ **Instalação e atualização** com confirmação por módulo ou em lote.
- ✅ **Desinstalação** de módulos (por número, só os legados retirados, ou todos) com dupla confirmação de segurança.
- ✅ **Detecção de módulos legados retirados** (AzureAD, AzureADPreview, MSOnline) com recomendação do substituto oficial.
- ✅ **Validação de ambiente**: versão do PowerShell, TLS 1.2, escopo automático (AllUsers se Administrador, senão CurrentUser).
- ✅ **Origem confiável garantida**: todas as operações usam exclusivamente o repositório `PSGallery`.
- ✅ **Tratamento de erros** com `try/catch` — falhas individuais não interrompem o lote.
- ✅ **Interface amigável**: logs coloridos com timestamp, menus numerados e opção de sair em qualquer etapa.
- ✅ **Modo não interativo** com o parâmetro `-AutoConfirmAll` (ideal para automação).

---

## Módulos gerenciados

| Categoria | Módulos |
|---|---|
| **Base / PackageManagement** | `PackageManagement`, `PowerShellGet` |
| **Microsoft Graph** | `Microsoft.Graph`, `Microsoft.Graph.Beta` |
| **Microsoft Entra** | `Microsoft.Entra`, `Microsoft.Entra.Beta` |
| **Exchange / SharePoint / Teams** | `ExchangeOnlineManagement`, `Microsoft.Online.SharePoint.PowerShell`, `PnP.PowerShell`, `MicrosoftTeams` |
| **Azure** | `Az` |
| **Intune / Autopilot** | `WindowsAutopilotIntune` |
| **Legados (detecção/remoção)** | `AzureAD`, `AzureADPreview`, `MSOnline` |

> A lista é facilmente editável no topo do script, nos arrays `$AdminModules` e `$RetiredModules`.

---

## Requisitos

- **Windows PowerShell 5.1** ou **PowerShell 7+**
- Conexão com a internet (acesso ao PowerShell Gallery)
- Recomendado executar **como Administrador** (instala em escopo `AllUsers`; sem elevação, usa `CurrentUser` automaticamente)

---

## Como usar

1. Faça o download do arquivo `Manage-AdminModules.ps1`.
2. Abra o **PowerShell como Administrador**.
3. (Se necessário) libere a execução do script na sessão atual:
   ```powershell
   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
   ```
4. Execute:
   ```powershell
   .\Manage-AdminModules.ps1
   ```

### Modo não interativo (automação)

Aplica a ação recomendada a todos os módulos sem perguntar:

```powershell
.\Manage-AdminModules.ps1 -AutoConfirmAll
```

---

## Fluxo de execução

### 1. Apresentação

Tela inicial com identificação da ferramenta.

<p align="center">
  <!-- Substitua pelo print: Apresentacao.png -->
  <img src="docs/img/apresentacao.png" alt="Apresentação" width="800">
</p>

### 2. Validação de ambiente e menu principal

Verifica PowerShell, TLS, privilégios, prepara o PowerShellGet/PSGallery, detecta módulos legados retirados e apresenta o menu principal (**Gerenciar / Desinstalar / Sair**).

<p align="center">
  <!-- Substitua pelo print: Primeira_interação.png -->
  <img src="docs/img/primeira_interacao.png" alt="Validação de ambiente e menu principal" width="800">
</p>

### 3. Análise de versões (local x PowerShell Gallery)

Compara cada módulo instalado com a versão mais recente online e classifica como *Atualizado*, *Desatualizado* ou *Não instalado*.

<p align="center">
  <!-- Substitua pelo print: analise_de_versao.png -->
  <img src="docs/img/analise_de_versao.png" alt="Análise de versões" width="800">
</p>

### 4. Instalação / atualização

Lista os módulos pendentes com cores por ação (`[INSTALAR]` / `[ATUALIZAR]`) e permite decidir em lote ou individualmente, com opção de sair a qualquer momento.

<p align="center">
  <!-- Substitua pelo print: Atualizacoes.png -->
  <img src="docs/img/atualizacoes.png" alt="Instalação e atualização" width="800">
</p>

### 5. Resumo final

Tabela consolidada com o estado de cada módulo e contadores de instalados / atualizados / mantidos / ignorados / falhas.

<p align="center">
  <!-- Substitua pelo print: resumo_final.png -->
  <img src="docs/img/resumo_final.png" alt="Resumo final" width="800">
</p>

---

## Sobre os módulos legados retirados

A Microsoft **retirou oficialmente** os módulos `AzureAD`, `AzureADPreview` e `MSOnline` do PowerShell Gallery:

- **MSOnline** — retirado entre abril e maio de 2025.
- **AzureAD / AzureADPreview** — retirados a partir de outubro de 2025.
- **Substituto oficial:** Microsoft Graph PowerShell SDK (`Microsoft.Graph`) e Microsoft Entra PowerShell (`Microsoft.Entra`).

O script **detecta** se esses módulos ainda estão instalados na máquina, avisa que foram retirados, indica o substituto e oferece a remoção através do **modo Desinstalar**.

---

## Segurança

- Todas as operações de instalação/atualização usam **exclusivamente** o repositório oficial `PSGallery`.
- A desinstalação exige **dupla confirmação** (digitar `SIM`) antes de remover qualquer módulo.
- Nenhum dado é coletado ou enviado para terceiros — o script é totalmente local e auditável.

---

## Estrutura do repositório

```
.
├── Manage-AdminModules.ps1     # O script principal
├── README.md                   # Este arquivo
└── docs/
    └── img/                    # Capturas de tela usadas no README
        ├── apresentacao.png
        ├── primeira_interacao.png
        ├── analise_de_versao.png
        ├── atualizacoes.png
        └── resumo_final.png
```

---

## Contribuindo

Sugestões, correções e novos módulos são bem-vindos. Abra uma *issue* ou envie um *pull request*.

---

## Licença

Distribuído sob a licença MIT. Sinta-se livre para usar, modificar e compartilhar.

---

> Feito para facilitar o dia a dia de quem administra ambientes Microsoft 365 / Entra ID.
