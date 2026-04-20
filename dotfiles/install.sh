#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_ROOT="${HOME}/.dotfiles-backups/$(date +%Y%m%d-%H%M%S)-$$"
SKIP_DEPS="${SKIP_DEPS:-0}"
BACKED_UP_PATHS=""
GHOSTTY_WALLPAPER_START="# dotfiles:start wallpaper"
GHOSTTY_WALLPAPER_END="# dotfiles:end wallpaper"

canonical_path() {
  local path="$1"

  if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "$path"
    return
  fi

  printf '%s\n' "$path"
}

backup_path() {
  local target="$1"
  local relative_target
  local backup_target

  if [[ -e "$target" || -L "$target" ]]; then
    relative_target="${target#"$HOME"/}"
    relative_target="${relative_target#/}"
    backup_target="$BACKUP_ROOT/$relative_target"
    mkdir -p "$(dirname "$backup_target")"
    cp -PR "$target" "$backup_target"
    printf 'Backed up %s to %s\n' "$target" "$backup_target"
  fi
}

backup_path_once() {
  local target="$1"

  if printf '%s' "$BACKED_UP_PATHS" | grep -Fqx -- "$target"; then
    return
  fi

  backup_path "$target"
  BACKED_UP_PATHS="${BACKED_UP_PATHS}${target}"$'\n'
}

ensure_target_is_not_directory() {
  local target="$1"

  if [[ -d "$target" && ! -L "$target" ]]; then
    printf 'Error: expected file path but found directory at %s\n' "$target" >&2
    exit 1
  fi
}

ensure_parent_path_is_usable() {
  local path="$1"

  if [[ -e "$path" && ! -d "$path" ]]; then
    printf 'Error: expected directory path but found file at %s\n' "$path" >&2
    exit 1
  fi
}

link_file() {
  local source="$1"
  local target="$2"
  local source_canonical
  local current_canonical
  local target_dir
  local temp_link

  target_dir="$(dirname "$target")"
  mkdir -p "$target_dir"
  source_canonical="$(canonical_path "$source")"
  ensure_target_is_not_directory "$target"

  if [[ -L "$target" ]]; then
    current_canonical="$(canonical_path "$target")"
    if [[ "$current_canonical" == "$source_canonical" ]]; then
      printf 'Already linked: %s\n' "$target"
      return
    fi
  fi

  temp_link="$(mktemp "$target_dir/.dotfiles-link.XXXXXX")"
  rm -f "$temp_link"
  ln -s "$source" "$temp_link"
  mv -f "$temp_link" "$target"
  printf 'Linked %s -> %s\n' "$target" "$source"
}

strip_managed_block() {
  local target="$1"
  local start_marker="$2"
  local end_marker="$3"
  local output="$4"

  if [[ ! -e "$target" ]]; then
    : > "$output"
    return
  fi

  awk -v start="$start_marker" -v end="$end_marker" '
    $0 == start { skip=1; next }
    $0 == end { skip=0; next }
    !skip { print }
  ' "$target" > "$output"
}

validate_managed_block_state() {
  local target="$1"
  local start_marker="$2"
  local end_marker="$3"

  if [[ ! -e "$target" ]]; then
    return
  fi

  if ! awk -v start="$start_marker" -v end="$end_marker" '
    BEGIN { state = 0; starts = 0; ends = 0 }
    $0 == start {
      if (state == 1) exit 1
      state = 1
      starts++
      next
    }
    $0 == end {
      if (state == 0) exit 1
      state = 0
      ends++
      next
    }
    END {
      if (state != 0) exit 1
      if (starts != ends) exit 1
      if (starts > 1) exit 1
    }
  ' "$target"; then
    printf 'Error: invalid managed block markers in %s\n' "$target" >&2
    exit 1
  fi
}

