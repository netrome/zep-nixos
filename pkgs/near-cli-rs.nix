{
  lib,
  rustPlatform,
  pkg-config,
  protobuf,
  openssl,
  udev,
  src,
}:

rustPlatform.buildRustPackage {
  pname = "near-cli-rs";
  # Read from the source rather than hardcoded, so bumping the pinned tag with
  # `nix flake update near-cli-rs` is the only edit needed.
  version = (lib.importTOML "${src}/Cargo.toml").package.version;
  inherit src;

  # No git dependencies in the lockfile, so no outputHashes needed.
  cargoLock.lockFile = "${src}/Cargo.lock";

  # protobuf: near-primitives reaches prost-build, whose build script shells out
  # to protoc and does not bundle one.
  nativeBuildInputs = [
    pkg-config
    protobuf
  ];

  # openssl: pulled in below via OPENSSL_NO_VENDOR.
  # udev: the `ledger` feature reaches Ledger devices through the hidapi crate,
  # whose Linux backend links libudev.
  buildInputs = [
    openssl
    udev
  ];

  # Cargo.toml requests openssl with the `vendored` feature, which would compile
  # a second, private OpenSSL out of the openssl-src crate — upstream's way of
  # avoiding a system dependency when shipping binaries. Here that system
  # dependency is the point: this makes openssl-sys link the nixpkgs OpenSSL, so
  # security updates arrive with a rebuild instead of a new upstream release.
  env.OPENSSL_NO_VENDOR = "1";

  # Every default feature except self-update. `near self-update` rewrites its own
  # binary in place, which cannot work from the read-only Nix store, and updating
  # by any route other than this flake is exactly what these machines are set up
  # not to do. Dropping the feature removes the subcommand outright rather than
  # leaving one that fails at the point of use.
  buildNoDefaultFeatures = true;
  buildFeatures = [
    "ledger"
    "ledger-ble"
    "inspect_contract"
    "verify_contract"
  ];

  # The unit tests run fine; tests/account.rs is an integration suite that talks
  # to a real RPC endpoint and downloads a sandbox node, neither of which exists
  # inside the build sandbox. Restricting the target keeps the tests that can
  # actually pass instead of turning doCheck off wholesale.
  cargoTestFlags = [
    "--lib"
    "--bins"
  ];

  meta = {
    description = "Command line utility for interacting with NEAR Protocol";
    homepage = "https://near.cli.rs";
    license = with lib.licenses; [ mit asl20 ];
    mainProgram = "near";
    platforms = lib.platforms.linux;
  };
}
