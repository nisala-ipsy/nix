{ pkgs, lib, inputs, pkgs-unstable, pkgs-node20, ... }:
let
  username = "s1n7ax";

  # Escape hatch for the linux-builder chicken-and-egg problem: the custom
  # `nix.linux-builder.config` below produces an aarch64-linux image that can
  # only be built BY a working Linux builder. When the builder is broken (or
  # was never activated), set this to true and `darwin-rebuild switch` — the
  # stock image is substituted from cache.nixos.org, no Linux build needed.
  # Once the builder VM is up, set it back to false and switch again.
  bootstrapStockBuilder = false;

  hostNameservers = [
    "10.75.65.96"
    "10.75.83.34"
  ];

  # Persistent disk backing the linux-builder VM's /home. Lives in the builder's
  # working directory so it survives VM restarts and `rm nixos.qcow2`. Attached
  # to the VM via `virtualisation.qemu.drives` and pre-created on the host by
  # `system.activationScripts.extraActivation` (both below).
  linuxBuilderHomeDisk = "/var/lib/linux-builder/home.qcow2";

  pkgsUnstableLinux = import inputs.nixpkgs-unstable {
    system = "aarch64-linux";
    config.allowUnfree = true;
  };

  pkgsNode20Linux = import inputs.nixpkgs-node20 {
    system = "aarch64-linux";
    config.allowUnfree = true;
  };
