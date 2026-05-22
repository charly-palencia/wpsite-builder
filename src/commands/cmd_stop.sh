cmd_stop() {
    local site_name="$1"

    if [ -z "$site_name" ]; then
        echo -e "${YELLOW}Stopping all sites...${NC}"
        for site_dir in "$SITES_DIR"/*/; do
            [ -f "$site_dir/docker-compose.yml" ] || continue
            grep -q "^  traefik:" "$site_dir/docker-compose.yml" 2>/dev/null && continue
            local name=$(basename "$site_dir")
            echo -e "  Stopping ${CYAN}${name}${NC}..."
            (cd "$site_dir" && docker compose down 2>/dev/null || true)
        done
        echo -e "${GREEN}All sites stopped${NC}"
        return
    fi

    local site_dir="$SITES_DIR/$site_name"

    if [ ! -d "$site_dir" ]; then
        echo -e "${RED}Error: Site '$site_name' not found${NC}"
        exit 1
    fi

    echo -e "${YELLOW}Stopping site '${site_name}'...${NC}"
    cd "$site_dir"
    docker compose down

    echo -e "${GREEN}Site stopped${NC}"
}