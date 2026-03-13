# NixOS module for Handy speech-to-text
#
# Handles system-level configuration that the package wrapper cannot:
#   - udev rule for /dev/uinput (rdev grab() needs it for virtual input)
#   - Adding users to the "input" group (evdev access for hotkeys)
#
# Usage in your flake:
#
#   inputs.handy.url = "github:cjpais/Handy";
#
#   nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
#     modules = [
#       handy.nixosModules.default
#       { programs.handy.enable = true; }
#     ];
#   };
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.handy;
in
{
  options.programs.handy = {
    enable = lib.mkEnableOption "Handy offline speech-to-text";

    package = lib.mkOption {
      type = lib.types.package;
      description = "The Handy package to use.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    # rdev grab() creates virtual input devices via /dev/uinput.
    # Default permissions are crw------- root root — open it to the input group.
    services.udev.extraRules = ''
      KERNEL=="uinput", GROUP="input", MODE="0660"
    '';
  };
}
