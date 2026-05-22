cmd_logs() {
    local site_name="$1"

    if [ -z "$site_name" ]; then
        echo -e "${RED}Error: Please specify a site name${NC}"
        echo -e "Usage: ${CYAN}wpsite logs <site-name>${NC}"
        exit 1
    fi

    local site_dir="$SITES_DIR/$site_name"

    if [ ! -d "$site_dir" ]; then
        echo -e "${RED}Error: Site '$site_name' not found${NC}"
        exit 1
    fi

    cd "$site_dir"
    docker compose logs -f
}