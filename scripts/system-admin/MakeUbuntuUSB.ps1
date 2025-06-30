<#
   Minimal Ubuntu-USB maker
   ✔ Windows 7 compatible
   ✔ Needs PowerShell v2+ (built-in)
   ✔ Run in an elevated PowerShell window:  PS> powershell -ep Bypass -f .\MakeUbuntuUSB.ps1
#>

$ISO   = "https://releases.ubuntu.com/24.04/ubuntu-24.04.1-desktop-amd64.iso"
$TEMP  = "$env:TEMP\UbuntuUSB"
$USBGB = 8   # refuse to touch sticks smaller than this (safety)

# Get latest Ventoy release URL from GitHub API
function Get-LatestVentoyUrl {
    try {
        Write-Host "[+] Finding latest Ventoy version..." -ForegroundColor Green
        $apiUrl = "https://api.github.com/repos/ventoy/Ventoy/releases/latest"
        $release = Invoke-RestMethod -Uri $apiUrl -ErrorAction Stop
        $windowsAsset = $release.assets | Where-Object { $_.name -like "*windows*" -and $_.name -like "*.zip" } | Select-Object -First 1
        if (-not $windowsAsset) {
            throw "Could not find Windows Ventoy asset in latest release"
        }
        Write-Host "    Found Ventoy $($release.tag_name)" -ForegroundColor Gray
        return $windowsAsset.browser_download_url
    }
    catch {
        Write-Host "[!] Failed to get latest Ventoy URL. Using fallback." -ForegroundColor Yellow
        Write-Host "    Error: $($_.Exception.Message)" -ForegroundColor Yellow
        return "https://github.com/ventoy/Ventoy/releases/download/v1.0.99/ventoy-1.0.99-windows.zip"
    }
}

# --- boilerplate checks ————————————————
Write-Host "🖥️  Ubuntu USB Creator for Windows 7+" -ForegroundColor Cyan
Write-Host "    This will download Ubuntu and create a bootable USB drive`n" -ForegroundColor Gray

