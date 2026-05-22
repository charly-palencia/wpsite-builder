# shellcheck shell=bash
cmd_infra_install() {

    check_docker

    if [ ! -d "$SITES_DIR" ]; then
        echo -e "${YELLOW}Creating directory ${SITES_DIR}...${NC}"
        mkdir -p "$SITES_DIR"
    fi

    if [ -f "$SITES_DIR/docker-compose.yml" ]; then
        echo -e "${YELLOW}docker-compose.yml already exists at ${SITES_DIR}${NC}"
        read -rp "Overwrite? (y/N): " overwrite
        if [[ ! "$overwrite" =~ ^[Yy]$ ]]; then
            echo "Canceled."
            exit 0
        fi
    fi

    if ! docker network ls | grep -q "wp-network"; then
        echo -e "${YELLOW}Creating Docker network 'wp-network'...${NC}"
        docker network create wp-network
    else
        echo -e "${GREEN}Docker network 'wp-network' already exists${NC}"
    fi

    echo -e "${YELLOW}Creating docker-compose.yml...${NC}"
    cat > "$SITES_DIR/docker-compose.yml" <<'COMPOSE'
services:
  mariadb:
    image: mariadb:10.6
    container_name: wp-mariadb
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: wp_root_secret_2024
      MYSQL_DATABASE: wordpress
    volumes:
      - mariadb_data:/var/lib/mysql
    networks:
      - wp-network
    healthcheck:
      test: ["CMD", "healthcheck.sh", "--connect", "--innodb_initialized"]
      start_period: 10s
      interval: 10s
      timeout: 5s
      retries: 3

  traefik:
    image: traefik:v3.3
    container_name: wp-traefik
    restart: unless-stopped
    command:
      - "--api.insecure=true"
      - "--providers.file.directory=/etc/traefik/dynamic"
      - "--providers.file.watch=true"
      - "--entrypoints.web.address=:80"
      - "--entrypoints.websecure.address=:443"
    ports:
      - "80:80"
      - "443:443"
      - "8080:8080"
    volumes:
      - ./traefik-dynamic.yml:/etc/traefik/dynamic/traefik-dynamic.yml:ro
      - ./certs:/etc/traefik/certs:ro
    networks:
      - wp-network

  phpmyadmin:
    image: phpmyadmin/phpmyadmin:latest
    container_name: wp-phpmyadmin
    restart: unless-stopped
    environment:
      PMA_HOST: wp-mariadb
      PMA_PORT: 3306
    networks:
      - wp-network

volumes:
  mariadb_data:

networks:
  wp-network:
    external: true
COMPOSE

    echo -e "${YELLOW}Creating traefik-dynamic.yml...${NC}"
    cat > "$SITES_DIR/traefik-dynamic.yml" <<'DYNAMIC'
http:
  middlewares:
    redirect-to-https:
      redirectScheme:
        scheme: https
        permanent: true
  routers:
    phpmyadmin:
      rule: "Host(`pma.test`)"
      entryPoints:
        - "web"
      service: "phpmyadmin"

  services:
    phpmyadmin:
      loadBalancer:
        servers:
          - url: "http://wp-phpmyadmin:80"

tls:
  stores:
    default:
      defaultCertificate:
        certFile: /etc/traefik/certs/default.pem
        keyFile: /etc/traefik/certs/default-key.pem
  certificates:
    - certFile: /etc/traefik/certs/default.pem
      keyFile: /etc/traefik/certs/default-key.pem
DYNAMIC

    mkdir -p "$SITES_DIR/certs"

    if ! check_mkcert_installed; then
        echo -e "${YELLOW}mkcert not found. HTTPS sites will require mkcert installation.${NC}"
    else
        setup_mkcert_caroot
        if [ ! -f "$SITES_DIR/certs/default.pem" ]; then
            echo -e "${YELLOW}Generating default SSL certificate for Traefik...${NC}"
            local mkcert_result=0
            mkcert -cert-file "$SITES_DIR/certs/default.pem" -key-file "$SITES_DIR/certs/default-key.pem" "*.test" "*.local" "localhost" 2>/dev/null || mkcert_result=$?
            if [ "$mkcert_result" -eq 0 ]; then
                echo -e "${GREEN}Default certificate generated${NC}"
            fi
        fi
    fi

    echo ""
    echo -e "${GREEN}Base infrastructure installed successfully!${NC}"
    echo ""
    echo -e "  ${CYAN}Location:${NC} ${SITES_DIR}/docker-compose.yml"
    echo -e "  ${CYAN}Network:${NC} wp-network"
    echo ""
    echo -e "  ${YELLOW}Next steps:${NC}"
    echo -e "    wpsite infra start      # Start infrastructure"
    echo -e "    wpsite dns setup        # Configure DNS for .test domains"
    echo -e "    wpsite create my-site   # Create your first WordPress site"
}

