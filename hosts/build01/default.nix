{ inputs, ... }:
{
  imports = [
    inputs.srvos.nixosModules.hardware-hetzner-online-amd
    inputs.self.nixosModules.disko-zfs
    inputs.self.nixosModules.builder
    inputs.self.nixosModules.community-builder
  ];

  system.etc.overlay = {
    enable = true;
    mutable = false;
  };
  services.userborn.enable = true;

  # Emulate riscv64 until we have proper builders
  boot.binfmt.emulatedSystems = [ "riscv64-linux" ];

  systemd.network.networks."10-uplink".networkConfig.Address = "2a01:4f9:3b:2946::1/64";

  system.stateVersion = "23.11";
}
