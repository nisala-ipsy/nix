{ config, ... }:
{
  # Secrets now live in this repo (encrypted with sops-age, see ../../.sops.yaml)
  # instead of the external nix-secrets.git flake input.
  sops.defaultSopsFile = ../secrets.yaml;
  sops.age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";

  # Every key consumed via `config.sops.placeholder.*` elsewhere in the config
  # must be declared here so sops-nix knows to decrypt it.
  # (`frigate/plus/api_key` is declared directly in frigate.nix.)
  sops.secrets."z2m/network_key" = { };
  sops.secrets."frigate/front_road/pass" = { };
  sops.secrets."frigate/front_car/pass" = { };
  sops.secrets."frigate/backyard_roof/pass" = { };
  sops.secrets."frigate/backyard_shower/pass" = { };
}
