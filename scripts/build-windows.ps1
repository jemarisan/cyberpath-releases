# CyberPath Windows Build Script
#
# Usage: .\build-windows.ps1 [version]
# Example: .\build-windows.ps1 2.0.0
#
# Prerequisites:
# - Flutter SDK installed and in PATH
# - Visual Studio 2022 with C++ desktop development workload
#

param(
    [string]$Version = "2.0.0"
)

$ErrorActionPreference = "Stop"

# Configuration
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $ScriptDir)
$FrontendDir = Join-Path $ProjectRoot "frontend"
$ReleaseDir = Join-Path $ProjectRoot "release\packages"
$AppName = "CyberPath"

Write-Host "🚀 Building CyberPath v$Version for Windows..." -ForegroundColor Cyan
Write-Host "📁 Project root: $ProjectRoot"
Write-Host "📁 Frontend dir: $FrontendDir"
Write-Host "📁 Release dir: $ReleaseDir"

# Ensure release directory exists
New-Item -ItemType Directory -Force -Path $ReleaseDir | Out-Null

# Navigate to frontend
Set-Location $FrontendDir

# Get dependencies
Write-Host "📦 Getting dependencies..." -ForegroundColor Yellow
flutter pub get

# Build Windows release
Write-Host "🔨 Building Windows release..." -ForegroundColor Yellow
flutter build windows --release

# Create ZIP
Write-Host "📦 Creating ZIP archive..." -ForegroundColor Yellow
$ZipName = "$AppName-$Version-windows.zip"
$BuildPath = Join-Path $FrontendDir "build\windows\x64\runner\Release"
$ZipPath = Join-Path $ReleaseDir $ZipName

# Remove old ZIP if exists
if (Test-Path $ZipPath) {
    Remove-Item $ZipPath -Force
}

# Create ZIP
Compress-Archive -Path "$BuildPath\*" -DestinationPath $ZipPath -Force

# Calculate checksum
Write-Host "🔐 Calculating checksum..." -ForegroundColor Yellow
$Hash = Get-FileHash -Path $ZipPath -Algorithm SHA256
$Checksum = $Hash.Hash.ToLower()
"$Checksum  $ZipName" | Out-File -FilePath "$ZipPath.sha256" -Encoding UTF8

Write-Host ""
Write-Host "✅ Build complete!" -ForegroundColor Green
Write-Host "📦 ZIP: $ZipPath"
Write-Host "📝 Size: $([math]::Round((Get-Item $ZipPath).Length / 1MB, 2)) MB"
Write-Host "🔐 SHA256: $Checksum"
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Test the application by extracting and running"
Write-Host "2. Upload to GitHub Releases"
Write-Host "3. Update CHANGELOG.md"
