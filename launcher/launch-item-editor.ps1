Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$script:ConfigPath = Join-Path $PSScriptRoot "launcher-config.json"
$script:StatePath = $null
$script:LaunchScriptPath = $null
$script:CurrentState = $null

function Read-JsonFile {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        return $null
    }
    return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Write-JsonFile {
    param(
        [string]$Path,
        [object]$Value
    )

    $parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent | Out-Null
    }

    $Value | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Get-VersionObject {
    param([string]$Value)
    $version = $null
    if ([System.Version]::TryParse($Value, [ref]$version)) {
        return $version
    }
    return [System.Version]::new(0, 0)
}

function Remove-DirectorySafe {
    param([string]$Path)
    if (Test-Path -LiteralPath $Path) {
        Remove-Item -LiteralPath $Path -Recurse -Force
    }
}

function Update-LauncherUi {
    param(
        [string]$VersionText,
        [string]$StatusText,
        [int]$ProgressValue
    )

    $script:VersionLabel.Text = $VersionText
    $script:StatusLabel.Text = $StatusText
    $script:ProgressBar.Value = [Math]::Max(0, [Math]::Min(100, $ProgressValue))
    [System.Windows.Forms.Application]::DoEvents()
}

function Install-Package {
    param(
        [string]$DataDir,
        [string]$PackageDir,
        [pscustomobject]$Manifest,
        [int]$TimeoutSeconds
    )

    $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("item-editor-launcher-" + [Guid]::NewGuid().ToString("N"))
    $zipPath = Join-Path $tempRoot "editor.zip"
    $extractPath = Join-Path $tempRoot "extract"
    $incomingRoot = Join-Path $DataDir "incoming"
    $backupRoot = Join-Path $DataDir "backup"

    New-Item -ItemType Directory -Path $tempRoot | Out-Null
    New-Item -ItemType Directory -Path $extractPath | Out-Null

    try {
        Update-LauncherUi -VersionText $script:VersionLabel.Text -StatusText "Downloading $($Manifest.version)..." -ProgressValue 25
        Invoke-WebRequest -Uri $Manifest.zipUrl -OutFile $zipPath -TimeoutSec $TimeoutSeconds

        Update-LauncherUi -VersionText $script:VersionLabel.Text -StatusText "Verifying package..." -ProgressValue 55
        $downloadHash = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToLowerInvariant()
        $expectedHash = ([string]$Manifest.zipSha256).ToLowerInvariant()
        if ($downloadHash -ne $expectedHash) {
            throw "Downloaded zip hash mismatch. Expected $expectedHash but got $downloadHash."
        }

        Update-LauncherUi -VersionText $script:VersionLabel.Text -StatusText "Installing update..." -ProgressValue 72
        Expand-Archive -LiteralPath $zipPath -DestinationPath $extractPath -Force

        Remove-DirectorySafe -Path $incomingRoot
        Move-Item -LiteralPath $extractPath -Destination $incomingRoot

        Remove-DirectorySafe -Path $backupRoot
        if (Test-Path -LiteralPath $PackageDir) {
            Move-Item -LiteralPath $PackageDir -Destination $backupRoot
        }

        Move-Item -LiteralPath $incomingRoot -Destination $PackageDir
        Remove-DirectorySafe -Path $backupRoot
    }
    finally {
        Remove-DirectorySafe -Path $tempRoot
    }
}

if (-not (Test-Path -LiteralPath $script:ConfigPath)) {
    throw "Launcher config not found: $script:ConfigPath"
}

$config = Read-JsonFile -Path $script:ConfigPath
if ($null -eq $config) {
    throw "Failed to parse launcher config: $script:ConfigPath"
}

$appName = [string]$config.appName
$manifestUrl = [string]$config.manifestUrl
$installRootName = [string]$config.installRoot
$stateFileName = [string]$config.stateFile
$packageRootName = [string]$config.packageRoot
$timeoutSeconds = [int]$config.requestTimeoutSeconds

$dataDir = Join-Path $PSScriptRoot $installRootName
$packageDir = Join-Path $dataDir $packageRootName
$script:StatePath = Join-Path $dataDir $stateFileName
$script:LaunchScriptPath = Join-Path $packageDir "run-item-editor.bat"
$script:CurrentState = Read-JsonFile -Path $script:StatePath
if ($null -eq $script:CurrentState) {
    $script:CurrentState = [pscustomobject]@{
        installedVersion = ""
        installedAtUtc = ""
    }
}

$form = New-Object System.Windows.Forms.Form
$form.Text = $appName
$form.ClientSize = New-Object System.Drawing.Size(360, 230)
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
$form.MaximizeBox = $false
$form.MinimizeBox = $false
$form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
$form.BackColor = [System.Drawing.Color]::FromArgb(25, 27, 31)
$form.ForeColor = [System.Drawing.Color]::FromArgb(232, 234, 237)
$form.Font = New-Object System.Drawing.Font("Segoe UI", 9)

