# shellcheck shell=bash
cmd_remove() {
    local site_name="$1"

    if [ -z "$site_name" ]; then
        echo -e "${RED}Error: You must specify a site name${NC}"
        echo -e "Usage: ${CYAN}wpsite remove <site-name>${NC}"
        exit 1
    fi

    local site_dir="$SITES_DIR/$site_name"

    if [ ! -d "$site_dir" ]; then
        echo -e "${RED}Error: Site '$site_name' not found${NC}"
        exit 1
    fi

    local db_name="wp_${site_name//-/_}"
    local db_user="wp_${site_name//-/_}"
    if [ -f "$site_dir/.site-info" ]; then
        local _db_name _db_user
        _db_name=$(grep "^DB_NAME=" "$site_dir/.site-info" | cut -d= -f2)
        _db_user=$(grep "^DB_USER=" "$site_dir/.site-info" | cut -d= -f2)
        db_name="$_db_name"
        db_user="$_db_user"
    fi

    echo -e "${YELLOW}This will completely remove site '${site_name}':${NC}"
    echo -e "  - WordPress container"
    echo -e "  - Database: ${CYAN}${db_name}${NC}"
    echo -e "  - DB User: ${CYAN}${db_user}${NC}"
    echo -e "  - Files: ${CYAN}${site_dir}${NC}"
    echo ""
    read -rp "Are you sure? (y/N): " confirm

    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Canceled."
        exit 0
    fi

    echo -e "${YELLOW}Removing site...${NC}"

    cd "$site_dir" || exit 1
    docker compose down -v 2>/dev/null || true

    if docker ps --format '{{.Names}}' | grep -q 'wp-mariadb'; then
        echo -e "${YELLOW}Removing database and user...${NC}"
        docker exec wp-mariadb mariadb -uroot -p"${DB_ROOT_PASSWORD}" -e "
            DROP DATABASE IF EXISTS \`${db_name}\`;
            DROP USER IF EXISTS '${db_user}'@'%';
            FLUSH PRIVILEGES;
        " 2>/dev/null || true
    fi

    if ! rm -rf "$site_dir" 2>/dev/null; then
        echo -e "${YELLOW}sudo required to remove files...${NC}"
        sudo rm -rf "$site_dir"
    fi

    echo -e "${GREEN}Site '${site_name}' removed${NC}"
}