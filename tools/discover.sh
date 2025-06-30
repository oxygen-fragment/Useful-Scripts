#!/bin/bash
#
# Script Discovery Tool for Useful-Scripts Repository
# Helps find and explore available scripts by category or functionality
#

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT="$(dirname "$SCRIPT_DIR")"
readonly SCRIPTS_DIR="$REPO_ROOT/scripts"

# Colors
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly YELLOW='\033[1;33m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

usage() {
    echo "Script Discovery Tool"
    echo
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo
    echo "COMMANDS:"
    echo "  list                 List all available scripts"
    echo "  categories           Show script categories"
    echo "  search KEYWORD       Search scripts by keyword"
    echo "  info SCRIPT_NAME     Show detailed information about a script"
    echo "  run SCRIPT_NAME      Execute a script (with safety prompts)"
    echo
    echo "OPTIONS:"
    echo "  -h, --help          Show this help"
    echo
    echo "EXAMPLES:"
    echo "  $0 list"
    echo "  $0 search ubuntu"
    echo "  $0 info MakeUbuntuUSB.ps1"
    exit 0
}

list_categories() {
    echo -e "${CYAN}📂 Available Script Categories:${NC}"
    echo
    
    for category_dir in "$SCRIPTS_DIR"/*; do
        if [[ -d "$category_dir" && "$(basename "$category_dir")" != "templates" ]]; then
            category=$(basename "$category_dir")
            script_count=$(find "$category_dir" -maxdepth 1 -type f \( -name "*.sh" -o -name "*.ps1" -o -name "*.py" \) | wc -l)
            
            echo -e "  ${GREEN}${category}${NC} (${script_count} scripts)"
            
            # Show scripts in category
            find "$category_dir" -maxdepth 1 -type f \( -name "*.sh" -o -name "*.ps1" -o -name "*.py" \) | while read -r script; do
                script_name=$(basename "$script")
                echo -e "    └── ${BLUE}${script_name}${NC}"
            done
            echo
        fi
    done
}

list_all_scripts() {
    echo -e "${CYAN}📋 All Available Scripts:${NC}"
    echo
    
    find "$SCRIPTS_DIR" -type f \( -name "*.sh" -o -name "*.ps1" -o -name "*.py" \) ! -path "*/templates/*" | sort | while read -r script; do
        script_name=$(basename "$script")
        category=$(basename "$(dirname "$script")")
        extension="${script_name##*.}"
        
        case $extension in
            sh) platform="🐧 Linux/macOS" ;;
            ps1) platform="🪟 Windows" ;;
            py) platform="🐍 Python" ;;
            *) platform="❓ Unknown" ;;
        esac
        
        echo -e "  ${GREEN}${script_name}${NC} [${YELLOW}${category}${NC}] - ${platform}"
    done
}

search_scripts() {
    local keyword="$1"
    echo -e "${CYAN}🔍 Searching for: '${keyword}'${NC}"
    echo
    
    found=false
    
    # Search in script names
    find "$SCRIPTS_DIR" -type f \( -name "*.sh" -o -name "*.ps1" -o -name "*.py" \) ! -path "*/templates/*" | while read -r script; do
        script_name=$(basename "$script")
        category=$(basename "$(dirname "$script")")
        
        if [[ "$script_name" =~ .*"$keyword".* ]] || [[ "$category" =~ .*"$keyword".* ]]; then
            echo -e "  📄 ${GREEN}${script_name}${NC} [${YELLOW}${category}${NC}]"
            found=true
        fi
    done
    
    # Search in README files for descriptions
    find "$SCRIPTS_DIR" -name "README.md" ! -path "*/templates/*" | while read -r readme; do
        category=$(basename "$(dirname "$readme")")
        if grep -qi "$keyword" "$readme" 2>/dev/null; then
            echo -e "  📖 Found in ${YELLOW}${category}${NC} documentation"
            # Show matching lines
            grep -i "$keyword" "$readme" | head -3 | sed 's/^/    /'
            found=true
        fi
    done
    
    if [[ "$found" == "false" ]]; then
        echo -e "  ${YELLOW}No scripts found matching '${keyword}'${NC}"
    fi
}

show_script_info() {
    local script_name="$1"
    echo -e "${CYAN}ℹ️  Information for: ${script_name}${NC}"
    echo
    
    # Find the script
    script_path=$(find "$SCRIPTS_DIR" -name "$script_name" ! -path "*/templates/*" | head -1)
    
    if [[ -z "$script_path" ]]; then
        echo -e "${YELLOW}Script '${script_name}' not found.${NC}"
        echo "Use '$0 list' to see available scripts."
        return 1
    fi
    
    category=$(basename "$(dirname "$script_path")")
    extension="${script_name##*.}"
    
    echo -e "📁 Category: ${GREEN}${category}${NC}"
    echo -e "📄 File: ${BLUE}${script_path}${NC}"
    
    case $extension in
        sh) echo -e "🐧 Platform: Linux/macOS (Bash)" ;;
        ps1) echo -e "🪟 Platform: Windows (PowerShell)" ;;
        py) echo -e "🐍 Platform: Cross-platform (Python)" ;;
    esac
    
    echo
    
    # Show first few lines of script for description
    echo -e "${CYAN}📝 Description:${NC}"
    case $extension in
        sh)
            grep -E "^#.*[Dd]escription|^# " "$script_path" | head -5 | sed 's/^# *//' | sed 's/^/  /'
            ;;
        ps1)
            grep -E "^\s*#.*[Dd]escription|^<#" -A 10 "$script_path" | head -10 | sed 's/^/  /'
            ;;
        py)
            grep -E '""".*[Dd]escription|^"""' -A 5 "$script_path" | head -8 | sed 's/^/  /'
            ;;
    esac
    
    echo
    
    # Check for category README
    readme_path="$(dirname "$script_path")/README.md"
    if [[ -f "$readme_path" ]]; then
        echo -e "${CYAN}📖 For detailed documentation, see:${NC}"
        echo -e "  ${BLUE}${readme_path}${NC}"
    fi
}

