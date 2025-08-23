# Git Multi-Push System

A platform and user-agnostic tool for configuring git repositories to push to multiple hosting services simultaneously, providing redundancy, platform independence, and automated backup capabilities.

## 🌟 Features

### Platform Agnostic
- **Any git hosting service**: GitHub, GitLab, Codeberg, Bitbucket, Keybase, Gitea, Forgejo, and more
- **Self-hosted support**: Configure custom domains for enterprise installations
- **Flexible authentication**: Token, SSH, or username/password authentication
- **Easy service addition**: Add new services via simple YAML configuration

### User Agnostic
- **Configuration-driven**: No hardcoded usernames or URLs
- **Multi-user ready**: Different usernames per service if needed
- **Team-friendly**: Shareable configuration templates
- **Environment-specific**: Different configs for development, staging, production

### Migration Scenarios
- **GitHub → GitLab**: Common corporate migration path
- **Single → Multi**: Add redundancy to existing repositories
- **Platform consolidation**: Migrate from multiple services to fewer
- **Backup strategies**: Automated push to backup services

### Safety & Reliability
- **Dry-run mode**: Test configurations before applying changes
- **Configuration backups**: Automatic `.git/config` backups
- **Batch processing**: Process multiple repositories safely
- **Error recovery**: Rollback capabilities and retry logic
- **Connectivity testing**: Verify remote access before migration

## 🚀 Quick Start

### 1. Installation
```bash
# Clone or download the Git Multi-Push System
git clone https://github.com/your-username/useful-scripts.git
cd useful-scripts/git-multi-push-system

# Or download individual files to your project
```

### 2. Initialize Configuration
```bash
# Create your configuration file
./git-multi-push.py --init

# Edit the generated config.yaml with your details
vim config/config.yaml
```

### 3. Configure Your Services
Edit `config/config.yaml`:
```yaml
user:
  username: "your-username"
  email: "your-email@example.com"

multi_push:
  primary_service: "gitlab"
  push_services: ["gitlab", "github", "codeberg"]

services:
  gitlab:
    auth_method: "token"
  github:
    auth_method: "token"
  codeberg:
    auth_method: "token"
```

### 4. Set Authentication
```bash
# Set environment variables for tokens
export GITLAB_TOKEN="your-gitlab-token"
export GITHUB_TOKEN="your-github-token"
export CODEBERG_TOKEN="your-codeberg-token"
```

### 5. Analyze Existing Repositories
```bash
# See what repositories you have and their current configuration
./analyze-git-repos.py

# Analyze specific directory
./analyze-git-repos.py --scan-path ~/Code
```

### 6. Migrate Repositories
```bash
# Test migration (safe, no changes)
./git-multi-push.py --repositories my-repo --dry-run

# Migrate specific repositories
./git-multi-push.py --repositories repo1,repo2,repo3

# Migrate all repositories in scan paths
./git-multi-push.py --all
```

### 7. Set Up New Repositories
```bash
# Interactive setup for new projects
./setup-multi-push-repo.sh

# Direct setup
./setup-multi-push-repo.sh my-new-project
```

## 📋 Configuration

### Basic Configuration (config.yaml)
```yaml
# User settings
user:
  username: "your-username"
  email: "your-email@example.com"

# Multi-push setup
multi_push:
  primary_service: "gitlab"          # Service used for git pull
  push_services: ["gitlab", "github", "codeberg"]  # Services for git push

# Service-specific settings
services:
  gitlab:
    auth_method: "token"             # token, ssh, or basic
  github:
    auth_method: "ssh"
  codeberg:
    custom_domain: "codeberg.org"    # For self-hosted services
```

### Preset Configurations
Use pre-built configurations for common scenarios:

```bash
# GitHub to GitLab migration
./git-multi-push.py --preset github-to-gitlab --all --dry-run

# Triple redundancy setup
./git-multi-push.py --preset triple-redundancy --repositories important-project

# Enterprise backup
./git-multi-push.py --preset enterprise-backup --scan-path ~/work-projects
```

### Supported Services
The system includes built-in support for:

- **GitHub** (`github.com`)
- **GitLab** (`gitlab.com`)
- **Codeberg** (`codeberg.org`) - FOSS-focused
- **Bitbucket** (`bitbucket.org`)
- **Keybase** (`keybase://`) - Encrypted distributed
- **Self-hosted services**:
  - Gitea
  - Forgejo
  - GitLab self-hosted
  - GitHub Enterprise

## 🛠️ Tools Overview

### Main Migration Tool
**`git-multi-push.py`** - Core migration and configuration tool
- Batch process multiple repositories
- Configuration-driven service setup
- Safety features (dry-run, backups, rollback)
- Flexible repository selection

