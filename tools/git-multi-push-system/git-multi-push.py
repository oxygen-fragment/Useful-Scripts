#!/usr/bin/env python3
"""
Git Multi-Push System - Generic Migration Tool

A platform and user-agnostic tool for configuring git repositories with
multi-push capabilities to multiple hosting services simultaneously.

Author: Generic Git Multi-Push System
License: MIT
"""

import os
import sys
import subprocess
import json
import yaml
import argparse
import logging
from pathlib import Path
from typing import Dict, List, Optional, Any
import shutil
from datetime import datetime

class GitMultiPushManager:
    def __init__(self, config_path: str = None, preset: str = None):
        self.config = {}
        self.services_config = {}
        self.logger = None
        
        # Load configuration
        self.load_services_config()
        self.load_config(config_path, preset)
        self.setup_logging()
        
    def load_services_config(self):
        """Load service definitions from services.yaml"""
        services_path = Path(__file__).parent / 'config' / 'services.yaml'
        try:
            with open(services_path, 'r') as f:
                self.services_config = yaml.safe_load(f)
        except FileNotFoundError:
            self.logger_error("services.yaml not found. Please ensure config/services.yaml exists.")
            sys.exit(1)
        except yaml.YAMLError as e:
            self.logger_error(f"Error parsing services.yaml: {e}")
            sys.exit(1)
    
    def load_config(self, config_path: str = None, preset: str = None):
        """Load user configuration with optional preset override"""
        config_paths = []
        
        # Priority: command line > preset > config.yaml > config.yaml.example
        if config_path:
            config_paths.append(config_path)
        elif preset:
            preset_path = Path(__file__).parent / 'config' / 'presets' / f'{preset}.yaml'
            config_paths.append(str(preset_path))
        
        # Default config locations
        script_dir = Path(__file__).parent
        config_paths.extend([
            script_dir / 'config' / 'config.yaml',
            script_dir / 'config' / 'config.yaml.example'
        ])
        
        config_loaded = False
        for path in config_paths:
            if Path(path).exists():
                try:
                    with open(path, 'r') as f:
                        self.config = yaml.safe_load(f)
                    config_loaded = True
                    break
                except yaml.YAMLError as e:
                    print(f"Error parsing {path}: {e}")
                    continue
        
        if not config_loaded:
            print("No valid configuration found. Please create config.yaml or use --init")
            sys.exit(1)
    
    def setup_logging(self):
        """Setup logging based on configuration"""
        log_config = self.config.get('logging', {})
        level = getattr(logging, log_config.get('level', 'INFO'))
        
        # Setup logger
        self.logger = logging.getLogger('git-multi-push')
        self.logger.setLevel(level)
        
        # Clear existing handlers
        self.logger.handlers = []
        
        # Create formatter
        if log_config.get('format', 'detailed') == 'json':
            formatter = logging.Formatter('{"timestamp": "%(asctime)s", "level": "%(levelname)s", "message": "%(message)s"}')
        elif log_config.get('format', 'detailed') == 'simple':
            formatter = logging.Formatter('%(levelname)s: %(message)s')
        else:
            formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
        
        # Console handler
        console_handler = logging.StreamHandler()
        console_handler.setFormatter(formatter)
        self.logger.addHandler(console_handler)
        
        # File handler if specified
        if log_config.get('file'):
            file_handler = logging.FileHandler(log_config['file'])
            file_handler.setFormatter(formatter)
            self.logger.addHandler(file_handler)
    
    def logger_error(self, msg):
        """Fallback error logging for when logger isn't set up yet"""
        if self.logger:
            self.logger.error(msg)
        else:
            print(f"ERROR: {msg}", file=sys.stderr)
    
    def run_git_command(self, repo_path: str, command: List[str], check: bool = True, timeout: int = None) -> Optional[str]:
        """Run a git command in the specified repository"""
        if timeout is None:
            timeout = self.config.get('advanced', {}).get('git_timeout', 30)
        
        try:
            result = subprocess.run(
                ['git'] + command,
                cwd=repo_path,
                capture_output=True,
                text=True,
                check=check,
                timeout=timeout
            )
            return result.stdout.strip()
        except subprocess.CalledProcessError as e:
            if check:
                self.logger.error(f"Git command failed: {' '.join(command)}")
                self.logger.error(f"Error: {e.stderr.strip()}")
            return None
        except subprocess.TimeoutExpired:
            self.logger.error(f"Git command timed out: {' '.join(command)}")
            return None
    
    def backup_git_config(self, repo_path: str) -> bool:
        """Create a backup of the current git configuration"""
        if not self.config.get('migration', {}).get('create_backups', True):
            return True
        
        try:
            config_path = Path(repo_path) / '.git' / 'config'
            backup_path = Path(repo_path) / '.git' / f'config.backup.{datetime.now().strftime("%Y%m%d_%H%M%S")}'
            
            shutil.copy2(config_path, backup_path)
            self.logger.info(f"Configuration backed up to {backup_path.name}")
            return True
        except Exception as e:
            self.logger.error(f"Failed to backup config: {e}")
            return False
    
    def get_current_remotes(self, repo_path: str) -> Dict[str, Dict[str, str]]:
        """Get current remote configuration for a repository"""
        remotes = {}
        
        # Get remote names
        remote_names = self.run_git_command(repo_path, ['remote'], check=False)
        if not remote_names:
            return remotes
        
        for remote_name in remote_names.split('\n'):
            if remote_name.strip():
                # Get URLs
                fetch_url = self.run_git_command(repo_path, ['remote', 'get-url', remote_name], check=False)
                push_urls_output = self.run_git_command(repo_path, ['remote', 'get-url', '--push', '--all', remote_name], check=False)
                push_urls = push_urls_output.split('\n') if push_urls_output else []
                
                remotes[remote_name] = {
                    'fetch': fetch_url,
                    'push': push_urls
                }
        
        return remotes
    
    def detect_service_from_url(self, url: str) -> Optional[str]:
        """Detect which service a URL belongs to"""
        if not url:
            return None
        
        for service_id, service_config in self.services_config['services'].items():
            domain = service_config.get('domain', '')
            
            # Handle custom domains
            if '{custom_domain}' in domain:
                continue  # Skip template services for auto-detection
            
            if domain in url:
                return service_id
        
        return None
    
    def generate_service_url(self, service_id: str, repo_name: str, auth: bool = False) -> str:
        """Generate URL for a specific service"""
        service_config = self.services_config['services'].get(service_id, {})
        user_service_config = self.config.get('services', {}).get(service_id, {})
        
        # Get username (service-specific or global)
        username = user_service_config.get('username', self.config.get('user', {}).get('username'))
        if not username:
            raise ValueError(f"No username configured for {service_id}")
        
        # Handle custom domains for self-hosted services
        custom_domain = user_service_config.get('custom_domain')
        if custom_domain:
            domain = custom_domain
        else:
            domain = service_config.get('domain', '')
            if '{custom_domain}' in domain:
                raise ValueError(f"Custom domain required for {service_id}")
        
        # Choose URL template
        if auth and user_service_config.get('auth_method') == 'token':
            template = service_config.get('auth_url_template')
            # Get token from environment or config
            token_env_var = service_config.get('token_env_var')
            token = os.getenv(token_env_var) if token_env_var else None
            if not token:
                self.logger.warning(f"No token found for {service_id}, using non-auth URL")
                template = service_config.get('url_template')
        elif user_service_config.get('auth_method') == 'ssh':
            template = service_config.get('ssh_url_template')
        else:
            template = service_config.get('url_template')
        
        if not template:
            raise ValueError(f"No URL template found for {service_id}")
        
        # Replace placeholders
        url = template.format(
            username=username,
            repo=repo_name,
            custom_domain=custom_domain or domain,
            domain=domain,
            token=os.getenv(service_config.get('token_env_var', '')) if auth else ''
        )
        
        return url
    
    def configure_multi_push(self, repo_path: str, repo_name: str, dry_run: bool = False) -> bool:
        """Configure a repository for multi-push"""
        self.logger.info(f"Configuring multi-push for: {repo_name}")
        self.logger.info("=" * 50)
        
        if not Path(repo_path, '.git').exists():
            self.logger.warning(f"Not a git repository: {repo_path}")
            return False
        
        # Backup configuration
        if not dry_run and not self.backup_git_config(repo_path):
            return False
        
        # Get current remotes
        current_remotes = self.get_current_remotes(repo_path)
        self.logger.info(f"Current remotes: {list(current_remotes.keys())}")
        
        # Get configuration
        primary_service = self.config.get('multi_push', {}).get('primary_service')
        push_services = self.config.get('multi_push', {}).get('push_services', [])
        
        if not primary_service or not push_services:
            self.logger.error("No primary_service or push_services configured")
            return False
        
        # Generate URLs for all services
        service_urls = {}
        for service in push_services:
            try:
                url = self.generate_service_url(service, repo_name, auth=True)
                service_urls[service] = url
                self.logger.info(f"  {service}: {url}")
            except Exception as e:
                self.logger.error(f"Failed to generate URL for {service}: {e}")
                return False
        
        if dry_run:
            self.logger.info("DRY RUN: Would configure multi-push remotes")
            return True
        
        try:
            # Remove existing origin
            self.run_git_command(repo_path, ['remote', 'remove', 'origin'], check=False)
            
            # Add primary as origin (for fetch)
            primary_url = service_urls[primary_service]
            self.run_git_command(repo_path, ['remote', 'add', 'origin', primary_url])
            self.logger.info(f"✓ Set primary ({primary_service}) as fetch remote")
            
            # Add all push URLs
            for service in push_services:
                url = service_urls[service]
                self.run_git_command(repo_path, ['remote', 'set-url', '--add', '--push', 'origin', url])
                self.logger.info(f"✓ Added push URL: {service}")
            
            # Verify configuration
            verification = self.run_git_command(repo_path, ['remote', '-v'])
            if verification:
                self.logger.info("Configuration verified:")
                for line in verification.split('\n'):
                    self.logger.info(f"  {line}")
            
            return True
        
        except Exception as e:
            self.logger.error(f"Failed to configure multi-push: {e}")
            return False
    
    def test_connectivity(self, repo_path: str) -> Dict[str, bool]:
        """Test connectivity to all configured push remotes"""
        results = {}
        timeout = self.config.get('advanced', {}).get('connectivity_timeout', 10)
        
        if not self.config.get('advanced', {}).get('test_connectivity', True):
            return results
        
        self.logger.info("Testing connectivity...")
        
        # Get push URLs
        push_urls_output = self.run_git_command(repo_path, ['remote', 'get-url', '--push', '--all', 'origin'], check=False)
        if not push_urls_output:
            return results
        
        push_urls = push_urls_output.split('\n')
        
        for url in push_urls:
            service = self.detect_service_from_url(url)
            if not service:
                service = 'unknown'
            
            # Test with ls-remote
            try:
                result = subprocess.run(
                    ['git', 'ls-remote', '--exit-code', url],
                    cwd=repo_path,
                    capture_output=True,
                    timeout=timeout,
                    check=True
                )
                results[service] = True
                self.logger.info(f"  ✓ {service}: Connection successful")
            except (subprocess.CalledProcessError, subprocess.TimeoutExpired):
                results[service] = False
                self.logger.warning(f"  ✗ {service}: Connection failed (repository may not exist yet)")
        
        return results
    
    def process_repositories(self, repo_paths: List[str], dry_run: bool = False):
        """Process multiple repositories for multi-push configuration"""
        migration_config = self.config.get('migration', {})
        batch_size = migration_config.get('batch_size', 10)
        delay_between_repos = migration_config.get('delay_between_repos', 1)
        stop_on_error = migration_config.get('stop_on_first_error', False)
        
        results = {
            'successful': [],
            'failed': [],
            'skipped': []
        }
        
        total_repos = len(repo_paths)
        self.logger.info(f"Processing {total_repos} repositories")
        self.logger.info(f"Dry run: {dry_run}")
        self.logger.info("=" * 80)
        
        # Process in batches
        for i in range(0, len(repo_paths), batch_size):
            batch = repo_paths[i:i+batch_size]
            self.logger.info(f"Processing batch {i//batch_size + 1} ({len(batch)} repositories)")
            
            for repo_path in batch:
                repo_name = Path(repo_path).name
                
                try:
                    success = self.configure_multi_push(repo_path, repo_name, dry_run)
                    
                    if success:
                        results['successful'].append(repo_name)
                        
                        if not dry_run and self.config.get('advanced', {}).get('test_connectivity', True):
                            connectivity = self.test_connectivity(repo_path)
                            failed_services = [svc for svc, success in connectivity.items() if not success]
                            if failed_services:
                                self.logger.warning(f"Connectivity failed for: {', '.join(failed_services)}")
                    else:
                        results['failed'].append(repo_name)
                        if stop_on_error:
                            self.logger.error("Stopping on first error as configured")
                            break
                
                except Exception as e:
                    self.logger.error(f"Unexpected error processing {repo_name}: {e}")
                    results['failed'].append(repo_name)
                    if stop_on_error:
                        break
                
                # Delay between repositories
                if delay_between_repos > 0:
                    import time
                    time.sleep(delay_between_repos)
        
        # Print summary
        self.logger.info("\n" + "=" * 80)
        self.logger.info("PROCESSING SUMMARY")
        self.logger.info("=" * 80)
        self.logger.info(f"Successful: {len(results['successful'])}")
        self.logger.info(f"Failed: {len(results['failed'])}")
        self.logger.info(f"Skipped: {len(results['skipped'])}")
        
        if results['failed']:
            self.logger.error("Failed repositories:")
            for repo in results['failed']:
                self.logger.error(f"  - {repo}")
        
        return results
    
    def create_initial_config(self):
        """Create initial configuration files"""
        script_dir = Path(__file__).parent
        config_path = script_dir / 'config' / 'config.yaml'
        
        if config_path.exists():
            print(f"Configuration already exists at {config_path}")
            response = input("Overwrite? (y/N): ")
            if not response.lower().startswith('y'):
                return
        
        # Copy example config
        example_path = script_dir / 'config' / 'config.yaml.example'
        if example_path.exists():
            shutil.copy2(example_path, config_path)
            print(f"Created configuration template at {config_path}")
            print("Please edit the configuration with your details:")
            print(f"  - Set your username and email")
            print(f"  - Configure your preferred services")
            print(f"  - Set up authentication tokens in environment variables")
        else:
            print("config.yaml.example not found. Please ensure the config directory is complete.")

