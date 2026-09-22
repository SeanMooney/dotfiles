#!/usr/bin/env python3
"""Exercise the evaluated activation hooks without switching Home Manager."""

import json
import os
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
config = json.loads(subprocess.check_output([
    "nix", "eval", "--offline", "--json",
    ".#homeConfigurations.smooney.config", "--apply", """
    c: {
      resolve = c.home.activation.resolveDotfilesCheckout.data;
      record = c.home.activation.recordDotfilesCheckout.data;
      bash = c.programs.bash.initExtra;
      stateHome = c.xdg.stateHome;
      alias = c.programs.bash.shellAliases.hmus;
    }
    """,
], cwd=root, text=True))

with tempfile.TemporaryDirectory(prefix="dotfiles-test-") as directory:
    base = Path(directory)
    home = base / "home"
    home.mkdir()
    checkout = base / "arbitrary location" / "checkout"
    checkout.mkdir(parents=True)
    (checkout / "flake.nix").touch()
    state = base / "state"
    recorded = state / "dotfiles" / "checkout"

    def sandbox(script):
        return script.replace(config["stateHome"], str(state))

    hooks = sandbox(config["resolve"] + config["record"])
    helper = sandbox(config["bash"].split("_dotfiles_cd()", 1)[1]
                     .split("\nfor _dir", 1)[0])
    helper = "_dotfiles_cd()" + helper

    def activate(reference, dry=False):
        # Match Home Manager: inherit the caller's cwd, then cd to HOME.
        subprocess.run([
            "bash", "-euc",
            'cd "$HOME"\n'
            'run() { if [[ ! -v DRY_RUN ]]; then "$@"; fi; }\n' + hooks,
        ], cwd=checkout, env={
            **os.environ, "HOME": str(home), "FLAKE_PATH": reference,
            **({"DRY_RUN": "1"} if dry else {}),
        }, check=True, capture_output=True, text=True)

    def shell(command):
        return subprocess.run(["bash", "-euc", helper + command],
                              cwd=home, capture_output=True, text=True)

    assert shell("\n_dotfiles_cd").returncode != 0
    activate(".", dry=True)
    assert not recorded.exists(), "Dry activation must not write state"
    for reference in (".", "../checkout", str(checkout), "path:" + str(checkout)):
        activate(reference)
        assert recorded.read_text() == str(checkout) + "\n"
        result = shell("\n_dotfiles_cd; pwd")
        assert result.returncode == 0, result.stderr
        assert result.stdout.strip() == str(checkout)

    for reference in ("", "github:SeanMooney/dotfiles", "/missing/checkout"):
        activate(reference)
        assert recorded.read_text() == str(checkout) + "\n"

    # hmus must operate in the checkout and must not switch after update fails.
    result = shell('\nnix() { [[ "$PWD" == ' + json.dumps(str(checkout))
                   + ' ]]; }; home-manager() { printf switched; };\n'
                   + config["alias"])
    assert result.returncode == 0 and result.stdout == "switched", result.stderr
    result = shell('\nnix() { return 1; }; home-manager() { printf switched; };\n'
                   + config["alias"])
    assert result.returncode != 0 and not result.stdout

    (checkout / "flake.nix").unlink()
    assert shell("\n_dotfiles_cd").returncode != 0

print("Checkout recording, aliases, and dry-run checks passed.")
