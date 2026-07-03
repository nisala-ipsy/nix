{ lib, config, pkgs, ... }:
lib.mkIf config.features.shell.fish.enable {
  # HM's fish module defaults generateCaches=true for `man -k` completions, but
  # on Darwin (stateVersion >= 26.05) programs.man.package is null — macOS ships
  # its own man and Nix's GNU man-db breaks apropos there.
  programs.man.generateCaches = lib.mkIf pkgs.stdenv.isDarwin (lib.mkForce false);

  programs.fish = {
    enable = true;
    shellInit = ''
      stty -ixon

      set -x PATH $PATH ~/.cargo/bin 

      # disable greeting
      set -g fish_greeting


      bind ctrl-n backward-word and backward-word and forward-word
      bind ctrl-e forward-word
      bind ctrl-w backward-kill-word
      bind ctrl-a beginning-of-line
      bind ctrl-o end-of-line
    '';
  };

  xdg.configFile."fish/config.fish".force = true;
}
