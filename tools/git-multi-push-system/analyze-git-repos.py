#!/usr/bin/env python3
"""
Git Repository Analysis Tool

Analyzes git repositories to understand their current configuration
and provides recommendations for multi-push setup.

Part of the Git Multi-Push System
"""

import os
import sys
import subprocess
import json
import yaml
import argparse
from pathlib import Path
from typing import Dict, List, Optional, Any
from datetime import datetime
import logging

class GitRepositoryAnalyzer:
    def __init__(self, config_path: str = None):
        self.config = {}
        self.services_config = {}
        self.logger = None
        
        # Load configuration
        self.load_services_config()
        self.load_config(config_path)
        self.setup_logging()
    
    def load_services_config(self):
        """Load service definitions from services.yaml"""
        services_path = Path(__file__).parent / 'config' / 'services.yaml'
        try:
            with open(services_path, 'r') as f:
                self.services_config = yaml.safe_load(f)
        except FileNotFoundError:
            print("services.yaml not found. Please ensure config/services.yaml exists.")
            sys.exit(1)
        except yaml.YAMLError as e:
            print(f"Error parsing services.yaml: {e}")
            sys.exit(1)
    
    def load_config(self, config_path: str = None):
        """Load user configuration"""
        config_paths = []
        
        if config_path:
            config_paths.append(config_path)
        
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
                        self.config = yaml.safe_load(f) or {}
                    config_loaded = True
                    break
                except yaml.YAMLError as e:
                    print(f"Error parsing {path}: {e}")
                    continue
        
        if not config_loaded:
            # Create minimal config for analysis
            self.config = {
                'logging': {'level': 'INFO'},
                'repositories': {'scan_paths': ['~/Code', '~/Projects']}
            }
    
    def setup_logging(self):
        """Setup logging based on configuration"""
        log_config = self.config.get('logging', {})
        level = getattr(logging, log_config.get('level', 'INFO'))
        
        self.logger = logging.getLogger('git-repo-analyzer')
        self.logger.setLevel(level)
        
        # Clear existing handlers
        self.logger.handlers = []
        
        # Console handler
        handler = logging.StreamHandler()
        formatter = logging.Formatter('%(levelname)s: %(message)s')
        handler.setFormatter(formatter)
        self.logger.addHandler(handler)
    
    def run_git_command(self, repo_path: str, command: List[str]) -> Optional[str]:
        """Run a git command in the specified repository"""
        try:
            result = subprocess.run(
                ['git'] + command,
                cwd=repo_path,
                capture_output=True,
                text=True,
                check=True
            )
            return result.stdout.strip()
        except subprocess.CalledProcessError:
            return None
    
    def detect_service_from_url(self, url: str) -> Optional[str]:
        """Detect which service a URL belongs to"""
        if not url:
            return None
        
        for service_id, service_config in self.services_config['services'].items():
            domain = service_config.get('domain', '')
            
            # Handle template domains
            if '{custom_domain}' in domain:
                continue
            
            if domain in url:
                return service_id
        
        # Check for common patterns not in services.yaml
        if 'github.com' in url:
            return 'github'
        elif 'gitlab.com' in url:
            return 'gitlab'
        elif 'bitbucket.org' in url:
            return 'bitbucket'
        elif 'codeberg.org' in url:
            return 'codeberg'
        elif 'keybase://' in url:
            return 'keybase'
        
        return 'unknown'
    
    def get_remotes(self, repo_path: str) -> Dict[str, Dict[str, Any]]:
        """Get all remotes and their URLs for a repository"""
        remotes = {}
        
        # Get remote names
        remote_names = self.run_git_command(repo_path, ['remote'])
        if not remote_names:
            return remotes
        
        for remote_name in remote_names.split('\n'):
            if remote_name.strip():
                # Get fetch URL
                fetch_url = self.run_git_command(repo_path, ['remote', 'get-url', remote_name])
                
                # Get push URLs (there might be multiple)
                push_urls_output = self.run_git_command(repo_path, ['remote', 'get-url', '--push', '--all', remote_name])
                push_urls = push_urls_output.split('\n') if push_urls_output else []
                
                remotes[remote_name] = {
                    'fetch_url': fetch_url,
                    'push_urls': push_urls,
                    'fetch_service': self.detect_service_from_url(fetch_url),
                    'push_services': [self.detect_service_from_url(url) for url in push_urls]
                }
        
        return remotes
    
    def get_repo_status(self, repo_path: str) -> Dict[str, Any]:
        """Get basic repository status information"""
        status = {}
        
        # Get current branch
        current_branch = self.run_git_command(repo_path, ['branch', '--show-current'])
        status['current_branch'] = current_branch or 'detached'
        
        # Check if repo has uncommitted changes
        git_status = self.run_git_command(repo_path, ['status', '--porcelain'])
        status['has_uncommitted_changes'] = bool(git_status)
        
        # Check if repo has unpushed commits
        try:
            unpushed = self.run_git_command(repo_path, ['log', '--oneline', '@{u}..'])
            status['has_unpushed_commits'] = bool(unpushed)
        except:
            status['has_unpushed_commits'] = None  # Unknown (no upstream)
        
        # Get last commit info
        last_commit = self.run_git_command(repo_path, ['log', '-1', '--format=%H|%an|%ae|%ad|%s', '--date=iso'])
        if last_commit:
            parts = last_commit.split('|', 4)
            status['last_commit'] = {
                'hash': parts[0][:8],
                'author_name': parts[1],
                'author_email': parts[2],
                'date': parts[3],
                'message': parts[4] if len(parts) > 4 else ''
            }
        
        # Get repository size (approximate)
        git_dir_size = self.get_directory_size(Path(repo_path) / '.git')
        status['git_size_mb'] = round(git_dir_size / (1024 * 1024), 1)
        
        return status
    
    def get_directory_size(self, path: Path) -> int:
        """Get the total size of a directory in bytes"""
        total_size = 0
        try:
            for dirpath, dirnames, filenames in os.walk(path):
                for filename in filenames:
                    filepath = os.path.join(dirpath, filename)
                    try:
                        total_size += os.path.getsize(filepath)
                    except (OSError, FileNotFoundError):
                        pass
        except (OSError, PermissionError):
            pass
        return total_size
    
    def classify_repository(self, analysis: Dict[str, Any]) -> Dict[str, Any]:
        """Classify repository and determine what actions are needed"""
        classification = {
            'current_services': set(),
            'has_multi_push': False,
            'primary_service': None,
            'needs_migration': False,
            'migration_complexity': 'simple',
            'recommendations': []
        }
        
        remotes = analysis.get('remotes', {})
        
        # Analyze current setup
        for remote_name, remote_info in remotes.items():
            fetch_service = remote_info.get('fetch_service')
            push_services = remote_info.get('push_services', [])
            
            if fetch_service:
                classification['current_services'].add(fetch_service)
            
            for service in push_services:
                if service:
                    classification['current_services'].add(service)
            
            # Check for multi-push
            if len(remote_info.get('push_urls', [])) > 1:
                classification['has_multi_push'] = True
            
            # Determine primary service (usually origin)
            if remote_name == 'origin' and fetch_service:
                classification['primary_service'] = fetch_service
        
        # Get target configuration from user config
        target_services = set(self.config.get('multi_push', {}).get('push_services', []))
        target_primary = self.config.get('multi_push', {}).get('primary_service')
        
        # Determine if migration is needed
        if target_services:
            missing_services = target_services - classification['current_services']
            classification['needs_migration'] = bool(missing_services) or not classification['has_multi_push']
            
            if classification['needs_migration']:
                if len(missing_services) >= 2:
                    classification['migration_complexity'] = 'complex'
                elif classification['primary_service'] != target_primary:
                    classification['migration_complexity'] = 'medium'
        else:
            # No target configured - recommend based on current setup
            if not classification['has_multi_push']:
                classification['needs_migration'] = True
                classification['recommendations'].append("Configure multi-push for redundancy")
        
        # Generate recommendations
        if classification['needs_migration']:
            if not classification['has_multi_push']:
                classification['recommendations'].append("Set up multi-push to multiple services")
            
            if target_services:
                missing = target_services - classification['current_services']
                if missing:
                    classification['recommendations'].append(f"Add services: {', '.join(missing)}")
        
        classification['current_services'] = list(classification['current_services'])
        return classification
    
    def analyze_repository(self, repo_path: str) -> Optional[Dict[str, Any]]:
        """Analyze a single repository"""
        repo_name = os.path.basename(repo_path)
        
        # Check if it's actually a git repository
        if not (Path(repo_path) / '.git').exists():
            return None
        
        self.logger.info(f"Analyzing {repo_name}...")
        
        analysis = {
            'name': repo_name,
            'path': repo_path,
            'remotes': self.get_remotes(repo_path),
            'status': self.get_repo_status(repo_path),
            'analyzed_at': datetime.now().isoformat()
        }
        
        # Classify the repository
        analysis['classification'] = self.classify_repository(analysis)
        
        return analysis
    
    def find_repositories(self, scan_paths: List[str]) -> List[str]:
        """Find all git repositories in the given paths"""
        repositories = []
        exclude_patterns = self.config.get('repositories', {}).get('exclude_patterns', [])
        
        for scan_path in scan_paths:
            path = Path(scan_path).expanduser()
            if not path.exists():
                self.logger.warning(f"Scan path does not exist: {path}")
                continue
            
            self.logger.info(f"Scanning: {path}")
            
            for item in path.iterdir():
                if item.is_dir() and not item.name.startswith('.'):
                    # Check if it's a git repository
                    if (item / '.git').exists():
                        # Check exclude patterns
                        excluded = False
                        for pattern in exclude_patterns:
                            if item.match(pattern):
                                excluded = True
                                break
                        
                        if not excluded:
                            repositories.append(str(item))
        
        return sorted(repositories)
    
    def generate_summary(self, analyses: List[Dict[str, Any]]) -> Dict[str, Any]:
        """Generate summary statistics from repository analyses"""
        summary = {
            'total_repositories': len(analyses),
            'services_usage': {},
            'migration_needed': 0,
            'has_multi_push': 0,
            'complexity_breakdown': {'simple': 0, 'medium': 0, 'complex': 0},
            'primary_services': {},
            'recommendations_summary': {},
            'total_size_mb': 0
        }
        
        for analysis in analyses:
            classification = analysis.get('classification', {})
            status = analysis.get('status', {})
            
            # Count service usage
            for service in classification.get('current_services', []):
                summary['services_usage'][service] = summary['services_usage'].get(service, 0) + 1
            
            # Count migration needs
            if classification.get('needs_migration'):
                summary['migration_needed'] += 1
            
            if classification.get('has_multi_push'):
                summary['has_multi_push'] += 1
            
            # Complexity breakdown
            complexity = classification.get('migration_complexity', 'simple')
            summary['complexity_breakdown'][complexity] += 1
            
            # Primary services
            primary = classification.get('primary_service')
            if primary:
                summary['primary_services'][primary] = summary['primary_services'].get(primary, 0) + 1
            
            # Recommendations
            for rec in classification.get('recommendations', []):
                summary['recommendations_summary'][rec] = summary['recommendations_summary'].get(rec, 0) + 1
            
            # Total size
            summary['total_size_mb'] += status.get('git_size_mb', 0)
        
        summary['total_size_mb'] = round(summary['total_size_mb'], 1)
        return summary
    
    def analyze_repositories(self, repo_paths: List[str] = None, scan_paths: List[str] = None) -> Dict[str, Any]:
        """Analyze multiple repositories"""
        if not repo_paths:
            if scan_paths:
                repo_paths = self.find_repositories(scan_paths)
            else:
                default_paths = self.config.get('repositories', {}).get('scan_paths', ['~/Code', '~/Projects'])
                repo_paths = self.find_repositories(default_paths)
        
        self.logger.info(f"Found {len(repo_paths)} repositories to analyze")
        self.logger.info("=" * 60)
        
        analyses = []
        for repo_path in repo_paths:
            analysis = self.analyze_repository(repo_path)
            if analysis:
                analyses.append(analysis)
        
        # Generate summary
        summary = self.generate_summary(analyses)
        
        result = {
            'summary': summary,
            'repositories': analyses,
            'analyzed_at': datetime.now().isoformat(),
            'analyzer_config': {
                'target_services': self.config.get('multi_push', {}).get('push_services', []),
                'primary_service': self.config.get('multi_push', {}).get('primary_service')
            }
        }
        
        return result
    
    def print_summary(self, result: Dict[str, Any]):
        """Print analysis summary to console"""
        summary = result['summary']
        
        print("\n" + "=" * 60)
        print("REPOSITORY ANALYSIS SUMMARY")
        print("=" * 60)
        print(f"Total repositories analyzed: {summary['total_repositories']}")
        print(f"Repositories needing migration: {summary['migration_needed']}")
        print(f"Repositories with multi-push: {summary['has_multi_push']}")
        print(f"Total size: {summary['total_size_mb']} MB")
        
        if summary['services_usage']:
            print(f"\nService usage:")
            for service, count in sorted(summary['services_usage'].items(), key=lambda x: x[1], reverse=True):
                print(f"  {service}: {count} repositories")
        
        if summary['primary_services']:
            print(f"\nPrimary services:")
            for service, count in sorted(summary['primary_services'].items(), key=lambda x: x[1], reverse=True):
                print(f"  {service}: {count} repositories")
        
        print(f"\nMigration complexity:")
        for complexity, count in summary['complexity_breakdown'].items():
            if count > 0:
                print(f"  {complexity}: {count} repositories")
        
        if summary['recommendations_summary']:
            print(f"\nTop recommendations:")
            for rec, count in list(sorted(summary['recommendations_summary'].items(), key=lambda x: x[1], reverse=True))[:5]:
                print(f"  {rec}: {count} repositories")

