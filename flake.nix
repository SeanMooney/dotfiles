{
  description = "Sean Mooney's dotfiles managed with Home Manager";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-25.05";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    llm-agents.url = "github:numtide/llm-agents.nix";
  };

  outputs = { self, nixpkgs, nixpkgs-stable, home-manager, llm-agents, ... }:
    let
      users = {
        smooney = { system = "x86_64-linux"; };
        sean    = { system = "x86_64-linux"; };
      };

      mkHome = username: { system }: let
        pkgs = nixpkgs.legacyPackages.${system};
        pkgs-stable = nixpkgs-stable.legacyPackages.${system};
        llm-pkgs = llm-agents.packages.${system};
      in home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        extraSpecialArgs = { inherit pkgs-stable llm-pkgs username system; };
        modules = [ ./home.nix ];
      };
    in {
      homeConfigurations = builtins.mapAttrs mkHome users;
    };
}

