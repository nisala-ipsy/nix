{ lib, ... }:
{
  imports = [
    ../common/options.nix
    ../dev-vm/options.nix
  ];

features = {
    development.ai.claude.enable = lib.mkForce false;
    development.ai.cursor-cli.enable = true;

    shell = {
      fish.enable = true;
    };

    editor.neovim.enable = true;

    cli = {
      eza.enable = true;
      lazygit.enable = true;
      scripts.enable = true;
      starship.enable = true;
      zoxide.enable = true;
      direnv.enable = true;
      fzf.enable = true;
      yazi.enable = true;
      vifm.enable = true;
      htop.enable = true;
      alias.enable = true;
      pet.enable = true;
      rustAlternatives.enable = true;
    };

    fonts.enable = true;
  };
}
