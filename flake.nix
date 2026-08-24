{
  description = "NixOS configurations for zep (Hetzner dedicated) and edo (TUXEDO InfinityBook 15)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    mindex.url = "github:netrome/mindex";
    mindex.inputs.nixpkgs.follows = "nixpkgs";
    agenix.url = "github:ryantm/agenix";
    agenix.inputs.nixpkgs.follows = "nixpkgs";
    zink.url = "github:netrome/zink";
    zink.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager/release-26.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # Own tools, packaged in ./pkgs. flake = false because neither repo has a
    # flake.nix — this pins the revision in flake.lock so `nix flake update`
    # bumps them like any other input, rather than hardcoding a sha256.
    slackmd.url = "github:netrome/slackmd";
    slackmd.flake = false;
    mojime.url = "github:netrome/mojime";
    mojime.flake = false;
  };

  outputs = { self, nixpkgs, disko, mindex, agenix, home-manager, zink, slackmd, mojime }: {
    nixosConfigurations.zep = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit mindex zink; };
      modules = [
        disko.nixosModules.disko
        agenix.nixosModules.default
        home-manager.nixosModules.home-manager
        ./hosts/zep/disko.nix
        ./hosts/zep/hardware.nix
        ./hosts/zep/configuration.nix
        ./hosts/zep/mindex.nix
        ./hosts/zep/zink.nix
      ];
    };

    nixosConfigurations.edo = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { slackmdSrc = slackmd; mojimeSrc = mojime; };
      modules = [
        disko.nixosModules.disko
        home-manager.nixosModules.home-manager
        ./hosts/edo/disko.nix
        ./hosts/edo/hardware.nix
        ./hosts/edo/configuration.nix
      ];
    };
  };
}
