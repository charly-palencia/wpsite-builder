# shellcheck shell=bash
cmd_create() {
    local site_name="$1"
    local domain_suffix="$2"

    if [ -z "$site_name" ]; then
        echo -e "${RED}Error: You must specify a site name${NC}"
        echo -e "Usage: ${CYAN}wpsite create my-site${NC}"
        exit 1
    fi

    local site_dir="$SITES_DIR/$site_name"

    if [ -n "$domain_suffix" ]; then
        local domain="${site_name}.${domain_suffix}"
    else
        read -rp "Enter domain suffix (default: test): " domain_suffix
        domain_suffix=${domain_suffix:-test}
        local domain="${site_name}.${domain_suffix}"
    fi

    local pma_domain="pma.${domain_suffix}"

    read -rp "Use HTTPS? (Y/n): " use_https
    use_https=${use_https:-Y}
    if [[ "$use_https" =~ ^[Nn]$ ]]; then
        local traefik_entrypoint="web"
        local protocol="http"
        local use_ssl=false
    else
        if ! check_mkcert_installed; then
            echo -e "${RED}Error: mkcert is required for HTTPS${NC}"
            read -rp "Install mkcert now? (Y/n): " install_mk
            install_mk=${install_mk:-Y}
            if [[ "$install_mk" =~ ^[Yy]$ ]]; then
                install_mkcert
                setup_mkcert_caroot
            else
                echo -e "${RED}Cannot create site with HTTPS without mkcert${NC}"
                exit 1
            fi
        else
            setup_mkcert_caroot
        fi

        local traefik_entrypoint="websecure"
        local protocol="https"
        local use_ssl=true
    fi

    local db_name="wp_${site_name//-/_}"
    local db_user="wp_${site_name//-/_}"
    local db_password
    db_password=$(openssl rand -hex 12)

    if [ -d "$site_dir" ]; then
        echo -e "${RED}Error: Site '$site_name' already exists${NC}"
        exit 1
    fi

    check_docker
    ensure_base_infra

    if ! docker ps --format '{{.Names}}' | grep -q 'wp-traefik'; then
        echo -e "${RED}Error: Traefik is not running${NC}"
        exit 1
    fi

    echo -e "${CYAN}Creating WordPress site: ${GREEN}${protocol}://${domain}${NC}"

    local user_exists
    user_exists=$(docker exec wp-mariadb mariadb -uroot -p"${DB_ROOT_PASSWORD}" -e "SELECT 1 FROM mysql.user WHERE user='${db_user}' LIMIT 1;" 2>/dev/null | tail -n1 || echo "0")

    if [ "$user_exists" = "1" ]; then
        echo -e "${YELLOW}Database user exists. Updating...${NC}"
        docker exec wp-mariadb mariadb -uroot -p"${DB_ROOT_PASSWORD}" -e "ALTER USER '${db_user}'@'%' IDENTIFIED BY '${db_password}'; FLUSH PRIVILEGES;" 2>/dev/null || true
        docker exec wp-mariadb mariadb -uroot -p"${DB_ROOT_PASSWORD}" -e "
            CREATE DATABASE IF NOT EXISTS \`${db_name}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
            GRANT ALL PRIVILEGES ON \`${db_name}\`.* TO '${db_user}'@'%';
            FLUSH PRIVILEGES;
        "
    else
        docker exec wp-mariadb mariadb -uroot -p"${DB_ROOT_PASSWORD}" -e "
            CREATE DATABASE IF NOT EXISTS \`${db_name}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
            CREATE USER '${db_user}'@'%' IDENTIFIED BY '${db_password}';
            GRANT ALL PRIVILEGES ON \`${db_name}\`.* TO '${db_user}'@'%';
            FLUSH PRIVILEGES;
        "
    fi

    mkdir -p "$site_dir/wordpress"

    if [ "$use_ssl" = true ]; then
        local cert_dir="$site_dir/ssl"
        if ! generate_ssl_cert "$domain" "$cert_dir"; then
            echo -e "${RED}Failed to generate SSL certificate${NC}"
            exit 1
        fi
    fi

    cat > "$site_dir/php.ini" <<'PHPCONFIG'
upload_max_filesize = 256M
post_max_size = 256M
memory_limit = 512M
max_execution_time = 300
max_input_time = 300
PHPCONFIG

    cat > "$site_dir/docker-compose.yml" <<COMPOSE
services:
  wordpress:
    image: wordpress:latest
    container_name: wp-${site_name}
    restart: unless-stopped
    environment:
      WORDPRESS_DB_HOST: wp-mariadb:3306
      WORDPRESS_DB_USER: ${db_user}
      WORDPRESS_DB_PASSWORD: ${db_password}
      WORDPRESS_DB_NAME: ${db_name}
    volumes:
      - ./wordpress:/var/www/html
      - ./php.ini:/usr/local/etc/php/php.ini
COMPOSE

    if [ "$use_ssl" = true ]; then
        cat >> "$site_dir/docker-compose.yml" <<SSL
      - ./ssl/cert.pem:/etc/ssl/certs/cert.pem:ro
      - ./ssl/key.pem:/etc/ssl/private/key.pem:ro
SSL
    fi

    cat >> "$site_dir/docker-compose.yml" <<COMPOSE
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.${site_name}.rule=Host(\`${domain}\`)"
      - "traefik.http.routers.${site_name}.entrypoints=${traefik_entrypoint}"
      - "traefik.http.services.${site_name}.loadbalancer.server.port=80"
    networks:
      - wp-network

networks:
  wp-network:
    external: true
COMPOSE

    # Save site info (must be before regenerate, which reads .site-info)
    cat > "$site_dir/.site-info" <<INFO
SITE_NAME=${site_name}
DOMAIN=${domain}
DOMAIN_SUFFIX=${domain_suffix}
DB_NAME=${db_name}
DB_USER=${db_user}
DB_PASSWORD=${db_password}
SSL=${use_ssl}
INFO

    # Regenerate Traefik config (scans all sites, writes clean YAML)
    regenerate_traefik_config

    if [ "$use_ssl" = true ]; then
        echo -e "${YELLOW}Restarting Traefik...${NC}"
        cd "$SITES_DIR" && docker compose restart traefik
    fi

    # Pull latest images then start the site
    echo -e "${YELLOW}Pulling latest Docker images...${NC}"
    cd "$site_dir" && docker compose pull
    echo -e "${YELLOW}Starting WordPress site...${NC}"
    cd "$site_dir" && docker compose up -d

    echo ""
    echo -e "${GREEN}WordPress site created successfully!${NC}"
    echo ""
    echo -e "  ${CYAN}Site:${NC}     ${protocol}://${domain}"
    echo -e "  ${CYAN}PHPMyAdmin:${NC} http://${pma_domain}"
    echo -e "  ${CYAN}Database:${NC}  ${db_name} (user: ${db_user})"
    echo ""
    echo -e "  ${DIM}WordPress files: ${site_dir}/wordpress/${NC}"
    echo -e "  ${DIM}Docker Compose:  ${site_dir}/docker-compose.yml${NC}"
    echo ""
    echo -e "  ${YELLOW}Note: It may take a few seconds for WordPress to initialize.${NC}"
    echo -e "  ${YELLOW}Check progress: wpsite logs ${site_name}${NC}"
}