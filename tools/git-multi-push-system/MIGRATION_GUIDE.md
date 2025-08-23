# Migration Guide - Git Multi-Push System

This comprehensive guide walks through common migration scenarios step-by-step, from initial analysis through successful deployment.

## 🎯 Migration Scenarios

### Scenario 1: GitHub → GitLab (Corporate Migration)

**Use Case**: Company switching from GitHub to GitLab while keeping GitHub as backup.

#### Step 1: Analysis
```bash
# Analyze current repositories
./analyze-git-repos.py --scan-path ~/work-projects --output pre-migration.json

# Review what you have
./analyze-git-repos.py --format detailed | grep -A 5 "github"
```

#### Step 2: Configuration
```bash
# Initialize configuration
./git-multi-push.py --init

# Edit config/config.yaml:
```
```yaml
user:
  username: "your-work-username"
  email: "you@company.com"

multi_push:
  primary_service: "gitlab"          # GitLab becomes primary
  push_services: ["gitlab", "github"] # Push to both

services:
  gitlab:
    auth_method: "token"
  github:
    auth_method: "token"
```

#### Step 3: Authentication Setup
```bash
# Set up tokens
export GITLAB_TOKEN="your-gitlab-token"
export GITHUB_TOKEN="your-github-token"

# Test authentication
git ls-remote https://gitlab.com/your-username/test-repo.git
```

#### Step 4: Repository Creation
Create corresponding GitLab repositories for each GitHub repo:
- Go to https://gitlab.com/projects/new
- Use same repository names
- Don't initialize with README

#### Step 5: Migration (Test First)
```bash
# Test with one repository
./git-multi-push.py --repositories important-project --dry-run

# If successful, migrate a few repositories
./git-multi-push.py --repositories project1,project2,project3

# Finally, migrate all
./git-multi-push.py --all
```

#### Step 6: Verification
```bash
# Analyze post-migration state
./analyze-git-repos.py --output post-migration.json

# Test push to verify everything works
cd important-project
echo "Test change" >> README.md
git add README.md
git commit -m "Test multi-push"
git push  # Should push to both GitLab and GitHub
```

---

### Scenario 2: Single Service → Triple Redundancy

**Use Case**: Adding backup redundancy to existing repositories.

#### Step 1: Current State Analysis
```bash
# See what services you're currently using
./analyze-git-repos.py --format summary

# Get detailed breakdown
./analyze-git-repos.py --format detailed --output current-state.json
```

#### Step 2: Triple Redundancy Configuration
```bash
# Use the triple redundancy preset
cp config/presets/triple-redundancy.yaml config/config.yaml

# Customize with your details:
```
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

#### Step 3: Environment Setup
```bash
# Set all required tokens
export GITLAB_TOKEN="your-gitlab-token"
export GITHUB_TOKEN="your-github-token"
export CODEBERG_TOKEN="your-codeberg-token"
```

#### Step 4: Repository Creation Strategy
Create repositories on missing services:

**Batch creation approach:**
1. List all your repositories: `./analyze-git-repos.py --format json | jq '.repositories[].name'`
2. Create them on each service (GitLab, GitHub, Codeberg)
3. Use the manual creation guide in README.md

#### Step 5: Phased Migration
```bash
# Start with less critical repositories
./git-multi-push.py --repositories test-repo,small-project --dry-run
./git-multi-push.py --repositories test-repo,small-project

# Verify the test repositories work
cd test-repo
git push  # Should push to all three services

# Migrate important repositories
./git-multi-push.py --repositories important-project1,important-project2

# Finally, migrate everything else
./git-multi-push.py --all --exclude test-repo,small-project,important-project1,important-project2
```

---

### Scenario 3: Platform Consolidation

**Use Case**: Moving from multiple disparate services to a standardized setup.

#### Step 1: Inventory Current Setup
```bash
# Get comprehensive analysis
./analyze-git-repos.py --scan-path ~/Code --scan-path ~/Projects --format detailed

# Identify all current services
./analyze-git-repos.py --format json | jq '.summary.services_usage'
```

#### Step 2: Choose Target Configuration
Decide on your target setup, e.g.:
- **Primary**: GitLab (for CI/CD, issue tracking)
- **Backup 1**: GitHub (for visibility, community)
- **Backup 2**: Codeberg (FOSS alternative)

