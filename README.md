# Kubernetes Zsh Environment Bootstrap

This repository provides a single, idempotent shell script to set up a
powerful and modern command-line environment tailored specifically for
interacting with Kubernetes clusters. It automates the installation of
essential CLI tools, configures Zsh with Oh My Zsh, and integrates
productivity enhancers like **kube-ps1** and **fzf**.

------------------------------------------------------------------------

## Features

The bootstrap script streamlines your setup by installing the following
core components:

### Shell & Productivity

-   **Zsh & Oh My Zsh** -- Modern shell with a rich plugin ecosystem.
-   **fzf (Fuzzy Finder)** -- Interactive fuzzy search for history and
    files.
-   **kube-ps1** -- Shows the current Kubernetes context and namespace
    in your prompt.

### Kubernetes Tooling

-   **kubectl** -- Official Kubernetes CLI.
-   **Helm v3** -- Kubernetes package manager.
-   **Krew** -- Plugin manager for kubectl, including:
    -   **kubectl-ctx** -- Switch between Kubernetes contexts.
    -   **kubectl-ns** -- Switch between namespaces.

------------------------------------------------------------------------

## Prerequisites

You only need:

-   A **Linux** or **macOS** environment\
-   `curl` installed\
-   `sudo` access (to install system packages)

------------------------------------------------------------------------

## Installation

To bootstrap your environment, run:

``` bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/shirzady1934/zshrc/main/bootstrap.sh)"
```
------------------------------------------------------------------------

## What the Script Does

### 1. Detects OS

Determines if your system is **Linux** or **macOS**.

### 2. Installs Dependencies

Uses the system package manager (`apt`, `dnf`, `yum`, `pacman`, or
`brew`) to install: - `git` - `zsh` - `fzf` - `tar` and other required
utilities

### 3. Installs Core CLI Tools

Automatically downloads and installs: - Latest **kubectl** - Latest
**helm**

### 4. Sets Up Zsh

-   Installs **Oh My Zsh**
-   Installs **kube-ps1**
-   Installs **fzf**

### 5. Installs kubectl Plugins

Sets up **krew**, then installs: - `kubectl-ctx` - `kubectl-ns`

------------------------------------------------------------------------

## Supported Operating Systems

The script currently supports:

### Linux

-   **Debian/Ubuntu** (`apt`)
-   **RHEL/CentOS/Fedora** (`dnf` / `yum`)
-   **Arch Linux** (`pacman`)

### macOS

-   Requires **Homebrew**; installs automatically if missing.

------------------------------------------------------------------------

## Post-Installation

After installation finishes, start a new shell session:

``` bash
exec zsh
```

You will now have:

-   **Kubernetes-aware prompt**:

        (my-cluster:dev) ~ $

-   **Quick context switching**:

    ``` bash
    kctx
    kns
    ```

-   **Fuzzy search via fzf**:

    -   `CTRL+R` → fuzzy history search\
    -   `CTRL+T` → file search

------------------------------------------------------------------------

## Troubleshooting

### Missing sudo or curl

Ensure: - `sudo` permissions are available\
- `curl` is installed

### Unsupported OS

If your Linux distro is not supported, the script will exit and show the
packages you must install manually.

### Authentication Issues

This script **does not** configure: - Cloud provider CLIs\
- `~/.kube/config`

You must authenticate separately to access Kubernetes clusters.

