{ config, pkgs, pkgs-stable, ... }:

let
  # Package groups for organization
  editorPkgs = with pkgs; [
    nano
    neovim
  ];

  editorToolPkgs = with pkgs; [
    ripgrep
    fd
    codespell
  ];

  systemToolPkgs = with pkgs; [
    htop
    atop
    lnav
    tree
    jq
    gnumake
  ];

  devToolPkgs = with pkgs; [
    gh
    git
    lazygit
    glab
    shellcheck
    uv
    sqlite
    virt-manager
    sphinx
  ];

  chatPkgs = with pkgs; [
    weechat
  ];

  langPkgs = with pkgs; [
    gcc
    go_1_24
    (hiPrio clang)
    llvmPackages.bintools
    rustup
    zig
    zls
  ];

  docPkgs = with pkgs; [
    multimarkdown
    hugo
  ];

  idePkgs = with pkgs; [
    vscode
  ];

  infraPkgs = with pkgs; [
    packer
  ];
in
{
  targets.genericLinux.enable = true;

  home.username = "smooney";
  home.homeDirectory = "/home/smooney";

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  home.stateVersion = "22.11"; # Please read the comment before changing.

  nixpkgs.overlays = [
    (self: super:
      {
        weechat = super.weechat.override {
          configure = { availablePlugins, ... }: {
            scripts = with super.weechatScripts; [
              wee-slack
              highmon
            ];
          };
        };
      }
    )
  ];

  nixpkgs.config.allowUnfreePredicate = _: true;

  home.packages = 
    editorPkgs ++ 
    editorToolPkgs ++ 
    systemToolPkgs ++ 
    devToolPkgs ++ 
    chatPkgs ++ 
    langPkgs ++ 
    docPkgs ++ 
    idePkgs ++ 
    infraPkgs;

  home.file = {
  };

  home.sessionVariables = {
    EDITOR = "nano";
  };

  # Nix configuration
  nix = {
    package = pkgs.nix;
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      auto-optimise-store = true;
    };
    gc = {
      automatic = true;
      frequency = "weekly";
      options = "--delete-older-than 30d";
    };
  };

  # Activation scripts for editor configs and automatic maintenance
  home.activation = {
    # Clone nvim config if it doesn't exist
    cloneNvimConfig = config.lib.dag.entryAfter [ "writeBoundary" ] ''
      if [ ! -d "$HOME/.config/nvim/.git" ]; then
        echo "Cloning nvim config..."
        $DRY_RUN_CMD ${pkgs.git}/bin/git clone \
          git@github.com:SeanMooney/nvim-config.git \
          "$HOME/.config/nvim"
      fi
    '';

    # Clone emacs config if it doesn't exist
    cloneEmacsConfig = config.lib.dag.entryAfter [ "writeBoundary" ] ''
      if [ ! -d "$HOME/.config/emacs/.git" ]; then
        echo "Cloning emacs config..."
        $DRY_RUN_CMD ${pkgs.git}/bin/git clone \
          git@github.com:SeanMooney/emacs.git \
          "$HOME/.config/emacs"
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

  # Shell aliases - written to a file you can source from .bashrc
  # Add this to your .bashrc: source ~/.config/home-manager-aliases.sh
  home.file.".config/home-manager-aliases.sh".text = ''
    # Home Manager operations
    alias hms="home-manager switch --flake ~/repos/dotfiles#smooney"
    alias hmu="nix flake update ~/repos/dotfiles"
    alias hmg="home-manager generations"

    # Update and switch in one command
    alias hmus="nix flake update ~/repos/dotfiles && home-manager switch --flake ~/repos/dotfiles#smooney"

    # Garbage collection
    alias hmgc="nix-collect-garbage"
    alias hmgc-old="nix-collect-garbage --delete-old"
    alias hmgc-30d="nix-collect-garbage --delete-older-than 30d"

    # Store optimization
    alias hmopt="nix store optimise"

    # Full cleanup (gc + optimize)
    alias hmclean="nix-collect-garbage --delete-older-than 7d && nix store optimise"

    # Show disk usage
    alias hmdu="nix path-info -Sh ~/.nix-profile"

    # List what would be garbage collected
    alias hmgc-dry="nix-collect-garbage --dry-run"
  '';

  programs.git = {
    enable = true;
    userName  = "Sean Mooney";
    extraConfig = {
        core = { editor = "nano"; };
    };
    signing = {
      key = "69505A0130F29B39";
      signByDefault = false;
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

