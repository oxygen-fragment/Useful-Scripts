# 🛠️ Useful Scripts

Welcome to **Useful-Scripts** — a curated collection of command-line tools organized by functionality. Each script is designed to solve specific problems, save time, and simplify workflows across different platforms.

---

## 🚀 Quick Start

### Discovery Tool
Use our built-in discovery tool to find and explore scripts:

```bash
# List all available scripts
./tools/discover.sh list

# Show script categories
./tools/discover.sh categories

# Search for specific functionality
./tools/discover.sh search ubuntu

# Get detailed info about a script
./tools/discover.sh info MakeUbuntuUSB.ps1

# Run a script with safety prompts
./tools/discover.sh run script_name.sh
```

### Direct Usage
Navigate to the script's category directory and run:

```bash
# For bash scripts
chmod +x script_name.sh
./script_name.sh [arguments]

# For PowerShell scripts (Windows)
powershell -ep Bypass -f script_name.ps1

# For Python scripts
python3 script_name.py [arguments]
```

---

## 📂 Script Categories

### 🔧 System Administration
**Location:** `scripts/system-admin/`
- **MakeUbuntuUSB.ps1** - Creates bootable Ubuntu USB drives on Windows (designed for non-technical users)

### 📄 Document Processing  
**Location:** `scripts/document-processing/`
- **prepare_arxiv.sh** - Automates LaTeX paper preparation for arXiv submission

### 📁 File Utilities
**Location:** `scripts/file-utilities/`
- **find_date_variants.sh** - Searches for files with date patterns in multiple formats

### 🔍 Data Processing
**Location:** `scripts/data-processing/`
- **remove_geo_garmin_json.py** - Strips geolocation data from JSON files for privacy

---

## 🎯 Platform Support

| Platform | Scripts Available | Usage |
|----------|------------------|-------|
| 🐧 **Linux/macOS** | Bash scripts (`.sh`) | `./script.sh` |
| 🪟 **Windows** | PowerShell (`.ps1`) | `powershell -ep Bypass -f script.ps1` |
| 🐍 **Cross-platform** | Python (`.py`) | `python3 script.py` |

---

## 📖 Documentation

Each category has detailed documentation:
- **Category README** - Overview and usage for all scripts in that category
- **Script Headers** - Usage examples and requirements in each script
- **Templates** - Standardized templates for new scripts in `scripts/templates/`

---

## 🔧 Development

### Adding New Scripts

1. **Choose Category** - Place in appropriate `scripts/[category]/` directory
2. **Use Template** - Start with a template from `scripts/templates/`
3. **Document** - Add entry to category README using `SCRIPT_TEMPLATE.md`
4. **Test** - Verify across target platforms

### Organization Principles

- **Self-contained** - Minimal dependencies, clear error messages
- **Safety-first** - Destructive operations require explicit confirmation
- **User-friendly** - Designed for both technical and non-technical users
- **Cross-platform** - Support multiple platforms where possible

---

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Add your script to the appropriate category
4. Update documentation
5. Submit a pull request

**Script Requirements:**
- Follow existing code style and safety patterns
- Include comprehensive error handling
- Add usage examples and documentation
- Test on target platforms

---

## 🧠 License

MIT — Use freely, attribution appreciated.

---

## 🔍 Need Help?

- Use `./tools/discover.sh` to explore available scripts
- Check category README files for detailed documentation
- Look at script headers for usage examples
- Refer to `SCRIPT_TEMPLATE.md` for documentation standards