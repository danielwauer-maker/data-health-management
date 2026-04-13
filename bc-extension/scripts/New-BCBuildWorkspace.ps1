[CmdletBinding()]
param(
    [ValidateSet("DevCloud", "ReleaseCloud", "OnPremBc19")]
    [string]$Profile = "ReleaseCloud",

    [string]$OutputPath
)

$repoRoot = Split-Path -Parent $PSScriptRoot

$manifestByProfile = @{
    DevCloud = "app.cloud.json"
    ReleaseCloud = "app.json"
    OnPremBc19 = "app.onprem.bc19.json"
}

$manifestName = $manifestByProfile[$Profile]
$manifestPath = Join-Path $repoRoot $manifestName

if (-not (Test-Path -LiteralPath $manifestPath)) {
    throw "Manifest not found: $manifestPath"
}

if (-not $OutputPath) {
    $OutputPath = Join-Path $repoRoot ".build\$Profile"
}

$outputRoot = [System.IO.Path]::GetFullPath($OutputPath)
$repoRootFull = [System.IO.Path]::GetFullPath($repoRoot)

New-Item -ItemType Directory -Path $outputRoot -Force | Out-Null

foreach ($path in @("app", ".alpackages", ".vscode", "app.json")) {
    $generatedPath = Join-Path $outputRoot $path
    if ((Test-Path -LiteralPath $generatedPath) -and $outputRoot.StartsWith($repoRootFull, [System.StringComparison]::OrdinalIgnoreCase)) {
        Remove-Item -LiteralPath $generatedPath -Recurse -Force
    }
}

Copy-Item -LiteralPath (Join-Path $repoRoot "app") -Destination (Join-Path $outputRoot "app") -Recurse -Force
Copy-Item -LiteralPath $manifestPath -Destination (Join-Path $outputRoot "app.json") -Force

$packageCachePath = Join-Path $repoRoot ".alpackages"
if (Test-Path -LiteralPath $packageCachePath) {
    Copy-Item -LiteralPath $packageCachePath -Destination (Join-Path $outputRoot ".alpackages") -Recurse -Force
}

$launchPath = Join-Path $repoRoot ".vscode\launch.json"
if ($Profile -eq "DevCloud" -and (Test-Path -LiteralPath $launchPath)) {
    New-Item -ItemType Directory -Path (Join-Path $outputRoot ".vscode") -Force | Out-Null
    Copy-Item -LiteralPath $launchPath -Destination (Join-Path $outputRoot ".vscode\launch.json") -Force
}

Write-Host "Prepared build workspace:"
Write-Host "  Profile: $Profile"
Write-Host "  Manifest: $manifestName"
Write-Host "  Output: $outputRoot"
