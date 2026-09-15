# Dotfiles

Sean Mooney's dotfiles managed with Nix Home Manager and Flakes.

## Quick Start

```bash
# Clone this repository
git clone git@github.com:SeanMooney/dotfiles.git ~/repos/dotfiles

# Apply configuration (also clones editor configs on first run)
cd ~/repos/dotfiles
home-manager switch --flake .#smooney
```

## Shell Aliases

Add this line to your `~/.bashrc` to enable the aliases:

```bash
source ~/.config/home-manager-aliases.sh
```

After sourcing, these aliases are available:

| Alias | Description |
|-------|-------------|
| `hms` | Switch to current config |
| `hmu` | Update all flake inputs |
| `hmus` | Update inputs and switch |
| `hmg` | List all generations |
| `hmgc` | Basic garbage collection |
| `hmgc-old` | Delete ALL old generations |
| `hmgc-30d` | Keep last 30 days |
| `hmopt` | Deduplicate store (hard links) |
| `hmclean` | Full cleanup (7d gc + optimize) |
| `hmdu` | Show profile disk usage |
| `hmgc-dry` | Preview what would be deleted |

## Automatic Maintenance

- **On every switch**: Keeps last 5 generations, runs garbage collection
- **Weekly**: Deep garbage collection (30+ days old)
- **On every build**: Auto-optimizes store

## Editor Configs

Neovim and Emacs configs are managed independently:

- `~/.config/nvim` → [github.com/SeanMooney/nvim-config](https://github.com/SeanMooney/nvim-config)
- `~/.config/emacs` → [github.com/SeanMooney/emacs](https://github.com/SeanMooney/emacs)

They are cloned automatically on first `home-manager switch` but remain fully independent afterward.

## Pi Configuration

Home Manager clones the independent Pi configuration repository into
`$PI_CODING_AGENT_DIR` when it is absent. On each switch, it initializes and
checks out the submodule revisions recorded by the current Pi configuration
checkout:

```bash
git submodule update --init --recursive
```

This operation does not pull or update the parent Pi configuration repository.
Fetching missing submodule objects may require network access. A submodule HEAD
that was manually moved may return to the revision recorded by the parent
checkout; conflicting local file changes cause the activation to fail instead
of forcing the checkout.

## Structure

```text
~/repos/dotfiles/
├── flake.nix       # Flake definition with inputs
├── flake.lock      # Pinned versions
├── home.nix        # Home Manager configuration
└── README.md
```
