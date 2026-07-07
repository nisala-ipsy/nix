# s1n7ax's Nix configuration

Declarative config for a Linux desktop, a Linux server, and an Apple Silicon MacBook.

## macOS setup (Apple Silicon)

### First-time setup

```shell
sh <(curl -L https://nixos.org/nix/install) --daemon
exec $SHELL -l
git clone https://github.com/s1n7ax/nixos.git ~/nixos
cd ~/nixos
sudo nix run --extra-experimental-features 'nix-command flakes' \
  nix-darwin/nix-darwin-26.05#darwin-rebuild -- switch --flake ~/nixos#macbook
```

### Update and rebuild

```shell
cd ~/nixos
nix flake update
sudo /run/current-system/sw/bin/darwin-rebuild switch --flake ~/nixos#macbook
```

### Linux build VM (linux-builder)

`bootstrapStockBuilder` in `profile/macbook/configuration.nix`:

- `true` (default) — stock builder, downloaded prebuilt. Leave here for a working machine.
- `false` — customized dev VM (fish, nvim, git, docker, cursor-agent). Only after step 4.

```shell
# Verify builder is up
sudo ssh linux-builder uname -m          # -> aarch64-linux

# Switch to custom VM: set bootstrapStockBuilder = false, then:
sudo /run/current-system/sw/bin/darwin-rebuild switch --flake ~/nixos#macbook

# Recreate disk so custom diskSize applies (home survives — see below)
sudo launchctl bootout system/org.nixos.linux-builder
sudo rm /var/lib/linux-builder/nixos.qcow2
sudo launchctl bootstrap system /Library/LaunchDaemons/org.nixos.linux-builder.plist

# Log into the VM (password: changeme)
ssh -p 31022 <username>@localhost

# If builder is broken and can't rebuild itself:
#   set bootstrapStockBuilder = true, switch, set false, switch again.

# Stuck / zombie builder
sudo pkill -f 'qemu-system-aarch64|create-builder'
sudo /run/current-system/sw/bin/darwin-rebuild switch --flake ~/nixos#macbook
```

The VM's `/home` lives on a dedicated ext4 disk image
(`/var/lib/linux-builder/empty0.qcow2`), not a 9p share — native filesystem
speed, and it survives VM restarts and the "recreate disk" step above. Files
live *inside* the image and are not visible from macOS Finder; reach them over
ssh/scp (`scp -P 31022 <username>@localhost:...`). To wipe home, delete
`empty0.qcow2` (it's re-created blank and auto-formatted on next boot). To grow
it: `sudo qemu-img resize /var/lib/linux-builder/empty0.qcow2 +20G`, then
restart the builder — `autoResize` expands the filesystem to fill it.

### Common macOS commands

```shell
nix flake update                                                                   # update inputs
sudo /run/current-system/sw/bin/darwin-rebuild switch --flake ~/nixos#macbook --dry-run
sudo /run/current-system/sw/bin/darwin-rebuild switch --rollback                   # undo
sudo nix-collect-garbage -d                                                        # free space
```

## NixOS (Linux) setup

Replace `hardware-configuration.nix` in the profile to match your hardware first.

Profiles: `desktop` (full DE), `server` (minimal), `macbook` (see above).

```shell
git clone https://github.com/s1n7ax/nixos.git
cd nixos

sudo nixos-rebuild switch --upgrade --flake ./#desktop   # or ./#server
sudo nixos-rebuild test --flake ./#desktop               # test, no boot default
sudo nixos-rebuild build --flake ./#desktop              # build only

home-manager switch --flake ./#desktop                   # user-level only
nix flake update
nix flake check
sudo nix-collect-garbage -d
```