#### Step 3: Repository Mapping
```bash
# Create mapping of current → target
./analyze-git-repos.py --format json | jq '.repositories[] | {name: .name, current_services: .classification.current_services, needs_migration: .classification.needs_migration}'
```

#### Step 4: Batch Migration
```bash
# Configure for consolidation
vim config/config.yaml  # Set your target services

# Migrate in phases
# Phase 1: Repositories currently on GitHub only
./git-multi-push.py --repositories $(./analyze-git-repos.py --format json | jq -r '.repositories[] | select(.classification.current_services == ["github"]) | .name' | tr '\n' ',' | sed 's/,$//')

# Phase 2: Repositories currently on GitLab only  
./git-multi-push.py --repositories $(./analyze-git-repos.py --format json | jq -r '.repositories[] | select(.classification.current_services == ["gitlab"]) | .name' | tr '\n' ',' | sed 's/,$//')

# Phase 3: Everything else
./git-multi-push.py --all
```

---

### Scenario 4: Enterprise Migration

**Use Case**: Enterprise GitHub/GitLab to external backup strategy.

#### Step 1: Enterprise Configuration
```bash
# Use enterprise preset as starting point
cp config/presets/enterprise-backup.yaml config/config.yaml
```

```yaml
user:
  username: "your-work-username"
  email: "you@company.com"

multi_push:
  primary_service: "github_enterprise"
  push_services: ["github_enterprise", "gitlab", "codeberg"]

services:
  github_enterprise:
    custom_domain: "github.yourcompany.com"
    auth_method: "token"
  gitlab:
    auth_method: "token"
  codeberg:
    auth_method: "token"
```

#### Step 2: Security Considerations
```bash
# Review repository sensitivity
./analyze-git-repos.py --scan-path ~/work --format detailed > enterprise-analysis.txt

# Identify repositories that should stay internal only
grep -A 10 "confidential\|internal\|sensitive" enterprise-analysis.txt
```

#### Step 3: Repository-Specific Rules
```yaml
# Add to config.yaml
repositories:
  overrides:
    confidential-project:
      push_services: ["github_enterprise"]  # Internal only
    public-tool:
      push_services: ["github_enterprise", "gitlab", "codeberg"]  # All services
```

#### Step 4: Compliance Migration
```bash
# Conservative settings for enterprise
# Edit config.yaml:
migration:
  dry_run_by_default: true
  batch_size: 3
  stop_on_first_error: true
  create_backups: true
```

```bash
# Always test first in enterprise environments
./git-multi-push.py --repositories non-sensitive-project --dry-run

# Apply to non-sensitive repositories first
./git-multi-push.py --repositories public-tool,open-source-project

# Gradually expand to other repositories
```

---

## ⚠️ Pre-Migration Checklist

Before starting any migration:

### Technical Prerequisites
- [ ] **Git configured**: `git config --global user.name` and `user.email` set
- [ ] **Python 3 installed**: `python3 --version`
- [ ] **Authentication ready**: Tokens/SSH keys for all target services
- [ ] **Network access**: Can reach all target services
- [ ] **Disk space**: Sufficient space for temporary backups

### Planning Prerequisites  
- [ ] **Repository inventory**: Know what repositories you have
- [ ] **Service accounts**: Accounts on all target services
- [ ] **Repository naming**: Consistent naming strategy across services
- [ ] **Access policies**: Understand visibility/permission requirements
- [ ] **Team coordination**: Notify team members of migration timeline

### Safety Prerequisites
- [ ] **Backups**: Current repositories backed up separately
- [ ] **Testing plan**: Strategy for verifying migration success
- [ ] **Rollback plan**: How to revert if something goes wrong
- [ ] **Staging environment**: Test the process on non-critical repositories
- [ ] **Communication plan**: How to notify stakeholders

## 🔧 Migration Best Practices

### Start Small
```bash
# Always start with test repositories
./git-multi-push.py --repositories test-repo --dry-run
./git-multi-push.py --repositories test-repo

# Verify success before proceeding
cd test-repo
git remote -v
git push
```

### Batch Processing
```bash
# Don't migrate all repositories at once
# Use reasonable batch sizes
./git-multi-push.py --repositories repo1,repo2,repo3  # Small batch first
```

