# Supported Services - Git Multi-Push System

This document details all supported git hosting services, their configuration options, and how to add new services.

## 🌍 Supported Services

### Major Hosted Services

#### GitHub (`github.com`)
- **Authentication**: Token, SSH
- **API Support**: Yes (v3 REST API)
- **Features**: Issues, PRs, Actions, Packages
- **Best For**: Open source, community projects, GitHub Pages

**Configuration:**
```yaml
github:
  auth_method: "token"  # or "ssh"
  # Token environment variable: GITHUB_TOKEN
```

**API Examples:**
```bash
# Create repository via API
curl -H "Authorization: token $GITHUB_TOKEN" \
     -d '{"name":"repo-name","private":false}' \
     https://api.github.com/user/repos

# List user repositories
curl -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/user/repos
```

#### GitLab (`gitlab.com`)
- **Authentication**: Token, SSH
- **API Support**: Yes (v4 REST API)
- **Features**: Issues, MRs, CI/CD, Package Registry, Container Registry
- **Best For**: DevOps, CI/CD, private projects

**Configuration:**
```yaml
gitlab:
  auth_method: "token"  # or "ssh"
  # Token environment variable: GITLAB_TOKEN
```

**API Examples:**
```bash
# Create repository via API
curl -H "PRIVATE-TOKEN: $GITLAB_TOKEN" \
     -H "Content-Type: application/json" \
     -d '{"name":"repo-name","visibility":"private"}' \
     https://gitlab.com/api/v4/projects

# List user projects
curl -H "PRIVATE-TOKEN: $GITLAB_TOKEN" https://gitlab.com/api/v4/projects
```

#### Codeberg (`codeberg.org`)
- **Authentication**: Token, SSH, Basic Auth
- **API Support**: Yes (Gitea API v1)
- **Features**: Issues, PRs, Actions, Pages
- **Best For**: FOSS projects, privacy-focused, EU-based hosting

**Configuration:**
```yaml
codeberg:
  auth_method: "token"  # or "ssh" or "basic"
  # Token environment variable: CODEBERG_TOKEN
```

**API Examples:**
```bash
# Create repository via API
curl -H "Authorization: token $CODEBERG_TOKEN" \
     -H "Content-Type: application/json" \
     -d '{"name":"repo-name","private":false}' \
     https://codeberg.org/api/v1/user/repos

# List user repositories
curl -H "Authorization: token $CODEBERG_TOKEN" https://codeberg.org/api/v1/user/repos
```

#### Bitbucket (`bitbucket.org`)
- **Authentication**: App Password, SSH
- **API Support**: Yes (v2.0 REST API)
- **Features**: Issues, PRs, Pipelines, Deployments
- **Best For**: Atlassian ecosystem, Jira integration

**Configuration:**
```yaml
bitbucket:
  auth_method: "app_password"  # or "ssh"
  # Token environment variable: BITBUCKET_TOKEN
```

**API Examples:**
```bash
# Create repository via API (requires workspace)
curl -X POST -H "Authorization: Bearer $BITBUCKET_TOKEN" \
     -H "Content-Type: application/json" \
     -d '{"name":"repo-name","is_private":true}' \
     https://api.bitbucket.org/2.0/repositories/your-workspace/repo-name
```

### Specialized Services

#### Keybase (`keybase://`)
- **Authentication**: Keybase client
- **API Support**: No (uses Keybase KBFS)
- **Features**: Encrypted, distributed, team-based
- **Best For**: Private projects, encrypted backup, team collaboration

**Configuration:**
```yaml
keybase:
  auth_method: "keybase_client"
  # Requires: Keybase client installed and logged in
```

**Setup:**
```bash
# Install Keybase client
curl --remote-name https://prerelease.keybase.io/keybase_amd64.deb
sudo dpkg -i keybase_amd64.deb

# Login and start service
keybase login
keybase service

# Create repository (automatic on first push)
git push keybase://private/username/repo-name
```

### Self-Hosted Solutions

#### Gitea
- **Authentication**: Token, SSH, Basic Auth
- **API Support**: Yes (v1 REST API, compatible with GitHub API v3)
- **Features**: Issues, PRs, Packages, Actions
- **Best For**: Self-hosted, lightweight, Docker deployments

**Configuration:**
```yaml
gitea:
  custom_domain: "git.yourdomain.com"
  auth_method: "token"  # or "ssh" or "basic"
  # Token environment variable: GITEA_TOKEN
```

**Installation:**
```bash
# Docker deployment
docker run -d --name=gitea -p 22:22 -p 3000:3000 \
  -v /var/lib/gitea:/data \
  -v /etc/timezone:/etc/timezone:ro \
  -v /etc/localtime:/etc/localtime:ro \
  gitea/gitea:latest
```

#### Forgejo
- **Authentication**: Token, SSH, Basic Auth  
- **API Support**: Yes (v1 REST API, Gitea-compatible)
- **Features**: Issues, PRs, Packages, Actions
- **Best For**: Community-driven fork of Gitea, enhanced privacy features

