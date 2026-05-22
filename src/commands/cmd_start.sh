cmd_start() {
    local site_name="$1"

    if [ -z "$site_name" ]; then
        echo -e "${YELLOW}Starting all sites...${NC}"
        ensure_base_infra
        for site_dir in "$SITES_DIR"/*/; do
            [ -f "$site_dir/docker-compose.yml" ] || continue
            grep -q "^  traefik:" "$site_dir/docker-compose.yml" 2>/dev/null && continue
            local name=$(basename "$site_dir")
            echo -e "  Starting ${CYAN}${name}${NC}..."
            (cd "$site_dir" && docker compose up -d)
        done
        echo -e "${GREEN}All sites started${NC}"
        return
    fi

    local site_dir="$SITES_DIR/$site_name"

    if [ ! -d "$site_dir" ]; then
        echo -e "${RED}Error: Site '$site_name' not found${NC}"
        exit 1
    fi

    ensure_base_infra

    echo -e "${YELLOW}Starting site '${site_name}'...${NC}"
    cd "$site_dir"
    docker compose up -d

    if [ -f "$site_dir/.site-info" ]; then
        local domain=$(grep "^DOMAIN=" "$site_dir/.site-info" | cut -d= -f2)
        echo -e "${GREEN}Site started: http://${domain}${NC}"
    else
        echo -e "${GREEN}Site started${NC}"
    fi
}