def main():
    parser = argparse.ArgumentParser(
        description='Analyze git repositories for multi-push configuration',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s                                 # Analyze default scan paths
  %(prog)s --scan-path ~/Code              # Analyze specific directory
  %(prog)s --repositories repo1,repo2     # Analyze specific repositories
  %(prog)s --output analysis.json         # Save results to file
  %(prog)s --config my-config.yaml        # Use custom configuration
        """)
    
    parser.add_argument('--config', help='Path to configuration file')
    parser.add_argument('--repositories', help='Comma-separated list of repository names or paths')
    parser.add_argument('--scan-path', action='append', help='Scan this path for repositories (can be used multiple times)')
    parser.add_argument('--output', help='Save analysis results to JSON file')
    parser.add_argument('--format', choices=['summary', 'detailed', 'json'], default='summary',
                       help='Output format')
    parser.add_argument('--quiet', action='store_true', help='Only show summary')
    
    args = parser.parse_args()
    
    # Create analyzer
    try:
        analyzer = GitRepositoryAnalyzer(args.config)
    except Exception as e:
        print(f"Failed to initialize analyzer: {e}")
        sys.exit(1)
    
    # Set logging level
    if args.quiet:
        analyzer.logger.setLevel(logging.WARNING)
    
    # Determine repositories to analyze
    repo_paths = None
    scan_paths = None
    
    if args.repositories:
        repo_paths = []
        for repo in args.repositories.split(','):
            repo = repo.strip()
            if Path(repo).is_absolute():
                repo_paths.append(repo)
            else:
                # Look in default scan paths
                default_paths = analyzer.config.get('repositories', {}).get('scan_paths', ['~/Code'])
                for scan_path in default_paths:
                    potential_path = Path(scan_path).expanduser() / repo
                    if potential_path.exists():
                        repo_paths.append(str(potential_path))
                        break
                else:
                    print(f"Repository not found: {repo}")
    
    if args.scan_path:
        scan_paths = args.scan_path
    
    # Perform analysis
    result = analyzer.analyze_repositories(repo_paths, scan_paths)
    
    # Output results
    if args.format == 'json' or args.output:
        output_data = json.dumps(result, indent=2)
        
        if args.output:
            with open(args.output, 'w') as f:
                f.write(output_data)
            analyzer.logger.info(f"Analysis saved to: {args.output}")
        
        if args.format == 'json':
            print(output_data)
    
    elif args.format == 'detailed':
        analyzer.print_summary(result)
        
        print(f"\nDetailed repository analysis:")
        print("-" * 40)
        for repo in result['repositories']:
            classification = repo['classification']
            if classification['needs_migration']:
                print(f"\n{repo['name']}:")
                print(f"  Current services: {', '.join(classification['current_services']) or 'None'}")
                print(f"  Primary: {classification['primary_service'] or 'None'}")
                print(f"  Multi-push: {'Yes' if classification['has_multi_push'] else 'No'}")
                print(f"  Complexity: {classification['migration_complexity']}")
                if classification['recommendations']:
                    print(f"  Recommendations:")
                    for rec in classification['recommendations']:
                        print(f"    - {rec}")
    
    else:  # summary
        analyzer.print_summary(result)

if __name__ == '__main__':
    main()