**Configuration:**
```yaml
forgejo:
  custom_domain: "forge.yourdomain.com"
  auth_method: "token"
  # Token environment variable: FORGEJO_TOKEN
```

#### GitLab Self-Hosted
- **Authentication**: Token, SSH
- **API Support**: Yes (v4 REST API, same as GitLab.com)
- **Features**: Full GitLab feature set
- **Best For**: Enterprise environments, full DevOps platform

**Configuration:**
```yaml
gitlab_self_hosted:
  custom_domain: "gitlab.company.com"
  auth_method: "token"
  # Token environment variable: GITLAB_SELF_HOSTED_TOKEN
```

#### GitHub Enterprise
- **Authentication**: Token, SSH
- **API Support**: Yes (v3 REST API, same as GitHub.com)
- **Features**: Full GitHub feature set + enterprise features
- **Best For**: Large organizations, compliance requirements

**Configuration:**
```yaml
github_enterprise:
  custom_domain: "github.company.com"
  auth_method: "token"
  # Token environment variable: GITHUB_ENTERPRISE_TOKEN
```

## 🔧 Adding New Services

### Step 1: Define Service in services.yaml

Add your service definition to `config/services.yaml`:

```yaml
services:
  your_service:
    name: "Your Service Name"
    domain: "git.yourservice.com"  # or "{custom_domain}" for self-hosted
    url_template: "https://{domain}/{username}/{repo}.git"
    auth_url_template: "https://{username}:{token}@{domain}/{username}/{repo}.git"
    ssh_url_template: "git@{domain}:{username}/{repo}.git"
    api_base: "https://{domain}/api/v1"  # Optional: for API operations
    auth_methods: ["token", "ssh", "basic"]
    token_env_var: "YOUR_SERVICE_TOKEN"
    description: "Description of your service"
    requires_custom_domain: false  # true for self-hosted
```

### Step 2: Template Variables

Available template variables:
- `{username}`: User's username on the service
- `{repo}`: Repository name
- `{domain}`: Service domain (from domain field)
- `{custom_domain}`: Custom domain (for self-hosted services)
- `{token}`: Authentication token (when using token auth)

### Step 3: Authentication Methods

Supported authentication methods:
- **`token`**: Personal access token or API token
- **`ssh`**: SSH key authentication  
- **`basic`**: Username and password
- **`app_password`**: App-specific password (Bitbucket)
- **`keybase_client`**: Keybase client authentication

### Step 4: Test Your Service

```bash
# Test URL generation
./git-multi-push.py --repositories test-repo --dry-run

# Test actual migration
./git-multi-push.py --repositories test-repo

# Test push operation
cd test-repo
git push
```

### Step 5: Add API Support (Optional)

For automated repository creation, add API endpoints:

```yaml
your_service:
  api_base: "https://{domain}/api/v1"
  api_endpoints:
    create_repo: "/user/repos"
    list_repos: "/user/repos" 
    get_repo: "/repos/{username}/{repo}"
```

### Example: Adding SourceForge

```yaml
services:
  sourceforge:
    name: "SourceForge"
    domain: "git.code.sf.net"
    url_template: "https://git.code.sf.net/p/{username}/{repo}"
    ssh_url_template: "ssh://{username}@git.code.sf.net/p/{username}/{repo}"
    auth_methods: ["ssh", "basic"]
    description: "SourceForge - Long-running FOSS hosting"
    special_handling: true  # Non-standard URL structure
```

## 🔐 Authentication Setup Guide

### Token-Based Authentication

#### Creating Personal Access Tokens

**GitHub:**
1. Go to Settings → Developer settings → Personal access tokens
2. Click "Generate new token"
3. Select scopes: `repo` (for private repos) or `public_repo` (for public only)
4. Copy token and set: `export GITHUB_TOKEN="your-token"`

**GitLab:**
1. Go to Preferences → Access Tokens
2. Create token with `api` scope
3. Set: `export GITLAB_TOKEN="your-token"`

**Codeberg:**
1. Go to Settings → Applications
2. Generate new token
3. Set: `export CODEBERG_TOKEN="your-token"`

#### Token Permissions Required
- **GitHub**: `repo` scope for full access, `public_repo` for public repositories only
- **GitLab**: `api` scope for full API access
- **Codeberg**: Basic token with repository access
- **Bitbucket**: App password with repository read/write permissions

### SSH Key Authentication

#### Setup Process
```bash
# 1. Generate SSH key (if you don't have one)
ssh-keygen -t ed25519 -C "your-email@example.com"

# 2. Add public key to each service
cat ~/.ssh/id_ed25519.pub
# Copy and paste to service's SSH key settings

# 3. Configure service to use SSH
# In config.yaml:
services:
  github:
    auth_method: "ssh"
```

