#!/usr/bin/env python3
"""Check activation SSH selection and ordering without switching or connecting."""

import json
from pathlib import Path
import subprocess

configs = json.loads(subprocess.check_output([
    "nix", "eval", "--offline", "--json", ".#homeConfigurations", "--apply", """
    configurations: builtins.mapAttrs (_: c: {
      ssh = c.config.home.activation.setupActivationSsh;
      signer = c.config.programs.git.signing.signer;
      clones = map (name: c.config.home.activation.${name}) [
        "cloneNvimConfig" "cloneEmacsConfig" "setupPiConfig"
      ];
    }) configurations
    """,
], cwd=Path(__file__).resolve().parents[1], text=True))

for name, config in configs.items():
    hook = config["ssh"]
    assert "writeBoundary" in hook["before"]
    ssh = subprocess.check_output([
        "bash", "-euc", hook["data"] + '\nprintf "%s" "$GIT_SSH_COMMAND"',
    ], text=True)
    if name == "smooney":
        assert ssh == "/usr/bin/ssh", ssh
        assert config["signer"] == "/usr/bin/ssh-keygen", config["signer"]
    else:
        assert ssh.startswith("/nix/store/") and ssh.endswith("/bin/ssh"), ssh
        assert config["signer"].startswith("/nix/store/")
        assert config["signer"].endswith("/bin/ssh-keygen")
    for clone in config["clones"]:
        assert "writeBoundary" in clone["after"]
        assert "GIT_SSH_COMMAND" not in clone["data"]
        subprocess.run(["bash", "-n"], input=clone["data"], text=True, check=True)

print("Activation SSH selection, ordering, and shell syntax checks passed.")
