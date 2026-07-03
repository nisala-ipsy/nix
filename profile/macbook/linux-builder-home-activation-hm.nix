{ lib, ... }:
{
  home.activation.repairStaleLinks = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    state="''${XDG_STATE_HOME:-$HOME/.local/state}"
    mkdir -p "$state/home-manager/gcroots" "$state/nix/profiles"

    for link in \
      "$state/home-manager/gcroots/current-home" \
      "$state/home-manager/gcroots/new-home" \
      "$state/nix/profiles/home-manager"
    do
      if [ -L "$link" ] && ! [ -e "$link" ]; then
        rm -f "$link"
      fi
    done

    find "$HOME/.config" -xtype l -delete 2>/dev/null || true
  '';
}
