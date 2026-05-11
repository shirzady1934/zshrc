# ── oh-my-zsh ─────────────────────────────────────────────────────────────
export ZSH="$HOME/.oh-my-zsh"
unset SSH_ASKPASS
TERM=xterm
ZSH_THEME="agnoster"
plugins=(
  git
  kubectl
  kube-ps1
  helm
  fzf
  colored-man-pages
  terraform
)
[[ -f "$ZSH/oh-my-zsh.sh" ]] && source "$ZSH/oh-my-zsh.sh"

# ── PATH ──────────────────────────────────────────────────────────────────
typeset -U path PATH
path=(
  "$HOME/.local/bin"
  "$HOME/Documents/sh"
  "$HOME/Documents/bin"
  "${KREW_ROOT:-$HOME/.krew}/bin"
  "$HOME/.npm-global/bin"
  "$HOME/go/bin"
  "$HOME/perl5/bin"
  "/usr/local/cuda/bin"
  $path
)

# ── env ───────────────────────────────────────────────────────────────────
export EDITOR=vim
export GPG_TTY=$(tty)
export GOPATH="$HOME/go"
[[ -d /usr/local/cuda/lib64 ]] && export LD_LIBRARY_PATH="/usr/local/cuda/lib64${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
[[ -d /usr/local/lib64/systemc ]] && export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:/usr/local/lib64/systemc"
export TERM=xterm-256color
export COLORTERM=truecolor
# Steam / Proton / Wine (set even if not installed; harmless)
export STEAM_COMPAT_DATA_PATH="$HOME/proton"
export STEAM_COMPAT_CLIENT_INSTALL_PATH="$HOME/proton"
export WINEPREFIX="$HOME/.wine"

# ── completions (skip silently when the tool is missing) ──────────────────
(( $+commands[docker]  )) && source <(docker completion zsh)
(( $+commands[kubectl] )) && source <(kubectl completion zsh)
(( $+commands[helm]    )) && source <(helm completion zsh)
(( $+commands[argocd]  )) && source <(argocd completion zsh)
[[ -f ~/.argo-rollouts-completion.zsh ]] && source ~/.argo-rollouts-completion.zsh
(( $+commands[kubectl-argo-rollouts] )) && \
  compdef _kubectl_argo_rollouts kubectl-argo-rollouts 2>/dev/null

