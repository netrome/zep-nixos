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

    # Not in nixpkgs: the JS `near-cli` was dropped in 2025 when upstream
    # archived it, and the Rust rewrite that replaced it was never packaged.
    # Same flake = false treatment as the tools above; pinned to a release tag
    # rather than a branch since this one isn't ours. Packaged in ./pkgs.
    near-cli-rs.url = "github:near/near-cli-rs/v0.30.0";
    near-cli-rs.flake = false;
  };

  outputs = { self, nixpkgs, disko, mindex, agenix, home-manager, zink, slackmd, mojime, near-cli-rs }: {
    nixosConfigurations.zep = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit mindex zink; nearCliSrc = near-cli-rs; };
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
      specialArgs = { slackmdSrc = slackmd; mojimeSrc = mojime; nearCliSrc = near-cli-rs; };
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
