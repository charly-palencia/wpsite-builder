cmd_list() {
    echo ""
    echo -e "${CYAN}WordPress Sites${NC}"
    echo -e "${DIM}─────────────────────────────────────────────${NC}"

    if [ ! -d "$SITES_DIR" ]; then
        echo "  No sites found."
        exit 0
    fi

    local pma_domain=$(get_pma_domain)
    local found=0

    for site_dir in "$SITES_DIR"/*/; do
        [ -f "$site_dir/docker-compose.yml" ] || continue
        grep -q "^  traefik:" "$site_dir/docker-compose.yml" 2>/dev/null && continue

        local site_name=$(basename "$site_dir")
        found=1

        if docker ps --format '{{.Names}}' | grep -q "wp-${site_name}$"; then
            local status="${GREEN}● running${NC}"
        else
            local status="${YELLOW}○ stopped${NC}"
        fi

        local site_domain="${site_name}.test"
        local db_name="wp_${site_name//-/_}"
        if [ -f "$site_dir/.site-info" ]; then
            site_domain=$(grep "^DOMAIN=" "$site_dir/.site-info" | cut -d= -f2)
        fi

        echo -e "  ${status}  ${CYAN}http://${site_domain}${NC}"
        echo -e "            DB: ${DIM}${db_name}${NC}  ${DIM}${site_dir}wordpress/${NC}"
    done

    if [ "$found" -eq 0 ]; then
        echo "  No sites found. Run: wpsite create <name>"
    fi

    echo ""
    echo -e "${DIM}─────────────────────────────────────────────${NC}"
    echo -e "  phpMyAdmin: ${CYAN}http://${pma_domain}${NC} ${DIM}(root / ${DB_ROOT_PASSWORD})${NC}"
    echo ""
}