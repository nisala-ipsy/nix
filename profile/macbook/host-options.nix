{ ... }:
{
  features = {
    terminal.kitty.enable = true;
    cli = {
      alias.enable = true;
      starship.enable = true;
    };
    shell.fish.enable = true;
  };

  programs.fish.enable = true;
}
