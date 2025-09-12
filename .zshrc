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
)
source $ZSH/oh-my-zsh.sh

#docker completion
source <(docker completion zsh)
#zsh completion
source <(kubectl completion zsh)
# helm completion
source <(helm completion zsh)
#kube-ps1
source ~/.kube-ps1/kube-ps1.sh

# Put Kubernetes on the RIGHT to keep agnoster clean:
RPROMPT='$(kube_ps1)'

#krew
export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"
#editor
export EDITOR=vim
#myscripts
export PATH=$HOME/Documents/sh:$HOME/.local/bin:$HOME/Documents/bin:$PATH""
export PATH="$PATH:/usr/local/cuda/bin/:$HOME/perl5/bin"
#steam proton and wine
export STEAM_COMPAT_DATA_PATH=$HOME/proton
export STEAM_COMPAT_CLIENT_INSTALL_PATH=$HOME/proton
export WINEPREFIX=$HOME/.wine
#for sign with git
export GPG_TTY=$(tty);
#golang
export GOPATH=$HOME/go
export PATH=$PATH:$GOROOT/bin:$GOPATH/bin
#cuda
export LD_LIBRARY_PATH=/usr/local/cuda/lib64
export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:/usr/local/lib64/systemc/"

#vi
alias vi='vim'
#python env
alias myenv="source $HOME/Tensorflow/.env/bin/activate"
#k8s
alias k=kubectl
alias kns='kubectl ns'
alias kctx='kubectl ctx'
#proton and gpu
alias proton="$HOME/.steam/steam/steamapps/common/Proton\ -\ Experimental/proton"
alias import_nvidia="export __NV_PRIME_RENDER_OFFLOAD=1; export __GLX_VENDOR_LIBRARY_NAME=nvidia;"
