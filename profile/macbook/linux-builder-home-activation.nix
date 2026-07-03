{
  config,
  lib,
  pkgs,
  ...
}:
let
  username = "s1n7ax";
  home = config.users.users.${username}.home;

  repairHomeManagerState = pkgs.writeShellScript "repair-home-manager-state" ''
    set -eu

    state="${home}/.local/state"
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

    find "${home}/.config" -xtype l -delete 2>/dev/null || true
  '';

  unmaskHomeManager = pkgs.writeShellScript "unmask-home-manager" ''
    set -eu
    changed=false
    for unit in /etc/systemd/system/home-manager-*.service; do
      if [ -L "$unit" ] && [ "$(readlink "$unit")" = "/dev/null" ]; then
        rm -f "$unit"
        changed=true
      fi
    done
    if $changed; then
      ${pkgs.systemd}/bin/systemctl daemon-reload
    fi
  '';
in
{
  home-manager.backupFileExtension = "hm-backup";

  systemd.services.home-manager-unmask = {
    description = "Remove stale home-manager unit masks";
    wantedBy = [ "multi-user.target" ];
    before = [ "home-manager-${username}.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = unmaskHomeManager;
    };
  };

  systemd.services."home-manager-${username}" = {
    before = [ "sshd.service" ];
    serviceConfig.ExecStartPre = lib.mkBefore repairHomeManagerState;
  };

  systemd.services.sshd = {
    after = [
      "home-manager-unmask.service"
      "home-manager-${username}.service"
    ];
  };
}
