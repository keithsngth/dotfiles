#!/usr/bin/env bash
# ============================================
# Dotfiles Installation Script
# ============================================

set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.dotfiles_backup/$(date +%Y%m%d_%H%M%S)"
WEZTERM_CONFIG_DIR="$HOME/.config/wezterm"

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

    # Addon/plugin installs for herdr go here.
    command -v herdr >/dev/null && herdr plugin install alexarthurs/herdr-sidebar/plugins/herdr-sidebar --yes

    success "herdr config installed. Reload a running server with 'herdr server reload-config'."
}

# Install herdr app configuration. The whole app home is linked, not single
# files: the app saves settings and keys by replacing them, which would break
# per-file links. herdr-app/.gitignore keeps its state out of Git.
install_herdr_app() {
    info "Installing herdr app configuration..."

    link "$DOTFILES_DIR/herdr-app" "$HOME/.config/herdr-app"

    success "herdr app config installed. Restart the Herdr app to read it."
}

# Install WezTerm configuration
install_wezterm() {
    info "Installing WezTerm configuration..."

    if [[ ! -d "/Applications/WezTerm.app" ]] && ! command -v wezterm >/dev/null 2>&1; then
        if command -v brew >/dev/null 2>&1; then
            info "WezTerm not found, installing..."
            brew install --cask wezterm
        else
            warn "WezTerm not found. Install it from https://wezterm.org/installation"
        fi
    fi

    # Catppuccin ships inside WezTerm, so the theme needs no plugin install;
    # the whole folder is linked so wezterm.lua can require its sibling modules.
    link "$DOTFILES_DIR/wezterm" "$WEZTERM_CONFIG_DIR"

    success "WezTerm config installed. A running WezTerm reloads it on save."
}

# Install shell enhancements (zoxide, zsh-autosuggestions, zsh-syntax-highlighting)
install_shell() {
    info "Installing shell enhancements..."

    if ! command -v brew >/dev/null 2>&1; then
        warn "Homebrew not found. Install zoxide, zsh-autosuggestions, and zsh-syntax-highlighting manually."
        return
    fi

    command -v zoxide >/dev/null 2>&1 || brew install zoxide
    brew list zsh-autosuggestions >/dev/null 2>&1 || brew install zsh-autosuggestions
    brew list zsh-syntax-highlighting >/dev/null 2>&1 || brew install zsh-syntax-highlighting

    success "Shell enhancements installed. Ensure ~/.zshrc sources zoxide, zsh-autosuggestions, and zsh-syntax-highlighting (the latter last)."
}

# Check which tool CLIs are present
deps() {
    info "Checking dependencies..."
    command -v herdr >/dev/null 2>&1 && success "herdr found" || warn "herdr not found (run: ./install.sh herdr)"
    command -v zoxide >/dev/null 2>&1 && success "zoxide found" || warn "zoxide not found (run: ./install.sh shell)"
    brew list zsh-autosuggestions >/dev/null 2>&1 && success "zsh-autosuggestions found" || warn "zsh-autosuggestions not found (run: ./install.sh shell)"
    brew list zsh-syntax-highlighting >/dev/null 2>&1 && success "zsh-syntax-highlighting found" || warn "zsh-syntax-highlighting not found (run: ./install.sh shell)"
    { [[ -d "/Applications/WezTerm.app" ]] || command -v wezterm >/dev/null 2>&1; } && success "wezterm found" || warn "wezterm not found (run: ./install.sh wezterm)"
}

# Remove symlinks
uninstall() {
    info "Uninstalling dotfiles..."

    [[ -L "$HOME/.config/herdr/config.toml" ]] && rm "$HOME/.config/herdr/config.toml" && success "Removed ~/.config/herdr/config.toml"
    if [[ -L "$HOME/.config/herdr-app" && "$(readlink "$HOME/.config/herdr-app")" == "$DOTFILES_DIR/herdr-app" ]]; then
        rm "$HOME/.config/herdr-app"
        success "Removed ~/.config/herdr-app link"
    fi
    if [[ -L "$WEZTERM_CONFIG_DIR" && "$(readlink "$WEZTERM_CONFIG_DIR")" == "$DOTFILES_DIR/wezterm" ]]; then
        rm "$WEZTERM_CONFIG_DIR"
        success "Removed $WEZTERM_CONFIG_DIR link"
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
  herdr-app    Install herdr app config only
  wezterm      Install WezTerm config only
  shell        Install zoxide, zsh-autosuggestions, and zsh-syntax-highlighting
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
        install) install_herdr; install_herdr_app; install_wezterm; install_shell ;;
        herdr) install_herdr ;;
        herdr-app) install_herdr_app ;;
        wezterm) install_wezterm ;;
        shell) install_shell ;;
        deps) deps ;;
        uninstall) uninstall ;;
        help|-h|--help) show_help ;;
        *) error "Unknown command: $cmd"; show_help; exit 1 ;;
    esac
}

main "$@"
