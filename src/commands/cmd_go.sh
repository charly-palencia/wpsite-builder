# shellcheck shell=bash
# =============================================
# cmd_go.sh - Jump into a site directory
# =============================================

cmd_go() {
    local site_name="$1"

    if [ -z "$site_name" ]; then
        echo -e "${RED}Error: Please specify a site name${NC}"
        echo -e "Usage: ${CYAN}wpsite go <site-name>${NC}"
        exit 1
    fi

    local site_dir="$SITES_DIR/$site_name"

    if [ ! -d "$site_dir" ]; then
        echo -e "${RED}Error: Site '$site_name' not found${NC}"
        exit 1
    fi

    # If stdout is not a terminal, just print the path so it can be used
    # with "cd $(wpsite go <site>)"
    if [ ! -t 1 ]; then
        echo "$site_dir"
        return 0
    fi

    echo -e "${YELLOW}Jumping into ${CYAN}${site_dir}${NC}..."
    echo -e "${DIM}Type 'exit' to return${NC}"
    cd "$site_dir" || exit 1
    exec "$SHELL"
}