in
{
  imports = [ inputs.home-manager.darwinModules.home-manager ];

  nixpkgs.hostPlatform = "aarch64-darwin";
  nixpkgs.config.allowUnfree = true;

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    trusted-users = [
      "@admin"
      username
    ];
  };

  nix.linux-builder = {
    enable = true;
    maxJobs = 4;
  }
  // lib.optionalAttrs (!bootstrapStockBuilder) {
    config =
      { lib, pkgs, ... }:
      {
        imports = [
          inputs.home-manager.nixosModules.home-manager
          ./linux-builder-home-activation.nix
          ../../system/nixos/core/nix-ld.nix
        ];

        nixpkgs.config.allowUnfree = true;

        virtualisation = {
          cores = 6;
          darwin-builder = {
            memorySize = 8 * 1024;
            diskSize = 60 * 1024;
          };

          # Back the dev user's home with a dedicated, persistent ext4 disk
          # image instead of a 9p share. This gives native filesystem speed and
          # semantics (inotify, hardlinks, fsync) — 9p is painfully slow for
          # git / node_modules / build workloads.
          #
          # The image MUST live in the builder's persistent working directory
          # (/var/lib/linux-builder). We deliberately do NOT use
          # `virtualisation.emptyDiskImages`: the nix-darwin linux-builder
          # daemon runs the VM with TMPDIR=/run/org.nixos.linux-builder and
          # `rm -rf`s that dir on every start and stop, and emptyDiskImages are
          # always created *there* (the runner `cd`s into TMPDIR) — so they get
          # wiped on every VM restart and re-formatted blank. Only NIX_DISK_IMAGE
          # (nixos.qcow2) is placed in the persistent working dir. So we instead
          # attach our own drive by absolute path via `qemu.drives`, and
          # pre-create the qcow2 on the host in `system.activationScripts` (see
          # `linuxBuilderHomeDisk` below) since QEMU won't create a `-drive
          # file=` target itself. This survives VM restarts AND the README's
          # "recreate nixos.qcow2" step. Trade-off vs the old 9p workspace:
          # files live *inside* the image and are no longer visible from
          # macOS — reach them over ssh/scp into the VM.
          #
          # serial=home => udev exposes it at /dev/disk/by-id/virtio-home, a
          # stable path independent of drive enumeration order.
          qemu.drives = [
            {
              name = "home";
              file = linuxBuilderHomeDisk;
              driveExtraOpts.werror = "report";
              deviceExtraOpts.serial = "home";
            }
          ];

          # Mount at /home (not /home/${username}): the freshly mkfs'd root is
          # root-owned, and NixOS activation then creates /home/${username} as a
          # subdir with correct user ownership — the standard separate-/home
          # pattern. autoFormat formats the blank image on first boot;
          # autoResize grows it to fill the device after a later qemu-img resize.
          fileSystems."/home" = {
            device = "/dev/disk/by-id/virtio-home";
            fsType = "ext4";
            autoFormat = true;
            autoResize = true;
          };

        };

        # NixOS's createHome runs in stage-2 activation *before* systemd mounts
        # /home, so the home dir it makes lands on the (shadowed) root fs and
        # vanishes under the mount, leaving the fresh image's /home root-owned
        # and empty. Recreate the home dir with tmpfiles instead: it runs after
        # local-fs.target (so /home is mounted) and before login and
        # home-manager-${username}.service, handing them a correctly-owned home.
        systemd.tmpfiles.rules = [
          "d /home/${username} 0700 ${username} users - -"
        ];

        nix.settings.experimental-features = [
          "nix-command"
          "flakes"
        ];

        networking.nameservers = lib.mkForce hostNameservers;
        networking.dhcpcd.extraConfig = lib.mkAfter ''
          nooption domain_name_servers
        '';

        virtualisation.useHostCerts = lib.mkForce true;
        virtualisation.docker.enable = true;

        programs.fish.enable = true;

        services.openssh.settings.PasswordAuthentication = true;

        users.users.${username} = {
          # System user (not normal) so uid can be pinned to 501 to match the
          # macOS user — NixOS forbids uid < 1000 for isNormalUser. (Kept from
          # the old 9p-workspace setup where host/guest uid parity mattered;
          # harmless now that home lives on a VM-private disk image.)
          isSystemUser = true;
          uid = 501;
          group = "users";
          createHome = true;
          home = "/home/${username}";
          extraGroups = [
            "wheel"
            "docker"
          ];
          shell = pkgs.fish;
          initialPassword = "changeme";
          openssh.authorizedKeys.keys = [
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHYKCu+PeBlMZvcbbCYQ3lJLXmsiND2kkrTYeluMCz+n ilabs-srineshanisala@ipsy.com"
          ];
        };

        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          extraSpecialArgs = {
            inherit inputs;
            pkgs-unstable = pkgsUnstableLinux;
            pkgs-node20 = pkgsNode20Linux;
          };
          users.${username} = import ./vm-home.nix;
        };
      };
  };

  # Pre-create the linux-builder's persistent /home disk on the host before the
  # VM boots. QEMU won't create a `-drive file=` target itself (unlike
  # NIX_DISK_IMAGE / emptyDiskImages, which the runner auto-creates), and the
  # builder daemon opens this drive with werror=report — a missing file would
  # abort VM start. extraActivation runs during `darwin-rebuild switch` before
  # the launchd `linux-builder` daemon is (re)loaded, and the file then persists
  # across reboots. The image is blank (no filesystem); the VM's `autoFormat`
  # mkfs's it on first boot. Thin qcow2, so it costs ~nothing until used. Only
  # created for the custom builder — the stock bootstrap builder ignores it.
  system.activationScripts.extraActivation.text = lib.optionalString (!bootstrapStockBuilder) ''
    if [ ! -e ${linuxBuilderHomeDisk} ]; then
      echo "creating linux-builder home disk (${linuxBuilderHomeDisk})..."
      mkdir -p "$(dirname ${linuxBuilderHomeDisk})"
      ${pkgs.qemu-utils}/bin/qemu-img create -f qcow2 ${linuxBuilderHomeDisk} 60G
    fi
  '';

  users.users.${username} = {
    name = username;
    home = "/Users/${username}";
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-backup";
    extraSpecialArgs = {
      inherit inputs pkgs-unstable pkgs-node20;
    };
    users.${username} = import ./home.nix;
  };

  system.primaryUser = username;
  system.defaults.dock.autohide = true;
  system.stateVersion = 6;

  programs.fish.enable = true;
  fonts.packages = [ pkgs.nerd-fonts.iosevka ];
}
