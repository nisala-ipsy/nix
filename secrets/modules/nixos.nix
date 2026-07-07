{ ... }:
{
  # Secrets now live in this repo (encrypted with sops-age, see ../../.sops.yaml)
  # instead of the external nix-secrets.git flake input.
  sops.defaultSopsFile = ../secrets.yaml;
  sops.age.keyFile = "/var/lib/sops-nix/key.txt";

  # Every key consumed via `config.sops.placeholder.*` elsewhere in the config
  # must be declared here so sops-nix knows to decrypt it.
  sops.secrets."wireguard/spoke_homelab/ip" = { };
  sops.secrets."wireguard/spoke_homelab/port" = { };
  sops.secrets."wireguard/spoke_homelab/private_key" = { };
  sops.secrets."wireguard/spoke_homelab/preshared_key" = { };
}
