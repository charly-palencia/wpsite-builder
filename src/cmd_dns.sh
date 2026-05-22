cmd_dns() {
    local action="${1:-status}"
    local arg="$2"
    local os=$(detect_os)

    case "$action" in
        install)
            cmd_dns_install "$os"
            ;;
        setup|config)
            cmd_dns_setup "$os"
            ;;
        add)
            if [ -z "$arg" ]; then
                echo -e "${RED}Error: Please specify a domain${NC}"
                echo -e "Usage: ${CYAN}wpsite dns add <domain>${NC}"
                echo -e "Example: ${CYAN}wpsite dns add mysite.local${NC}"
                exit 1
            fi
            cmd_dns_add "$os" "$arg"
            ;;
        remove|rm)
            if [ -z "$arg" ]; then
                echo -e "${RED}Error: Please specify a domain${NC}"
                echo -e "Usage: ${CYAN}wpsite dns remove <domain>${NC}"
                exit 1
            fi
            cmd_dns_remove "$os" "$arg"
            ;;
        status|s)
            cmd_dns_status "$os"
            ;;
        restart|reload)
            cmd_dns_restart "$os"
            ;;
        *)
            echo -e "${RED}Unknown dns command: $action${NC}"
            echo ""
            echo "Usage: wpsite dns [install|setup|add|remove|status|restart]"
            exit 1
            ;;
    esac
}

cmd_dns_install() {
    local os="$1"

    echo -e "${CYAN}Installing dnsmasq...${NC}"

    if [ "$os" = "macos" ]; then
        if ! command -v brew &> /dev/null; then
            echo -e "${RED}Error: Homebrew is required. Install from https://brew.sh${NC}"
            exit 1
        fi
        if brew list dnsmasq &>/dev/null; then
            echo -e "${GREEN}dnsmasq is already installed${NC}"
        else
            brew install dnsmasq
        fi
        echo -e "${YELLOW}Starting dnsmasq service...${NC}"
        sudo brew services start dnsmasq

    elif [ "$os" = "linux" ]; then
        if command -v apt-get &> /dev/null; then
            sudo apt-get update
            sudo apt-get install -y dnsmasq
        elif command -v dnf &> /dev/null; then
            sudo dnf install -y dnsmasq
        elif command -v yum &> /dev/null; then
            sudo yum install -y dnsmasq
        elif command -v pacman &> /dev/null; then
            sudo pacman -S --noconfirm dnsmasq
        else
            echo -e "${RED}Error: Could not detect package manager${NC}"
            exit 1
        fi
        sudo systemctl enable dnsmasq
        sudo systemctl start dnsmasq
    else
        echo -e "${RED}Error: Unsupported OS${NC}"
        exit 1
    fi

    echo -e "${GREEN}dnsmasq installed successfully${NC}"
}

