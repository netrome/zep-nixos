{
  lib,
  rustPlatform,
  makeWrapper,
  pkg-config,
  libxkbcommon,
  wayland,
  libGL,
  vulkan-loader,
  fontconfig,
  libx11,
  libxcursor,
  libxrandr,
  libxi,
  wl-clipboard,
  src,
}:

let
  # eframe/winit dlopen these through libloading at runtime rather than linking
  # them, so build-time buildInputs is not enough — they must be on
  # LD_LIBRARY_PATH or the binary starts and then dies looking for a backend.
  runtimeLibs = [
    libxkbcommon
    wayland
    libGL
    vulkan-loader # the lockfile pulls in ash/wgpu alongside glow
    fontconfig
    libx11 # x11-dl is in the lockfile; harmless under Wayland but dlopened
    libxcursor
    libxrandr
    libxi
  ];
in

rustPlatform.buildRustPackage {
  pname = "mojime";
  version = "0.1.0";
  inherit src;

  cargoLock.lockFile = "${src}/Cargo.lock";

  nativeBuildInputs = [
    pkg-config
    makeWrapper
  ];
  buildInputs = runtimeLibs;

  # The emoji dataset and OpenMoji font are embedded with include_str! /
  # include_bytes!, so nothing needs installing alongside the binary.
  postInstall = ''
    wrapProgram $out/bin/mojime \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath runtimeLibs} \
      --prefix PATH : ${lib.makeBinPath [ wl-clipboard ]}
  '';

  meta = {
    description = "Minimal Wayland emoji picker built with Rust and egui";
    homepage = "https://github.com/netrome/mojime";
    license = lib.licenses.mit;
    mainProgram = "mojime";
    platforms = lib.platforms.linux;
  };
}
