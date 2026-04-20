# Dotfiles

This repo manages:

- `zsh` via managed blocks in `~/.zprofile` and `~/.zshrc`
- `tmux` via a managed block in `~/.tmux.conf`
- `ghostty` via symlinked files in `~/.config/ghostty/`

## Install

Prereqs:

- Homebrew is installed
- `git` is installed

Bootstrap everything:

```bash
./install.sh
```

Install only packages and external dependencies:

```bash
./install-dependencies.sh
```

## What `install.sh` does

- installs dependencies
- updates the managed `zsh` and `tmux` blocks in your home directory
- symlinks `ghostty` config files into `~/.config/ghostty/`
- migrates legacy Ghostty wallpaper settings from `~/.config/ghostty/config` into `~/.config/ghostty/config.local` when safe
- tries to install tmux plugins
- backs up existing managed config files into `~/.dotfiles-backups/` before updating, replacing, or migrating them

## Local Overrides

Use these for machine-specific settings that should not live in git:

- `~/.zshrc.before.local`
- `~/.zshrc.local`
- `~/.config/ghostty/config.local`

Examples live in:

- [configs/zsh/.zshrc.before.local.example](/Users/cmize/projects/dev-tools/dotfiles/configs/zsh/.zshrc.before.local.example)
- [configs/zsh/.zshrc.local.example](/Users/cmize/projects/dev-tools/dotfiles/configs/zsh/.zshrc.local.example)
- [configs/ghostty/config.local.example](/Users/cmize/projects/dev-tools/dotfiles/configs/ghostty/config.local.example)

## Run

After install:

- open a new shell to pick up `zsh` changes
- start `tmux` normally
- open `Ghostty` normally

To update the Ghostty wallpaper interactively:

```bash
~/.config/ghostty/change_wallpaper.sh
```
