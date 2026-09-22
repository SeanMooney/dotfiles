# Dotfiles

Sean Mooney's dotfiles managed with Nix Home Manager and Flakes.

## Quick Start

```bash
# Clone this repository
git clone git@github.com:SeanMooney/dotfiles.git

# Apply configuration from the checkout (which can live anywhere)
cd dotfiles
home-manager switch --impure --flake .#smooney
```

## Shell Aliases

Home Manager manages these aliases in Bash. Open a new shell after switching.

The initial `home-manager switch --impure --flake .#smooney` records the
checkout location in `${XDG_STATE_HOME:-~/.local/state}/dotfiles/checkout`
(using Home Manager's configured `xdg.stateHome`). The aliases use that location
from any working directory, without searching or assuming a clone layout.
If you move the checkout, run the switch command from its new location once.

This relies on Home Manager exporting `FLAKE_PATH` during activation. Local
absolute paths, `.`/`./…`/`../…`, and `path:` versions of those paths are supported.
Remote flake references and direct generation activation leave any recorded
location unchanged. Dry runs do not write it.

Configuration-evaluating aliases use `--impure` so builds include current edits
from the local wee-slack checkout.

On generic Linux, Git activation and SSH commit signing use the host OpenSSH so
system identity providers such as SSSD can resolve the user. NixOS and macOS use
Nix OpenSSH.

These aliases are available:

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

It also invokes `scripts/install-local-dependencies.sh --if-missing` from the Pi
configuration checkout. Run that script without the option to reinstall all
locked local extension dependencies manually.

This operation does not pull or update the parent Pi configuration repository.
Fetching missing submodule objects may require network access. A submodule HEAD
that was manually moved may return to the revision recorded by the parent
checkout; conflicting local file changes cause the activation to fail instead
of forcing the checkout.

## Checks

Run `python3 tests/test-dotfiles-checkout.py` to evaluate and test the checkout
hooks and aliases in temporary directories, without activating Home Manager.
Run `python3 tests/test-activation-ssh.py` to check SSH selection and ordering.

## Structure

```text
dotfiles/
├── flake.nix       # Flake definition with inputs
├── flake.lock      # Pinned versions
├── home.nix        # Home Manager configuration
└── README.md
```
