{
  config,
  pkgs,
  lib,
  username,
  system,
  configName,
  inputs,
  ...
}:

let
  # Package groups for organization
  editorPkgs = with pkgs; [
    nano
    neovim
    emacs
  ];

  editorToolPkgs = with pkgs; [
    ripgrep
    fd
    codespell
    bat # better cat with syntax highlighting
    eza # modern ls replacement with git integration
  ];

  systemToolPkgs = with pkgs; [
    htop
    btop
    lnav
    jq
    gnumake
    openssh
  ];

  devToolPkgs = with pkgs; [
    acli
    gh
    git
    git-crypt
    lazygit
    glab
    shellcheck
    uv
    pre-commit
    prek
    nix-direnv
    direnv
  ];

  linuxOnlyPkgs = with pkgs; [
    virt-manager
    weechat # overlay with wee-slack/highmon only applies on Linux
  ];

  darwinOnlyPkgs = with pkgs; [
    coreutils # GNU core utilities (gls, gcat, etc.)
    findutils # GNU find, xargs, locate
    watch # execute a program periodically, showing output fullscreen
  ];

  chatPkgs = with pkgs; [
    halloy
  ];

  langPkgs = with pkgs; [
    gcc
    go_1_25
    (lib.hiPrio clang)
    llvmPackages.bintools
    rustup
    zig
    zls
  ];

  docPkgs = with pkgs; [
    multimarkdown
    hugo
  ];

  nixToolPkgs = with pkgs; [
    nix-output-monitor
    comma
    nixfmt
  ];

  agentPkgs = with inputs.llm-agents.packages.${system}; [
    codex
    pi
  ];

  homeConfigTarget =
    if username == "sean" && pkgs.stdenv.isLinux then
      "sean-linux"
    else if username == "sean" && pkgs.stdenv.isDarwin then
      "sean-darwin"
    else
      configName;

