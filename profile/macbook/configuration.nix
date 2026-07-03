{ pkgs, inputs, pkgs-unstable, ... }:
let
  username = "s1n7ax";

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

    config =
      { lib, ... }:
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
        };

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
          isNormalUser = true;
          home = "/home/${username}";
          extraGroups = [
            "wheel"
            "docker"
          ];
          shell = pkgs.fish;
          initialPassword = "changeme";
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
