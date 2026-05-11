# Kubernetes Zsh Environment Bootstrap

A portable Zsh setup tailored for working with Kubernetes — kubectl, Helm,
Argo CD, kube-ps1, fzf — that **gracefully skips any tool that isn't
installed on the current machine**. Drop the same `.zshrc` onto any Linux
or macOS host and only the parts whose binaries exist will activate.

---

## Features

### Shell & productivity
- **Zsh + Oh My Zsh** with the `agnoster` theme
- **kube-ps1** — shows current context and namespace in `RPROMPT`
- **HTTP_PROXY indicator** — shows proxy port in the prompt when set
- **fzf** — `Ctrl-R` history, `Ctrl-T` file search

### Kubernetes tooling
- **kubectl**, **Helm v3**
- **Krew** with `kubectl-ctx` and `kubectl-ns` plugins
- **Argo CD CLI** integration (see below)
- **Argo Rollouts** completion (when `kubectl-argo-rollouts` is installed)

### Smart completions
- All tool completions are loaded **only when the binary is present** — no
  errors on minimal hosts.
- `k argocd ...` and `k argo rollouts ...` autocomplete correctly via a
  custom dispatcher that bridges kubectl plugin completion gaps.
- Argo CD app **names** and **revision SHAs** complete dynamically (the
  argocd CLI itself doesn't ship this) with a 30s cache.

---

## Argo CD integration

This config adds a `kargo` shell function that runs `argocd --core`
against the `argocd` namespace **without** touching your current kubectl
context — useful when your day-to-day namespace is something else:

```bash
kargo app list
kargo app sync zentra-prod --revision <SHA>
kargo app history porta-prod
```

You can also use the kubectl-plugin form, which has identical completion:

```bash
k argocd app sync zentra-prod --revision <TAB>   # → list of historical SHAs, newest first
k argocd app sync <TAB>                          # → list of app names
```

The `kargo` command works by spinning up a throwaway kubeconfig that
points to namespace `argocd`, running argocd Core mode against it, then
deleting it on exit. Your real `~/.kube/config` and current namespace are
never modified.

---

## Prerequisites

- **Linux** or **macOS**
- `curl`
- `sudo` (only needed by `setup.sh` to install system packages)

---

## Installation

### Clone and run

```bash
git clone https://github.com/shirzady1934/zshrc ~/zshrc
~/zshrc/setup.sh
exec zsh
```

`setup.sh` installs the tools **and** copies `.zshrc` into place (your
existing `~/.zshrc` is backed up to `~/.zshrc.bak.<timestamp>`).

### Just take the `.zshrc` (no tool install)

```bash
git clone https://github.com/shirzady1934/zshrc ~/zshrc
ln -sf ~/zshrc/.zshrc ~/.zshrc
exec zsh
```

### Override behavior via env vars

```bash
ARGOCD_VERSION=v3.3.9 ~/zshrc/setup.sh        # pin to cluster version
INSTALL_ARGOCD=no ~/zshrc/setup.sh            # skip argocd
INSTALL_ARGO_ROLLOUTS=no ~/zshrc/setup.sh     # skip rollouts plugin
INSTALL_ZSHRC=no ~/zshrc/setup.sh             # don't touch ~/.zshrc
```

---

## What `setup.sh` does

1. **Detects OS** — Linux or macOS.
2. **Installs base packages** via `apt`, `dnf`, `yum`, `pacman`, or `brew`:
   git, curl, zsh, tar, unzip, ca-certificates, fzf.
3. **Installs Oh My Zsh** (skips if already present).
4. **Installs latest kubectl** to `/usr/local/bin`.
5. **Installs latest Helm v3**.
6. **Installs latest Argo CD CLI** (`ARGOCD_VERSION=` to pin, `INSTALL_ARGOCD=no` to skip).
7. **Installs latest `kubectl-argo-rollouts`** + generates `~/.argo-rollouts-completion.zsh`
   (`ARGO_ROLLOUTS_VERSION=` / `INSTALL_ARGO_ROLLOUTS=no`).
8. **Installs kube-ps1** to `~/.kube-ps1`.
9. **Installs Krew** + the `ctx` and `ns` plugins.
10. **Installs `.zshrc`** from the repo into `$HOME` (backs up any existing
    non-symlink). Skip with `INSTALL_ZSHRC=no`.

It is idempotent — re-running it skips anything already installed.

---

## Supported operating systems

| OS         | Package manager  |
|------------|------------------|
| Debian / Ubuntu | `apt`        |
| RHEL / CentOS / Fedora | `dnf` / `yum` |
| Arch Linux | `pacman`         |
| macOS      | `brew` (installed if missing) |

---

## Portability

The `.zshrc` is designed to be the **same file across every machine**.
Each tool-specific block is guarded with a `command -v` (or file existence)
check, so missing tools don't produce errors or block shell startup:

| Guarded section | Activation condition |
|---|---|
| Docker completion | `docker` on `$PATH` |
| kubectl completion + dispatcher | `kubectl` on `$PATH` |
| Helm completion | `helm` on `$PATH` |
| Argo CD completion + `kargo` + smart completions | both `argocd` and `kubectl` on `$PATH` |
| Argo Rollouts completion | `kubectl-argo-rollouts` on `$PATH` |
| kube-ps1 prompt | `~/.kube-ps1/kube-ps1.sh` exists |
| `myenv` (Python venv) alias | `~/Tensorflow/.env/` exists |
| `proton` alias | Proton binary exists |
| CUDA `LD_LIBRARY_PATH` | `/usr/local/cuda/lib64` exists |

`PATH` is managed with `typeset -U path` so entries auto-dedupe — safe to
re-source the rc file repeatedly.

---

## Post-installation

```bash
exec zsh
```

You should see something like:

```
user@host ~  (⎈|my-cluster:default)
```

Try:

| Command | Result |
|---------|--------|
| `kctx`  | Switch kubectl context (krew plugin) |
| `kns`   | Switch namespace (krew plugin) |
| `Ctrl-R` | fzf history search |
| `Ctrl-T` | fzf file search |
| `kargo app list` | List Argo CD apps in core mode |
| `k argocd app sync <TAB>` | Tab-complete app names |
| `k argocd app sync <app> --revision <TAB>` | Tab-complete deploy SHAs |

---

## Troubleshooting

### Completion shows file names instead of subcommands

You probably edited `.zshrc` and need to clear the completion cache:

```bash
rm -f ~/.zcompdump* && exec zsh
```

zsh prefers a compiled `.zwc` dump over the live config — stale dumps
cause "unknown command" or "file completion" surprises.

### `argocd app list` fails with `configmap "argocd-cm" not found`

Argo CD Core mode reads its configmap from the **current kubeconfig
context's namespace**. Use the bundled `kargo` wrapper, which temporarily
points to namespace `argocd`, or switch namespace with `kns argocd`.

### `error: unknown command "argocd" for "kubectl"` while tab-completing

This was kubectl's completion intercepting `k argocd <TAB>`. The included
`_k_dispatch` function fixes it — make sure the `.zshrc` is loaded and
the dump is fresh (see above).

### Unsupported Linux distro

`setup.sh` will exit and print the package list to install manually.

### Authentication

`setup.sh` does **not** configure cloud CLIs or `~/.kube/config`. Set those
up separately.
