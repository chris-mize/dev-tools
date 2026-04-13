#!/usr/bin/env bash

set -euo pipefail

# Official references:
# - Oh My Zsh install: https://github.com/ohmyzsh/ohmyzsh#basic-installation
# - Oh My Zsh manual install: https://github.com/ohmyzsh/ohmyzsh?tab=readme-ov-file#manual-installation
# - TPM install: https://github.com/tmux-plugins/tpm
# - Homebrew bundle package source-of-truth: ./Brewfile

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

require_command() {
  local cmd="$1"

  if ! command -v "$cmd" >/dev/null 2>&1; then
    printf 'Missing required command: %s\n' "$cmd" >&2
    exit 1
  fi
}

ensure_directory_path() {
  local path="$1"

  if [[ -e "$path" && ! -d "$path" ]]; then
    printf 'Error: expected directory path but found file at %s\n' "$path" >&2
    exit 1
  fi
}

validate_dependency_targets() {
  ensure_directory_path "$HOME/.dotfiles-backups"
  ensure_directory_path "$HOME"
  ensure_directory_path "$(dirname "$HOME/.oh-my-zsh")"
  ensure_directory_path "$HOME/.tmux"
  ensure_directory_path "$(dirname "$HOME/.tmux/plugins/tpm")"
}

backup_existing_dir() {
  local target="$1"
  local backup_root="$HOME/.dotfiles-backups/$(date +%Y%m%d-%H%M%S)-$$"

  if [[ -e "$target" || -L "$target" ]]; then
    mkdir -p "$backup_root"
    mv "$target" "$backup_root/"
    printf 'Backed up %s to %s\n' "$target" "$backup_root/"
  fi
}

install_oh_my_zsh() {
  local omz_dir="$HOME/.oh-my-zsh"
  local parent_dir
  local temp_clone

  if [[ -d "$omz_dir/.git" && -f "$omz_dir/oh-my-zsh.sh" ]]; then
    printf 'Already installed: oh-my-zsh\n'
    return
  fi

  require_command git
  parent_dir="$(dirname "$omz_dir")"
  ensure_directory_path "$parent_dir"
  mkdir -p "$parent_dir"
  temp_clone="$(mktemp -d "$parent_dir/.oh-my-zsh.clone.XXXXXX")"
  rmdir "$temp_clone"
  git clone --depth 1 https://github.com/ohmyzsh/ohmyzsh.git "$temp_clone"
  if [[ -e "$omz_dir" ]]; then
    backup_existing_dir "$omz_dir"
  fi
  mv "$temp_clone" "$omz_dir"
  printf 'Installed: oh-my-zsh\n'
}

install_tpm() {
  local tpm_dir="$HOME/.tmux/plugins/tpm"
  local parent_dir
  local temp_clone

  if [[ -d "$tpm_dir/.git" && -x "$tpm_dir/tpm" ]]; then
    printf 'Already installed: tpm\n'
    return
  fi

  require_command git
  parent_dir="$(dirname "$tpm_dir")"
  ensure_directory_path "$HOME/.tmux"
  ensure_directory_path "$parent_dir"
  mkdir -p "$parent_dir"
  temp_clone="$(mktemp -d "$parent_dir/.tpm.clone.XXXXXX")"
  rmdir "$temp_clone"
  git clone --depth 1 https://github.com/tmux-plugins/tpm "$temp_clone"
  if [[ -e "$tpm_dir" ]]; then
    backup_existing_dir "$tpm_dir"
  fi
  mv "$temp_clone" "$tpm_dir"
  printf 'Installed: tpm\n'
}

main() {
  require_command brew
  require_command git
  validate_dependency_targets

  brew bundle --file "$REPO_ROOT/Brewfile"
  install_oh_my_zsh
  install_tpm

  printf 'Dependency install complete.\n'
}

main "$@"
