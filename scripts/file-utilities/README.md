# File Utilities Scripts

Scripts for file management, search, and organization tasks.

## find_date_variants.sh

### 📝 Description
Searches for files containing date patterns in multiple formats. Useful for finding files with dates in filenames across different naming conventions.

### 🎯 Use Cases
- Finding files from specific dates with various naming patterns
- Organizing files by date when formats are inconsistent
- Searching through backup directories with date-based filenames
- Locating photos/documents by date across different sources

### 🔧 Requirements
**Platform:** Linux/macOS/Windows (with bash)
**Dependencies:** 
- bash, find, date (standard Unix tools)
**Permissions:** Regular user (read access to search directories)

### 📦 Usage
```bash
# Make executable
chmod +x find_date_variants.sh

# Search in script directory
./find_date_variants.sh 2021-11-16

# Search in specific path
./find_date_variants.sh /path/to/search 2021-11-16

# Also accepts YYYYMMDD format
./find_date_variants.sh 20211116
```

### ⚙️ Supported Date Formats
- `YYYY-MM-DD` (2021-11-16)
- `DD-MM-YYYY` (16-11-2021)  
- `YYYY_MM_DD` (2021_11_16)
- `DD_MM_YYYY` (16_11_2021)
- `YYYY.MM.DD` (2021.11.16)
- `DD.MM.YYYY` (16.11.2021)
- `YYYY MM DD` (2021 11 16)
- `MonthAbbr DD YYYY` (Nov 16 2021)
- `MonthFull DD YYYY` (November 16 2021)
- `YYYYMMDD` (20211116)

### 🔒 Safety Notes
- Read-only operation - never modifies files
- Validates date input before searching
- Handles invalid dates gracefully
- Case-insensitive matching

### 🐛 Troubleshooting
**Invalid date format:**
- Symptom: "Invalid date format" error
- Solution: Use YYYY-MM-DD or YYYYMMDD format

**No results found:**
- Symptom: No files returned
- Solution: Check date is valid, verify files exist in search path

**Permission denied:**
- Symptom: find command fails on some directories
- Solution: Run with appropriate permissions or search in accessible directories

### 🔗 Related Scripts
- Use with file organization scripts
- Combine with backup verification tools

---
*Last updated: 2024-12-30*
*Tested on: Ubuntu 20.04+, macOS, Windows WSL*