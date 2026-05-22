# shellcheck shell=bash
# =============================================
# config.sh - Global configuration and constants
# =============================================

# Single source of truth: VERSION file at project root
# Run: make set-version NEW_VERSION=x.y.z

# These variables are used across sourced modules
# shellcheck disable=SC2034
VERSION="1.3.1"
DB_ROOT_PASSWORD="wp_root_secret_2024"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
DIM='\033[2m'
NC='\033[0m'

# Base directory
SITES_DIR="$HOME/wp-sites"