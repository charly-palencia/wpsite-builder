#!/bin/bash
# shellcheck shell=bash
set -e

# =============================================
# wpsite - WordPress Site Manager
# Manage local Docker-based WordPress sites
#
# Version: 1.4.0
# Changelog:
#   1.3.1 - Fixed YAML corruption bug in 'wpsite infra ssl' command
#         - Refactored SSL configuration into reusable helper function
#         - Now uses yq for proper YAML manipulation (deduped certs, idempotent)
#         - Helper also adds HTTPS routers and HTTP to HTTPS redirect automatically
#   1.3.0 - Added HTTPS/SSL support with mkcert
#   1.2.2 - Fixed Traefik to serve site-specific certificates
#   1.2.1 - Fixed PyYAML dependency issue - now uses pure bash for YAML updates
#   1.2.0 - Switched to Traefik file provider (workaround for Docker Desktop socket issues)
#   1.1.0 - Added 'wpsite infra install' command to create base infrastructure
#   1.0.0 - Initial release
# =============================================

# Determine script directory for sourcing modules
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source all modules in dependency order
# shellcheck source=src/lib/config.sh
source "$SCRIPT_DIR/lib/config.sh"
# shellcheck source=src/lib/detect_os.sh
source "$SCRIPT_DIR/lib/detect_os.sh"
# shellcheck source=src/lib/helpers.sh
source "$SCRIPT_DIR/lib/helpers.sh"
# shellcheck source=src/lib/ssl.sh
source "$SCRIPT_DIR/lib/ssl.sh"

# Source command modules
# shellcheck source=src/commands/cmd_create.sh
source "$SCRIPT_DIR/commands/cmd_create.sh"
# shellcheck source=src/commands/cmd_list.sh
source "$SCRIPT_DIR/commands/cmd_list.sh"
# shellcheck source=src/commands/cmd_start.sh
source "$SCRIPT_DIR/commands/cmd_start.sh"
# shellcheck source=src/commands/cmd_stop.sh
source "$SCRIPT_DIR/commands/cmd_stop.sh"
# shellcheck source=src/commands/cmd_restart.sh
source "$SCRIPT_DIR/commands/cmd_restart.sh"
# shellcheck source=src/commands/cmd_remove.sh
source "$SCRIPT_DIR/commands/cmd_remove.sh"
# shellcheck source=src/commands/cmd_logs.sh
source "$SCRIPT_DIR/commands/cmd_logs.sh"
# shellcheck source=src/commands/cmd_shell.sh
source "$SCRIPT_DIR/commands/cmd_shell.sh"
# shellcheck source=src/commands/cmd_go.sh
source "$SCRIPT_DIR/commands/cmd_go.sh"
# shellcheck source=src/commands/cmd_open.sh
source "$SCRIPT_DIR/commands/cmd_open.sh"
# shellcheck source=src/cmd_dns.sh
source "$SCRIPT_DIR/cmd_dns.sh"
# shellcheck source=src/cmd_infra.sh
source "$SCRIPT_DIR/cmd_infra.sh"

# Source dispatcher
# shellcheck source=src/dispatcher.sh
source "$SCRIPT_DIR/dispatcher.sh"