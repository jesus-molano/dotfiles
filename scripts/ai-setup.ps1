# Native Windows deployment: no Stow, symlinks, WSL or administrator required.
[CmdletBinding()]
param(
    [ValidateSet('plan', 'apply', 'check', 'rollback')][string]$Mode = 'plan',
    [ValidateSet('both', 'claude', 'codex')][string]$Clients = 'claude',
    [string]$TargetHome = $env:USERPROFILE,
    [string]$Backup
)
$ErrorActionPreference = 'Stop'
$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python) { throw 'Instala Python 3.11 o posterior y reinicia la terminal.' }
& $python.Source -c 'import sys; sys.exit(0 if sys.version_info >= (3,11) else 1)'
if ($LASTEXITCODE -ne 0) { throw 'Se necesita Python 3.11 o posterior.' }
$arguments = @((Join-Path $PSScriptRoot 'sync-ai.py'), $Mode,
    '--platform', 'windows', '--clients', $Clients, '--home', $TargetHome)
if ($Backup) { $arguments += @('--backup', $Backup) }
& $python.Source @arguments
exit $LASTEXITCODE
