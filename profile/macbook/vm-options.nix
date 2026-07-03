{ lib, ... }:
{
  imports = [
    ../common/options.nix
    ../dev-vm/options.nix
  ];

  # Cursor CLI in place of Claude Code.
  features = {
    development.ai.claude.enable = lib.mkForce false;
    development.ai.cursor-cli.enable = true;
    cli.starship.enable = true;
    shell.fish.enable = true;
  };

  programs.fish.enable = true;
}
