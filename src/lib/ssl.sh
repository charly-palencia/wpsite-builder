# shellcheck shell=bash
# =============================================
# ssl.sh - mkcert and SSL functions
# =============================================

check_mkcert_installed() {
    command -v mkcert &> /dev/null
}

install_mkcert() {
    local os
    os=$(detect_os)

    echo -e "${YELLOW}Installing mkcert...${NC}"

    if [ "$os" = "macos" ]; then
        if ! command -v brew &> /dev/null; then
            echo -e "${RED}Error: Homebrew is required. Install from https://brew.sh${NC}"
            exit 1
        fi
        brew install mkcert nss
        mkcert -install
    elif [ "$os" = "linux" ]; then
        if command -v apt-get &> /dev/null; then
            sudo apt-get update
            sudo apt-get install -y mkcert libnss3-tools
        elif command -v dnf &> /dev/null; then
            sudo dnf install -y mkcert
        elif command -v yum &> /dev/null; then
            sudo yum install -y mkcert
        elif command -v pacman &> /dev/null; then
            sudo pacman -S --noconfirm mkcert
        else
            echo -e "${RED}Error: Could not detect package manager${NC}"
            echo -e "${CYAN}Install manually: https://github.com/FiloSottile/mkcert${NC}"
            exit 1
        fi
        mkcert -install
    else
        echo -e "${RED}Error: Unsupported OS${NC}"
        exit 1
    fi

    echo -e "${GREEN}mkcert installed successfully${NC}"
}

generate_ssl_cert() {
    local domain="$1"
    local cert_dir="$2"

    mkdir -p "$cert_dir"

    echo -e "${YELLOW}Generating SSL certificate for ${domain}...${NC}"

    local mkcert_result=0
    mkcert -cert-file "$cert_dir/cert.pem" -key-file "$cert_dir/key.pem" "$domain" "*.${domain}" 2>/dev/null || mkcert_result=$?

    if [ "$mkcert_result" -eq 0 ]; then
        echo -e "${GREEN}SSL certificate generated successfully${NC}"
        return 0
    else
        echo -e "${RED}Error generating SSL certificate${NC}"
        return 1
    fi
}

setup_mkcert_caroot() {
    if ! mkcert -CAROOT 2>/dev/null | grep -q .; then
        echo -e "${YELLOW}Installing mkcert CA root...${NC}"
        mkcert -install
    fi
}

# Scan all site directories and regenerate traefik-dynamic.yml from scratch.
# This keeps the config clean with no stale entries from removed sites
# and avoids YAML corruption from sed-based patching.
regenerate_traefik_config() {
    local dynamic_file="$SITES_DIR/traefik-dynamic.yml"
    local certs_dir="$SITES_DIR/certs"
    mkdir -p "$certs_dir"

    # Copy each site's SSL certs to the shared certs dir
    for site_dir in "$SITES_DIR"/*/; do
        [ -f "$site_dir/.site-info" ] || continue
        local site_name
        site_name=$(basename "$site_dir")
        if [ -f "$site_dir/ssl/cert.pem" ] && [ -f "$site_dir/ssl/key.pem" ]; then
            cp "$site_dir/ssl/cert.pem" "$certs_dir/${site_name}-cert.pem" 2>/dev/null || true
            cp "$site_dir/ssl/key.pem" "$certs_dir/${site_name}-key.pem" 2>/dev/null || true
        fi
    done

    # Generate the full config from scratch
    {
        # Base header
        echo "http:"
        echo "  middlewares:"
        echo "    redirect-to-https:"
        echo "      redirectScheme:"
        echo "        scheme: https"
        echo "        permanent: true"
        echo "  routers:"
        echo "    phpmyadmin:"
        echo "      rule: \"Host(\`pma.test\`)\""
        echo "      entryPoints:"
        echo "        - \"web\""
        echo "      service: \"phpmyadmin\""

        # Per-site routers
        for site_dir in "$SITES_DIR"/*/; do
            [ -f "$site_dir/.site-info" ] || continue
            local site_name
            site_name=$(basename "$site_dir")
            local domain
            domain=$(grep "^DOMAIN=" "$site_dir/.site-info" | cut -d= -f2)
            local ssl
            ssl=$(grep "^SSL=" "$site_dir/.site-info" | cut -d= -f2)

            if [ "$ssl" = "true" ]; then
                echo "    ${site_name}-https:"
                echo "      rule: \"Host(\`${domain}\`)\""
                echo "      entryPoints:"
                echo "        - \"websecure\""
                echo "      service: \"${site_name}\""
                echo "      tls: {}"
                echo "    ${site_name}-http:"
                echo "      rule: \"Host(\`${domain}\`)\""
                echo "      entryPoints:"
                echo "        - \"web\""
                echo "      middlewares:"
                echo "        - \"redirect-to-https\""
                echo "      service: \"${site_name}\""
            else
                echo "    ${site_name}:"
                echo "      rule: \"Host(\`${domain}\`)\""
                echo "      entryPoints:"
                echo "        - \"web\""
                echo "      service: \"${site_name}\""
            fi
        done

        # Services header
        echo "  services:"
        echo "    phpmyadmin:"
        echo "      loadBalancer:"
        echo "        servers:"
        echo "          - url: \"http://wp-phpmyadmin:80\""

        # Per-site services
        for site_dir in "$SITES_DIR"/*/; do
            [ -f "$site_dir/.site-info" ] || continue
            local site_name
            site_name=$(basename "$site_dir")

            echo "    ${site_name}:"
            echo "      loadBalancer:"
            echo "        servers:"
            echo "          - url: \"http://wp-${site_name}:80\""
        done

        # TLS section
        echo ""
        echo "tls:"
        echo "  stores:"
        echo "    default:"
        echo "      defaultCertificate:"
        echo "        certFile: /etc/traefik/certs/default.pem"
        echo "        keyFile: /etc/traefik/certs/default-key.pem"
        echo "  certificates:"
        echo "    - certFile: /etc/traefik/certs/default.pem"
        echo "      keyFile: /etc/traefik/certs/default-key.pem"

        # Per-site TLS certs
        for site_dir in "$SITES_DIR"/*/; do
            [ -f "$site_dir/.site-info" ] || continue
            local site_name
            site_name=$(basename "$site_dir")
            local ssl
            ssl=$(grep "^SSL=" "$site_dir/.site-info" | cut -d= -f2)

            if [ "$ssl" = "true" ]; then
                echo "    - certFile: /etc/traefik/certs/${site_name}-cert.pem"
                echo "      keyFile: /etc/traefik/certs/${site_name}-key.pem"
            fi
        done
    } > "$dynamic_file"

    echo -e "${GREEN}Traefik configuration regenerated (${dynamic_file})${NC}"
}