write_managed_block() {
  local source="$1"
  local target="$2"
  local start_marker="$3"
  local end_marker="$4"
  local placement="${5:-bottom}"
  local target_dir
  local stripped
  local normalized
  local rendered

  target_dir="$(dirname "$target")"
  mkdir -p "$target_dir"
  ensure_target_is_not_directory "$target"

  stripped="$(mktemp)"
  normalized="$(mktemp)"
  rendered="$(mktemp "$target_dir/.dotfiles-rendered.XXXXXX")"

  if [[ -e "$target" ]]; then
    strip_managed_block "$target" "$start_marker" "$end_marker" "$stripped"
  else
    : > "$stripped"
  fi

  awk '
    { lines[NR] = $0 }
    END {
      first = 1
      last = NR
      while (first <= NR && lines[first] == "") {
        first++
      }
      while (last > 0 && lines[last] == "") {
        last--
      }
      for (i = first; i <= last; i++) {
        print lines[i]
      }
    }
  ' "$stripped" > "$normalized"

  {
    if [[ "$placement" == "top" ]]; then
      printf '%s\n' "$start_marker"
      cat "$source"
      if [[ -n "$(tail -c 1 "$source" 2>/dev/null || true)" ]]; then
        printf '\n'
      fi
      printf '%s\n' "$end_marker"
      if [[ -s "$normalized" ]]; then
        printf '\n\n'
        cat "$normalized"
      fi
    else
      cat "$normalized"
      if [[ -s "$normalized" ]]; then
        printf '\n\n'
      fi
      printf '%s\n' "$start_marker"
      cat "$source"
      if [[ -n "$(tail -c 1 "$source" 2>/dev/null || true)" ]]; then
        printf '\n'
      fi
      printf '%s\n' "$end_marker"
    fi
  } > "$rendered"

  if [[ -e "$target" && ! -L "$target" ]] && cmp -s "$rendered" "$target"; then
    rm -f "$stripped" "$normalized" "$rendered"
    printf 'Managed block already up to date: %s\n' "$target"
    return
  fi

  mv "$rendered" "$target"
  rm -f "$stripped" "$normalized" "$rendered"
  printf 'Updated managed block in %s\n' "$target"
}

warn_on_duplicate_patterns() {
  local target="$1"
  local start_marker="$2"
  local end_marker="$3"
  local category="$4"
  local pattern="$5"
  local stripped

  if ! command -v rg >/dev/null 2>&1; then
    return
  fi

  stripped="$(mktemp)"
  strip_managed_block "$target" "$start_marker" "$end_marker" "$stripped"

  if rg -q --pcre2 "$pattern" "$stripped"; then
    printf 'Warning: %s contains unmanaged %s settings that may duplicate the managed block.\n' "$target" "$category"
  fi

  rm -f "$stripped"
}

warn_on_ghostty_extra_configs() {
  local path
  local extra_paths=(
    "$HOME/Library/Application Support/com.mitchellh.ghostty/config"
    "$HOME/Library/Application Support/com.mitchellh.ghostty/config.ghostty"
  )

  for path in "${extra_paths[@]}"; do
    if [[ -e "$path" || -L "$path" ]]; then
      printf 'Warning: Ghostty also has config at %s\n' "$path"
    fi
  done
}

extract_legacy_ghostty_local_settings() {
  local legacy_config="$1"
  local output="$2"

  printf 'background = 000000\n' > "$output"

  awk '
    /^[[:space:]]*#/ || /^[[:space:]]*$/ { next }
    {
      line = $0
      sub(/^[[:space:]]*/, "", line)
      split(line, parts, "=")
      key = parts[1]
      gsub(/[[:space:]]+$/, "", key)
      value = substr(line, index(line, "=") + 1)
      sub(/^[[:space:]]*/, "", value)

      if (key == "background-image" || key == "background-image-opacity" || key == "background-image-fit") {
        print key " = " value
      }
    }
  ' "$legacy_config" >> "$output"
}

ghostty_legacy_has_unexpected_active_settings() {
  local legacy_config="$1"

  awk '
    /^[[:space:]]*#/ || /^[[:space:]]*$/ { next }
    {
      line = $0
      sub(/^[[:space:]]*/, "", line)
      split(line, parts, "=")
      key = parts[1]
      gsub(/[[:space:]]+$/, "", key)

      if (key == "term" || key == "maximize" || key == "background" || key == "background-image" || key == "background-image-opacity" || key == "background-image-fit") {
        next
      }

      exit 1
    }
  ' "$legacy_config"
}

write_ghostty_local_block() {
  local source_lines="$1"
  local target="$2"
  local stripped
  local normalized
  local rendered
  local target_dir

  target_dir="$(dirname "$target")"
  mkdir -p "$target_dir"
  ensure_target_is_not_directory "$target"
  validate_managed_block_state "$target" "$GHOSTTY_WALLPAPER_START" "$GHOSTTY_WALLPAPER_END"

  stripped="$(mktemp)"
  normalized="$(mktemp)"
  rendered="$(mktemp "$target_dir/.ghostty-config.local.XXXXXX")"

  if [[ -e "$target" ]]; then
    strip_managed_block "$target" "$GHOSTTY_WALLPAPER_START" "$GHOSTTY_WALLPAPER_END" "$stripped"
  else
    : > "$stripped"
  fi

  awk '
    { lines[NR] = $0 }
    END {
      first = 1
      last = NR
      while (first <= NR && lines[first] == "") {
        first++
      }
      while (last > 0 && lines[last] == "") {
        last--
      }
      for (i = first; i <= last; i++) {
        print lines[i]
      }
    }
  ' "$stripped" > "$normalized"

  {
    cat "$normalized"
    if [[ -s "$normalized" ]]; then
      printf '\n\n'
    fi
    printf '%s\n' "$GHOSTTY_WALLPAPER_START"
    cat "$source_lines"
    if [[ -n "$(tail -c 1 "$source_lines" 2>/dev/null || true)" ]]; then
      printf '\n'
    fi
    printf '%s\n' "$GHOSTTY_WALLPAPER_END"
  } > "$rendered"

  if [[ -e "$target" && ! -L "$target" ]] && cmp -s "$rendered" "$target"; then
    rm -f "$stripped" "$normalized" "$rendered"
    printf 'Ghostty local wallpaper settings already up to date: %s\n' "$target"
    return
  fi

  mv "$rendered" "$target"
  rm -f "$stripped" "$normalized" "$rendered"
  printf 'Updated Ghostty local wallpaper settings in %s\n' "$target"
}

