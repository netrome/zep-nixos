# zep — NixOS config

Minimal dev server: SSH in, review PRs, and develop. It also hosts the Mindex
instance at `m.blankfors.se` and a Zink relay. Everything the machine *is* lives
in this repo; reprovisioning is ~30 minutes with nixos-anywhere, so nothing on
the system disk is treated as durable. Zink's runtime state lives on `/data`.

## Layout

| File | Purpose |
|---|---|
| `flake.nix` | Pins nixpkgs (`nixos-26.05`) and disko |
| `disko.nix` | Disk 134B: ESP + ext4 root. Disk 12EC: ext4 on `/data`. No RAID. |
| `hardware.nix` | Kernel modules, AMD microcode |
| `configuration.nix` | Network, SSH, users, packages |
| `mindex.nix` | Mindex service and its Caddy reverse proxy |
| `zink.nix` | Zink relay and persistent state under `/data` |
| `git-credentials.nix` | Per-user GitHub credentials from agenix secrets |
| `opencode-near.nix` | OpenCode configured for NEAR AI Cloud (`dev-near` only) |

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

Public services must be declared in a host module and have only their required
ports opened in `networking.firewall`. Currently Caddy exposes Mindex on ports
80/443, while the Zink relay uses UDP 4400/4401 and TCP 4401. Lessons encoded
from the 2026-07-28 incident: Caddy's admin API stays disabled (`admin off`),
services do not run as root, and ad-hoc dev servers must not bind `0.0.0.0` —
bind loopback and use `ssh -L` instead.

## Secrets

agenix; recipients listed in `secrets/secrets.nix` (the `marten@edo` key and
zep's host key). Decrypted at boot into `/run/agenix`, never on disk.

To add or rotate one, from a clone on the laptop:

```sh
cd secrets   # agenix reads ./secrets.nix, and rule keys are bare filenames
nix run github:ryantm/agenix -- -e <name>.age
```

For OpenCode, create `near-ai-api-key.age` with only the raw NEAR AI Cloud API
key (no variable name or quotes), then rebuild zep. It is decrypted read-only
for `dev-near`; OpenCode reads it directly from `/run/agenix` without placing
the plaintext in the Nix store or exporting it into the shell environment.

```sh
cd secrets
nix run github:ryantm/agenix -- -e near-ai-api-key.age
```

After deploying, log in as `dev-near` and run `opencode`. The declarative
configuration selects NEAR AI Cloud's `z-ai/glm-5.2` model by default.

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

## Commit signing

Signatures are made with SSH keys (`gpg.format = ssh`), set up in each host's
`programs.git.signing` block. No GPG: no gpg-agent, no keyring, no smartcard
daemon, and one mechanism that also covers a hardware key later.

On edo this reuses `marten`'s existing `~/.ssh/id_ed25519`, which has a
passphrase — so each commit prompts for it. That prompt needs a tty, so agent
sessions running as `marten` can't commit unless a key is loaded in the
`gcr-ssh-agent` already running under the graphical session (nothing exports
`SSH_AUTH_SOCK` to it yet).

zep's users have no SSH key of their own — pushes go over HTTPS with a PAT, see
above — so signing needs one generated per user, once. `dev` and `dev-near`
commit unattended, so theirs must have no passphrase:

```sh
for u in marten dev dev-near; do
  sudo -u "$u" ssh-keygen -q -t ed25519 -N "" -C "git signing $u@zep" \
    -f "/home/$u/.ssh/id_ed25519"
done
```

Each key then has to be registered on GitHub *as a signing key* — Settings →
SSH and GPG keys → New SSH key → key type **Signing key**. That is separate
from an authentication key; the same public key can be registered as both.

Verifying signatures locally (`git log --show-signature`, `git verify-commit`)
additionally needs `gpg.ssh.allowedSignersFile` pointing at a file of trusted
public keys. Not configured — without it git reports every signature as coming
from an unknown key, which affects nothing about making them.

### Signing with a YubiKey instead

Nothing gets imported onto the key: `ssh-keygen` generates a FIDO2 credential
on the YubiKey itself, and the file it writes is a *handle* that is useless
without the physical key plus a touch.

```sh
ssh-keygen -t ed25519-sk -C "git signing yubikey" -f ~/.ssh/id_ed25519_sk
```

Needs a YubiKey 5 on firmware 5.2.3 or newer; `-t ecdsa-sk` otherwise. No
system config for it — udev handles FIDO natively (`hardware.u2f` was removed
from nixpkgs for exactly that reason), and systemd's `60-fido-id.rules` and
`70-uaccess.rules` already give the logged-in seat access to a plugged-in key.

Switching between the two keys is one `user.signingkey` path, but *not* via
`git config --global`, for the read-only-symlink reason above. Either flip
`signing.key` in `hosts/edo/configuration.nix` and rebuild, or set it per repo:

```sh
git config --local user.signingkey ~/.ssh/id_ed25519_sk.pub
```

For a toggle that doesn't need a rebuild, add `programs.git.includes = [{ path
= "${config.xdg.configHome}/git/signing.conf"; }]` and write that file by hand —
a later include wins, and git ignores a missing one, so the declarative default
applies whenever the file is absent.

## Running Claude with --dangerously-skip-permissions

The isolation model, in decreasing order of importance:

1. **The machine holds nothing valuable.** No vault, no production keys, no
   service credentials. Anything secret stays on the laptop; the repo checkout
   and a scoped GitHub token are the blast radius.
2. **Run agent sessions as `dev`**, not `marten`: no sudo, no read access to
   `marten`'s home (0700). Give `dev` its own fine-grained GitHub PAT scoped to
   the repos it works on, not your main token.
3. The firewall admits only the explicitly declared SSH, Mindex/Caddy, and Zink
   relay ports; arbitrary development ports remain unreachable.

If stronger isolation is wanted later: per-project `nixos-container` or
microvm.nix guests are both declarative one-file additions.
