# dotfiles

Personal config for [herdr](https://herdr.dev) and [pi](https://www.npmjs.com/package/@earendil-works/pi-coding-agent), synced across machines.

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
./install.sh pi         # install pi config only
./install.sh deps       # check which tool CLIs are installed
./install.sh uninstall  # remove symlinks
./install.sh help       # show usage
```

Or via the Makefile: `make install`, `make herdr`, `make pi`, `make deps`, `make uninstall`.

Each tool installs its own CLI if missing, then links its configuration into place. Pi uses `pi/` in this repository as its complete agent directory, so its settings, model catalog, extensions, package manifest, lockfile, and installed package sources all resolve from this checkout. Anything already at a target path is backed up (not deleted) to `~/.dotfiles_backup/<timestamp>/` before being replaced.

Pi's `~/.pi/agent` path becomes a symlink to `pi/`. The generated `pi/npm/node_modules/` directory is ignored by Git; `pi/npm/package.json` and `pi/npm/package-lock.json` are the reproducible extension dependency state. Pi credentials, sessions, and helper binaries stay in `~/.pi/local/` and are exposed through ignored symlinks inside `pi/`.

Requires Node/npm to already be on the machine for `pi`'s install — the script tells you if it's missing rather than installing a runtime for you.

## Adding a new tool or addon

1. Drop its config file(s) in a new folder here, e.g. `newtool/config.yaml`.
2. Add an `install_newtool()` function in `install.sh`: call `link "$DOTFILES_DIR/newtool/config.yaml" "$HOME/.config/newtool/config.yaml"` for each file, plus whatever else that tool needs — installing its CLI if missing, installing a plugin/addon through the tool's own CLI (see the comment in `install_herdr` for where that goes).
3. Wire it into the `install` case in `main()`, and add its symlink(s) to `uninstall()`.

Each tool's install logic — config symlinks, CLI bootstrap, plugin/addon steps — lives together in one function and can be run on its own (`./install.sh newtool`), instead of one shared data file describing every tool.

## What's intentionally not tracked

Secrets and machine-local runtime state never enter Git:

- pi's `auth.json` (live OAuth tokens)
- pi's `bin/` (vendored `fd`/`rg` binaries), `sessions/` (chat history), and generated `npm/node_modules/`
- herdr's logs, sockets, and session state
- herdr's generated Pi integration file (`pi/extensions/herdr-agent-state.ts`) — herdr manages and overwrites this itself when the integration is installed/updated, so it isn't hand-synced here