$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Text = "Item Editor"
$titleLabel.ForeColor = [System.Drawing.Color]::FromArgb(241, 177, 75)
$titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 24, [System.Drawing.FontStyle]::Bold)
$titleLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$titleLabel.SetBounds(20, 18, 320, 40)
$form.Controls.Add($titleLabel)

$launchButton = New-Object System.Windows.Forms.Button
$launchButton.Text = "Launch"
$launchButton.BackColor = [System.Drawing.Color]::FromArgb(226, 145, 49)
$launchButton.ForeColor = [System.Drawing.Color]::FromArgb(28, 18, 8)
$launchButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$launchButton.FlatAppearance.BorderSize = 0
$launchButton.Font = New-Object System.Drawing.Font("Segoe UI", 20, [System.Drawing.FontStyle]::Bold)
$launchButton.SetBounds(20, 72, 320, 68)
$form.Controls.Add($launchButton)

$script:VersionLabel = New-Object System.Windows.Forms.Label
$script:VersionLabel.Text = "Installed version: " + ($(if ([string]::IsNullOrWhiteSpace([string]$script:CurrentState.installedVersion)) { "none" } else { [string]$script:CurrentState.installedVersion }))
$script:VersionLabel.ForeColor = [System.Drawing.Color]::FromArgb(191, 201, 215)
$script:VersionLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$script:VersionLabel.SetBounds(20, 148, 320, 20)
$form.Controls.Add($script:VersionLabel)

$script:ProgressBar = New-Object System.Windows.Forms.ProgressBar
$script:ProgressBar.Style = [System.Windows.Forms.ProgressBarStyle]::Continuous
$script:ProgressBar.SetBounds(20, 176, 320, 12)
$script:ProgressBar.Minimum = 0
$script:ProgressBar.Maximum = 100
$form.Controls.Add($script:ProgressBar)

$script:StatusLabel = New-Object System.Windows.Forms.Label
$script:StatusLabel.Text = "Ready"
$script:StatusLabel.ForeColor = [System.Drawing.Color]::FromArgb(171, 180, 191)
$script:StatusLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$script:StatusLabel.SetBounds(20, 194, 320, 20)
$form.Controls.Add($script:StatusLabel)

$launchButton.Add_Click({
    $launchButton.Enabled = $false
    try {
        if (-not (Test-Path -LiteralPath $dataDir)) {
            New-Item -ItemType Directory -Path $dataDir | Out-Null
        }

        Update-LauncherUi -VersionText $script:VersionLabel.Text -StatusText "Fetching manifest..." -ProgressValue 8
        $manifest = Invoke-RestMethod -Uri $manifestUrl -TimeoutSec $timeoutSeconds

        if ([string]::IsNullOrWhiteSpace([string]$manifest.version) -or [string]::IsNullOrWhiteSpace([string]$manifest.zipUrl) -or [string]::IsNullOrWhiteSpace([string]$manifest.zipSha256)) {
            throw "Manifest is missing version, zipUrl, or zipSha256."
        }

        $needsUpdate = (-not (Test-Path -LiteralPath $script:LaunchScriptPath)) -or `
            [string]::IsNullOrWhiteSpace([string]$script:CurrentState.installedVersion) -or `
            ((Get-VersionObject ([string]$manifest.version)) -gt (Get-VersionObject ([string]$script:CurrentState.installedVersion)))

        if ($needsUpdate) {
            Install-Package -DataDir $dataDir -PackageDir $packageDir -Manifest $manifest -TimeoutSeconds $timeoutSeconds
            $script:CurrentState.installedVersion = [string]$manifest.version
            $script:CurrentState.installedAtUtc = [DateTime]::UtcNow.ToString("o")
            Write-JsonFile -Path $script:StatePath -Value $script:CurrentState
        } else {
            Update-LauncherUi -VersionText $script:VersionLabel.Text -StatusText "Latest version already installed." -ProgressValue 85
        }

        $script:VersionLabel.Text = "Installed version: " + [string]$script:CurrentState.installedVersion

        if (-not (Test-Path -LiteralPath $script:LaunchScriptPath)) {
            throw "Installed launch script was not found: $script:LaunchScriptPath"
        }

        Update-LauncherUi -VersionText $script:VersionLabel.Text -StatusText "Starting editor..." -ProgressValue 100
        Start-Process -FilePath $script:LaunchScriptPath -WorkingDirectory (Split-Path -Parent $script:LaunchScriptPath)
        $form.Close()
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, "Launcher Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
        Update-LauncherUi -VersionText $script:VersionLabel.Text -StatusText "Launch failed." -ProgressValue 0
    }
    finally {
        $launchButton.Enabled = $true
    }
})

[void]$form.ShowDialog()
