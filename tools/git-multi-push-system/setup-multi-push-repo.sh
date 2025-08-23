#!/bin/bash

# Setup Multi-Push Repository Script
# Part of the Git Multi-Push System
# 
# This script sets up a new repository with multi-push configuration
# based on your configuration file settings.

set -e  # Exit on any error

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config/config.yaml"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_section() {
    echo -e "\n${CYAN}$1${NC}"
    echo "${CYAN}$(printf '=%.0s' $(seq 1 ${#1}))${NC}"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to parse YAML (simple key extraction)
get_config_value() {
    local key="$1"
    local config_file="$2"
    
    if [ -f "$config_file" ]; then
        # This is a simple YAML parser - works for basic key: value pairs
        grep "^[[:space:]]*$key:" "$config_file" | head -1 | sed 's/.*:[[:space:]]*//' | sed 's/["\x27]//g'
    fi
}

get_config_array() {
    local key="$1"
    local config_file="$2"
    
    if [ -f "$config_file" ]; then
        # Extract array values (assumes format: key: [item1, item2, item3])
        grep "^[[:space:]]*$key:" "$config_file" | head -1 | sed 's/.*:\[//' | sed 's/\]//' | sed 's/["\x27]//g' | tr ',' '\n' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//'
    fi
}

# Function to validate repository name
validate_repo_name() {
    local repo_name="$1"
    if [[ ! "$repo_name" =~ ^[a-zA-Z0-9._-]+$ ]]; then
        print_error "Invalid repository name. Use only letters, numbers, dots, underscores, and hyphens."
        return 1
    fi
    return 0
}

# Function to read configuration
load_configuration() {
    print_section "Loading Configuration"
    
    if [ ! -f "$CONFIG_FILE" ]; then
        print_warning "Configuration file not found: $CONFIG_FILE"
        print_info "Looking for config.yaml.example..."
        
        local example_config="$SCRIPT_DIR/config/config.yaml.example"
        if [ -f "$example_config" ]; then
            print_info "Using example configuration as template"
            CONFIG_FILE="$example_config"
        else
            print_error "No configuration found. Please create config/config.yaml"
            print_info "Run: ./git-multi-push.py --init"
            exit 1
        fi
    fi
    
    # Load basic configuration
    USERNAME=$(get_config_value "username" "$CONFIG_FILE")
    EMAIL=$(get_config_value "email" "$CONFIG_FILE")
    PRIMARY_SERVICE=$(get_config_value "primary_service" "$CONFIG_FILE")
    
    # Load push services (this is a simplified approach)
    PUSH_SERVICES_RAW=$(get_config_array "push_services" "$CONFIG_FILE")
    
    if [ -z "$USERNAME" ] || [ -z "$EMAIL" ]; then
        print_error "Username and email must be configured in config.yaml"
        exit 1
    fi
    
    if [ -z "$PRIMARY_SERVICE" ]; then
        print_warning "No primary service configured, defaulting to 'gitlab'"
        PRIMARY_SERVICE="gitlab"
    fi
    
    print_success "Configuration loaded successfully"
    print_info "Username: $USERNAME"
    print_info "Email: $EMAIL"
    print_info "Primary service: $PRIMARY_SERVICE"
}

