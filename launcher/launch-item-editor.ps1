param(
    [string]$ConfigPath = (Join-Path $PSScriptRoot 'launcher-config.json')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Step([string]$Message) {
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Ensure-Directory([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path | Out-Null
    }
}

function Get-ConfigValue($Config, [string]$Name) {
    $property = $Config.PSObject.Properties[$Name]
    if ($null -eq $property -or [string]::IsNullOrWhiteSpace([string]$property.Value)) {
        throw "Missing required config value '$Name' in $ConfigPath"
    }
    return [string]$property.Value
}

function Resolve-Version([string]$VersionText) {
    try {
        return [version]$VersionText
    }
    catch {
        throw "Manifest version '$VersionText' is not a valid .NET version string."
    }
}

function Load-State([string]$StatePath) {
    if (-not (Test-Path -LiteralPath $StatePath)) {
        return [pscustomobject]@{
            version = ''
        }
    }

    return Get-Content -LiteralPath $StatePath -Raw | ConvertFrom-Json
}

function Save-State([string]$StatePath, [string]$Version) {
    $state = [pscustomobject]@{
        version = $Version
        updatedAtUtc = [DateTime]::UtcNow.ToString('o')
    }
    $state | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $StatePath -Encoding UTF8
}

function Test-NeedsUpdate([string]$LocalVersion, [string]$RemoteVersion, [string]$LaunchScriptPath) {
    if (-not (Test-Path -LiteralPath $LaunchScriptPath)) {
        return $true
    }
    if ([string]::IsNullOrWhiteSpace($LocalVersion)) {
        return $true
    }

    return (Resolve-Version $RemoteVersion) -gt (Resolve-Version $LocalVersion)
}

if (-not (Test-Path -LiteralPath $ConfigPath)) {
    throw "Launcher config not found: $ConfigPath"
}

$config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
$appName = Get-ConfigValue $config 'appName'
$manifestUrl = Get-ConfigValue $config 'manifestUrl'
$installRootName = Get-ConfigValue $config 'installRoot'
$stateFileName = Get-ConfigValue $config 'stateFile'
$packageRootName = Get-ConfigValue $config 'packageRoot'
$timeoutSeconds = [int](Get-ConfigValue $config 'requestTimeoutSeconds')

$launcherRoot = Split-Path -Parent $ConfigPath
$installRoot = Join-Path $launcherRoot $installRootName
$packageRoot = Join-Path $installRoot $packageRootName
$statePath = Join-Path $installRoot $stateFileName
$launchScript = Join-Path $packageRoot 'run-item-editor.bat'

Ensure-Directory $installRoot

Step "Checking $appName updates"
$manifest = Invoke-RestMethod -Uri $manifestUrl -TimeoutSec $timeoutSeconds

if ([string]::IsNullOrWhiteSpace([string]$manifest.version)) {
    throw "Manifest at $manifestUrl does not contain a version."
}
if ([string]::IsNullOrWhiteSpace([string]$manifest.zipUrl)) {
    throw "Manifest at $manifestUrl does not contain a zipUrl."
}
if ([string]::IsNullOrWhiteSpace([string]$manifest.zipSha256)) {
    throw "Manifest at $manifestUrl does not contain a zipSha256."
}

$state = Load-State $statePath
$remoteVersion = [string]$manifest.version
$localVersion = [string]$state.version

if (Test-NeedsUpdate -LocalVersion $localVersion -RemoteVersion $remoteVersion -LaunchScriptPath $launchScript) {
    Step "Downloading version $remoteVersion"
    $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("raynna-item-editor-" + [System.Guid]::NewGuid().ToString('N'))
    $zipPath = Join-Path $tempRoot 'editor.zip'
    $extractPath = Join-Path $tempRoot 'extract'
    $incomingRoot = Join-Path $installRoot 'incoming'
    $backupRoot = Join-Path $installRoot 'backup'

    Ensure-Directory $tempRoot
    Ensure-Directory $extractPath

    try {
        Invoke-WebRequest -Uri $manifest.zipUrl -OutFile $zipPath -TimeoutSec $timeoutSeconds
        $downloadHash = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToLowerInvariant()
        $expectedHash = ([string]$manifest.zipSha256).ToLowerInvariant()
        if ($downloadHash -ne $expectedHash) {
            throw "Downloaded zip hash mismatch. Expected $expectedHash but got $downloadHash."
        }

        Expand-Archive -LiteralPath $zipPath -DestinationPath $extractPath -Force

        if (Test-Path -LiteralPath $incomingRoot) {
            Remove-Item -LiteralPath $incomingRoot -Recurse -Force
        }
        Move-Item -LiteralPath $extractPath -Destination $incomingRoot

        if (Test-Path -LiteralPath $backupRoot) {
            Remove-Item -LiteralPath $backupRoot -Recurse -Force
        }
        if (Test-Path -LiteralPath $packageRoot) {
            Move-Item -LiteralPath $packageRoot -Destination $backupRoot
        }

        Move-Item -LiteralPath $incomingRoot -Destination $packageRoot

        if (Test-Path -LiteralPath $backupRoot) {
            Remove-Item -LiteralPath $backupRoot -Recurse -Force
        }

        Save-State -StatePath $statePath -Version $remoteVersion
    }
    finally {
        if (Test-Path -LiteralPath $tempRoot) {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force
        }
    }
} else {
    Step "$appName is already on version $localVersion"
}

if (-not (Test-Path -LiteralPath $launchScript)) {
    throw "Installed editor launcher not found: $launchScript"
}

Step "Starting $appName"
& $launchScript
exit $LASTEXITCODE
