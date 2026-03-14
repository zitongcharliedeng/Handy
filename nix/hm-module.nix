# Home-manager module for Handy speech-to-text
#
# Manages per-user configuration:
#   - Systemd user service (autostart)
#   - ALSA → PipeWire routing (.asoundrc)
#   - Settings seed (first-install defaults)
#
# Usage with home-manager:
#
#   imports = [ handy.homeManagerModules.default ];
#   services.handy.enable = true;
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.handy;
in
{
  options.services.handy = {
    enable = lib.mkEnableOption "Handy speech-to-text user service";

    package = lib.mkOption {
      type = lib.types.package;
      description = "The Handy package to use.";
    };

    settings = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = ''
        Handy settings to seed on first install. These are written to
        settings_store.json only if the file does not exist yet.
        After first launch, Handy's own UI is the source of truth.
      '';
    };

    alsaPipewire = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Route ALSA through PipeWire via .asoundrc (required for CPAL audio capture on NixOS).";
    };
  };

  config = lib.mkIf cfg.enable {
    # .asoundrc: route ALSA default PCM through PipeWire
    home.file.".asoundrc" = lib.mkIf cfg.alsaPipewire {
      text = ''
        pcm.!default {
            type pipewire
        }
        ctl.!default {
            type pipewire
        }
      '';
    };

    # Seed settings on first install only (Handy overwrites at runtime)
    home.activation.handy-settings = lib.mkIf (cfg.settings != { }) (
      let
        settingsJson = pkgs.writeText "handy-settings.json" (
          builtins.toJSON { settings = cfg.settings; }
        );
        dir = ".local/share/com.pais.handy";
        file = "${dir}/settings_store.json";
      in
      config.lib.dag.entryAfter [ "writeBoundary" ] ''
        mkdir -p "$HOME/${dir}"
        if [ ! -f "$HOME/${file}" ]; then
          cp ${settingsJson} "$HOME/${file}"
          chmod 644 "$HOME/${file}"
        fi
      ''
    );

    # Systemd user service
    systemd.user.services.handy = {
      Unit = {
        Description = "Handy speech-to-text";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = "${cfg.package}/bin/handy";
        Environment = [
          "ALSA_PLUGIN_DIR=${pkgs.pipewire}/lib/alsa-lib"
        ];
        Restart = "on-failure";
        RestartSec = 5;
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