#### SSH Configuration
Add to `~/.ssh/config` for custom domains:
```
Host git.company.com
    HostName git.company.com
    User git
    IdentityFile ~/.ssh/id_ed25519
```

### Environment Variable Management

#### Development Environment
```bash
# Add to ~/.bashrc or ~/.zshrc
export GITHUB_TOKEN="ghp_xxxxxxxxxxxx"
export GITLAB_TOKEN="glpat-xxxxxxxxxxxx" 
export CODEBERG_TOKEN="your-codeberg-token"
export GITEA_TOKEN="your-gitea-token"
```

#### Production Environment
```bash
# Use environment files (more secure)
echo "GITHUB_TOKEN=ghp_xxxxxxxxxxxx" > .env
echo "GITLAB_TOKEN=glpat-xxxxxxxxxxxx" >> .env
chmod 600 .env
source .env
```

#### Docker Environment
```yaml
# docker-compose.yml
version: '3'
services:
  git-multi-push:
    environment:
      - GITHUB_TOKEN=${GITHUB_TOKEN}
      - GITLAB_TOKEN=${GITLAB_TOKEN}
      - CODEBERG_TOKEN=${CODEBERG_TOKEN}
```

## 🚀 Service-Specific Features

### GitHub-Specific Features
- **GitHub Pages**: Automatic deployment from repository
- **GitHub Actions**: CI/CD workflows
- **GitHub Packages**: Package registry
- **Dependabot**: Automated dependency updates

### GitLab-Specific Features  
- **GitLab CI/CD**: Built-in continuous integration
- **Issue Boards**: Kanban-style project management
- **Container Registry**: Docker image hosting
- **GitLab Pages**: Static site hosting

### Codeberg-Specific Features
- **Codeberg Pages**: Static site hosting for FOSS projects
- **Privacy Focus**: No tracking, EU-based
- **Woodpecker CI**: Lightweight CI/CD integration
- **FOSS Community**: Dedicated to free and open source software

### Self-Hosted Advantages
- **Data Control**: Keep your code on your infrastructure
- **Customization**: Modify the platform to your needs
- **Security**: Air-gapped or VPN-only access
- **Compliance**: Meet specific regulatory requirements

## 📊 Service Comparison Matrix

| Service | Public Repos | Private Repos | CI/CD | Issues | API | Self-Hosted |
|---------|-------------|---------------|--------|--------|-----|-------------|
| GitHub | ✅ Free | ✅ Paid | Actions | ✅ | v3 REST | Enterprise |
| GitLab | ✅ Free | ✅ Free | Built-in | ✅ | v4 REST | ✅ |
| Codeberg | ✅ Free | ✅ Free | Woodpecker | ✅ | Gitea API | ❌ |
| Bitbucket | ✅ Free | ✅ Limited | Pipelines | ✅ | v2 REST | Server |
| Keybase | ❌ | ✅ Free | ❌ | ❌ | ❌ | ❌ |
| Gitea | N/A | N/A | Actions | ✅ | v1 REST | ✅ |
| Forgejo | N/A | N/A | Actions | ✅ | v1 REST | ✅ |

## 🔍 Service Selection Guide

### For Open Source Projects
1. **GitHub** - Maximum visibility and community
2. **Codeberg** - FOSS-focused, privacy-respecting
3. **GitLab** - Additional DevOps features

### For Private Projects
1. **GitLab** - Free private repositories, full feature set
2. **GitHub** - Best ecosystem, paid for advanced features
3. **Keybase** - Encrypted, secure, team-based

### For Enterprise
1. **GitLab Self-Hosted** - Complete DevOps platform
2. **GitHub Enterprise** - Enterprise features, GitHub ecosystem
3. **Gitea/Forgejo** - Lightweight, easy to maintain

### For Backup/Redundancy
1. **Multiple major services** - Different geographical locations
2. **Mix of hosted + self-hosted** - Ultimate redundancy
3. **Include Keybase** - Encrypted, distributed backup

## 🚨 Service-Specific Troubleshooting

### GitHub Issues
```bash
# Test GitHub API access
curl -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/user

# Check token scopes
curl -H "Authorization: token $GITHUB_TOKEN" -I https://api.github.com/user | grep -i x-oauth-scopes
```

### GitLab Issues
```bash
# Test GitLab API access
curl -H "PRIVATE-TOKEN: $GITLAB_TOKEN" https://gitlab.com/api/v4/user

# Check GitLab instance version
curl https://gitlab.com/api/v4/version
```

### SSH Issues
```bash
# Test SSH connectivity
ssh -T git@github.com
ssh -T git@gitlab.com
ssh -T git@codeberg.org

# Debug SSH connection
ssh -vT git@github.com
```

### Self-Hosted Issues
```bash
# Check custom domain accessibility
curl -I https://git.yourdomain.com

# Test API endpoint
curl -H "Authorization: token $TOKEN" https://git.yourdomain.com/api/v1/user
```

This comprehensive service guide ensures you can successfully configure and use any git hosting service with the Git Multi-Push System.