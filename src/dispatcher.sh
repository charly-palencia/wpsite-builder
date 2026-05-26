# shellcheck shell=bash

COMMAND="${1:-help}"
ARG1="$2"
ARG2="$3"

# shellcheck disable=SC2034

if [ "$COMMAND" = "--version" ] || [ "$COMMAND" = "-v" ] || [ "$COMMAND" = "version" ]; then
    echo "wpsite version $VERSION"
    exit 0
fi

case "$COMMAND" in
    create|new|c)
        cmd_create "$ARG1" "$ARG2"
        ;;
    list|ls|l)
        cmd_list
        ;;
    start|up)
        cmd_start "$ARG1"
        ;;
    stop|down)
        cmd_stop "$ARG1"
        ;;
    restart|r)
        cmd_restart "$ARG1"
        ;;
    remove|rm|delete)
        cmd_remove "$ARG1"
        ;;
    logs)
        cmd_logs "$ARG1"
        ;;
    shell|ssh|exec)
        cmd_shell "$ARG1"
        ;;
    go|cd)
        cmd_go "$ARG1"
        ;;
    open|o)
        cmd_open "$ARG1"
        ;;
    infra|base|i)
        cmd_infra "$ARG1" "$ARG2"
        ;;
    dns)
        cmd_dns "$ARG1" "$ARG2"
        ;;
    help|h|--help|-h)
        show_help
        ;;
    *)
        echo -e "${RED}Unknown command: $COMMAND${NC}"
        show_help
        exit 1
        ;;
esac