in
{
  targets.genericLinux.enable = (builtins.match ".*-linux" system) != null;

  home.username = username;
  home.homeDirectory =
    if (builtins.match ".*-darwin" system) != null then "/Users/${username}" else "/home/${username}";

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  home.stateVersion = "22.11"; # Please read the comment before changing.

  nixpkgs.overlays = lib.optionals ((builtins.match ".*-linux" system) != null) [
    (_: super: {
      weechat = super.weechat.override {
        configure =
          { ... }:
          {
            scripts = with super.weechatScripts; [
              wee-slack
              highmon
            ];
          };
      };
    })
  ];

  nixpkgs.config.allowUnfreePredicate = _: true;

  home.packages =
    editorPkgs
    ++ editorToolPkgs
    ++ systemToolPkgs
    ++ devToolPkgs
    ++ chatPkgs
    ++ agentPkgs
    ++ langPkgs
    ++ docPkgs
    ++ nixToolPkgs
    ++ (lib.optionals pkgs.stdenv.isLinux linuxOnlyPkgs)
    ++ (lib.optionals pkgs.stdenv.isDarwin darwinOnlyPkgs);

  home.file = {
    # Allowed signers file for SSH commit verification
    ".config/git/allowed_signers".text = ''
      work@seanmooney.info ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDUyOgpeDn3nHO//e3SVPS3XqM7CcWEJDp+wc7OaGzA3 sean@p50
    '';

    # Nano configuration
    ".nanorc".text = ''
      # Remember search/replace strings for next session
      set historylog

      # Enable vim-style lock files
      set locking

      # Use codespell as spell checker
      set speller "codespell -i2"

      # Show state flags in title bar (I=autoindent, M=mark, etc.)
      set stateflags

      # Tab settings
      set tabsize 4
      set tabstospaces

      # Syntax highlighting
      include "${pkgs.nano}/share/nano/*.nanorc"
    '';
  };

  home.sessionVariables = {
    EDITOR = "nano";
    KUBE_EDITOR = "nano";
    NPM_PACKAGES = "$HOME/.local/npm-packages";
    PI_CODING_AGENT_DIR = "${config.xdg.configHome}/pi";
    PI_CODING_AGENT_SESSION_DIR = "${config.xdg.stateHome}/pi/sessions";
  }
  // lib.optionalAttrs pkgs.stdenv.isLinux {
    LOCALE_ARCHIVE = "/usr/lib/locale/locale-archive";
  };

  home.sessionPath = [
    "$HOME/bin"
    "$HOME/.local/bin"
    "$HOME/go/bin"
    "$HOME/.cargo/bin"
    "$HOME/.local/npm-packages/bin"
    "$HOME/.claude/local"
    "$HOME/.opencode/bin"
  ];

  # Nix configuration
  nix = {
    package = pkgs.nix;
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      auto-optimise-store = true;
    };
    gc = lib.mkIf pkgs.stdenv.isLinux {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
    registry.nixpkgs.flake = inputs.nixpkgs;
    nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];
  };

  # Activation scripts for editor configs and automatic maintenance
  home.activation = {
    # Clone nvim config if it doesn't exist
    cloneNvimConfig = config.lib.dag.entryAfter [ "writeBoundary" ] ''
      if [ ! -d "$HOME/.config/nvim/.git" ]; then
        echo "Cloning nvim config..."
        export GIT_SSH_COMMAND="${pkgs.openssh}/bin/ssh"
        $DRY_RUN_CMD ${pkgs.git}/bin/git clone \
          git@github.com:SeanMooney/nvim-config.git \
          "$HOME/.config/nvim"
      fi
    '';

    # Clone emacs config if it doesn't exist
    cloneEmacsConfig = config.lib.dag.entryAfter [ "writeBoundary" ] ''
      if [ ! -d "$HOME/.config/emacs/.git" ]; then
        echo "Cloning emacs config..."
        export GIT_SSH_COMMAND="${pkgs.openssh}/bin/ssh"
        $DRY_RUN_CMD ${pkgs.git}/bin/git clone \
          git@github.com:SeanMooney/emacs.git \
          "$HOME/.config/emacs"
      fi
    '';

    # Clone pi config if it doesn't exist and create session storage
    setupPiConfig = config.lib.dag.entryAfter [ "writeBoundary" ] ''
      export PI_CODING_AGENT_DIR="${config.xdg.configHome}/pi"
      export PI_CODING_AGENT_SESSION_DIR="${config.xdg.stateHome}/pi/sessions"

      if [ ! -e "$PI_CODING_AGENT_DIR" ]; then
        echo "Cloning pi config..."
        export GIT_SSH_COMMAND="${pkgs.openssh}/bin/ssh"
        $DRY_RUN_CMD ${pkgs.git}/bin/git clone \
          git@github.com:SeanMooney/pi-config.git \
          "$PI_CODING_AGENT_DIR"
      elif [ ! -d "$PI_CODING_AGENT_DIR/.git" ]; then
        echo "Skipping pi config clone: $PI_CODING_AGENT_DIR exists but is not a git checkout"
      fi

      if [ ! -d "$PI_CODING_AGENT_SESSION_DIR" ]; then
        echo "Creating pi session storage..."
        $DRY_RUN_CMD ${pkgs.coreutils}/bin/mkdir -p "$PI_CODING_AGENT_SESSION_DIR"
      fi
    '';

    # Automatic cleanup - runs after every switch, keeps last 5 generations
    cleanupOldGenerations = config.lib.dag.entryAfter [ "writeBoundary" ] ''
      echo "Cleaning up old Home Manager generations (keeping last 5)..."
      $DRY_RUN_CMD ${pkgs.bash}/bin/bash -c '
        # Get generation IDs older than the 5 most recent
        gens=$(home-manager generations 2>/dev/null | tail -n +6 | grep -oP "id \K[0-9]+" || true)
        for gen in $gens; do
          if [ -n "$gen" ]; then
            echo "Removing generation: $gen"
            home-manager remove-generations "$gen" 2>/dev/null || true
          fi
        done
      '
    '';

    # Run garbage collection after cleanup
    garbageCollect = config.lib.dag.entryAfter [ "cleanupOldGenerations" ] ''
      echo "Running garbage collection..."
      $DRY_RUN_CMD ${pkgs.nix}/bin/nix-collect-garbage 2>/dev/null || true
    '';
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  # Bash configuration
  programs.bash = {
    enable = true;

    historyControl = [ "ignoreboth" ];
    historySize = 1000;
    historyFileSize = 2000;

    shellOptions = [
      "histappend"
      "checkwinsize"
    ];

    shellAliases = {
      # Modern CLI replacements
      ls = "eza --color=auto";
      ll = "eza -la --git";
      la = "eza -a";
      tree = "eza --tree";
      cat = "bat --paging=never";

      # Home Manager aliases
      hms = "home-manager switch --flake ~/repos/dotfiles#${homeConfigTarget}";
      hmu = "(cd ~/repos/dotfiles && nix flake update)";
      hmus = "(cd ~/repos/dotfiles && nix flake update) && home-manager switch --flake ~/repos/dotfiles#${homeConfigTarget}";
      hmg = "home-manager --flake ~/repos/dotfiles#${homeConfigTarget} generations";
      hmn = "home-manager --flake ~/repos/dotfiles#${homeConfigTarget} news";
      hmgc = "nix-collect-garbage";
      hmgc-old = "nix-collect-garbage --delete-old";
      hmgc-30d = "nix-collect-garbage --delete-older-than 30d";
      hmopt = "nix store optimise";
      hmclean = "nix-collect-garbage --delete-older-than 7d && nix store optimise";
      hmdu = "nix path-info -Sh ~/.nix-profile";
      hmgc-dry = "nix-collect-garbage --dry-run";

      # Other common aliases
      tb = "nc termbin.com 9999";
      ocl = "oc login -u kubeadmin -p tester https://api.crc.testing:6443";
    }
    // lib.optionalAttrs pkgs.stdenv.isLinux {
      # Linux-only aliases
      ipmi = "ipmitool -U admin -P tester -I lanplus -H";
      clear-journal = "sudo journalctl --flush --rotate && sudo journalctl --vacuum-time=7d";
    }
    // lib.optionalAttrs pkgs.stdenv.isDarwin {
      # macOS-only aliases
      flush-dns = "sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder";
      show-hidden = "defaults write com.apple.finder AppleShowAllFiles YES; killall Finder";
      hide-hidden = "defaults write com.apple.finder AppleShowAllFiles NO; killall Finder";
      # Clipboard aliases for consistency with Linux (xclip-style)
      xclip = "pbcopy";
      xsel = "pbcopy";
    };

    initExtra = ''
      for _dir in "$HOME/bin" "$HOME/.local/bin" "$HOME/go/bin" "$HOME/.cargo/bin" \
                  "$HOME/.local/npm-packages/bin" "$HOME/.claude/local" "$HOME/.opencode/bin"; do
        case ":$PATH:" in
          *":$_dir:"*) ;;
          *) export PATH="$_dir:$PATH" ;;
        esac
      done
      unset _dir

      # nix.sh (sourced later in .bashrc) always prepends .nix-profile/bin unconditionally.
      # Use PROMPT_COMMAND so the dedup runs after all shell init is complete.
      # Starship preserves existing PROMPT_COMMAND via STARSHIP_PROMPT_COMMAND.
      _dedup_nix_path() {
        local _nix_bin="$HOME/.nix-profile/bin"
        local _seen=":"
        local _p_new=""
        local _oi="$IFS"
        IFS=:
        for _p in $PATH; do
          if [[ -n "$_p" && "$_p" != "$_nix_bin" && "$_seen" != *":$_p:"* ]]; then
            [[ -n "$_p_new" ]] && _p_new="$_p_new:$_p" || _p_new="$_p"
            _seen="$_seen$_p:"
          fi
        done
        IFS="$_oi"
        export PATH="$_p_new:$_nix_bin"
      }
      PROMPT_COMMAND="_dedup_nix_path"

      # macOS: Add GNU coreutils to PATH (with 'g' prefix)
      # This provides commands like gls, gcat, gfind, etc.
      # To use without 'g' prefix, add gnubin dirs to PATH first:
      # export PATH="$HOME/.nix-profile/libexec/gnubin:$PATH"

      # nvm setup (if installed)
      export NVM_DIR="$HOME/.nvm"
      [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
      [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

      # CRC/OpenShift setup
      command -v crc &>/dev/null && eval "$(crc oc-env)"
      [ -f "${config.home.homeDirectory}/.crc/machines/crc/kubeconfig" ] && export KUBECONFIG="${config.home.homeDirectory}/.crc/machines/crc/kubeconfig"

      # Flux completion
      command -v flux &>/dev/null && . <(flux completion bash)

      # GPG passphrase prompt in terminal
      export GPG_TTY=$(tty)

      # Ghostty terminal fix
      [[ "$TERM_PROGRAM" == "ghostty" ]] && export TERM=xterm-256color

      # Source secrets if present
      [ -f "$HOME/.secrets" ] && . "$HOME/.secrets"

      # uv completions
      command -v uv &>/dev/null && eval "$(uv generate-shell-completion bash)"
    '';
  };

  programs.git = {
    enable = true;

    # SSH key signing
    signing = {
      key = "~/.ssh/id_ed25519.pub";
      signByDefault = true;
    };

    settings = {
      user.name = "Sean Mooney";
      user.email = "work@seanmooney.info";

      # SSH signing format
      gpg.format = "ssh";
      gpg.ssh.allowedSignersFile = "~/.config/git/allowed_signers";

      # Branch defaults
      init.defaultBranch = "master";
      push.autoSetupRemote = true;

      # Rebase workflow settings
      pull.ff = "only";
      rebase.autoStash = true;
      rebase.autoSquash = true;
      rebase.updateRefs = true;

      # Better merge conflict markers
      merge.conflictStyle = "zdiff3";

      # Cleanup stale remote branches
      fetch.prune = true;
      fetch.pruneTags = true;

      # Remember conflict resolutions
      rerere.enabled = true;
      rerere.autoUpdate = true;

      # Diff improvements
      diff.algorithm = "histogram";
      diff.colorMoved = "default";

      core.editor = "nano";

      # Git aliases
      alias = {
        st = "status -sb";
        co = "checkout";
        br = "branch";
        ci = "commit";
        unstage = "reset HEAD --";
        last = "log -1 HEAD";
        lg = "log --oneline --graph --decorate -20";
        amend = "commit --amend --no-edit";
        wip = "commit -am 'WIP'";
      };
    };
  };

  # Delta for better git diffs
  programs.delta = {
    enable = true;
    enableGitIntegration = false;
    options = {
      navigate = true;
      side-by-side = true;
      line-numbers = true;
    };
  };

  programs.neovim.plugins = [
    pkgs.vimPlugins.nvim-treesitter.withAllGrammars
  ];

  programs.starship = {
    enable = true;
    settings = {
      add_newline = false;
      character = {
        success_symbol = "[>](bold green)";
      };
      package.disabled = true;
      directory = {
        truncate_to_repo = false;
        truncation_length = 5;
      };
      time = {
        disabled = false;
        format = "[\\[$time\\]]($style)";
      };
      git_branch.symbol = "";
      python.symbol = "python: ";
    };
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  programs.fzf = {
    enable = true;
    enableBashIntegration = true;
  };

}
