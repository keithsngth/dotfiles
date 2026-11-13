# ============================================
# Dotfiles Makefile
# ============================================

.PHONY: all install herdr herdr-app wezterm shell deps uninstall help

all: install

install: ## Install all configurations
	@./install.sh install

herdr: ## Install only herdr configuration
	@./install.sh herdr

herdr-app: ## Install only herdr app configuration
	@./install.sh herdr-app

wezterm: ## Install only WezTerm configuration
	@./install.sh wezterm

shell: ## Install zoxide, zsh-autosuggestions, and zsh-syntax-highlighting
	@./install.sh shell

deps: ## Check which tool CLIs are installed
	@./install.sh deps

uninstall: ## Remove symlinks
	@./install.sh uninstall

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'
