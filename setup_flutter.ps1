# setup_flutter.ps1
# Automates the extraction, path configuration, and verification of the downloaded Flutter SDK.

$zipPath = "$env:USERPROFILE\Downloads\flutter_sdk.zip"
$destDir = "$env:USERPROFILE\flutter"
$binPath = "$destDir\flutter\bin"

Write-Host "=== EmmaSarmingStore v2: Automated Flutter SDK Setup ===" -ForegroundColor Cyan

# 1. Wait for the download to complete
if (Test-Path $zipPath) {
    Write-Host "Checking download status..." -ForegroundColor Yellow
    
    # Wait until the file size is stable (indicating the download task completed and released the file lock)
    $lastSize = 0
    $stableCount = 0
    
    while ($true) {
        $file = Get-Item $zipPath -ErrorAction SilentlyContinue
        if ($file) {
            $currentSize = $file.Length
            $sizeInMB = [Math]::Round($currentSize / 1MB, 2)
            Write-Host "Current file size: $sizeInMB MB..." -ForegroundColor Gray
            
            if ($currentSize -eq $lastSize -and $currentSize -gt 800MB) {
                $stableCount++
                if ($stableCount -ge 3) {
                    Write-Host "Download appears complete and stable!" -ForegroundColor Green
                    break;
                }
            } else {
                $stableCount = 0
                $lastSize = $currentSize
            }
        } else {
            Write-Host "Waiting for downloaded file to appear..." -ForegroundColor Red
        }
        
        Write-Host "Download in progress. Waiting 15 seconds to check again..." -ForegroundColor Yellow
        Start-Sleep -Seconds 15
    }
} else {
    Write-Host "Error: '$zipPath' not found. Please wait for the download task to create the file." -ForegroundColor Red
    Exit 1
}

# 2. Extract the ZIP file
Write-Host "Extracting Flutter SDK to '$destDir' (this may take a few minutes)..." -ForegroundColor Cyan
if (Test-Path $destDir) {
    Write-Host "Target directory '$destDir' already exists. Cleaning up old files..." -ForegroundColor Yellow
    Remove-Item -Recurse -Force $destDir -ErrorAction SilentlyContinue
}

New-Item -ItemType Directory -Force -Path $destDir | Out-Null

try {
    # Using Expand-Archive which is standard in modern PowerShell
    Expand-Archive -Path $zipPath -DestinationPath $destDir -Force
    Write-Host "Extraction completed successfully!" -ForegroundColor Green
} catch {
    Write-Host "Error during extraction: $_" -ForegroundColor Red
    Exit 1
}

# 3. Configure the PATH Environment Variable
Write-Host "Adding Flutter binary path to User PATH environment variable..." -ForegroundColor Cyan

# Get current user PATH
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")

if ($userPath -like "*$binPath*") {
    Write-Host "Flutter is already in your PATH!" -ForegroundColor Green
} else {
    $newUserPath = "$userPath;$binPath"
    [Environment]::SetEnvironmentVariable("Path", $newUserPath, "User")
    Write-Host "Added '$binPath' to PATH successfully!" -ForegroundColor Green
    Write-Host "NOTE: You may need to restart your terminal or IDE to apply the path updates." -ForegroundColor Yellow
}

# Update current session PATH so we can run flutter doctor right away
$env:Path += ";$binPath"

# 4. Verify Installation
Write-Host "Running 'flutter doctor' to verify setup..." -ForegroundColor Cyan
try {
    & flutter doctor
} catch {
    Write-Host "Failed to execute 'flutter doctor'. Please make sure the path is configured correctly." -ForegroundColor Red
}

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "Setup Completed! You are now ready to run the app!" -ForegroundColor Green
Write-Host "To run the app, restart your editor/terminal and execute:" -ForegroundColor White
Write-Host "  flutter run" -ForegroundColor Yellow
Write-Host "=============================================" -ForegroundColor Cyan