### Repository Analysis
**`analyze-git-repos.py`** - Understand your current repository setup
- Discover all git repositories in specified paths
- Analyze current remote configurations
- Identify migration needs and complexity
- Generate detailed reports

### New Repository Setup
**`setup-multi-push-repo.sh`** - Set up new repositories with multi-push from the start
- Initialize git repository
- Create basic project files
- Configure multi-push remotes
- Guide through manual repository creation

## 📚 Usage Examples

### Migration Scenarios

#### Migrate from GitHub to GitLab (keep GitHub as backup)
```bash
# 1. Configure services
vim config/config.yaml  # Set primary_service: "gitlab", push_services: ["gitlab", "github"]

# 2. Test migration
./git-multi-push.py --repositories my-project --dry-run

# 3. Create GitLab repositories manually (see guide below)

# 4. Migrate
./git-multi-push.py --repositories my-project
```

#### Add Redundancy to Existing Repositories
```bash
# 1. Analyze current setup
./analyze-git-repos.py --output current-state.json

# 2. Configure additional services in config.yaml

# 3. Batch migrate all repositories
./git-multi-push.py --all --dry-run  # Test first
./git-multi-push.py --all             # Apply changes
```

#### Corporate Migration (Enterprise → External Backup)
```bash
# Use the enterprise preset
./git-multi-push.py --preset enterprise-backup --scan-path ~/work --dry-run

# Customize for your enterprise domain in config.yaml:
# services:
#   github_enterprise:
#     custom_domain: "github.yourcompany.com"
```

### Analysis and Reporting

#### Comprehensive Repository Analysis
```bash
# Analyze all repositories and save detailed report
./analyze-git-repos.py --output analysis-report.json --format detailed

# Quick summary of current state
./analyze-git-repos.py --format summary

# Analyze specific directory
./analyze-git-repos.py --scan-path ~/important-projects --format detailed
```

#### Check Migration Status
```bash
# See which repositories still need migration
./analyze-git-repos.py --format detailed | grep "needs_migration: true"

# Generate report after migration
./analyze-git-repos.py --output post-migration-report.json
```

### New Project Workflows

#### Start a New Multi-Push Project
```bash
# Interactive setup (recommended for first time)
./setup-multi-push-repo.sh

# Direct setup if you know the project name
./setup-multi-push-repo.sh awesome-new-project

# The script will:
# 1. Create git repository
# 2. Add README.md and .gitignore
# 3. Configure multi-push remotes
# 4. Guide you through creating repositories on each service
```

## 🔧 Advanced Configuration

### Custom Service Definitions
Add new services by editing `config/services.yaml`:

```yaml
services:
  my_custom_gitea:
    name: "Custom Gitea"
    domain: "git.mycompany.com"
    url_template: "https://{custom_domain}/{username}/{repo}.git"
    auth_url_template: "https://{username}:{token}@{custom_domain}/{username}/{repo}.git"
    api_base: "https://{custom_domain}/api/v1"
    auth_methods: ["token", "ssh"]
    requires_custom_domain: true
```

### Repository-Specific Overrides
Configure different services for specific repositories:

```yaml
repositories:
  overrides:
    sensitive-project:
      push_services: ["gitlab"]  # Only internal GitLab
    open-source-tool:
      push_services: ["github", "codeberg"]  # Public services only
```

### Advanced Migration Settings
```yaml
migration:
  create_backups: true           # Backup .git/config before changes
  dry_run_by_default: false     # Always do dry run unless --force
  batch_size: 5                 # Process N repositories at a time
  delay_between_repos: 2        # Seconds to wait between repositories
  stop_on_first_error: true     # Stop on first error vs. continue
  max_retries: 3                # Retry failed operations
```

## 📖 Manual Repository Creation Guide

After configuring multi-push, you need to create repositories on each service:

### GitLab
1. Go to https://gitlab.com/projects/new
2. **Project name**: Enter your repository name
3. **Visibility**: Choose public/private
4. **❗ IMPORTANT**: Uncheck "Initialize repository with a README"
5. Click "Create project"

### GitHub
1. Go to https://github.com/new
2. **Repository name**: Enter your repository name
3. **Visibility**: Choose public/private
4. **❗ IMPORTANT**: Don't initialize with README, .gitignore, or license
5. Click "Create repository"

### Codeberg
1. Go to https://codeberg.org/repo/create
2. **Repository name**: Enter your repository name
3. **Visibility**: Choose public/private
4. **❗ IMPORTANT**: Uncheck "Initialize this repository with selected files and template"
5. Click "Create Repository"

