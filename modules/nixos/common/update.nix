{ config, pkgs, ... }:
{
  #srvos.diff.enable = false;

  # adapted from:
  # https://github.com/Mic92/dotfiles/blob/020180880d9413e076073889f82c4751a27734e9/nixos/modules/update-prefetch.nix
  # https://github.com/NixOS/nixpkgs/blob/3428bdf3c93a7608615dddd44dec50c3df89b4be/nixos/modules/system/boot/kexec.nix
  # https://github.com/NixOS/nixpkgs/blob/3428bdf3c93a7608615dddd44dec50c3df89b4be/nixos/modules/tasks/auto-upgrade.nix
  systemd.services.update-host = {
    restartIfChanged = false;
    unitConfig.X-StopOnRemoval = false;
    serviceConfig.Restart = "on-failure";
    serviceConfig.RestartSec = "30s";
    serviceConfig.Type = "oneshot";
    path = [
      config.nix.package
      config.systemd.package
      pkgs.coreutils
      pkgs.curl
      pkgs.kexec-tools
      pkgs.nvd
    ];
    script = ''
      hostname=$(</proc/sys/kernel/hostname)
      p="$(curl -sL https://buildbot.nix-community.org/nix-outputs/nix-community/infra/nixos-$hostname)"

      if [[ "$(readlink /run/booted-system)" == "$p" ]]; then
        return
      fi
      if [[ "$(readlink /run/current-system)" == "$p" ]]; then
        return
      fi

      nix-store --realise $p
      nix-env --profile /nix/var/nix/profiles/system --set $p

      echo "--- diff to current-system"
      nvd diff /run/current-system $p
      echo "---"

      booted="$(readlink /run/booted-system/{initrd,kernel,kernel-modules} && cat /run/booted-system/kernel-params)"
      built="$(readlink $p/{initrd,kernel,kernel-modules} && cat $p/kernel-params)"
      if [[ "$booted" != "$built" ]]; then
        /nix/var/nix/profiles/system/bin/switch-to-configuration boot
        # don't use kexec if system is virtualized, reboots are fast enough
        if ! systemd-detect-virt -q; then
          kexec --load $p/kernel --initrd=$p/initrd --append="$(cat $p/kernel-params) init=$p/init"
        fi
        if [[ ! -e /run/systemd/shutdown/scheduled ]]; then
          shutdown -r "+$(shuf -i 1-60 -n 1)"
        fi
      else
        /nix/var/nix/profiles/system/bin/switch-to-configuration switch
      fi
    '';
  };

  systemd.timers.update-host = {
    timerConfig.OnBootSec = "5m";
    timerConfig.OnUnitInactiveSec = "5m";
  };
}