# Function to initialize git repository
init_git_repo() {
    local repo_path="$1"
    local repo_name="$2"
    
    print_section "Initializing Git Repository"
    
    cd "$repo_path"
    
    # Initialize git if not already done
    if [ ! -d ".git" ]; then
        git init
        print_success "Git repository initialized"
    else
        print_info "Git repository already exists"
    fi
    
    # Set user configuration
    git config user.name "$USERNAME"
    git config user.email "$EMAIL"
    print_success "Git user configuration set"
    
    # Create initial commit if no commits exist
    if [ -z "$(git log --oneline 2>/dev/null)" ]; then
        # Create basic files if they don't exist
        if [ ! -f "README.md" ]; then
            cat > README.md << EOF
# $repo_name

## Description

Add your project description here.

## Installation

\`\`\`bash
# Add installation instructions
\`\`\`

## Usage

\`\`\`bash
# Add usage examples
\`\`\`

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## License

Add license information here.
EOF
            print_success "Created README.md"
        fi
        
        # Create .gitignore if it doesn't exist
        if [ ! -f ".gitignore" ]; then
            cat > .gitignore << EOF
# OS generated files
.DS_Store
.DS_Store?
._*
.Spotlight-V100
.Trashes
ehthumbs.db
Thumbs.db

# IDE files
.vscode/
.idea/
*.swp
*.swo

# Logs
*.log
logs/

# Runtime data
pids
*.pid
*.seed

# Environment variables
.env
.env.local
.env.development.local
.env.test.local
.env.production.local

# Dependency directories
node_modules/
vendor/

# Build outputs
dist/
build/
*.o
*.so

# Temporary files
tmp/
temp/
EOF
            print_success "Created .gitignore"
        fi
        
        git add README.md .gitignore
        git commit -m "Initial commit

Created basic project structure with README and .gitignore"
        print_success "Initial commit created"
    fi
}

# Function to configure multi-push using the Python script
configure_multi_push() {
    local repo_name="$1"
    
    print_section "Configuring Multi-Push"
    
    # Use the Python script to configure multi-push
    print_info "Using git-multi-push.py to configure remotes..."
    
    if [ -f "$SCRIPT_DIR/git-multi-push.py" ]; then
        python3 "$SCRIPT_DIR/git-multi-push.py" --repositories "$(pwd)" --config "$CONFIG_FILE"
        
        if [ $? -eq 0 ]; then
            print_success "Multi-push configuration completed"
            return 0
        else
            print_error "Failed to configure multi-push"
            return 1
        fi
    else
        print_warning "git-multi-push.py not found, configuring manually..."
        configure_multi_push_manual "$repo_name"
    fi
}

# Function to manually configure multi-push (fallback)
configure_multi_push_manual() {
    local repo_name="$1"
    
    print_info "Manual multi-push configuration"
    
    # This is a simplified manual configuration
    # In a real implementation, this would read the services.yaml and generate URLs
    
    local gitlab_url="https://gitlab.com/$USERNAME/$repo_name.git"
    local github_url="https://github.com/$USERNAME/$repo_name.git"
    local codeberg_url="https://codeberg.org/$USERNAME/$repo_name.git"
    
    print_info "Configuring remotes:"
    print_info "  GitLab (primary): $gitlab_url"
    print_info "  GitHub: $github_url"
    print_info "  Codeberg: $codeberg_url"
    
    # Remove existing origin if it exists
    git remote remove origin 2>/dev/null || true
    
    # Add GitLab as primary
    git remote add origin "$gitlab_url"
    
    # Add push URLs for multi-push
    git remote set-url --add --push origin "$gitlab_url"
    git remote set-url --add --push origin "$github_url"
    git remote set-url --add --push origin "$codeberg_url"
    
    print_success "Manual multi-push configuration completed"
}

# Function to show remote configuration
show_remote_config() {
    print_section "Remote Configuration"
    
    print_info "Current remote configuration:"
    git remote -v | sed 's/^/  /'
}

# Function to test connectivity
test_connectivity() {
    print_section "Testing Connectivity"
    
    # Get all push URLs
    local push_urls
    push_urls=$(git remote get-url --push --all origin 2>/dev/null)
    
    if [ -z "$push_urls" ]; then
        print_warning "No push URLs configured"
        return
    fi
    
    local all_success=true
    
    while IFS= read -r url; do
        local service_name
        if [[ "$url" == *"gitlab.com"* ]]; then
            service_name="GitLab"
        elif [[ "$url" == *"github.com"* ]]; then
            service_name="GitHub"
        elif [[ "$url" == *"codeberg.org"* ]]; then
            service_name="Codeberg"
        elif [[ "$url" == *"bitbucket.org"* ]]; then
            service_name="Bitbucket"
        elif [[ "$url" == keybase://* ]]; then
            service_name="Keybase"
        else
            service_name="Unknown Service"
        fi
        
        print_info "Testing $service_name connectivity..."
        
        # Use a timeout for the connectivity test
        if timeout 10 git ls-remote --exit-code "$url" &>/dev/null; then
            print_success "$service_name: Connection successful"
        else
            print_warning "$service_name: Connection failed (repository may not exist yet)"
            all_success=false
        fi
    done <<< "$push_urls"
    
    if [ "$all_success" = true ]; then
        print_success "All connectivity tests passed"
    else
        print_warning "Some connectivity tests failed. You may need to create repositories manually."
    fi
}

# Function to show repository creation guide
show_repository_creation_guide() {
    local repo_name="$1"
    
    print_section "Repository Creation Guide"
    
    echo ""
    echo "You need to manually create repositories on the following services:"
    echo ""
    
    # Parse push services from configuration and show creation instructions
    while IFS= read -r service; do
        case "$service" in
            "gitlab")
                echo "📍 GitLab (https://gitlab.com)"
                echo "   1. Go to https://gitlab.com/projects/new"
                echo "   2. Project name: $repo_name"
                echo "   3. Visibility: Choose as needed"
                echo "   4. ❗ IMPORTANT: Uncheck 'Initialize repository with a README'"
                echo ""
                ;;
            "github")
                echo "📍 GitHub (https://github.com)"
                echo "   1. Go to https://github.com/new"
                echo "   2. Repository name: $repo_name"
                echo "   3. Visibility: Choose as needed"
                echo "   4. ❗ IMPORTANT: Don't initialize with README, .gitignore, or license"
                echo ""
                ;;
            "codeberg")
                echo "📍 Codeberg (https://codeberg.org)"
                echo "   1. Go to https://codeberg.org/repo/create"
                echo "   2. Repository name: $repo_name"
                echo "   3. Visibility: Choose as needed"
                echo "   4. ❗ IMPORTANT: Don't initialize with selected files"
                echo ""
                ;;
            "keybase")
                echo "📍 Keybase"
                echo "   • Keybase repositories are created automatically on first push"
                echo "   • Ensure Keybase client is installed and you're logged in"
                echo ""
                ;;
        esac
    done <<< "$PUSH_SERVICES_RAW"
}

# Function to perform initial push
initial_push() {
    local branch_name
    branch_name=$(git branch --show-current)
    
    print_section "Initial Push"
    
    print_info "Preparing to push to branch: $branch_name"
    
    echo ""
    read -p "Attempt initial push to all remotes now? (y/N): " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Pushing to all configured remotes..."
        
        if git push -u origin "$branch_name" 2>/dev/null; then
            print_success "Initial push successful to all remotes!"
        else
            print_warning "Initial push failed. This is expected if repositories don't exist yet."
            print_info "Create the repositories manually first, then run:"
            print_info "  git push -u origin $branch_name"
        fi
    else
        print_info "Skipping initial push."
        print_info "When repositories are created, run:"
        print_info "  git push -u origin $branch_name"
    fi
}

# Function to show next steps
show_next_steps() {
    local repo_name="$1"
    
    print_section "Next Steps"
    
    echo ""
    echo "🎉 Repository setup complete!"
    echo ""
    echo "Next steps:"
    echo "  1. Create repositories manually on your configured services"
    echo "  2. Run 'git push -u origin main' to push to all remotes"
    echo "  3. All future pushes will automatically go to all configured services"
    echo ""
    echo "Useful commands:"
    echo "  git remote -v                    # View configured remotes"
    echo "  git push                         # Push to all services"
    echo "  ./analyze-git-repos.py          # Analyze repository status"
    echo "  ./git-multi-push.py --help      # See migration options"
    echo ""
}

# Main function
main() {
    print_section "Git Multi-Push Repository Setup"
    
    # Check dependencies
    if ! command_exists git; then
        print_error "Git is not installed or not in PATH"
        exit 1
    fi
    
    if ! command_exists python3; then
        print_warning "Python3 not found. Some features may not work."
    fi
    
    # Load configuration
    load_configuration
    
    # Get repository name
    local repo_name
    if [ $# -eq 0 ]; then
        echo ""
        read -p "Enter repository name: " repo_name
    else
        repo_name="$1"
    fi
    
    # Validate repository name
    if ! validate_repo_name "$repo_name"; then
        exit 1
    fi
    
    # Determine repository path
    local repo_path
    if [ -d "$repo_name" ]; then
        repo_path="$(pwd)/$repo_name"
        print_info "Using existing directory: $repo_path"
    elif [ -f "README.md" ] || [ -f ".git/config" ]; then
        repo_path="$(pwd)"
        repo_name=$(basename "$repo_path")
        print_info "Using current directory: $repo_path"
        print_info "Repository name: $repo_name"
    else
        repo_path="$(pwd)/$repo_name"
        print_info "Creating new directory: $repo_path"
        mkdir -p "$repo_path"
    fi
    
    # Setup repository
    init_git_repo "$repo_path" "$repo_name"
    
    # Configure multi-push
    configure_multi_push "$repo_name"
    
    # Show configuration
    show_remote_config
    
    # Test connectivity
    test_connectivity
    
    # Show creation guide
    show_repository_creation_guide "$repo_name"
    
    # Offer initial push
    initial_push
    
    # Show next steps
    show_next_steps "$repo_name"
}

# Help function
show_help() {
    cat << EOF
Git Multi-Push Repository Setup Script

This script sets up a new repository with multi-push configuration for
multiple git hosting services based on your config.yaml settings.

Usage:
  $0 [repository-name]
  $0 --help

Arguments:
  repository-name    Name of the repository to create/setup

Examples:
  $0                      # Interactive mode - prompts for repository name
  $0 my-new-project      # Setup repository named 'my-new-project'

Requirements:
  - Git installed and configured
  - config/config.yaml file with your settings
  - Python 3 (optional, for advanced features)

The script will:
  1. Initialize a git repository (if needed)
  2. Create basic files (README.md, .gitignore)
  3. Configure multi-push remotes based on your config.yaml
  4. Test connectivity to remotes
  5. Guide you through manual repository creation
  6. Offer to perform initial push

Configuration:
  Edit config/config.yaml to set:
  - Your username and email
  - Primary service (for fetch operations)
  - Push services (array of services to push to)

EOF
}

# Check for help flag
if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    show_help
    exit 0
fi

# Run main function
main "$@"