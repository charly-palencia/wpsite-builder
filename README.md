# wpsite - WordPress Site Manager

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![ShellCheck](https://img.shields.io/badge/shellcheck-passing-brightgreen)](https://github.com/koalaman/shellcheck)
![Version](https://img.shields.io/github/v/tag/charly-palencia/wpsite-builer?label=version&sort=semver)

**wpsite** is a single-command tool to create and manage local Docker-based WordPress sites on macOS and Linux.  
No Vagrant, no MAMP, no heavy GUI — just Docker Compose, Traefik, and a bash script.

## Quick Install

```bash
curl -fsSL https://raw.githubusercontent.com/charly-palencia/wpsite-builer/main/install.sh | bash
```

Or with wget:

```bash
wget -qO- https://raw.githubusercontent.com/charly-palencia/wpsite-builer/main/install.sh | bash
```

## Requirements

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (Mac/Linux) or `docker` + `docker compose`
- `openssl` (pre-installed on macOS and most Linux distros)
- `mkcert` (optional, for HTTPS support — auto-installed if needed)

## Quick Start

```bash
# 1. Install infrastructure (MariaDB, Traefik, phpMyAdmin)
wpsite infra install

# 2. Start the infrastructure
wpsite infra start

# 3. Configure DNS for .test domains
wpsite dns setup

# 4. Create your first site
wpsite create my-site
# → http://my-site.test
```

## Usage

### Site Management

```bash
wpsite create <name> [domain-suffix]   # Create a WordPress site
wpsite list                            # List all sites with status
wpsite start [name]                    # Start site (or all if no name)
wpsite stop [name]                     # Stop site (or all if no name)
wpsite restart <name>                  # Restart a site
wpsite remove <name>                   # Remove a site (destructive)
wpsite logs <name>                     # Follow container logs
wpsite shell <name>                    # Open bash in WordPress container
```

### Infrastructure

```bash
wpsite infra install                   # Generate docker-compose.yml once
wpsite infra start                     # Start MariaDB, Traefik, phpMyAdmin
wpsite infra stop                      # Stop all infrastructure
wpsite infra restart                   # Restart infrastructure
wpsite infra status                    # Check running services
wpsite infra ssl <name>                # Configure SSL for existing site
wpsite infra logs                      # Follow infrastructure logs
```

### DNS (dnsmasq)

```bash
wpsite dns install                     # Install dnsmasq via brew/apt
wpsite dns setup                       # Configure .test domain resolution
wpsite dns add <domain>                # Add a custom domain
wpsite dns remove <domain>             # Remove a custom domain
wpsite dns status                      # Check DNS configuration
wpsite dns restart                     # Restart dnsmasq
```

### Examples

```bash
# Create site with custom TLD
wpsite create mysite local.dev
# → http://mysite.local.dev

# Create site with HTTPS
wpsite create my-secure-site
# → https://my-secure-site.test
```

**phpMyAdmin** is available at `http://pma.test` (credentials: `root` / `wp_root_secret_2024`).

## Directory Structure

```
~/wp-sites/                          # All sites live here
├── docker-compose.yml               # Base infrastructure (MariaDB, Traefik, PMA)
├── traefik-dynamic.yml              # Traefik routing config
├── certs/                           # SSL certificates (shared)
├── <site-name>/
│   ├── docker-compose.yml           # Per-site WordPress config
│   ├── wordpress/                   # WordPress files (mounted volume)
│   ├── php.ini                      # Custom PHP config
│   ├── .site-info                   # Site metadata
│   └── ssl/                         # Site-specific SSL certs (if HTTPS)
```

## Development

```bash
git clone https://github.com/charly-palencia/wpsite-builer.git
cd wpsite

# Install dependencies for development
brew install shellcheck    # macOS
apt install shellcheck     # Debian/Ubuntu

# Run from source (no build needed)
./src/main.sh --version

# Build the single-file script
make build

# Run smoke tests
make test

# Lint with ShellCheck
make lint
```

### Project Structure

```
wpsite/
├── VERSION                # Single source of truth for version
├── Makefile               # Build, install, test, lint, set-version targets
├── install.sh             # One-liner curl|bash installer
├── README.md              # This file
├── wpsite                 # Compiled single-file script (output of make build)
├── src/
│   ├── main.sh            # Entry point (shebang, sources modules, dispatches)
│   ├── dispatcher.sh      # Command routing (case statement)
│   ├── lib/
│   │   ├── config.sh      # VERSION, colors, paths
│   │   ├── detect_os.sh   # OS detection
│   │   ├── helpers.sh     # shared helpers (help, check_docker, etc.)
│   │   └── ssl.sh         # mkcert setup, cert generation, Traefik config
│   ├── commands/
│   │   ├── cmd_create.sh  # Create site
│   │   ├── cmd_list.sh    # List sites
│   │   ├── cmd_start.sh   # Start site
│   │   ├── cmd_stop.sh    # Stop site
│   │   ├── cmd_restart.sh # Restart site
│   │   ├── cmd_remove.sh  # Remove site
│   │   ├── cmd_logs.sh    # Container logs
│   │   └── cmd_shell.sh   # Container shell
│   ├── cmd_dns.sh         # DNS dnsmasq management
│   └── cmd_infra.sh       # Infrastructure management
└── .github/workflows/
    ├── release.yml        # Auto-release on tag
    └── test.yml           # CI (ShellCheck + build test)
```

## Version Management

The canonical version is stored in the `VERSION` file at the project root. To bump the version across all files:

```bash
make set-version NEW_VERSION=1.4.0
```

This updates:
- `VERSION` file
- `src/lib/config.sh` (runtime variable)
- `src/main.sh` (changelog header)

Then rebuilds `wpsite` with the new version.

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Make changes in `src/` (not the built `wpsite` file)
4. Run `make lint` and `make test`
5. Commit and push
6. Open a Pull Request

## License

MIT