extract_existing_ghostty_local_settings_with_black_background() {
  local target="$1"
  local output="$2"

  printf 'background = 000000\n' > "$output"

  if [[ ! -e "$target" ]]; then
    return
  fi

  awk -v start="$GHOSTTY_WALLPAPER_START" -v end="$GHOSTTY_WALLPAPER_END" '
    $0 == start { in_block = 1; next }
    $0 == end { in_block = 0; next }
    in_block {
      line = $0
      sub(/^[[:space:]]*/, "", line)
      split(line, parts, "=")
      key = parts[1]
      gsub(/[[:space:]]+$/, "", key)

      if (key != "background") {
        print $0
      }
    }
  ' "$target" >> "$output"
}

maybe_migrate_ghostty_legacy_config() {
  local legacy_config="$HOME/.config/ghostty/config"
  local local_config="$HOME/.config/ghostty/config.local"
  local extracted

  extracted="$(mktemp)"

  if [[ ! -f "$legacy_config" ]]; then
    extract_existing_ghostty_local_settings_with_black_background "$local_config" "$extracted"
    write_ghostty_local_block "$extracted" "$local_config"
    rm -f "$extracted"
    return
  fi

  if ! ghostty_legacy_has_unexpected_active_settings "$legacy_config"; then
    printf 'Warning: legacy Ghostty config has unexpected active settings; leaving %s in place for manual review.\n' "$legacy_config"
    extract_existing_ghostty_local_settings_with_black_background "$local_config" "$extracted"
    write_ghostty_local_block "$extracted" "$local_config"
    rm -f "$extracted"
    return
  fi

  extract_legacy_ghostty_local_settings "$legacy_config" "$extracted"

  if [[ -s "$extracted" ]]; then
    write_ghostty_local_block "$extracted" "$local_config"
  fi

  rm -f "$legacy_config"
  rm -f "$extracted"
  printf 'Migrated legacy Ghostty config from %s\n' "$legacy_config"
}

install_tmux_plugins() {
  local installer="$HOME/.tmux/plugins/tpm/bin/install_plugins"
  local socket_name="dotfiles-bootstrap-$$"
  local status=0

  if [[ ! -x "$installer" ]]; then
    printf 'Skipping tmux plugin install: TPM is not available.\n'
    return
  fi

  if ! command -v tmux >/dev/null 2>&1; then
    printf 'Skipping tmux plugin install: tmux is not available.\n'
    return
  fi

  if tmux ls >/dev/null 2>&1; then
    set +e
    "$installer"
    status=$?
    set -e
    if [[ "$status" -ne 0 ]]; then
      printf 'Warning: tmux plugin install failed; run prefix + I inside tmux to retry.\n'
      return
    fi
    printf 'Installed tmux plugins.\n'
    return
  fi

  set +e
  tmux -L "$socket_name" -f "$HOME/.tmux.conf" new-session -d
  status=$?
  set -e
  if [[ "$status" -ne 0 ]]; then
    printf 'Warning: temporary tmux bootstrap failed; run prefix + I inside tmux to install plugins.\n'
    return
  fi

  set +e
  TMUX_PLUGIN_MANAGER_PATH="$HOME/.tmux/plugins" TMUX_TMPDIR="${TMPDIR:-/tmp}" tmux -L "$socket_name" run-shell "$HOME/.tmux/plugins/tpm/scripts/install_plugins.sh"
  status=$?
  set -e
  tmux -L "$socket_name" kill-server >/dev/null 2>&1 || true
  if [[ "$status" -ne 0 ]]; then
    printf 'Warning: tmux plugin install failed; run prefix + I inside tmux to retry.\n'
    return
  fi
  printf 'Installed tmux plugins.\n'
}

