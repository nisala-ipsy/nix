{ ... }:
{
  # Home-manager config for the dev user *inside* the Mac's linux-builder VM
  # (aarch64-linux). The secrets module is intentionally omitted: only the
  # self-hosted-service features need sops, and none of those are enabled here,
  # so the VM needs no age key.
  imports = [
    ../common/options.nix
    ./vm-options.nix
    ./linux-builder-home-activation-hm.nix
    ../../system/home-manager
  ];

  dconf.enable = false;

  home.username = "s1n7ax";
  home.homeDirectory = "/home/s1n7ax";
  home.stateVersion = "24.05";
}
