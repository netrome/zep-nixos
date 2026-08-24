{
  lib,
  rustPlatform,
  makeWrapper,
  wl-clipboard,
  src,
}:

rustPlatform.buildRustPackage {
  pname = "slackmd";
  version = "0.1.0";
  inherit src;

  # No git dependencies in the lockfile, so no outputHashes needed.
  cargoLock.lockFile = "${src}/Cargo.lock";

  nativeBuildInputs = [ makeWrapper ];

  # slackmd shells out to wl-copy/wl-paste rather than linking a clipboard
  # crate, so wl-clipboard has to be on PATH at runtime — it cannot be assumed
  # present just because the keybinding runs inside a Wayland session.
  postInstall = ''
    wrapProgram $out/bin/slackmd \
      --prefix PATH : ${lib.makeBinPath [ wl-clipboard ]}
  '';

  meta = {
    description = "Convert clipboard content between Slack rich text and Markdown";
    homepage = "https://github.com/netrome/slackmd";
    mainProgram = "slackmd";
    platforms = lib.platforms.linux;
  };
}
