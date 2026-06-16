# Paulos Shell

A safe, updateable PowerShell 7 dev-shell toolkit with a `paulos` command center.

This repo turns a large personal PowerShell profile into a module-based setup:

```powershell
Import-Module PaulosShell
Initialize-PaulosShell
```

The installer only adds a small managed block to your PowerShell profile and backs up everything before changing it.

## What it gives you

- `paulos -h` command center with bordered tables.
- Safe PowerShell profile installer/updater/uninstaller.
- Tool checks for `git`, `pnpm`, `rg`, `fd`, `eza`, `bat`, `lazygit`, `delta`, `gh`, `.NET`, `zoxide`, `fnm`, and more.
- Action commands:
  - `paulos delta` / `paulos delta fix`
  - `paulos font` / `paulos font download`
  - `paulos starship` / `paulos starship fix` / `paulos starship config`
  - `paulos github` / `paulos github login`
  - `paulos update`
  - `paulos wizard`
- Your current dev shortcuts: `dev`, `build`, `lt`, `grep`, `todo`, `lg`, `scripts`, `port`, `killport`, `.NET` helpers, pnpm helpers, Biome helpers, etc.

## Safe install from a cloned repo

```powershell
git clone https://github.com/dpaulos6/paulos-shell.git
cd paulos-shell
.\install.ps1
```

Open a new terminal, then run:

```powershell
paulos setup
```

## Full interactive setup

```powershell
paulos wizard
```

The wizard asks before making changes. It can:

- backup your profile
- install missing tools/modules
- configure Delta
- configure Starship
- create a default `starship.toml`
- open the Nerd Font download
- run GitHub CLI login

## One-line install later

After uploading this repo to GitHub, you can eventually install with:

```powershell
irm https://raw.githubusercontent.com/dpaulos6/paulos-shell/main/install.ps1 -OutFile install-paulos.ps1
notepad install-paulos.ps1
.\install-paulos.ps1
```

Avoid blindly piping remote scripts into `iex` unless you trust and reviewed the script.

## Useful commands

```powershell
paulos -h
paulos setup
paulos doctor
paulos wizard
paulos tools
paulos tools install
paulos modules
paulos delta
paulos delta fix
paulos font
paulos font download
paulos starship
paulos starship fix
paulos starship config
paulos github
paulos github login
paulos update
paulos repos
paulos repo-status
paulos pnpm approve
repos -NoFetch
repos -All -NoFetch
```

## Delta

Check status:

```powershell
paulos delta
```

Configure Git Delta globally:

```powershell
paulos delta fix
```

Test after:

```powershell
git diff
git show HEAD
git log -p
```

## Font

Recommended terminal font:

```text
CaskaydiaCove Nerd Font Mono
```

Open download:

```powershell
paulos font download
```

Then set it in Windows Terminal:

```text
Windows Terminal → Settings → PowerShell profile → Appearance → Font face → CaskaydiaCove Nerd Font Mono
```

## Starship

Install/update Starship profile block:

```powershell
paulos starship fix
```

Create default config:

```powershell
paulos starship config
```

Open config:

```powershell
paulos starship open
```

## Update

`paulos update self` installs the latest GitHub release into the current user module path.

Default behavior:

```powershell
paulos update self
```

This checks the latest release tag against the installed `PaulosShell.psd1` version, then prompts before downloading and replacing the installed module.

Skip the prompt:

```powershell
paulos update yes
```

Reinstall the latest release even if the installed version is already current:

```powershell
paulos update force
```

The updater is intentionally conservative:

- downloads the release archive to `~/.paulos-shell/downloads`
- extracts it to `~/.paulos-shell/staging`
- backs up the installed module to `~/.paulos-shell/backups/modules/PaulosShell.<timestamp>`
- replaces only `~/Documents/PowerShell/Modules/PaulosShell`
- leaves your PowerShell profile untouched

After a successful update, reload the current session:

```powershell
Remove-Module PaulosShell -Force -ErrorAction SilentlyContinue
. $PROFILE
```

If you prefer the repo-local updater while developing from a clone, you can still use:

```powershell
git pull
.\update.ps1 -RunDoctor
```

Update installed tools:

```powershell
paulos update winget
```

Update PowerShell modules:

```powershell
paulos update modules
```

Update current project dependencies:

```powershell
paulos update pnpm
```

## Winget

PaulosShell will be published to Windows Package Manager as `dpaulos6.shell` starting with `v0.4.0`.

Install, upgrade, or remove it with:

```powershell
winget install dpaulos6.shell
winget upgrade dpaulos6.shell
winget uninstall dpaulos6.shell
```

The Windows installer is built with Inno Setup and installs the module into the current user's PowerShell module path:

`$HOME\Documents\PowerShell\Modules\PaulosShell`

Silent installs are supported with:

```powershell
PaulosShell-0.4.0-Setup.exe /VERYSILENT /NORESTART
```

Release process:

1. Bump the module version in `src/PaulosShell/PaulosShell.psd1`.
2. Build the installer with `.\scripts\build-installer.ps1`.
3. Create the GitHub release.
4. Compute the installer SHA256 and update the winget installer manifest with `.\scripts\update-winget-manifest.ps1`.
5. Validate the package directory with `winget validate --manifest packaging\winget\dpaulos6.shell\<version>`.
6. Submit the package to [microsoft/winget-pkgs](https://github.com/microsoft/winget-pkgs).

Do not publish `v0.3.1` to winget. The winget package should begin with `v0.4.0` after the manifest-corruption fix is released.

## Uninstall

Remove managed profile blocks:

```powershell
.\uninstall.ps1
```

Also delete installed module files:

```powershell
.\uninstall.ps1 -RemoveFiles
```

## Safety model

This repo is designed to be conservative:

- It backs up your PowerShell profile before editing it.
- It uses marked managed blocks so it can update/remove only what it owns.
- It does not delete your custom profile content.
- It installs the module under your user documents folder.
- Self-updates back up the installed module before replacement.
- It does not silently configure GitHub auth or fonts.
- Starship and Delta are explicit commands.

## Rollback

If a self-update needs to be rolled back, copy the backup module directory back into the user module path.

Example:

```powershell
Remove-Item "$HOME\Documents\PowerShell\Modules\PaulosShell" -Recurse -Force
Copy-Item "$HOME\.paulos-shell\backups\modules\PaulosShell.<timestamp>" "$HOME\Documents\PowerShell\Modules\PaulosShell" -Recurse -Force
Remove-Module PaulosShell -Force -ErrorAction SilentlyContinue
. $PROFILE
```

Pick the timestamped backup you want from `~/.paulos-shell/backups/modules`.

## Custom local overrides

Create this file for private/local tweaks that should survive updates:

```powershell
~\.paulos-shell\local.ps1
```

It is dot-sourced by `Initialize-PaulosShell` if present.