cmd_dns_setup() {
    local os="$1"

    echo -e "${CYAN}Configuring dnsmasq for .test domains...${NC}"

    if [ "$os" = "macos" ]; then
        local dnsmasq_conf="/opt/homebrew/etc/dnsmasq.conf"
        if [ ! -f "$dnsmasq_conf" ]; then
            dnsmasq_conf="/usr/local/etc/dnsmasq.conf"
        fi

        if [ ! -f "$dnsmasq_conf" ]; then
            echo -e "${RED}Error: dnsmasq.conf not found. Install dnsmasq first.${NC}"
            exit 1
        fi

        if ! grep -q "address=/test/127.0.0.1" "$dnsmasq_conf"; then
            echo "address=/test/127.0.0.1" | sudo tee -a "$dnsmasq_conf" > /dev/null
            echo -e "  ${GREEN}+${NC} Added address=/test/127.0.0.1"
        else
            echo -e "  ${YELLOW}•${NC} .test domains already configured"
        fi

        # Also add .local as fallback
        if ! grep -q "address=/local/127.0.0.1" "$dnsmasq_conf"; then
            echo "address=/local/127.0.0.1" | sudo tee -a "$dnsmasq_conf" > /dev/null
            echo -e "  ${GREEN}+${NC} Added address=/local/127.0.0.1"
        fi

        # Create resolver for .test
        if [ ! -d "/etc/resolver" ]; then
            sudo mkdir -p /etc/resolver
        fi
        if [ ! -f "/etc/resolver/test" ]; then
            echo "nameserver 127.0.0.1" | sudo tee /etc/resolver/test > /dev/null
            echo -e "  ${GREEN}+${NC} Created /etc/resolver/test"
        fi

        echo -e "${YELLOW}Restarting dnsmasq...${NC}"
        sudo brew services restart dnsmasq
        sudo dscacheutil -flushcache
        sudo killall -HUP mDNSResponder 2>/dev/null || true

    elif [ "$os" = "linux" ]; then
        if [ -d "/etc/dnsmasq.d" ]; then
            echo "address=/test/127.0.0.1" | sudo tee /etc/dnsmasq.d/wp-test.conf > /dev/null
            echo -e "  ${GREEN}+${NC} Created /etc/dnsmasq.d/wp-test.conf"
        else
            if ! grep -q "address=/test/127.0.0.1" /etc/dnsmasq.conf 2>/dev/null; then
                echo "address=/test/127.0.0.1" | sudo tee -a /etc/dnsmasq.conf > /dev/null
                echo -e "  ${GREEN}+${NC} Added to /etc/dnsmasq.conf"
            fi
        fi
        sudo systemctl restart dnsmasq
    else
        echo -e "${RED}Error: Unsupported OS${NC}"
        exit 1
    fi

    echo ""
    echo -e "${GREEN}dnsmasq configured for .test domains${NC}"
    echo ""
    echo -e "  ${YELLOW}Now you can create sites with:${NC}"
    echo -e "    wpsite create my-site"
    echo -e "    → http://my-site.test"
}

cmd_dns_add() {
    local os="$1"
    local domain="$2"

    echo -e "${CYAN}Adding domain: ${domain}${NC}"

    if [ "$os" = "macos" ]; then
        local dnsmasq_conf="/opt/homebrew/etc/dnsmasq.conf"
        if [ ! -f "$dnsmasq_conf" ]; then
            dnsmasq_conf="/usr/local/etc/dnsmasq.conf"
        fi

        if [ -f "$dnsmasq_conf" ]; then
            if ! grep -q "address=/${domain}/127.0.0.1" "$dnsmasq_conf"; then
                echo "address=/${domain}/127.0.0.1" | sudo tee -a "$dnsmasq_conf" > /dev/null
                echo -e "${GREEN}Added ${domain} -> 127.0.0.1${NC}"
                sudo brew services restart dnsmasq
            else
                echo -e "${YELLOW}${domain} already configured${NC}"
            fi
        fi

        local tld="${domain#*.}"
        if [ "$tld" != "test" ] && [ ! -f "/etc/resolver/${tld}" ]; then
            echo "nameserver 127.0.0.1" | sudo tee "/etc/resolver/${tld}" > /dev/null
            echo -e "${GREEN}Created /etc/resolver/${tld}${NC}"
            sudo dscacheutil -flushcache
        fi

    elif [ "$os" = "linux" ]; then
        if [ -d "/etc/dnsmasq.d" ]; then
            echo "address=/${domain}/127.0.0.1" | sudo tee "/etc/dnsmasq.d/wp-${domain}.conf" > /dev/null
        else
            if ! grep -q "address=/${domain}/127.0.0.1" /etc/dnsmasq.conf 2>/dev/null; then
                echo "address=/${domain}/127.0.0.1" | sudo tee -a /etc/dnsmasq.conf > /dev/null
            fi
        fi
        echo -e "${GREEN}Added ${domain} -> 127.0.0.1${NC}"
        sudo systemctl restart dnsmasq
    fi
}

