# wpsite — One-Command WordPress Development Environment

[![Version](https://img.shields.io/github/v/tag/charly-palencia/wpsite-builder?label=version&sort=semver)](https://github.com/charly-palencia/wpsite-builder/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![ShellCheck](https://img.shields.io/badge/shellcheck-passing-brightgreen)](https://github.com/koalaman/shellcheck)

> Stop fighting with MAMP, Vagrant, or manual Docker setups. **wpsite** spins up production-grade local WordPress sites with SSL, DNS, and reverse-proxy in a single command.

---

## Install in 10 Seconds

```bash
curl -fsSL https://raw.githubusercontent.com/charly-palencia/wpsite-builder/main/install.sh | bash
```

No config files. No GUI bloat. Just Docker.

---

## Why wpsite?

| Before | After |
|--------|-------|
| Download MAMP / LocalWP / XAMPP | `wpsite create my-site` |
| Manually edit `hosts` file | `wpsite dns setup` (auto-configures `.test` domains) |
| Self-signed SSL nightmares | `wpsite create my-site` → HTTPS works instantly (mkcert) |
| One giant shared database | Per-site isolated MariaDB users & databases |
| No reverse proxy | Traefik routes every site with clean URLs |
| Stuck in a GUI | Full CLI control: start, stop, logs, shell — all from the terminal |

---

## Features

- **One Command** — `wpsite create <name>` gives you a running WordPress site
- **Custom Domains** — `my-site.test`, `shop.local.dev`, anything you want
- **Auto SSL** — HTTPS via mkcert, no browser warnings, no manual cert config
- **Shared Infrastructure** — One MariaDB + Traefik + phpMyAdmin serves all sites
- **Per-Site Isolation** — Each site gets its own database, user, and container
- **DNS Automation** — dnsmasq setup for `.test` domains with zero `hosts` file edits
- **Developer-Friendly** — Jump into directories, open folders, tail logs, exec into containers
- **Clean Removal** — `wpsite remove <name>` deletes everything: container, DB, files
- **macOS & Linux** — Works on both platforms with the same CLI

---

## Quick Start

```bash
# 1. Install shared infrastructure (once)
wpsite infra install

# 2. Start MariaDB, Traefik, and phpMyAdmin
wpsite infra start

# 3. Configure DNS for .test domains
wpsite dns setup

# 4. Create your first WordPress site
wpsite create my-site
# → https://my-site.test (with SSL)
```

**phpMyAdmin** is available at `http://pma.test` (credentials: `root` / `wp_root_secret_2024`).

---

## Commands

### Site Management

| Command | Description |
|---------|-------------|
| `wpsite create <name> [suffix]` | Create a WordPress site with optional custom domain suffix |
| `wpsite list` | Show all sites with status (running / stopped) |
| `wpsite start [name]` | Start a site, or all sites if no name given |
| `wpsite stop [name]` | Stop a site, or all sites if no name given |
| `wpsite restart <name>` | Restart a site |
| `wpsite remove <name>` | Completely remove a site (containers, DB, files) |
| `wpsite logs <name>` | Follow real-time container logs |
| `wpsite shell <name>` | Open a bash shell inside the WordPress container |
| `wpsite go <name>` | Jump into the site's directory in a new shell |
| `wpsite open <name>` | Open the site's folder in Finder (macOS) or file manager (Linux) |

### Infrastructure

| Command | Description |
|---------|-------------|
| `wpsite infra install` | Generate base `docker-compose.yml` (one-time setup) |
| `wpsite infra start` | Start MariaDB, Traefik, phpMyAdmin |
| `wpsite infra stop` | Stop all infrastructure |
| `wpsite infra restart` | Restart infrastructure |
| `wpsite infra status` | Check which services are running |
| `wpsite infra ssl <name>` | Configure SSL for an existing site |
| `wpsite infra logs` | Follow infrastructure logs |

### DNS (dnsmasq)

| Command | Description |
|---------|-------------|
| `wpsite dns install` | Install dnsmasq via Homebrew or apt |
| `wpsite dns setup` | Configure `.test` domain resolution automatically |
| `wpsite dns add <domain>` | Add a custom domain to dnsmasq |
| `wpsite dns remove <domain>` | Remove a custom domain |
| `wpsite dns status` | Check DNS configuration |
| `wpsite dns restart` | Restart dnsmasq |

---

## Examples

```bash
# Create a site with a custom TLD
wpsite create mysite local.dev
# → http://mysite.local.dev

# Create a site with HTTPS (auto-generated SSL)
wpsite create my-secure-site
# → https://my-secure-site.test

# Create and immediately start working
wpsite create client-project
wpsite go client-project
```

---

## Directory Structure

```
~/wp-sites/                          # All sites live here
├── docker-compose.yml               # Base infrastructure (MariaDB, Traefik, PMA)
├── traefik-dynamic.yml              # Traefik routing config
├── certs/                           # SSL certificates (shared)
├── my-site/
│   ├── docker-compose.yml           # Per-site WordPress config
│   ├── wordpress/                   # WordPress files (mounted volume)
│   ├── php.ini                      # Custom PHP config
│   ├── .site-info                   # Site metadata
│   └── ssl/                         # Site-specific SSL certs (if HTTPS)
```

---

## Development

```bash
git clone https://github.com/charly-palencia/wpsite-builder.git
cd wpsite

# Install linting dependency
brew install shellcheck    # macOS
# apt install shellcheck   # Debian/Ubuntu

# Run from source
./src/main.sh --version

# Build the single-file script
make build

# Run tests
make test

# Lint
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
│   │   ├── cmd_shell.sh   # Container shell
│   │   ├── cmd_go.sh      # Jump into site directory
│   │   └── cmd_open.sh    # Open site folder in file manager
│   ├── cmd_dns.sh         # DNS dnsmasq management
│   └── cmd_infra.sh       # Infrastructure management
└── .github/workflows/
    ├── release.yml        # Auto-release on tag
    └── test.yml           # CI (ShellCheck + build test)
```

---

## Version Management

The canonical version lives in the `VERSION` file. To bump:

```bash
make set-version NEW_VERSION=1.5.0
```

This updates `VERSION`, `src/lib/config.sh`, `src/main.sh`, `README.md`, and rebuilds `wpsite`.

---

## Requirements

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (Mac/Linux) or `docker` + `docker compose`
- `openssl` (pre-installed on macOS and most Linux distros)
- `mkcert` (optional, auto-installed when you create an HTTPS site)

---

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Make changes in `src/` (not the built `wpsite` file)
4. Run `make lint` and `make test`
5. Commit and push
6. Open a Pull Request

---

## License

MIT
