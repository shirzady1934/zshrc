#!/usr/bin/env bash
set -euo pipefail

# --------------------------------------------
# Kubernetes + Zsh Environment Bootstrap Script
# Installs: Oh My Zsh, kube-ps1, krew (ctx, ns),
# kubectl, helm, argocd, argo-rollouts, fzf
#
# Overrides via env:
#   ARGOCD_VERSION=v3.3.9   (default: latest)
#   ARGO_ROLLOUTS_VERSION=v1.7.2 (default: latest)
#   INSTALL_ARGOCD=no       (skip argocd)
#   INSTALL_ARGO_ROLLOUTS=no
# --------------------------------------------

msg() { printf "\033[1;32m==>\033[0m %s\n" "$*"; }
err() { printf "\033[1;31m[ERR]\033[0m %s\n" "$*" >&2; }
have() { command -v "$1" >/dev/null 2>&1; }

OS="$(uname -s)"
ARCH="$(uname -m)"

# Normalize arch
case "$ARCH" in
  x86_64|amd64) ARCH_NORM="amd64" ;;
  aarch64|arm64) ARCH_NORM="arm64" ;;
  armv7l) ARCH_NORM="arm" ;;
  *) ARCH_NORM="$ARCH" ;;
esac

# --- Install packages ---
install_pkgs_linux() {
  if have apt-get; then
    msg "Installing base packages via apt..."
    sudo apt-get update -y
    sudo apt-get install -y git curl zsh tar unzip ca-certificates fzf
  elif have dnf; then
    msg "Installing base packages via dnf..."
    sudo dnf install -y git curl zsh tar unzip ca-certificates fzf
  elif have yum; then
    msg "Installing base packages via yum..."
    sudo yum install -y git curl zsh tar unzip ca-certificates fzf
  elif have pacman; then
    msg "Installing base packages via pacman..."
    sudo pacman -Syu --noconfirm git curl zsh tar unzip ca-certificates fzf
  else
    err "Unsupported Linux package manager. Install git, curl, zsh, tar, unzip, ca-certificates, fzf manually."
  fi
}

install_pkgs_macos() {
  if ! have brew; then
    msg "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
  msg "Installing base packages via brew..."
  brew install git curl zsh gnu-tar unzip fzf
  if have gtar && ! have tar; then
    alias tar=gtar
  fi
}

# --- Oh My Zsh ---
install_ohmyzsh() {
  if [ -d "$HOME/.oh-my-zsh" ]; then
    msg "Oh My Zsh already installed"
    return
  fi
  msg "Installing Oh My Zsh ..."
  RUNZSH=no KEEP_ZSHRC=yes \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  msg "Oh My Zsh installed."
}

# --- kubectl ---
install_kubectl() {
  if have kubectl; then
    msg "kubectl already installed: $(kubectl version --client 2>/dev/null | head -1)"
    return
  fi
  msg "Installing kubectl ..."
  PLATFORM=$([ "$OS" = "Darwin" ] && echo "darwin" || echo "linux")
  KUBECTL_VERSION="$(curl -fsSL https://storage.googleapis.com/kubernetes-release/release/stable.txt)"
  curl -fsSLo /tmp/kubectl "https://storage.googleapis.com/kubernetes-release/release/${KUBECTL_VERSION}/bin/${PLATFORM}/${ARCH_NORM}/kubectl"
  chmod +x /tmp/kubectl
  sudo mv /tmp/kubectl /usr/local/bin/kubectl
  msg "kubectl installed: $(kubectl version --client 2>/dev/null | head -1)"
}

# --- argocd CLI ---
install_argocd() {
  [ "${INSTALL_ARGOCD:-yes}" = "no" ] && { msg "Skipping argocd (INSTALL_ARGOCD=no)"; return; }
  if have argocd; then
    msg "argocd already installed: $(argocd version --client --short 2>/dev/null | head -1)"
    return
  fi
  msg "Resolving argocd version ..."
  local ver="${ARGOCD_VERSION:-}"
  if [ -z "$ver" ]; then
    ver="$(curl -fsSL -o /dev/null -w '%{url_effective}' https://github.com/argoproj/argo-cd/releases/latest | sed 's@.*/@@')"
  fi
  [ -z "$ver" ] && { err "Could not resolve argocd version; set ARGOCD_VERSION."; return 1; }
  local platform asset
  platform=$([ "$OS" = "Darwin" ] && echo "darwin" || echo "linux")
  asset="argocd-${platform}-${ARCH_NORM}"
  msg "Installing argocd ${ver} (${asset}) ..."
  curl -fsSLo /tmp/argocd "https://github.com/argoproj/argo-cd/releases/download/${ver}/${asset}"
  chmod +x /tmp/argocd
  sudo mv /tmp/argocd /usr/local/bin/argocd
  msg "argocd installed: $(argocd version --client --short 2>/dev/null | head -1)"
}

