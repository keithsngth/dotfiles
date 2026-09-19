#!/usr/bin/env bash
# ============================================
# Dotfiles Installation Script
# ============================================

set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.dotfiles_backup/$(date +%Y%m%d_%H%M%S)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Back up an existing file/symlink before it's replaced
backup() {
    local target="$1"
    if [[ -e "$target" || -L "$target" ]]; then
        mkdir -p "$BACKUP_DIR"
        mv "$target" "$BACKUP_DIR/"
        warn "Backed up existing $target to $BACKUP_DIR/"
    fi
}

# Create a symlink, backing up whatever's currently at dst
link() {
    local src="$1"
    local dst="$2"

    if [[ -L "$dst" ]]; then
        rm "$dst"
    elif [[ -e "$dst" ]]; then
        backup "$dst"
    fi

    mkdir -p "$(dirname "$dst")"
    ln -sf "$src" "$dst"
    success "Linked $dst -> $src"
}

# Install herdr configuration
install_herdr() {
    info "Installing herdr configuration..."

    if ! command -v herdr >/dev/null 2>&1; then
        info "herdr CLI not found, installing..."
        curl -fsSL https://herdr.dev/install.sh | sh
    fi

    mkdir -p "$HOME/.config/herdr"
    link "$DOTFILES_DIR/herdr/config.toml" "$HOME/.config/herdr/config.toml"

    # Addon/plugin installs for herdr go here, e.g.:
    #   command -v herdr >/dev/null && herdr plugin install <owner>/<plugin> --yes

    success "herdr config installed. Reload a running server with 'herdr server reload-config'."
}

# Install pi configuration
install_pi() {
    info "Installing pi configuration..."

    if ! command -v pi >/dev/null 2>&1; then
        if ! command -v npm >/dev/null 2>&1; then
            error "npm not found. Install Node.js first, then re-run: ./install.sh pi"
            return 1
        fi
        info "pi CLI not found, installing..."
        npm install -g @earendil-works/pi-coding-agent
    fi

    mkdir -p "$HOME/.pi/agent"
    link "$DOTFILES_DIR/pi/settings.json" "$HOME/.pi/agent/settings.json"
    link "$DOTFILES_DIR/pi/models-store.json" "$HOME/.pi/agent/models-store.json"

    # Addon/plugin installs for pi go here.

    success "pi config installed."
}

# Check which tool CLIs are present
deps() {
    info "Checking dependencies..."
    command -v herdr >/dev/null 2>&1 && success "herdr found" || warn "herdr not found (run: ./install.sh herdr)"
    command -v npm >/dev/null 2>&1 && success "npm found" || warn "npm not found (needed for pi)"
    command -v pi >/dev/null 2>&1 && success "pi found" || warn "pi not found (run: ./install.sh pi)"
}

# Remove symlinks
uninstall() {
    info "Uninstalling dotfiles..."

    [[ -L "$HOME/.config/herdr/config.toml" ]] && rm "$HOME/.config/herdr/config.toml" && success "Removed ~/.config/herdr/config.toml"
    [[ -L "$HOME/.pi/agent/settings.json" ]] && rm "$HOME/.pi/agent/settings.json" && success "Removed ~/.pi/agent/settings.json"
    [[ -L "$HOME/.pi/agent/models-store.json" ]] && rm "$HOME/.pi/agent/models-store.json" && success "Removed ~/.pi/agent/models-store.json"

    if [[ -d "$HOME/.dotfiles_backup" ]]; then
        info "Backups available at: $HOME/.dotfiles_backup/"
    fi
}

show_help() {
    cat <<EOF
Usage: ./install.sh [command]

Commands:
  install      Install everything (default)
  herdr        Install herdr config only
  pi           Install pi config only
  deps         Check which tool CLIs are installed
  uninstall    Remove symlinks
  help         Show this help

Adding a new tool: drop its config in a new folder here, write an
install_<tool>() function using link()/backup() (see install_herdr for the
pattern, including where a plugin/addon install step would go), then wire it
into the case below and into uninstall().
EOF
}

main() {
    local cmd="${1:-install}"
    case "$cmd" in
        install) install_herdr; install_pi ;;
        herdr) install_herdr ;;
        pi) install_pi ;;
        deps) deps ;;
        uninstall) uninstall ;;
        help|-h|--help) show_help ;;
        *) error "Unknown command: $cmd"; show_help; exit 1 ;;
    esac
}

main "$@"
