# dotfiles

Personal config for [herdr](https://herdr.dev) (its CLI and desktop app) and [WezTerm](https://wezterm.org), synced across machines, plus shell tooling (zoxide, zsh-autosuggestions, zsh-syntax-highlighting).

## Usage

```sh
git clone https://github.com/keithsngth/dotfiles.git ~/Documents/GitHub/dotfiles
cd ~/Documents/GitHub/dotfiles
./install.sh
```

## Commands

```sh
./install.sh            # install everything
./install.sh herdr      # install herdr config only
./install.sh herdr-app  # install herdr app config only
./install.sh wezterm    # install WezTerm config only
./install.sh shell      # install zoxide, zsh-autosuggestions, and zsh-syntax-highlighting
./install.sh deps       # check which tool CLIs are installed
./install.sh uninstall  # remove symlinks
./install.sh help       # show usage
```

Or via the Makefile: `make install`, `make herdr`, `make herdr-app`, `make wezterm`, `make shell`, `make deps`, `make uninstall`.

Each tool installs its own CLI if missing, then links its configuration into place. Anything already at a target path is backed up (not deleted) to `~/.dotfiles_backup/<timestamp>/` before being replaced. The herdr desktop app is not installed by this repo; install it separately, then run `./install.sh herdr-app`.

WezTerm links the whole `wezterm/` folder to `~/.config/wezterm` so `wezterm.lua` can `require` its sibling modules. The theme is [Catppuccin](https://github.com/catppuccin/wezterm) Mocha — which ships inside WezTerm, so no plugin is fetched at startup — and `wezterm/bar.lua` draws a powerline tab bar and status line in the same shapes and colours as the starship prompt. Change the `FLAVOR` constant at the top of `wezterm/wezterm.lua` to switch flavour, and keep `starship.toml`'s `palette` in step with it. The bar needs a Nerd Font; the config asks for `JetBrainsMono Nerd Font`.

The herdr app links its whole home, `~/.config/herdr-app`, to `herdr-app/` here. The app saves settings and keys by replacing their files, so single-file links would break on the first change made in the app. `herdr-app/.gitignore` ignores everything except the tracked config (`settings.json`, `keys.json`, `themes/catppuccin-mocha.json`); to track a new layout or mod, add a `!` line for it there. Restart the app after linking.

Shell tooling has no config to link — `shell` just installs the packages via Homebrew and reminds you to source them from `~/.zshrc` (`zoxide init zsh`, then `zsh-autosuggestions`, then `zsh-syntax-highlighting` last so it can wrap the other widgets).

## Adding a new tool or addon

1. Drop its config file(s) in a new folder here, e.g. `newtool/config.yaml`.
2. Add an `install_newtool()` function in `install.sh`: call `link "$DOTFILES_DIR/newtool/config.yaml" "$HOME/.config/newtool/config.yaml"` for each file, plus whatever else that tool needs — installing its CLI if missing, installing a plugin/addon through the tool's own CLI (see the comment in `install_herdr` for where that goes).
3. Wire it into the `install` case in `main()`, and add its symlink(s) to `uninstall()`.

Each tool's install logic — config symlinks, CLI bootstrap, plugin/addon steps — lives together in one function and can be run on its own (`./install.sh newtool`), instead of one shared data file describing every tool.

## What's intentionally not tracked

Secrets and machine-local runtime state never enter Git:

- credential files such as `auth.json` (ignored anywhere in the repo)
- herdr's logs, sockets, and session state
- the herdr app's runtime state and shipped files (`view.json`, `window.json`, `shared.json`, `data/`, `icons/`, shipped `layouts/`, `mods/`, `themes/`), kept out by `herdr-app/.gitignore`
