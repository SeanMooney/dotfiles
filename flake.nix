{
  description = "Sean Mooney's dotfiles managed with Home Manager";

  nixConfig = {
    extra-substituters = [
      "https://cache.numtide.com"
      "https://nix-community.cachix.org"
    ];
    extra-trusted-public-keys = [
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-25.05";
    llm-agents.url = "github:numtide/llm-agents.nix";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      nixpkgs-stable,
      llm-agents,
      home-manager,
      ...
    }:
    let
      users = {
        smooney = {
          username = "smooney";
          system = "x86_64-linux";
        };
        sean-linux = {
          username = "sean";
          system = "x86_64-linux";
          genericLinux = false;
        };
        sean-darwin = {
          username = "sean";
          system = "aarch64-darwin";
        };
      };

      mkHome =
        configName:
        { username, system, genericLinux ? (builtins.match ".*-linux" system) != null }:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          pkgs-stable = nixpkgs-stable.legacyPackages.${system};
        in
        home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          extraSpecialArgs = {
            inherit
              pkgs-stable
              username
              system
              configName
              genericLinux
              ;
            inputs = {
              inherit
                nixpkgs
                llm-agents
                ;
            };
          };
          modules = [ ./home.nix ];
        };
    in
    {
      homeConfigurations = builtins.mapAttrs mkHome users;
    };
}