if (-not ([Security.Principal.WindowsPrincipal] `
          [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
          [Security.Principal.WindowsBuiltinRole]::Administrator)) {
  Write-Host "[!] This script needs Administrator privileges to work with USB drives." -ForegroundColor Red
  Write-Host "    Please:" -ForegroundColor Yellow
  Write-Host "    1. Right-click on PowerShell" -ForegroundColor Yellow
  Write-Host "    2. Select 'Run as Administrator'" -ForegroundColor Yellow
  Write-Host "    3. Run this script again" -ForegroundColor Yellow
  Read-Host "`nPress Enter to exit"
  exit 1
}

# Check internet connection
try {
    Test-Connection -ComputerName "8.8.8.8" -Count 1 -Quiet | Out-Null
} catch {
    Write-Host "[!] No internet connection detected." -ForegroundColor Red
    Write-Host "    Please check your network connection and try again." -ForegroundColor Yellow
    Read-Host "`nPress Enter to exit"
    exit 1
}

Write-Host "[+] Administrator check passed ✓" -ForegroundColor Green
Write-Host "[+] Internet connection verified ✓" -ForegroundColor Green

try {
    New-Item -Force -ItemType Directory $TEMP | Out-Null
    Set-Location $TEMP
    Write-Host "[+] Created working directory: $TEMP" -ForegroundColor Green
} catch {
    Write-Host "[!] Failed to create working directory." -ForegroundColor Red
    Write-Host "    Error: $($_.Exception.Message)" -ForegroundColor Yellow
    Read-Host "`nPress Enter to exit"
    exit 1
}

# --- 1. download Ubuntu ISO & Ventoy —————————
function Download-WithProgress {
    param([string]$Url, [string]$OutputFile, [string]$Description)
    
    try {
        Write-Host "[+] Downloading $Description..." -ForegroundColor Green
        Write-Host "    From: $Url" -ForegroundColor Gray
        Write-Host "    To: $OutputFile" -ForegroundColor Gray
        Write-Host "    This may take several minutes depending on your internet speed..." -ForegroundColor Gray
        
        # Use BITS transfer for better progress and resume capability (if available)
        if (Get-Command Start-BitsTransfer -ErrorAction SilentlyContinue) {
            Start-BitsTransfer -Source $Url -Destination $OutputFile -DisplayName $Description
        } else {
            # Fallback to Invoke-WebRequest
            Invoke-WebRequest -Uri $Url -OutFile $OutputFile -ErrorAction Stop
        }
        
        if (Test-Path $OutputFile) {
            $size = [math]::Round((Get-Item $OutputFile).Length / 1MB, 1)
            Write-Host "    ✓ Downloaded successfully ($size MB)" -ForegroundColor Green
        } else {
            throw "File was not created"
        }
    }
    catch {
        Write-Host "[!] Failed to download $Description" -ForegroundColor Red
        Write-Host "    Error: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "    Please check your internet connection and try again." -ForegroundColor Yellow
        throw
    }
}

# Check available disk space first
$freeSpace = [math]::Round((Get-WmiObject -Class Win32_LogicalDisk -Filter "DeviceID='$($env:TEMP[0]):'" | Select-Object -ExpandProperty FreeSpace) / 1GB, 1)
if ($freeSpace -lt 8) {
    Write-Host "[!] Not enough disk space for downloads." -ForegroundColor Red
    Write-Host "    Need: ~8 GB free space" -ForegroundColor Yellow
    Write-Host "    Available: $freeSpace GB" -ForegroundColor Yellow
    Write-Host "    Please free up some disk space and try again." -ForegroundColor Yellow
    Read-Host "`nPress Enter to exit"
    exit 1
}
Write-Host "[+] Disk space check passed ($freeSpace GB available) ✓" -ForegroundColor Green

Download-WithProgress -Url $ISO -OutputFile "ubuntu.iso" -Description "Ubuntu ISO"

$VENT = Get-LatestVentoyUrl
Download-WithProgress -Url $VENT -OutputFile "ventoy.zip" -Description "Ventoy"

Write-Host "[+] Extracting Ventoy..." -ForegroundColor Green
try {
    Expand-Archive ventoy.zip -Force -ErrorAction Stop
    Write-Host "    ✓ Ventoy extracted successfully" -ForegroundColor Green
} catch {
    Write-Host "[!] Failed to extract Ventoy" -ForegroundColor Red
    Write-Host "    Error: $($_.Exception.Message)" -ForegroundColor Yellow
    throw
}

# --- 2. pick the USB drive (auto-select if only one) —
Write-Host "`n[+] Looking for USB drives..." -ForegroundColor Green

$usb = Get-WmiObject Win32_DiskDrive | Where {$_.MediaType -match 'Removable' -and $_.Size/1GB -ge $USBGB}

if (-not $usb) {
    Write-Host "[!] No suitable USB drive found." -ForegroundColor Red
    Write-Host "    Requirements:" -ForegroundColor Yellow
    Write-Host "    - Must be at least $USBGB GB" -ForegroundColor Yellow
    Write-Host "    - Must be a removable drive (USB stick)" -ForegroundColor Yellow
    Write-Host "`n    Please:" -ForegroundColor Yellow
    Write-Host "    1. Insert a USB drive that's $USBGB GB or larger" -ForegroundColor Yellow
    Write-Host "    2. Wait a few seconds for Windows to recognize it" -ForegroundColor Yellow
    Write-Host "    3. Run this script again" -ForegroundColor Yellow
    Read-Host "`nPress Enter to exit"
    exit 1
}

if ($usb.Count -gt 1) {
    Write-Host "    Found multiple USB drives:" -ForegroundColor Yellow
    $usb | ForEach-Object { 
        $sizeGB = [math]::Round($_.Size/1GB, 1)
        Write-Host "    [$($_.Index)] $sizeGB GB - $($_.Model)" -ForegroundColor Cyan
    }
    
    do {
        $choice = Read-Host "`nType the disk number to use (or 'q' to quit)"
        if ($choice -eq 'q') { exit }
        $selectedUsb = $usb | Where {$_.Index -eq [int]$choice}
    } while (-not $selectedUsb)
    
    $usb = $selectedUsb
} else {
    $sizeGB = [math]::Round($usb.Size/1GB, 1)
    Write-Host "    Found: $sizeGB GB - $($usb.Model)" -ForegroundColor Cyan
}

$disk = "Drive:$($usb.Index):"
$sizeGB = [math]::Round($usb.Size/1GB, 1)

Write-Host "`n⚠️  IMPORTANT WARNING ⚠️" -ForegroundColor Red
Write-Host "This will COMPLETELY ERASE the USB drive:" -ForegroundColor Red
Write-Host "Drive: $($usb.Model) ($sizeGB GB)" -ForegroundColor Red
Write-Host "All data on this drive will be permanently lost!" -ForegroundColor Red

Write-Host "`nAre you absolutely sure you want to continue? (Type 'YES' to confirm)" -ForegroundColor Yellow
$confirmation = Read-Host
if ($confirmation -ne 'YES') { 
    Write-Host "Operation cancelled. No changes were made." -ForegroundColor Green
    exit 
}

# --- 3. install Ventoy & copy ISO ——————————
Write-Host "`n[+] Installing Ventoy to USB drive..." -ForegroundColor Green
Write-Host "    This will take a few minutes..." -ForegroundColor Gray

$ventExe = Get-ChildItem . -Filter Ventoy2Disk.exe -Recurse | Select -First 1
if (-not $ventExe) {
    Write-Host "[!] Ventoy executable not found." -ForegroundColor Red
    Write-Host "    The downloaded Ventoy package may be corrupted." -ForegroundColor Yellow
    Read-Host "`nPress Enter to exit"
    exit 1
}

Write-Host "    Using: $($ventExe.FullName)" -ForegroundColor Gray
try {
    & $ventExe VTOYCLI /I /$disk /GPT /NOSB
    if ($LASTEXITCODE -ne 0) { 
        throw "Ventoy installation returned error code $LASTEXITCODE" 
    }
    Write-Host "    ✓ Ventoy installed successfully" -ForegroundColor Green
} catch {
    Write-Host "[!] Failed to install Ventoy" -ForegroundColor Red
    Write-Host "    Error: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "    This could be due to:" -ForegroundColor Yellow
    Write-Host "    - USB drive is write-protected" -ForegroundColor Yellow
    Write-Host "    - USB drive is being used by another program" -ForegroundColor Yellow
    Write-Host "    - Insufficient permissions" -ForegroundColor Yellow
    Read-Host "`nPress Enter to exit"
    exit 1
}

Write-Host "[+] Waiting for USB drive to be ready..." -ForegroundColor Green
Start-Sleep 3

# Find the Ventoy volume
$vol = $null
$attempts = 0
do {
    $vol = (Get-WmiObject Win32_Volume | Where {$_.Label -eq 'Ventoy'}).DriveLetter
    if (-not $vol) {
        Start-Sleep 2
        $attempts++
    }
} while (-not $vol -and $attempts -lt 10)

if (-not $vol) {
    Write-Host "[!] Could not find Ventoy volume." -ForegroundColor Red
    Write-Host "    Ventoy may have been installed, but the volume is not accessible." -ForegroundColor Yellow
    Write-Host "    Try manually copying ubuntu.iso to the Ventoy USB drive." -ForegroundColor Yellow
    Read-Host "`nPress Enter to exit"
    exit 1
}

Write-Host "[+] Copying Ubuntu ISO to USB drive..." -ForegroundColor Green
Write-Host "    Copying to: $vol\" -ForegroundColor Gray
try {
    Copy-Item ubuntu.iso "$vol\" -Verbose -ErrorAction Stop
    Write-Host "    ✓ Ubuntu ISO copied successfully" -ForegroundColor Green
} catch {
    Write-Host "[!] Failed to copy Ubuntu ISO" -ForegroundColor Red
    Write-Host "    Error: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "    You can manually copy 'ubuntu.iso' to the USB drive later." -ForegroundColor Yellow
}

# Cleanup
Write-Host "`n[+] Cleaning up temporary files..." -ForegroundColor Green
try {
    Set-Location $env:TEMP
    Remove-Item -Path $TEMP -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "    ✓ Cleanup completed" -ForegroundColor Green
} catch {
    Write-Host "    Note: Some temporary files may remain in $TEMP" -ForegroundColor Yellow
}

Write-Host "`n🎉 SUCCESS! 🎉" -ForegroundColor Green
Write-Host "Your Ubuntu USB drive is ready!" -ForegroundColor Green
Write-Host "`nNext steps:" -ForegroundColor Cyan
Write-Host "1. Safely eject the USB drive" -ForegroundColor Yellow
Write-Host "2. Insert it into the computer where you want to install Ubuntu" -ForegroundColor Yellow
Write-Host "3. Boot from the USB drive (may need to change BIOS/UEFI settings)" -ForegroundColor Yellow
Write-Host "4. Select 'Ubuntu' in the Ventoy boot menu" -ForegroundColor Yellow
Write-Host "5. Follow the Ubuntu installation instructions" -ForegroundColor Yellow

Read-Host "`nPress Enter to exit"