# --- argo-rollouts kubectl plugin ---
install_argo_rollouts() {
  [ "${INSTALL_ARGO_ROLLOUTS:-yes}" = "no" ] && { msg "Skipping argo-rollouts (INSTALL_ARGO_ROLLOUTS=no)"; return; }
  if have kubectl-argo-rollouts; then
    msg "kubectl-argo-rollouts already installed: $(kubectl-argo-rollouts version 2>/dev/null | head -1)"
    return
  fi
  msg "Resolving argo-rollouts version ..."
  local ver="${ARGO_ROLLOUTS_VERSION:-}"
  if [ -z "$ver" ]; then
    ver="$(curl -fsSL -o /dev/null -w '%{url_effective}' https://github.com/argoproj/argo-rollouts/releases/latest | sed 's@.*/@@')"
  fi
  [ -z "$ver" ] && { err "Could not resolve argo-rollouts version; set ARGO_ROLLOUTS_VERSION."; return 1; }
  local platform asset
  platform=$([ "$OS" = "Darwin" ] && echo "darwin" || echo "linux")
  asset="kubectl-argo-rollouts-${platform}-${ARCH_NORM}"
  msg "Installing kubectl-argo-rollouts ${ver} (${asset}) ..."
  curl -fsSLo /tmp/kubectl-argo-rollouts "https://github.com/argoproj/argo-rollouts/releases/download/${ver}/${asset}"
  chmod +x /tmp/kubectl-argo-rollouts
  sudo mv /tmp/kubectl-argo-rollouts /usr/local/bin/kubectl-argo-rollouts
  # Optional completion script (the .zshrc sources it if present)
  if kubectl-argo-rollouts completion zsh > "$HOME/.argo-rollouts-completion.zsh" 2>/dev/null; then
    msg "Generated ~/.argo-rollouts-completion.zsh"
  fi
  msg "kubectl-argo-rollouts installed: $(kubectl-argo-rollouts version 2>/dev/null | head -1)"
}

# --- Helm ---
install_helm() {
  if have helm; then
    msg "helm already installed: $(helm version --short 2>/dev/null || echo)"
    return
  fi
  msg "Installing Helm ..."
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
  msg "helm installed: $(helm version --short)"
}

# --- fzf ---
ensure_fzf() {
  if have fzf; then return; fi
  msg "Installing fzf from source ..."
  git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
  ~/.fzf/install --all
}

# --- kube-ps1 ---
install_kube_ps1() {
  if [ -f "${HOME}/.kube-ps1/kube-ps1.sh" ]; then
    msg "kube-ps1 already installed"
    return
  fi
  msg "Installing kube-ps1 ..."
  git clone https://github.com/jonmosco/kube-ps1.git "${HOME}/.kube-ps1"
  msg "kube-ps1 installed."
}

# --- krew ---
install_krew() {
  if kubectl krew version >/dev/null 2>&1; then
    msg "krew already installed"
    return
  fi
  msg "Installing krew ..."
  OS_LOWER="$(uname | tr '[:upper:]' '[:lower:]')"
  KREW_TMP="$(mktemp -d)"
  pushd "$KREW_TMP" >/dev/null
  KREW_TAR="krew-${OS_LOWER}_${ARCH_NORM}.tar.gz"
  curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/${KREW_TAR}"
  tar zxvf "${KREW_TAR}" >/dev/null
  ./krew-"${OS_LOWER}"_"${ARCH_NORM}" install krew
  popd >/dev/null
  export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"
  msg "krew installed"
}

# --- krew plugins ---
install_krew_plugins() {
  export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"
  msg "Installing krew plugins: ctx, ns ..."
  kubectl krew install ctx ns >/dev/null 2>&1 || true
  msg "Installed krew plugins:"
  kubectl krew list || true
}

# --- Docker completion hint ---
hint_docker_completion() {
  if have docker; then
    msg "Docker CLI found. zsh completion will work."
  else
    msg "Docker CLI not found. Install Docker if you need completion."
  fi
}

# --- Main flow ---
case "$OS" in
  Linux) install_pkgs_linux ;;
  Darwin) install_pkgs_macos ;;
  *) err "Unsupported OS: $OS"; exit 1 ;;
esac

install_ohmyzsh
install_kubectl
install_helm
install_argocd
install_argo_rollouts
ensure_fzf
install_kube_ps1
install_krew
install_krew_plugins
hint_docker_completion

# Install the .zshrc from this repo if running from a checkout
if [ -f "${BASH_SOURCE%/*}/.zshrc" ] && [ "${INSTALL_ZSHRC:-yes}" != "no" ]; then
  if [ -f "$HOME/.zshrc" ] && [ ! -L "$HOME/.zshrc" ]; then
    cp "$HOME/.zshrc" "$HOME/.zshrc.bak.$(date +%s)"
    msg "Existing ~/.zshrc backed up"
  fi
  cp "${BASH_SOURCE%/*}/.zshrc" "$HOME/.zshrc"
  msg "Installed ~/.zshrc from repo"
fi

msg "All done!
- Oh My Zsh at ~/.oh-my-zsh
- kube-ps1 at ~/.kube-ps1
- krew at ~/.krew (ctx, ns plugins installed)
- kubectl, helm, fzf installed
- argocd installed (skip with INSTALL_ARGOCD=no)
- kubectl-argo-rollouts installed (skip with INSTALL_ARGO_ROLLOUTS=no)
Reopen your terminal or run: exec zsh"

