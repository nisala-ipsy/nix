{ pkgs, lib, inputs, pkgs-unstable, ... }:
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

  pkgsUnstableLinux = import inputs.nixpkgs-unstable {
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
          # git / node_modules / build workloads. The image is a qcow2 stored
          # next to nixos.qcow2 at /var/lib/linux-builder/empty0.qcow2, so all
          # of /home (dotfiles, shell history, cloned repos, caches) survives VM
          # restarts AND the README's "recreate nixos.qcow2" step. Trade-off vs
          # the old 9p workspace: files live *inside* the image and are no
          # longer visible from macOS — reach them over ssh/scp into the VM.
          emptyDiskImages = [
            {
              size = 60 * 1024; # 60 GiB, thin-provisioned qcow2
              # serial => udev exposes it at /dev/disk/by-id/virtio-home, a
              # stable path independent of drive enumeration order.
              driveConfig.deviceExtraOpts.serial = "home";
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
          };
          users.${username} = import ./vm-home.nix;
        };
      };
  };

  users.users.${username} = {
    name = username;
    home = "/Users/${username}";
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-backup";
    extraSpecialArgs = {
      inherit inputs pkgs-unstable;
    };
    users.${username} = import ./home.nix;
  };

  system.primaryUser = username;
  system.defaults.dock.autohide = true;
  system.stateVersion = 6;

  programs.fish.enable = true;
  fonts.packages = [ pkgs.nerd-fonts.iosevka ];
}
