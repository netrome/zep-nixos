# zep — NixOS config

Minimal dev server: SSH in, review PRs, develop. No public services beyond SSH.
Everything the machine *is* lives in this repo; reprovisioning is ~30 minutes
with nixos-anywhere, so nothing on the box is treated as durable.

## Layout

| File | Purpose |
|---|---|
| `flake.nix` | Pins nixpkgs (`nixos-26.05`) and disko |
| `disko.nix` | Disk 134B: ESP + ext4 root. Disk 12EC: ext4 on `/data`. No RAID. |
| `hardware.nix` | Kernel modules, AMD microcode |
| `configuration.nix` | Network, SSH, users, packages |

Users: `marten` (wheel, passwordless sudo) and `dev` (no sudo — sandbox for
agent sessions). Both log in with the `marten@edo` key only.

## Install runbook (wipes the machine)

Prerequisites — in order, all irreversible once the wipe happens:

1. **Evidence capture** (see `~/incident-2026-07-28/NOTES.md`): root journal
   export, `/var/log/{btmp,wtmp,lastlog}`, `journalctl -u ssh` — copied off-box.
2. **Data off-box**: everything worth keeping from `/home/marten` (~1.4 TB as
   of 2026-07-29) and the incident repo itself.
3. **This repo pushed** somewhere reachable, and cloned on the laptop.
   nixos-anywhere runs *from the laptop* (needs Nix installed there), not on zep.

Then:

```sh
# 1. Hetzner Robot → server → Rescue tab → linux64 → activate, then Reset tab
#    → Execute automatic hardware reset. Note the rescue root password.

# 2. (Optional, recommended post-incident) secure-erase both drives from rescue:
ssh root@65.109.124.100
blkdiscard -f /dev/nvme0n1 && blkdiscard -f /dev/nvme1n1
exit

# 3. Install from the laptop:
cd zep-nixos
nix run github:nix-community/nixos-anywhere -- --flake .#zep root@65.109.124.100
```

The machine kexecs a NixOS installer, disko partitions per `disko.nix`,
the system installs and reboots.

Post-install — sshd listens on **8822**; the rescue/installer steps above are
the only time port 22 is used:

```sh
ssh-keygen -R 65.109.124.100   # old host keys are gone (deliberately)
ssh -p 8822 marten@65.109.124.100
```

Recommended `~/.ssh/config` entry on the laptop, used by the deploy command below:

```
Host zep
  HostName 65.109.124.100
  Port 8822
  User marten
```

## Making changes

Edit, commit, then from the laptop (or any clone):

```sh
nixos-rebuild switch --flake .#zep --target-host zep --use-remote-sudo
```

Adding a public service later = declare it in `configuration.nix` **and** open
its port in `networking.firewall`. Nothing is reachable by default. Lessons
encoded from the 2026-07-28 incident: no Caddy admin API (and if Caddy ever
returns, `admin off`), no root-run services, no `0.0.0.0` dev servers — bind
loopback and use `ssh -L` instead.

## Secrets

agenix; recipients listed in `secrets/secrets.nix` (the `marten@edo` key and
zep's host key). Decrypted at boot into `/run/agenix`, never on disk.

To add or rotate one, from a clone on the laptop:

```sh
cd secrets   # agenix reads ./secrets.nix, and rule keys are bare filenames
nix run github:ryantm/agenix -- -e <name>.age
```

`git-credentials.nix` gives each user in its `patUsers` list a GitHub PAT via a
credential helper scoped to `https://github.com`. The secret is the literal
two-line answer to git's credential protocol:

```
username=<github login>
password=<the PAT>
```

Not `git config credential.helper store` — home-manager owns
`~/.config/git/config` as a read-only store symlink, and the `store` helper
rewrites its file after every successful auth, which fails against `/run/agenix`.

## Running Claude with --dangerously-skip-permissions

The isolation model, in decreasing order of importance:

1. **The machine holds nothing valuable.** No vault, no production keys, no
   service credentials. Anything secret stays on the laptop; the repo checkout
   and a scoped GitHub token are the blast radius.
2. **Run agent sessions as `dev`**, not `marten`: no sudo, no read access to
   `marten`'s home (0700). Give `dev` its own fine-grained GitHub PAT scoped to
   the repos it works on, not your main token.
3. The firewall blocks all inbound except SSH.

If stronger isolation is wanted later: per-project `nixos-container` or
microvm.nix guests are both declarative one-file additions.
