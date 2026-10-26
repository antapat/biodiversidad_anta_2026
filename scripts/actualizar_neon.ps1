param(
  [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$Rscript = Get-Command Rscript.exe -ErrorAction SilentlyContinue

if (-not $Rscript) {
  $Candidates = @(
    'C:\Program Files\R\R-4.6.1\bin\Rscript.exe',
    'C:\Program Files\R\R-4.5.2\bin\Rscript.exe',
    'C:\Program Files\R\R-4.5.1\bin\Rscript.exe',
    'C:\Program Files\R\R-4.4.3\bin\Rscript.exe'
  )
  $RscriptPath = $Candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
} else {
  $RscriptPath = $Rscript.Source
}

if (-not $RscriptPath) {
  throw 'No se encontró Rscript.exe. Instala R y agrega Rscript al PATH.'
}

Set-Location -LiteralPath $ProjectRoot
$RscriptArgs = @('scripts/migrar_a_supabase.R')
if ($DryRun) { $RscriptArgs += '--dry-run' }
$LogDir = Join-Path $ProjectRoot 'logs'
if (-not (Test-Path -LiteralPath $LogDir)) {
  New-Item -ItemType Directory -Path $LogDir | Out-Null
}
$LogFile = Join-Path $LogDir ('neon_' + (Get-Date -Format 'yyyyMMdd_HHmmss') + '.log')
& $RscriptPath @RscriptArgs
$RunExitCode = $LASTEXITCODE
if ($LASTEXITCODE -ne 0) {
  "[$(Get-Date -Format o)] Falló la actualización a Neon (código $RunExitCode)." | Add-Content -Path $LogFile
  throw "La actualización a Neon terminó con código $RunExitCode. Log: $LogFile"
}
"[$(Get-Date -Format o)] Actualización a Neon completada correctamente." | Add-Content -Path $LogFile