cmd_dns_remove() {
    local os="$1"
    local domain="$2"

    echo -e "${YELLOW}Removing domain: ${domain}${NC}"

    if [ "$os" = "macos" ]; then
        local dnsmasq_conf="/opt/homebrew/etc/dnsmasq.conf"
        if [ ! -f "$dnsmasq_conf" ]; then
            dnsmasq_conf="/usr/local/etc/dnsmasq.conf"
        fi

        if [ -f "$dnsmasq_conf" ]; then
            sudo sed -i '' "/address=\/${domain}\/127.0.0.1/d" "$dnsmasq_conf"
            echo -e "${GREEN}Removed ${domain} from dnsmasq${NC}"
            sudo brew services restart dnsmasq
        fi

    elif [ "$os" = "linux" ]; then
        if [ -f "/etc/dnsmasq.d/wp-${domain}.conf" ]; then
            sudo rm "/etc/dnsmasq.d/wp-${domain}.conf"
            echo -e "${GREEN}Removed /etc/dnsmasq.d/wp-${domain}.conf${NC}"
            sudo systemctl restart dnsmasq
        else
            sudo sed -i "/address=\/${domain}\/127.0.0.1/d" /etc/dnsmasq.conf
            echo -e "${GREEN}Removed ${domain} from dnsmasq.conf${NC}"
            sudo systemctl restart dnsmasq
        fi
    fi
}

cmd_dns_status() {
    local os="$1"

    echo -e "${CYAN}DNS Status${NC}"
    echo -e "${DIM}─────────────────────────────────────────────${NC}"
    echo ""

    if command -v dnsmasq &> /dev/null; then
        echo -e "  ${GREEN}●${NC} dnsmasq installed"
        dnsmasq --version | head -1
    else
        echo -e "  ${YELLOW}○${NC} dnsmasq not installed"
        echo -e "      Run: ${CYAN}wpsite dns install${NC}"
    fi
    echo ""

    if [ "$os" = "macos" ]; then
        if brew services list | grep -q "dnsmasq.*started"; then
            echo -e "  ${GREEN}●${NC} dnsmasq service running"
        else
            echo -e "  ${YELLOW}○${NC} dnsmasq service not running"
        fi
    elif [ "$os" = "linux" ]; then
        if systemctl is-active --quiet dnsmasq 2>/dev/null; then
            echo -e "  ${GREEN}●${NC} dnsmasq service running"
        else
            echo -e "  ${YELLOW}○${NC} dnsmasq service not running"
        fi
    fi
    echo ""

    echo -e "  ${CYAN}Configured domains:${NC}"
    if [ "$os" = "macos" ]; then
        local dnsmasq_conf="/opt/homebrew/etc/dnsmasq.conf"
        if [ ! -f "$dnsmasq_conf" ]; then
            dnsmasq_conf="/usr/local/etc/dnsmasq.conf"
        fi
        if [ -f "$dnsmasq_conf" ]; then
            grep "^address=" "$dnsmasq_conf" 2>/dev/null | while read line; do
                local dom=$(echo "$line" | sed 's/address=\/\(.*\)\/127.0.0.1/\1/')
                echo -e "      ${dom} -> 127.0.0.1"
            done
        fi

        if [ -d "/etc/resolver" ]; then
            echo ""
            echo -e "  ${CYAN}Resolver configs:${NC}"
            for f in /etc/resolver/*; do
                if [ -f "$f" ]; then
                    local tld=$(basename "$f")
                    echo -e "      /etc/resolver/${tld}"
                fi
            done
        fi

    elif [ "$os" = "linux" ]; then
        if [ -d "/etc/dnsmasq.d" ]; then
            for f in /etc/dnsmasq.d/wp-*.conf; do
                if [ -f "$f" ]; then
                    grep "^address=" "$f" | while read line; do
                        local dom=$(echo "$line" | sed 's/address=\/\(.*\)\/127.0.0.1/\1/')
                        echo -e "      ${dom} -> 127.0.0.1"
                    done
                fi
            done
        fi
        grep "^address=" /etc/dnsmasq.conf 2>/dev/null | while read line; do
            local dom=$(echo "$line" | sed 's/address=\/\(.*\)\/127.0.0.1/\1/')
            echo -e "      ${dom} -> 127.0.0.1"
        done
    fi
    echo ""
}

cmd_dns_restart() {
    local os="$1"

    echo -e "${YELLOW}Restarting dnsmasq...${NC}"

    if [ "$os" = "macos" ]; then
        sudo brew services restart dnsmasq
        sudo dscacheutil -flushcache
        sudo killall -HUP mDNSResponder 2>/dev/null || true
    elif [ "$os" = "linux" ]; then
        sudo systemctl restart dnsmasq
    fi

    echo -e "${GREEN}dnsmasq restarted${NC}"
}