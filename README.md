# PowerShell Profile

This project is a collection of PowerShell scripts and functions designed to enhance your command-line experience with a focus on speed, usability, and developer productivity. It features a modular structure, deferred loading for a fast startup time, and a host of useful utilities for daily tasks.

## Features

- **Fast Startup:** Components like `oh-my-posh` and `PSReadLine` are loaded asynchronously, so your shell is ready to use instantly.
- **Enhanced Prompt:** A clean and informative prompt powered by `oh-my-posh`.
- **Powerful Command Editing:** Advanced command history, syntax highlighting, and keybindings with `PSReadLine`.
- **Git Integration:**
    - `gclean`: Deletes local branches that have been merged.
    - `gg` (`Git-Go`): A fuzzy-search branch switcher using `fzf`.
- **Autocompletion:**
    - `dotnet` CLI
    - `az` (Azure CLI)
    - `git` aliases
- **Useful Aliases:**
    - `ep`: Edit your profile.
    - `..`, `...`: Navigate up directories.
    - And many more for common commands.

## Prerequisites

Before installation, ensure you have the following tools installed and available in your `PATH`:

- [oh-my-posh](https://ohmyposh.dev/docs/installation)
- [fzf](https://github.com/junegunn/fzf)
- [PSReadLine](https://github.com/PowerShell/PSReadLine) (usually included with modern PowerShell)

## Installation

1.  Clone this repository to a location of your choice (e.g., `C:\Users\YourUser\Documents\PowerShell-Profile`).
2.  Open a PowerShell terminal **with Administrator privileges**.
3.  Navigate to the cloned repository's directory.
4.  Run the setup script:
    ```powershell
    .\setup.ps1
    ```

The setup script will create a symbolic link from your PowerShell profile file (`$PROFILE`) to the `profile.ps1` file in this repository. This means any updates you pull from this repository will be automatically reflected in your shell.

5.  Restart your PowerShell terminal.

## Usage

Once installed, the functions and aliases will be automatically available in your PowerShell sessions.

- **Switch Git branches:**
  ```powershell
  gg my-feature-branch
  ```
  (This will open an `fzf` fuzzy-search prompt)

- **Clean up merged Git branches:**
  ```powershell
  gclean
  ```

## Available Function Modules

This profile is organized into the following function modules located in the `functions/` directory:

- `ai-functions.ps1`: Functions related to AI and machine learning tasks.
- `azure-functions.ps1`: Helpers for interacting with Microsoft Azure.
- `dev-functions.ps1`: General developer utilities.
- `file-functions.ps1`: Functions for file manipulation.
- `git-functions.ps1`: Git-related helpers.
- `kubernetes-functions.ps1`: Functions for interacting with Kubernetes.
- `network-functions.ps1`: Networking utilities.
- `import-modules.ps1`: Handles the import of required modules.
- `setup-autocompletions.ps1`: Sets up custom command autocompletions.