### Verification Steps
```bash
# After each batch, verify:
# 1. Remote configuration is correct
git remote -v

# 2. Push works to all services
git push

# 3. All services received the push
# Check each service's web interface

# 4. No corruption occurred
git log --oneline -5
git status
```

### Error Handling
```bash
# If migration fails partway through:

# 1. Check what succeeded
./analyze-git-repos.py --format detailed | grep "has_multi_push: true"

# 2. Restore failed repositories from backup
cd failed-repo
cp .git/config.backup.* .git/config

# 3. Investigate the error
./git-multi-push.py --repositories failed-repo --dry-run  # See what would happen
```

### Team Coordination
1. **Notify team** before migration starts
2. **Establish quiet period** (no pushes during migration)
3. **Update documentation** with new procedures
4. **Train team** on new multi-push workflow

## 📊 Progress Tracking

### Before Migration
```bash
# Baseline analysis
./analyze-git-repos.py --output pre-migration-$(date +%Y%m%d).json
```

### During Migration
```bash
# Track progress
./analyze-git-repos.py --format summary | grep "multi_push"

# List remaining repositories
./analyze-git-repos.py --format json | jq '.repositories[] | select(.classification.needs_migration == true) | .name'
```

### After Migration
```bash
# Final verification
./analyze-git-repos.py --output post-migration-$(date +%Y%m%d).json

# Compare before/after
diff <(jq '.summary' pre-migration-*.json) <(jq '.summary' post-migration-*.json)
```

## 🚨 Troubleshooting Migration Issues

### Authentication Problems
```bash
# Test tokens individually
curl -H "Authorization: token $GITLAB_TOKEN" https://gitlab.com/api/v4/user
curl -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/user

# Verify token scopes
# GitLab: Token needs 'api' scope
# GitHub: Token needs 'repo' scope
```

### Repository Creation Issues
```bash
# Check if repository exists on service
curl -H "Authorization: token $GITLAB_TOKEN" https://gitlab.com/api/v4/projects/username%2Frepo-name

# Create repository via API (GitLab example)
curl -H "Authorization: token $GITLAB_TOKEN" \
     -H "Content-Type: application/json" \
     -d '{"name":"repo-name","visibility":"private"}' \
     https://gitlab.com/api/v4/projects
```

### Push Failures
```bash
# Test individual services
git push https://gitlab.com/username/repo.git main
git push https://github.com/username/repo.git main

# Check for large files or LFS issues
git lfs ls-files
```

### Network/Firewall Issues
```bash
# Test connectivity
ping gitlab.com
ping github.com
ping codeberg.org

# Test HTTPS access
curl -I https://gitlab.com
curl -I https://github.com
```

## 📈 Migration Success Metrics

Track these metrics to measure migration success:

### Technical Metrics
- **Migration completion rate**: % of repositories successfully migrated
- **Multi-push success rate**: % of pushes that succeed to all services
- **Backup verification**: % of repositories with verified backups
- **Error rate**: Number of failed operations per repository

### Business Metrics
- **Platform independence**: Reduced vendor lock-in risk
- **Redundancy coverage**: % of critical repositories with backups
- **Recovery capability**: Time to restore from backup services
- **Team adoption**: % of team using new multi-push workflow

### Monitoring Commands
```bash
# Check migration status
./analyze-git-repos.py --format summary | grep -E "(total_repositories|has_multi_push|migration_needed)"

# Verify backup coverage
./analyze-git-repos.py --format json | jq '.repositories[] | select(.classification.current_services | length >= 2) | .name' | wc -l

# Test push success rate
cd test-repo && git push  # Should succeed to all services
```

---

## 🎉 Post-Migration

### Team Training
1. **New workflow**: `git push` now pushes to multiple services
2. **Verification**: How to check that all services received updates
3. **Troubleshooting**: What to do if push fails to one service
4. **Recovery**: How to use backup services if primary is down

### Documentation Updates
- Update team documentation with new remote configurations
- Add troubleshooting guides for common multi-push issues
- Document the backup and recovery procedures

### Ongoing Maintenance
```bash
# Regular verification (weekly/monthly)
./analyze-git-repos.py --format summary

# Check for repositories that lost multi-push configuration
./analyze-git-repos.py --format detailed | grep "needs_migration: true"

# Verify backups are current
# (Check that all services have recent commits)
```

This migration guide provides the framework for successful git multi-push migrations. Adapt the specific steps based on your unique environment and requirements.