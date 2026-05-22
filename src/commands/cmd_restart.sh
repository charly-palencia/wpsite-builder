# shellcheck shell=bash
cmd_restart() {

    if [ -z "$site_name" ]; then
        echo -e "${RED}Error: Please specify a site name${NC}"
        echo -e "Usage: ${CYAN}wpsite restart <site-name>${NC}"
        exit 1
    fi

    local site_dir="$SITES_DIR/$site_name"

    if [ ! -d "$site_dir" ]; then
        echo -e "${RED}Error: Site '$site_name' not found${NC}"
        exit 1
    fi

    echo -e "${YELLOW}Restarting site '${site_name}'...${NC}"
    cd "$site_dir" || exit 1
    docker compose restart

    if [ -f "$site_dir/.site-info" ]; then
        local domain
        domain=$(grep "^DOMAIN=" "$site_dir/.site-info" | cut -d= -f2)
        echo -e "${GREEN}Site restarted: http://${domain}${NC}"
    else
        echo -e "${GREEN}Site restarted${NC}"
    fi
}