### Self-Hosted Services
- Use the same pattern as above
- Navigate to your instance's "new repository" page
- Ensure you don't initialize with any files

### Automated Repository Creation (Advanced)
Some services support API-based repository creation. See the `SERVICES.md` file for API examples.

## 🔐 Authentication Setup

### Personal Access Tokens (Recommended)

#### GitLab
1. Go to GitLab → Settings → Access Tokens
2. Create token with `api` scope
3. `export GITLAB_TOKEN="your-token"`

#### GitHub
1. Go to GitHub → Settings → Developer settings → Personal access tokens
2. Create token with `repo` scope
3. `export GITHUB_TOKEN="your-token"`

#### Codeberg
1. Go to Codeberg → Settings → Applications
2. Generate new token
3. `export CODEBERG_TOKEN="your-token"`

### SSH Keys (Alternative)
1. Generate SSH key: `ssh-keygen -t ed25519 -C "your-email@example.com"`
2. Add public key to each service
3. Set `auth_method: "ssh"` in config.yaml

### Environment Variable Management
```bash
# Add to your shell profile (.bashrc, .zshrc, etc.)
export GITLAB_TOKEN="your-gitlab-token"
export GITHUB_TOKEN="your-github-token" 
export CODEBERG_TOKEN="your-codeberg-token"

# Or use a .env file (not recommended for production)
echo "GITLAB_TOKEN=your-token" >> .env
source .env
```

## 🚨 Troubleshooting

### Common Issues

#### "No configuration found"
```bash
# Solution: Initialize configuration
./git-multi-push.py --init
# Then edit config/config.yaml with your details
```

#### "Authentication failed"
```bash
# Check your tokens are set
echo $GITLAB_TOKEN
echo $GITHUB_TOKEN

# Verify token permissions (should include 'repo' or 'api' scope)
# Try manual git operation to test auth:
git ls-remote https://username:token@gitlab.com/username/repo.git
```

#### "Repository not found on service"
```bash
# You need to create repositories manually first
# See the "Manual Repository Creation Guide" above

# Then retry the migration:
./git-multi-push.py --repositories your-repo
```

#### "Git command failed"
```bash
# Check git configuration
git config --list

# Ensure git user is configured
git config user.name "Your Name"
git config user.email "your-email@example.com"
```

### Recovery Procedures

#### Restore Original Configuration
```bash
# Configuration backups are automatically created
cd your-repository
ls .git/config.backup*

# Restore if needed
cp .git/config.backup.20240101_120000 .git/config
```

#### Reset Remote Configuration
```bash
# Remove all remotes and start over
git remote remove origin
git remote add origin https://your-primary-service.com/username/repo.git
```

#### Connectivity Issues
```bash
# Test connectivity manually
git ls-remote --exit-code https://gitlab.com/username/repo.git
git ls-remote --exit-code https://github.com/username/repo.git

# Check firewall/network issues
curl -I https://gitlab.com
curl -I https://github.com
```

## 🔧 Development and Customization

### Adding New Services
1. Edit `config/services.yaml`
2. Add service definition with URL templates
3. Test with a sample repository
4. Submit pull request (if contributing back)

### Custom Presets
Create custom preset files in `config/presets/`:
```yaml
name: "My Custom Setup"
description: "Corporate + Personal backup strategy"
multi_push:
  primary_service: "github_enterprise"
  push_services: ["github_enterprise", "gitlab", "codeberg"]
```

### Extending the Tools
The Python scripts use modular design:
- `GitMultiPushManager`: Core migration logic
- `GitRepositoryAnalyzer`: Repository analysis
- YAML-based configuration system
- Pluggable service definitions

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/new-service`
3. Add your changes (new services, presets, fixes)
4. Test with multiple scenarios
5. Update documentation
6. Submit pull request

### Areas for Contribution
- **New service support**: Add popular git hosting services
- **API integrations**: Automated repository creation
- **Migration presets**: Common migration scenarios
- **Documentation**: Usage examples, troubleshooting
- **Testing**: Test with different service combinations

## 📄 License

MIT License - see LICENSE file for details.

## 🙏 Acknowledgments

- Git community for the excellent version control system
- All the git hosting services that enable open collaboration
- Contributors who help improve this tool

## 📞 Support

- **Issues**: Report bugs and request features via GitHub issues
- **Discussions**: Ask questions in GitHub discussions
- **Documentation**: Check the `/docs` directory for detailed guides
- **Examples**: See `/examples` for real-world usage scenarios

---

**Start achieving git platform independence and redundancy today!**

Whether you're migrating between services, adding backup redundancy, or setting up new projects with multi-push from the start, the Git Multi-Push System provides the tools and flexibility you need.