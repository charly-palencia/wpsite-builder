# shellcheck shell=bash
# =============================================
# helpers.sh - Shared helper functions
# =============================================

show_help() {
    cat << 'EOF'
WordPress Site Manager - Manage local Docker WordPress sites

USAGE:
    wpsite <command> [options]

COMMANDS:
    create, new, c    Create a new WordPress site
    list, ls, l       List all sites with status
    start, up         Start a site (or all sites)
    stop, down        Stop a site (or all sites)
    restart, r        Restart a site
    remove, rm        Remove a site completely
    logs              Show logs for a site
    shell             Open shell in site container
    go, cd            Jump into a site directory (spawns a new shell)
    open, o           Open site folder in file manager
    infra             Manage base infrastructure (mysql, traefik, pma)
    dns               Manage local DNS with dnsmasq
    help, h           Show this help message
    --version         Show version information

EXAMPLES:
    wpsite create my-blog           Create site at my-blog.test
    wpsite create shop local.dev    Create site at shop.local.dev
    wpsite list                     Show all sites
    wpsite start my-blog            Start the site
    wpsite stop my-blog             Stop the site
    wpsite restart my-blog          Restart the site
    wpsite remove my-blog           Remove site completely
    wpsite logs my-blog             Show site logs
    wpsite shell my-blog            Open bash in container

    wpsite infra install            Create and install base infrastructure
    wpsite infra start              Start base infrastructure
    wpsite infra stop               Stop base infrastructure
    wpsite infra restart            Restart base infrastructure
    wpsite infra status             Show infrastructure status
    wpsite infra ssl <site>         Configure SSL certificate for a site

    wpsite dns install              Install dnsmasq (brew/apt)
    wpsite dns setup                Configure dnsmasq for .test domains
    wpsite dns add <domain>         Add custom domain to dnsmasq
    wpsite dns status               Check DNS configuration status

phpMyAdmin: http://pma.test (or pma.<your-domain>)
EOF
}

check_docker() {
    if ! docker info > /dev/null 2>&1; then
        echo -e "${RED}Error: Docker is not running${NC}"
        exit 1
    fi
}

ensure_base_infra() {
    if ! docker ps --format '{{.Names}}' | grep -q 'wp-mariadb'; then
        echo -e "${YELLOW}Base infrastructure not running. Starting...${NC}"
        cd "$SITES_DIR" && docker compose up -d
        echo -e "${YELLOW}Waiting for MariaDB...${NC}"
        sleep 8
    fi
}

get_pma_domain() {
    local pma_domain="pma.test"
    for dir in "$SITES_DIR"/*/; do
        [ -f "$dir/.site-info" ] || continue
        local suffix
        suffix=$(grep "^DOMAIN_SUFFIX=" "$dir/.site-info" 2>/dev/null | cut -d= -f2)
        if [ -n "$suffix" ]; then
            pma_domain="pma.${suffix}"
            break
        fi
    done
    echo "$pma_domain"
}