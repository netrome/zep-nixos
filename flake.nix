{
  description = "NixOS configurations for zep (Hetzner dedicated) and laptop (TUXEDO InfinityBook 15)";

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
  };

  outputs = { self, nixpkgs, disko, mindex, agenix, home-manager, zink }: {
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

    nixosConfigurations.laptop = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        disko.nixosModules.disko
        ./hosts/laptop/disko.nix
        ./hosts/laptop/hardware.nix
        ./hosts/laptop/configuration.nix
      ];
    };
  };
}