def main():
    parser = argparse.ArgumentParser(
        description='Git Multi-Push System - Configure repositories for multi-service push',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s --init                           # Create initial configuration
  %(prog)s --preset triple-redundancy --dry-run # Test with preset
  %(prog)s --repositories repo1,repo2      # Configure specific repos
  %(prog)s --scan-path ~/Code --dry-run    # Scan directory and test
  %(prog)s --config my-config.yaml --all   # Use custom config for all repos
        """)
    
    parser.add_argument('--config', help='Path to configuration file')
    parser.add_argument('--preset', help='Use a configuration preset', 
                       choices=['github-to-gitlab', 'triple-redundancy', 'enterprise-backup'])
    parser.add_argument('--init', action='store_true', help='Create initial configuration')
    parser.add_argument('--repositories', help='Comma-separated list of repository names or paths')
    parser.add_argument('--scan-path', help='Scan this path for git repositories')
    parser.add_argument('--all', action='store_true', help='Process all repositories in scan paths')
    parser.add_argument('--dry-run', action='store_true', help='Show what would be done without making changes')
    parser.add_argument('--force', action='store_true', help='Override dry-run defaults')
    
    args = parser.parse_args()
    
    # Handle initialization
    if args.init:
        manager = GitMultiPushManager.__new__(GitMultiPushManager)
        manager.create_initial_config()
        return
    
    # Create manager
    try:
        manager = GitMultiPushManager(args.config, args.preset)
    except Exception as e:
        print(f"Failed to initialize: {e}")
        sys.exit(1)
    
    # Determine repositories to process
    repo_paths = []
    
    if args.repositories:
        for repo in args.repositories.split(','):
            repo = repo.strip()
            if Path(repo).is_absolute():
                repo_paths.append(repo)
            else:
                # Look in scan paths
                for scan_path in manager.config.get('repositories', {}).get('scan_paths', []):
                    potential_path = Path(scan_path).expanduser() / repo
                    if potential_path.exists():
                        repo_paths.append(str(potential_path))
                        break
                else:
                    manager.logger.warning(f"Repository not found: {repo}")
    
    elif args.scan_path:
        scan_path = Path(args.scan_path).expanduser()
        if not scan_path.exists():
            manager.logger.error(f"Scan path does not exist: {scan_path}")
            sys.exit(1)
        
        for item in scan_path.iterdir():
            if item.is_dir() and (item / '.git').exists():
                repo_paths.append(str(item))
    
    elif args.all:
        scan_paths = manager.config.get('repositories', {}).get('scan_paths', [])
        for scan_path in scan_paths:
            path = Path(scan_path).expanduser()
            if path.exists():
                for item in path.iterdir():
                    if item.is_dir() and (item / '.git').exists():
                        repo_paths.append(str(item))
    
    if not repo_paths:
        parser.print_help()
        print("\nNo repositories specified. Use --repositories, --scan-path, --all, or --init")
        sys.exit(1)
    
    # Determine if this should be a dry run
    dry_run = args.dry_run or (
        manager.config.get('migration', {}).get('dry_run_by_default', False) and not args.force
    )
    
    # Process repositories
    manager.process_repositories(repo_paths, dry_run)

if __name__ == '__main__':
    main()