# ── argocd helpers ────────────────────────────────────────────────────────
if (( $+commands[argocd] && $+commands[kubectl] )); then
  # run argocd in core mode against the `argocd` namespace, without touching
  # the user's current kubectl context
  kargo() {
    local tmpcfg
    tmpcfg=$(mktemp) || return
    kubectl config view --raw --minify --flatten > "$tmpcfg" 2>/dev/null
    KUBECONFIG="$tmpcfg" kubectl config set-context --current --namespace=argocd >/dev/null
    KUBECONFIG="$tmpcfg" command argocd --core "$@"
    local rc=$?
    rm -f "$tmpcfg"
    return $rc
  }

  # argocd CLI lacks dynamic completion for app names / revisions — add it.
  zmodload -F zsh/datetime b:EPOCHSECONDS 2>/dev/null
  typeset -g _argocd_apps_cache _argocd_apps_cache_ts=0

  _argocd_app_names() {
    if (( ${EPOCHSECONDS:-0} - _argocd_apps_cache_ts > 30 )) || [[ -z "$_argocd_apps_cache" ]]; then
      _argocd_apps_cache="$(kargo app list -o name 2>/dev/null)"
      _argocd_apps_cache_ts=${EPOCHSECONDS:-0}
    fi
    local -a apps
    apps=(${(f)_argocd_apps_cache})
    apps=(${apps#*/})
    (( ${#apps} > 0 )) && _describe 'argocd app' apps
  }

  _argocd_revisions() {
    local app="" i
    for (( i = 2; i <= $#words; i++ )); do
      if [[ "${words[i]}" == "app" ]]; then
        app="${words[i+2]:-}"
        break
      fi
    done
    [[ -z "$app" || "$app" == -* ]] && return
    local -a rev_desc
    local line sha
    while IFS= read -r line; do
      if [[ "$line" =~ '\(([a-f0-9]+)\)[[:space:]]*$' ]]; then
        sha="${match[1]}"
        rev_desc=("${sha}:${line## #}" $rev_desc)
      fi
    done < <(kargo app history "$app" 2>/dev/null)
    (( ${#rev_desc} > 0 )) && _describe -V 'revision' rev_desc
  }

  _argocd_smart() {
    local prev="${words[CURRENT-1]:-}"
    case "$prev" in
      --revision|-r|--source-revisions)
        _argocd_revisions
        return
        ;;
    esac
    local i app_idx=0 verb=""
    for (( i = 2; i <= $#words; i++ )); do
      if [[ "${words[i]}" == "app" ]]; then
        app_idx=$i
        verb="${words[i+1]:-}"
        break
      fi
    done
    if (( app_idx > 0 && CURRENT == app_idx + 2 )); then
      case "$verb" in
        sync|get|diff|logs|delete|wait|history|rollback|manifests|resources|set|patch|edit|terminate-op|actions)
          _argocd_app_names
          return
          ;;
      esac
    fi
    _argocd
  }
  compdef _argocd_smart argocd 2>/dev/null
  compdef _argocd_smart kargo  2>/dev/null
fi

# ── kubectl dispatcher: route `k argocd ...` / `k argo rollouts ...` ──────
if (( $+commands[kubectl] )); then
  _k_dispatch() {
    case "${words[2]:-}" in
      argocd)
        if (( $+functions[_argocd_smart] )); then
          shift words
          (( CURRENT-- ))
          _normal
          return
        fi
        ;;
      argo)
        if [[ "${words[3]:-}" == "rollouts" ]] && (( $+functions[_kubectl_argo_rollouts] )); then
          words=(kubectl-argo-rollouts "${(@)words[4,-1]}")
          (( CURRENT -= 2 ))
          _normal
          return
        fi
        ;;
    esac
    _kubectl
  }
  compdef _k_dispatch k kubectl 2>/dev/null
fi

# ── prompt extras ─────────────────────────────────────────────────────────
[[ -f ~/.kube-ps1/kube-ps1.sh ]] && source ~/.kube-ps1/kube-ps1.sh

proxy_prompt_info() {
  local http="${HTTP_PROXY:-${http_proxy:-}}"
  local https="${HTTPS_PROXY:-${https_proxy:-}}"
  [[ -z "$http$https" ]] && return
  local port mark
  port=$(printf '%s' "${http:-$https}" | sed -E 's#.*:([0-9]+).*#\1#')
  [[ -n "$http" && -n "$https" ]] && mark="*" || mark=""
  printf '%%F{yellow}PROXY: %s%s%%f' "$port" "$mark"
}

_kube_ps1_seg() { (( $+functions[kube_ps1] )) && kube_ps1; }
RPROMPT='$(_kube_ps1_seg) $(proxy_prompt_info)'

# ── aliases ───────────────────────────────────────────────────────────────
alias vi='vim'
[[ -d "$HOME/Tensorflow/.env" ]] && alias myenv="source $HOME/Tensorflow/.env/bin/activate"
alias k=kubectl
alias kns='kubectl ns'
alias kctx='kubectl ctx'
[[ -x "$HOME/.steam/steam/steamapps/common/Proton - Experimental/proton" ]] && \
  alias proton="$HOME/.steam/steam/steamapps/common/Proton\ -\ Experimental/proton"
alias import_nvidia="export __NV_PRIME_RENDER_OFFLOAD=1; export __GLX_VENDOR_LIBRARY_NAME=nvidia;"

# ── nvm ───────────────────────────────────────────────────────────────────
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
