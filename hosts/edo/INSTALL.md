# edo install playbook

Installing NixOS (**edo**) on the second NVMe drive of the TUXEDO InfinityBook 15,
from the running TuxedoOS, leaving TuxedoOS untouched.

| | |
|---|---|
| Target disk | Samsung 990 PRO 4TB (was `/datadisk`) |
| Untouched | Samsung 990 PRO 2TB (TuxedoOS) |
| Flake | `.#edo` |
| Boot picker | firmware boot menu at power-on (F7) |

Each phase notes where you're standing when you run it.

## 1. Preflight *(in TuxedoOS)*

1. Salvage anything you still want from `/datadisk` — it will be wiped.
2. Make sure everything is committed and the flake is healthy:

   ```sh
   git status          # clean
   nix flake check     # checks zep + edo
   ```

   Flakes ignore untracked and uncommitted files — an unclean tree is the
   classic "my change didn't apply" trap.
3. Push the repo somewhere reachable from a freshly installed edo (zep, or a
   remote). This is both the rescue copy and what gets cloned in phase 5.
4. Pre-build the entire system now, while comfortably in TuxedoOS:

   ```sh
   nix build .#nixosConfigurations.edo.config.system.build.toplevel
   ```

   Downloads a few GB (kernel, Hyprland, Firefox…). If this succeeds, the
   install itself has no build work left. Remove the `result` symlink
   afterwards; the store paths are reused.

## 2. Detach the data disk *(in TuxedoOS)*

1. `sudo umount /datadisk`
2. Delete the `/datadisk` line from `/etc/fstab`. Skipping this makes TuxedoOS
   hang at its next boot looking for the wiped partition.
3. **Verify:** `findmnt /datadisk` prints nothing, and the fstab line is gone.

## 3. Partition & encrypt *(in TuxedoOS — destructive)*

1. Verify the target first:

   ```sh
   lsblk /dev/disk/by-id/nvme-Samsung_SSD_990_PRO_4TB_S7DPNU0Y405376T
   ```

   Expect the 3.6T disk with no mountpoints. The disko config uses this
   serial-numbered path, so it cannot hit the wrong drive — this check is
   belt-and-braces.
2. **Point of no return** — erases the 4TB drive:

   ```sh
   sudo nix run github:nix-community/disko -- --mode disko ./hosts/edo/disko.nix
   ```

   It prompts for the LUKS passphrase. Use letters and digits only (the
   early-boot prompt may run a US keymap, and å ä ö and most symbols move
   between layouts). If forgotten, the data is unrecoverable by design.
3. **Verify:** `findmnt /mnt` shows `/dev/mapper/cryptroot` on ext4, and
   `findmnt /mnt/boot` shows the vfat ESP.

## 4. Install & reboot *(TuxedoOS → firmware)*

1. Run the installer (the `env` wrapper lets root find the nix tools):

   ```sh
   nix shell nixpkgs#nixos-install-tools
   sudo env "PATH=$PATH" nixos-install --flake .#edo
   ```

   Thanks to the pre-build this is mostly copying. At the end it asks for a
   **root password** — set one; it's the fallback login.
2. Reboot. At the TUXEDO logo open the firmware boot menu (F7) and pick the
   new entry — *Linux Boot Manager* on the Samsung 990 PRO 4TB.
3. Leave the default boot order pointing at TuxedoOS for now; pick edo
   manually until it's trusted, then change the order in the BIOS.

## 5. First boot *(on edo)*

1. systemd-boot menu → NixOS → LUKS passphrase prompt → TTY login.
2. Log in as `marten` / `changeme`, then immediately: `passwd`
3. Wi-Fi: `nmtui` (menu-driven), or:

   ```sh
   nmcli device wifi connect "SSID" password "…"
   ```

4. Launch `Hyprland`. First run generates `~/.config/hypr/hyprland.conf` with
   kitty as its terminal, which isn't installed — so exit (Super+M), then:

   ```sh
   sed -i 's/kitty/alacritty/' ~/.config/hypr/hyprland.conf
   ```

   Relaunch; Super+Q now opens alacritty.
5. Clone the repo onto edo. From then on, changes apply with:

   ```sh
   sudo nixos-rebuild switch --flake .
   ```

   Hostname matches the flake attribute, so no `#edo` needed.
6. **Verify dual boot:** reboot once more and confirm TuxedoOS still comes up
   normally.

## If edo won't boot

Nothing is lost: boot TuxedoOS from the firmware menu, fix the flake, and
re-run phases 3–4 — disko wipes and rebuilds the layout cleanly every time.
The TuxedoOS drive is never written to at any point in this playbook; the only
shared state is the boot entry in UEFI NVRAM, which is harmless to leave or
remove (`efibootmgr`).
