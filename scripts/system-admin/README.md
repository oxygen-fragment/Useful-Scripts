# System Administration Scripts

Scripts for system management, hardware setup, and administrative tasks.

## MakeUbuntuUSB.ps1

### 📝 Description
Creates a bootable Ubuntu USB drive on Windows systems using Ventoy. Designed for non-technical users with comprehensive error handling and user-friendly prompts.

### 🎯 Use Cases
- Creating Ubuntu installation media for family/friends
- Setting up dual-boot systems
- Installing Ubuntu on older hardware
- Emergency Ubuntu rescue drives

### 🔧 Requirements
**Platform:** Windows 7+
**Dependencies:** PowerShell v2+ (built-in), Internet connection
**Permissions:** Administrator required

### 📦 Usage
```powershell
# Run from elevated PowerShell
powershell -ep Bypass -f .\MakeUbuntuUSB.ps1
```

### 🔒 Safety Notes
- **DESTRUCTIVE**: Completely erases the target USB drive
- Requires explicit "YES" confirmation before proceeding
- Only targets removable drives ≥8GB
- Automatically fetches latest Ventoy version
- Includes comprehensive error checking

### 🐛 Troubleshooting
**No USB drives found:**
- Symptom: "No suitable USB drive found"
- Solution: Insert USB drive ≥8GB, wait for Windows recognition

**Download failures:**
- Symptom: Network timeout or 404 errors
- Solution: Check internet connection, script auto-retries with fallback URLs

**Ventoy installation fails:**
- Symptom: "Failed to install Ventoy"
- Solution: Check USB isn't write-protected, close other programs using the drive

---
*Last updated: 2024-12-30*
*Tested on: Windows 7, Windows 10, Windows 11*