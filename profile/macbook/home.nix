{ ... }:
{
  imports = [
    ./host-options.nix
    ../../system/home-manager
  ];

  dconf.enable = false;

  home.username = "s1n7ax";
  home.homeDirectory = "/Users/s1n7ax";
  home.stateVersion = "26.05";
}
