# shellcheck shell=bash
# =============================================
# cmd_open.sh - Open site folder in file manager
# =============================================

cmd_open() {
    local site_name="$1"

    if [ -z "$site_name" ]; then
        echo -e "${RED}Error: Please specify a site name${NC}"
        echo -e "Usage: ${CYAN}wpsite open <site-name>${NC}"
        exit 1
    fi

    local site_dir="$SITES_DIR/$site_name"

    if [ ! -d "$site_dir" ]; then
        echo -e "${RED}Error: Site '$site_name' not found${NC}"
        exit 1
    fi

    local os
    os=$(detect_os)

    if [ "$os" = "macos" ]; then
        echo -e "${CYAN}Opening ${site_dir} in Finder...${NC}"
        open "$site_dir"
    elif [ "$os" = "linux" ]; then
        if command -v xdg-open &> /dev/null; then
            echo -e "${CYAN}Opening ${site_dir}...${NC}"
            xdg-open "$site_dir"
        else
            echo -e "${RED}Error: xdg-open is required on Linux${NC}"
            echo -e "Install it with your package manager (e.g. sudo apt install xdg-utils)"
            exit 1
        fi
    else
        echo -e "${RED}Error: Unsupported OS for 'open' command${NC}"
        exit 1
    fi
}