cmd_infra() {
    local action="$1"

    if [ -z "$action" ]; then
        action="status"
    fi

    check_docker

    case "$action" in
        start|up)
            echo -e "${YELLOW}Starting base infrastructure...${NC}"
            if [ ! -d "$SITES_DIR" ]; then
                echo -e "${RED}Error: $SITES_DIR does not exist${NC}"
                exit 1
            fi
            cd "$SITES_DIR" || exit 1
            docker compose up -d
            echo -e "${GREEN}Infrastructure started${NC}"
            echo ""
            echo -e "  ${CYAN}Services:${NC}"
            docker ps --format '  {{.Names}} ({{.Status}})' | grep -E 'wp-mariadb|wp-traefik|wp-phpmyadmin' || true
            ;;
        stop|down)
            echo -e "${YELLOW}Stopping base infrastructure...${NC}"
            cd "$SITES_DIR" || exit 1
            docker compose down
            echo -e "${GREEN}Infrastructure stopped${NC}"
            ;;
        restart|r)
            echo -e "${YELLOW}Restarting base infrastructure...${NC}"
            cd "$SITES_DIR" || exit 1
            docker compose restart
            echo -e "${GREEN}Infrastructure restarted${NC}"
            echo ""
            echo -e "  ${CYAN}Services:${NC}"
            docker ps --format '  {{.Names}} ({{.Status}})' | grep -E 'wp-mariadb|wp-traefik|wp-phpmyadmin' || true
            ;;
        ssl)
            local site_name="$2"
            if [ -z "$site_name" ]; then
                echo -e "${RED}Error: Site name required${NC}"
                echo "Usage: wpsite infra ssl <site_name>"
                exit 1
            fi

            local site_dir="$SITES_DIR/$site_name"
            if [ ! -d "$site_dir" ]; then
                echo -e "${RED}Error: Site '$site_name' not found${NC}"
                exit 1
            fi

            if [ ! -d "$site_dir/ssl" ]; then
                echo -e "${RED}Error: Site '$site_name' does not have SSL certificates${NC}"
                exit 1
            fi

            echo -e "${CYAN}Configuring SSL for site: $site_name${NC}"

            local domain=""
            if [ -f "$site_dir/.site-info" ]; then
                local _domain
                _domain=$(grep "^DOMAIN=" "$site_dir/.site-info" | cut -d= -f2)
                domain="$_domain"
            fi

            if [ -z "$domain" ] && [ -f "$site_dir/docker-compose.yml" ]; then
                local _domain
                _domain=$(grep -o "Host(\`[^']*\`)" "$site_dir/docker-compose.yml" | head -1 | sed "s/Host(\`//;s/\`//")
                domain="$_domain"
            fi

            if [ -z "$domain" ] && [ -f "$SITES_DIR/traefik-dynamic.yml" ]; then
                local _domain
                _domain=$(grep -A2 "rule: \"Host(\`${site_name}" "$SITES_DIR/traefik-dynamic.yml" | grep "rule:" | sed "s/.*Host(\`//;s/\`)//" | head -1)
                domain="$_domain"
            fi

            if [ -z "$domain" ]; then
                echo -e "${RED}Error: Could not determine domain for site '$site_name'${NC}"
                echo "Please provide the domain:"
                read -rp "Domain (e.g., gmaq.test): " domain
                if [ -z "$domain" ]; then
                    echo -e "${RED}Domain is required${NC}"
                    exit 1
                fi
            fi

            echo -e "${YELLOW}Configuring SSL in Traefik for $site_name ($domain)...${NC}"
            if ! configure_site_ssl_in_traefik "$site_name" "$domain"; then
                echo -e "${RED}Failed to configure SSL${NC}"
                exit 1
            fi

            echo -e "${YELLOW}Restarting Traefik...${NC}"
            cd "$SITES_DIR" || exit 1
            docker compose restart traefik

            echo -e "${GREEN}SSL configured for $site_name ($domain)${NC}"
            echo ""
            echo -e "  ${CYAN}Certificate location:${NC}"
            echo -e "    $SITES_DIR/certs/${site_name}-cert.pem"
            echo -e "    $SITES_DIR/certs/${site_name}-key.pem"
            echo ""
            echo -e "  ${CYAN}Test at:${NC}"
            echo -e "    https://$domain"
            ;;
        status|s)
            echo -e "${CYAN}Infrastructure Status${NC}"
            echo -e "${DIM}─────────────────────────────────────────────${NC}"
            echo ""
            local infra_running=0
            for svc in wp-mariadb wp-traefik wp-phpmyadmin; do
                if docker ps --format '{{.Names}}' | grep -q "^${svc}$"; then
                    local status
                    status=$(docker ps --format '{{.Status}}' --filter "name=${svc}")
                    echo -e "  ${GREEN}●${NC} ${svc}"
                    echo -e "       ${DIM}${status}${NC}"
                    infra_running=1
                else
                    echo -e "  ${YELLOW}○${NC} ${svc} ${YELLOW}(stopped)${NC}"
                fi
            done
            echo ""
            if [ "$infra_running" -eq 1 ]; then
                local pma_domain
                pma_domain=$(get_pma_domain)
                echo -e "  phpMyAdmin: ${CYAN}http://${pma_domain}${NC}"
            fi
            ;;
        install|init)
            cmd_infra_install
            ;;
        logs)
            cd "$SITES_DIR" || exit 1
            docker compose logs -f
            ;;
        *)
            echo -e "${RED}Unknown infra command: $action${NC}"
            echo ""
            echo "Usage: wpsite infra [install|start|stop|restart|status|logs|ssl <site>]"
            exit 1
            ;;
    esac
}