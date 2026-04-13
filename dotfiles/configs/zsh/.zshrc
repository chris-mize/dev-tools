export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="robbyrussell"
plugins=(git)

DISABLE_AUTO_TITLE="true"

# Official references:
# - Oh My Zsh install/config: https://github.com/ohmyzsh/ohmyzsh#basic-installation
if [[ -f "$ZSH/oh-my-zsh.sh" ]]; then
  source "$ZSH/oh-my-zsh.sh"
fi

alias zed="/Applications/Zed.app/Contents/MacOS/cli"
alias ghostty_wallswitch="$HOME/.config/ghostty/change_wallpaper.sh"

export NVM_DIR="$HOME/.nvm"
[[ -s "$NVM_DIR/nvm.sh" ]] && . "$NVM_DIR/nvm.sh"
[[ -s "$NVM_DIR/bash_completion" ]] && . "$NVM_DIR/bash_completion"

export PATH="$HOME/.local/bin:$PATH"

if [[ -f "$HOME/.zshrc.before.local" ]]; then
  source "$HOME/.zshrc.before.local"
fi

# Official reference: https://github.com/junegunn/fzf#setting-up-shell-integration
if command -v fzf >/dev/null 2>&1; then
  source <(fzf --zsh)
fi

# Official reference: https://github.com/ajeetdsouza/zoxide#installation
if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi

HOMEBREW_PREFIX="${HOMEBREW_PREFIX:-}"
if [[ -z "$HOMEBREW_PREFIX" ]] && command -v brew >/dev/null 2>&1; then
  HOMEBREW_PREFIX="$(brew --prefix)"
fi

# Official reference: https://formulae.brew.sh/formula/zsh-autosuggestions
if [[ -n "$HOMEBREW_PREFIX" && -f "$HOMEBREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]]; then
  source "$HOMEBREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
fi

# Keep syntax highlighting last.
# Official reference: https://formulae.brew.sh/formula/zsh-syntax-highlighting
if [[ -n "$HOMEBREW_PREFIX" && -f "$HOMEBREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]]; then
  source "$HOMEBREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
fi

if [[ -f "$HOME/.zshrc.local" ]]; then
  source "$HOME/.zshrc.local"
fi
