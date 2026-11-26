param(
    [string]$PluginPath = "$env:ProgramData\aviutl2\Plugin\SYNC_Sanpai\SYNC_Sanpai.auf2",
    [string]$ImageDirectory,
    [switch]$MotionPreview
)

$ErrorActionPreference = 'Stop'
$project = Split-Path -Parent $PSScriptRoot
$PluginPath = (Resolve-Path -LiteralPath $PluginPath).Path
$output = Join-Path $project 'Win64\Verification'
$dcu = Join-Path $output 'DCU'
if (-not $ImageDirectory) { $ImageDirectory = Join-Path $output 'Images' }
$ImageDirectory = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($ImageDirectory)
$studio = 'C:\Program Files (x86)\Embarcadero\Studio\37.0'
$library = Join-Path $studio 'lib\Win64\release'
New-Item -ItemType Directory -Path $dcu,$ImageDirectory -Force | Out-Null

Push-Location $PSScriptRoot
try {
    $dccArguments = @('--no-config','-B','-Q','-TX.exe','-NSSystem;Winapi;Vcl',
        "-U$library;$library\JA","-E$output","-NU$dcu",'Sanpai_RenderTests.dpr')
    & (Join-Path $studio 'bin\dcc64.exe') @dccArguments
    if ($LASTEXITCODE -ne 0) { throw 'Render test build failed.' }
    $testArguments = @($PluginPath,$ImageDirectory)
    if ($MotionPreview) { $testArguments += '--motion-preview' }
    & (Join-Path $output 'Sanpai_RenderTests.exe') @testArguments
    if ($LASTEXITCODE -ne 0) { throw 'Production AUF2 verification failed.' }
}
finally { Pop-Location }