run_script() {
    local script_name="$1"
    shift
    
    script_path=$(find "$SCRIPTS_DIR" -name "$script_name" ! -path "*/templates/*" | head -1)
    
    if [[ -z "$script_path" ]]; then
        echo -e "${YELLOW}Script '${script_name}' not found.${NC}"
        return 1
    fi
    
    extension="${script_name##*.}"
    
    echo -e "${CYAN}🚀 Running: ${script_name}${NC}"
    echo -e "📁 Location: ${script_path}"
    echo
    
    # Safety prompt
    echo -e "${YELLOW}⚠️  You are about to execute a script. Please ensure you understand what it does.${NC}"
    read -p "Continue? (y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Execution cancelled."
        return 0
    fi
    
    # Execute based on file type
    case $extension in
        sh)
            if [[ -x "$script_path" ]]; then
                "$script_path" "$@"
            else
                bash "$script_path" "$@"
            fi
            ;;
        ps1)
            powershell -ExecutionPolicy Bypass -File "$script_path" "$@"
            ;;
        py)
            python3 "$script_path" "$@"
            ;;
        *)
            echo -e "${YELLOW}Don't know how to execute ${extension} files${NC}"
            return 1
            ;;
    esac
}

# Main logic
case "${1:-list}" in
    list|ls)
        list_all_scripts
        ;;
    categories|cat)
        list_categories
        ;;
    search|find)
        if [[ $# -lt 2 ]]; then
            echo "Usage: $0 search KEYWORD"
            exit 1
        fi
        search_scripts "$2"
        ;;
    info|show)
        if [[ $# -lt 2 ]]; then
            echo "Usage: $0 info SCRIPT_NAME"
            exit 1
        fi
        show_script_info "$2"
        ;;
    run|exec)
        if [[ $# -lt 2 ]]; then
            echo "Usage: $0 run SCRIPT_NAME [ARGS...]"
            exit 1
        fi
        shift
        run_script "$@"
        ;;
    -h|--help|help)
        usage
        ;;
    *)
        echo "Unknown command: $1"
        usage
        ;;
esac