{
  description = "NixOS configuration for zep (Hetzner dedicated, AMD 7950X3D)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    mindex.url = "github:netrome/mindex";
    mindex.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, disko, mindex }: {
    nixosConfigurations.zep = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit mindex; };
      modules = [
        disko.nixosModules.disko
        ./disko.nix
        ./hardware.nix
        ./configuration.nix
      ];
    };
  };
}
