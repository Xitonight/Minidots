#!/usr/bin/env bash

set -e
set -u
set -o pipefail

INSTALL_DIR="$HOME/Minidots"
REPO_URL="https://github.com/Xitonight/Minidots"

install_aur_helper() {
  if ! command -v git &>/dev/null; then
    sudo pacman -Sy git
  fi
  aur_helper=""
  if command -v yay &>/dev/null; then
    aur_helper="yay"
    echo $aur_helper
  elif command -v paru &>/dev/null; then
    aur_helper="paru"
    echo $aur_helper
  else
    echo "Installing yay-bin..."
    tmpdir=$(mktemp -d)
    git clone https://aur.archlinux.org/yay-bin.git "$tmpdir/yay-bin"
    cd "$tmpdir/yay-bin"
    makepkg -si --noconfirm
    cd - >/dev/null
    rm -rf "$tmpdir"
    aur_helper="yay"
  fi
}

clone_repo() {
  if [ -d "$INSTALL_DIR" ]; then
    echo "Updating dotfiles..."
    git -C "$INSTALL_DIR" pull
  else
    echo "Cloning dotfiles..."
    git clone "$REPO_URL" "$INSTALL_DIR"
  fi
}

install_packages() {
  echo "Installing required packages..."
  grep -v '^$' $INSTALL_DIR/requirements.lst | sed '/^#/d' | $aur_helper -Syy --noconfirm --needed -
}

install_npm() {
  if command -v npm &>/dev/null; then
    echo "Installing node / npm..."
    nvm install node
    nvm install --lts
    nvm use node
  fi
  $SHELL
}

install_node_packages() {
  npm install -g pnpm@latest-10
  pnpm add -g typescript
}

stow_dots() {
  echo "Stowing dotfiles in $HOME"
  stow --target=$HOME --dir=$INSTALL_DIR dots
}

install_tmux_plugins() {
  if [[ ! -d ~/.tmux/plugins/tpm ]]; then
    echo "TPM is not installed. Installing right now..."
    git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
  fi
}

setup_kanata() {
  if [[ -z "$(getent group uinput)" ]]; then
    sudo groupadd uinput
  fi

  sudo usermod -aG input $USER
  sudo usermod -aG uinput $USER

  sudo touch /etc/udev/rules.d/99-input.rules

  echo 'KERNEL=="uinput", MODE="0660", GROUP="uinput", OPTIONS+="static_node=uinput"' | sudo tee /etc/udev/rules.d/99-input.rules

  sudo udevadm control --reload-rules && sudo udevadm trigger

  sudo modprobe uinput

  systemctl --user daemon-reload
  systemctl enable --now --user kanata.service
}

setup_ssh() {
  systemctl enable --now sshd.service
}

if [ "$(id -u)" -eq 0 ]; then
  echo "Please do not run this script as root."
  exit 1
fi

clone_repo
install_aur_helper
install_packages
stow_dots
install_npm
install_node_packages
install_tmux_plugins
setup_kanata
