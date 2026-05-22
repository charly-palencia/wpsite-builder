# shellcheck shell=bash
# =============================================
# ssl.sh - mkcert and SSL functions
# =============================================

check_mkcert_installed() {
    if command -v mkcert &> /dev/null; then
        return 0
    else
        return 1
    fi
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

    # Generate certificate and key
    local mkcert_result
    mkcert_result=0
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

# Configure SSL for a site in Traefik dynamic config.
# Copies certs to certs/, adds/dedupes cert in tls.certificates,
# and ensures HTTPS routers + redirect middleware exist for the site.
configure_site_ssl_in_traefik() {
    local site_name="$1"
    local domain="$2"
    local site_dir="$SITES_DIR/$site_name"
    local dynamic_file="$SITES_DIR/traefik-dynamic.yml"
    local certs_dir="$SITES_DIR/certs"

    # Ensure certs directory exists
    mkdir -p "$certs_dir"

    # Copy site certificates to the shared certs directory
    if [ -f "$site_dir/ssl/cert.pem" ] && [ -f "$site_dir/ssl/key.pem" ]; then
        cp "$site_dir/ssl/cert.pem" "$certs_dir/${site_name}-cert.pem"
        cp "$site_dir/ssl/key.pem" "$certs_dir/${site_name}-key.pem"
        echo -e "${GREEN}Certificates copied to shared certs directory${NC}"
    else
        echo -e "${RED}Error: SSL certificates not found for $site_name${NC}"
        echo -e "Run 'wpsite create' with HTTPS enabled to generate certificates."
        return 1
    fi

    # Read the current dynamic file
    local content
    content=$(cat "$dynamic_file")

    # Remove any existing cert entry for this site (dedup)
    content=$(echo "$content" | sed -n '/# cert: '"${site_name}"'/,/^  - certFile:/{/^  - certFile:/d; /# cert: '"${site_name}"'/d;};p')

    # Insert after the tls: certificates: line
    content=$(echo "$content" | sed "/^tls:/,/^  stores:/{
/^  certificates:/a\
    - certFile: /etc/traefik/certs/${site_name}-cert.pem\
      keyFile: /etc/traefik/certs/${site_name}-key.pem
}")

    # Ensure HTTPS router exists for this site
    if ! echo "$content" | grep -q "router-${site_name}-https"; then
        # Insert before the services section
        content=$(echo "$content" | sed "/^  services:/i\\
    ${site_name}-https:\\
      rule: \"Host(\`${domain}\`)\"\\
      entryPoints:\\
        - \"websecure\"\\
      service: \"${site_name}\"\\
      tls: {}
")
    fi

    # Ensure redirect middleware exists
    if ! echo "$content" | grep -q "redirect-to-https"; then
        content=$(echo "$content" | sed "/^  middlewares:/a\\
    redirect-to-https:\\
      redirectScheme:\\
        scheme: https\\
        permanent: true
")
    fi

    # Ensure HTTP router with redirect exists for this site
    if ! echo "$content" | grep -q "router-${site_name}-http"; then
        content=$(echo "$content" | sed "/^  services:/i\\
    ${site_name}-http:\\
      rule: \"Host(\`${domain}\`)\"\\
      entryPoints:\\
        - \"web\"\\
      middlewares:\\
        - \"redirect-to-https\"\\
      service: \"${site_name}\"
")
    fi

    echo "$content" > "$dynamic_file"
    echo -e "${GREEN}Traefik configuration updated for ${domain} (HTTPS)${NC}"
}