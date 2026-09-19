#!/usr/bin/env bash
# ============================================
# Dotfiles Installation Script
# ============================================

set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.dotfiles_backup/$(date +%Y%m%d_%H%M%S)"
PI_REPO_DIR="$DOTFILES_DIR/pi"
PI_AGENT_DIR="$HOME/.pi/agent"
PI_SETTINGS_PATH="$HOME/.pi/settings.json"
PI_LOCAL_STATE_DIR="$HOME/.pi/local"

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

# Move an existing Pi runtime item into the machine-local state directory.
move_if_present() {
    local src="$1"
    local dst="$2"

    if [[ ! -e "$src" && ! -L "$src" ]]; then
        return
    fi

    if [[ -e "$dst" || -L "$dst" ]]; then
        warn "Keeping existing $src; local state already exists at $dst"
        return
    fi

    mkdir -p "$(dirname "$dst")"
    mv "$src" "$dst"
    success "Moved $src -> $dst"
}

# Keep credentials, history, and helper binaries outside the repository while
# making them available through the repo-backed Pi agent directory.
prepare_pi_local_state() {
    mkdir -p "$HOME/.pi" "$PI_LOCAL_STATE_DIR"

    if [[ -d "$PI_AGENT_DIR" && ! -L "$PI_AGENT_DIR" ]]; then
        move_if_present "$PI_AGENT_DIR/auth.json" "$PI_LOCAL_STATE_DIR/auth.json"
        move_if_present "$PI_AGENT_DIR/bin" "$PI_LOCAL_STATE_DIR/bin"
        move_if_present "$PI_AGENT_DIR/sessions" "$PI_LOCAL_STATE_DIR/sessions"

        if [[ -d "$PI_AGENT_DIR/npm" && ! -e "$PI_REPO_DIR/npm" ]]; then
            mv "$PI_AGENT_DIR/npm" "$PI_REPO_DIR/npm"
            success "Moved $PI_AGENT_DIR/npm -> $PI_REPO_DIR/npm"
        fi

        # These were the old per-file links. The whole agent directory will
        # become one link to the repository below.
        [[ -L "$PI_AGENT_DIR/settings.json" ]] && rm "$PI_AGENT_DIR/settings.json"
        [[ -L "$PI_AGENT_DIR/models-store.json" ]] && rm "$PI_AGENT_DIR/models-store.json"
        [[ -L "$PI_AGENT_DIR/extensions/pi-footer.json" ]] && rm "$PI_AGENT_DIR/extensions/pi-footer.json"
        [[ -d "$PI_AGENT_DIR/extensions" ]] && rmdir "$PI_AGENT_DIR/extensions" 2>/dev/null || true

        if [[ -n "$(find "$PI_AGENT_DIR" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
            backup "$PI_AGENT_DIR"
        else
            rmdir "$PI_AGENT_DIR"
        fi
    elif [[ -e "$PI_AGENT_DIR" || -L "$PI_AGENT_DIR" ]]; then
        if [[ "$(readlink "$PI_AGENT_DIR" 2>/dev/null || true)" != "$PI_REPO_DIR" ]]; then
            backup "$PI_AGENT_DIR"
        else
            return
        fi
    fi

    ln -s "$PI_REPO_DIR" "$PI_AGENT_DIR"
    success "Linked $PI_AGENT_DIR -> $PI_REPO_DIR"
}

prepare_pi_state_links() {
    mkdir -p "$PI_LOCAL_STATE_DIR/bin" "$PI_LOCAL_STATE_DIR/sessions"
    link "$PI_LOCAL_STATE_DIR/auth.json" "$PI_REPO_DIR/auth.json"
    link "$PI_LOCAL_STATE_DIR/bin" "$PI_REPO_DIR/bin"
    link "$PI_LOCAL_STATE_DIR/sessions" "$PI_REPO_DIR/sessions"
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

    # Addon/plugin installs for herdr go here.
    command -v herdr >/dev/null && herdr plugin install alexarthurs/herdr-sidebar/plugins/herdr-sidebar --yes

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

    mkdir -p "$PI_REPO_DIR/extensions"
    prepare_pi_local_state
    link "$PI_REPO_DIR/settings.json" "$PI_SETTINGS_PATH"
    prepare_pi_state_links

    if [[ -f "$PI_REPO_DIR/npm/package.json" && -f "$PI_REPO_DIR/npm/package-lock.json" && ! -d "$PI_REPO_DIR/npm/node_modules" ]]; then
        info "Installing Pi packages into the repository..."
        npm install --prefix "$PI_REPO_DIR/npm" --no-audit --no-fund
    fi

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
    if [[ -L "$PI_AGENT_DIR" && "$(readlink "$PI_AGENT_DIR")" == "$PI_REPO_DIR" ]]; then
        rm "$PI_AGENT_DIR"
        success "Removed $PI_AGENT_DIR link"
    fi
    if [[ -L "$PI_SETTINGS_PATH" && "$(readlink "$PI_SETTINGS_PATH")" == "$PI_REPO_DIR/settings.json" ]]; then
        rm "$PI_SETTINGS_PATH"
        success "Removed $PI_SETTINGS_PATH link"
    fi

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