reload_tmux_if_running() {
  if command -v tmux >/dev/null 2>&1 && tmux ls >/dev/null 2>&1; then
    tmux source-file "$HOME/.tmux.conf"
    printf 'Reloaded tmux config in running server.\n'
  fi
}

validate_install_targets() {
  ensure_parent_path_is_usable "$HOME/.dotfiles-backups"
  ensure_parent_path_is_usable "$HOME/.config"
  ensure_parent_path_is_usable "$HOME/.config/ghostty"
  ensure_target_is_not_directory "$HOME/.zprofile"
  ensure_target_is_not_directory "$HOME/.zshrc"
  ensure_target_is_not_directory "$HOME/.tmux.conf"
  ensure_target_is_not_directory "$HOME/.config/ghostty/config.ghostty"
  ensure_target_is_not_directory "$HOME/.config/ghostty/config.local"
  ensure_target_is_not_directory "$HOME/.config/ghostty/config"
  ensure_target_is_not_directory "$HOME/.config/ghostty/change_wallpaper.sh"
}

install_managed_shell_configs() {
  local zprofile_target="$HOME/.zprofile"
  local zshrc_target="$HOME/.zshrc"
  local tmux_target="$HOME/.tmux.conf"
  local zprofile_start="# dotfiles:start managed zprofile"
  local zprofile_end="# dotfiles:end managed zprofile"
  local zshrc_start="# dotfiles:start managed zshrc"
  local zshrc_end="# dotfiles:end managed zshrc"
  local tmux_start="# dotfiles:start managed tmux"
  local tmux_end="# dotfiles:end managed tmux"

  backup_path_once "$zprofile_target"
  backup_path_once "$zshrc_target"
  backup_path_once "$tmux_target"

  validate_managed_block_state "$zprofile_target" "$zprofile_start" "$zprofile_end"
  validate_managed_block_state "$zshrc_target" "$zshrc_start" "$zshrc_end"
  validate_managed_block_state "$tmux_target" "$tmux_start" "$tmux_end"

  write_managed_block "$REPO_ROOT/configs/zsh/.zprofile" "$zprofile_target" "$zprofile_start" "$zprofile_end" "top"
  write_managed_block "$REPO_ROOT/configs/zsh/.zshrc" "$zshrc_target" "$zshrc_start" "$zshrc_end" "top"
  write_managed_block "$REPO_ROOT/configs/tmux/.tmux.conf" "$tmux_target" "$tmux_start" "$tmux_end" "bottom"

  warn_on_duplicate_patterns "$zprofile_target" "$zprofile_start" "$zprofile_end" "Homebrew shellenv" 'brew[[:space:]]+shellenv'
  warn_on_duplicate_patterns "$zshrc_target" "$zshrc_start" "$zshrc_end" "Oh My Zsh bootstrap" 'oh-my-zsh\.sh'
  warn_on_duplicate_patterns "$zshrc_target" "$zshrc_start" "$zshrc_end" "fzf integration" 'fzf[[:space:]]+--zsh'
  warn_on_duplicate_patterns "$zshrc_target" "$zshrc_start" "$zshrc_end" "zoxide integration" 'zoxide[[:space:]]+init[[:space:]]+zsh'
  warn_on_duplicate_patterns "$zshrc_target" "$zshrc_start" "$zshrc_end" "zsh-autosuggestions" 'zsh-autosuggestions'
  warn_on_duplicate_patterns "$zshrc_target" "$zshrc_start" "$zshrc_end" "zsh-syntax-highlighting" 'zsh-syntax-highlighting'
  warn_on_duplicate_patterns "$tmux_target" "$tmux_start" "$tmux_end" "TPM setup" 'tmux-plugins/tpm|run[[:space:]]+['\''"]~/.tmux/plugins/tpm/tpm['\''"]'
}

backup_ghostty_targets() {
  backup_path_once "$HOME/.config/ghostty/config.ghostty"
  backup_path_once "$HOME/.config/ghostty/config.local"
  backup_path_once "$HOME/.config/ghostty/config"
  backup_path_once "$HOME/.config/ghostty/change_wallpaper.sh"
}

validate_install_targets

if [[ "$SKIP_DEPS" != "1" ]]; then
  "$REPO_ROOT/install-dependencies.sh"
fi

install_managed_shell_configs
backup_ghostty_targets
link_file "$REPO_ROOT/configs/ghostty/config.ghostty" "$HOME/.config/ghostty/config.ghostty"
maybe_migrate_ghostty_legacy_config
link_file "$REPO_ROOT/configs/ghostty/change_wallpaper.sh" "$HOME/.config/ghostty/change_wallpaper.sh"
warn_on_ghostty_extra_configs

reload_tmux_if_running
install_tmux_plugins

printf 'Install complete.\n'
