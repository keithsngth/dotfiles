# dotfiles

Personal config for [herdr](https://herdr.dev) and [pi](https://www.npmjs.com/package/@earendil-works/pi-coding-agent), synced across machines.

## Usage

```sh
git clone https://github.com/keithsngth/dotfiles.git ~/Documents/GitHub/dotfiles
cd ~/Documents/GitHub/dotfiles
./install.sh
```

`install.sh` installs `herdr` and `pi` if they're missing, then symlinks every entry in `manifest.conf` into place. It's safe to re-run any time, e.g. after `git pull` to pick up new entries.

Requires Node/npm to already be on the machine for `pi`'s install — the script tells you if it's missing rather than installing a runtime for you.

## Adding a new tool

Drop its config file(s) in a new folder here, then add a `repo/relative/path|~/absolute/target/path` line to `manifest.conf`. `install.sh` picks it up automatically — no other changes needed.

## What's intentionally not tracked

Secrets and machine-local runtime state never leave the machine:

- pi's `auth.json` (live OAuth tokens)
- pi's `bin/` (vendored `fd`/`rg` binaries) and `sessions/` (chat history)
- herdr's logs, sockets, and session state
- herdr's pi integration file (`~/.pi/agent/extensions/herdr-agent-state.ts`) — herdr manages and overwrites this itself when the integration is installed/updated, so it isn't hand-synced here
