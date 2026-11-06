{
  config,
  osConfig,
  lib,
  pkgs,
  ...
}:
let
  hostname = osConfig.networking.hostName;
  isNotebook = hostname == "xps" || hostname == "yoga";
  isYoga = hostname == "yoga";

  # Idle dim/resume as real scripts instead of inline shell strings:
  #   * the old one-liners only worked if the caller ran them through a shell
  #     (they used `>` redirection and `$(cat ...)`),
  #   * the saved level lived in a predictable /tmp path,
  #   * the fallback assumed a maximum of 100, and
  #   * both lines unconditionally wrote a keyboard-backlight device that
  #     does not exist on every machine.
  # Saving the percentage (brightnessctl -m field 4) rather than a raw value
  # makes the restore independent of the device's raw maximum.
  dimScript = pkgs.writeShellScript "noctalia-dim" ''
    set -eu
    runtime="''${XDG_RUNTIME_DIR:-/tmp}"
    brightnessctl -m g | cut -d, -f4 | tr -d '%' > "$runtime/noctalia-brightness"
    brightnessctl set 10%
    brightnessctl -d '*::kbd_backlight' set 0 2>/dev/null || true
  '';
  undimScript = pkgs.writeShellScript "noctalia-undim" ''
    set -eu
    runtime="''${XDG_RUNTIME_DIR:-/tmp}"
    level="$(cat "$runtime/noctalia-brightness" 2>/dev/null || echo 50)"
    brightnessctl set "$level%"
    brightnessctl -d '*::kbd_backlight' set 2 2>/dev/null || true
  '';
in
{
  # NOTE: nix.settings extra-substituters for noctalia.cachix.org live in
  # modules/common.nix — this is a Home Manager module, so nix.settings
  # (a NixOS option) was previously declared here and silently dropped,
  # which forced every noctalia derivation to build locally.

  programs.noctalia = {
    enable = true;
    systemd.enable = true;
    settings = {
      bar.default = {
        background_opacity = 0.34;
        capsule = true;
        center = [
          "clock"
          "weather"
        ];
        end =
          [
            "cpu"
            "ram"
            "tray"
            "clipboard"
            "network"
            "bluetooth"
            "volume"
          ]
          # Desktop hosts have neither a battery nor a backlight, so these
          # widgets rendered empty or errored on pc.
          ++ lib.optionals isNotebook [
            "brightness"
            "battery"
          ]
          ++ [
            "power_profile"
            "control-center"
            "notifications"
          ]
          ++ lib.optionals isYoga [ "osk_toggle" ];
        font_family = "FiraCode Nerd Font Mono";
        font_weight = 400;
        margin_edge = 4;
        margin_ends = 12;
        radius = 10;
        start = [
          "launcher"
          "wallhaven"
          "taskbar"
          "active_window"
        ];
        thickness = 45;
        widget_spacing = 6;
      };

      brightness = {
        minimum_brightness = 0.01;
      };

      # System-monitor sampling. Upstream defaults are cpu/memory 2 s, network
      # 3 s, GPU 5 s — on a notebook that is a continuous wakeup source, and
      # every sample repaints the bar (the bar shows the cpu and ram widgets).
      # 10 s on the laptops cuts that by 5x; the desktop keeps the snappy
      # defaults because it runs on AC. Option name is `[system.monitor]` in
      # noctalia's TOML; graph widgets use the fastest interval configured here.
      system.monitor = lib.mkIf isNotebook {
        cpu_poll_seconds = 10.0;
        memory_poll_seconds = 10.0;
        network_poll_seconds = 10.0;
        gpu_poll_seconds = 10.0;
        disk_poll_seconds = 10.0;
      };

      idle = {
        pre_action_fade_seconds = 2.0;
        behavior =
          {
            lock = {
              timeout = 300;
              action = "lock";
              enabled = true;
            };
            "screen-off" = {
              timeout = 450;
              action = "screen_off";
              enabled = true;
            };
          }
          # Dimming only makes sense where a backlight exists. Assembled as
          # plain Nix data (rather than lib.mkIf) so it behaves correctly
          # whatever the underlying settings option type is.
          // lib.optionalAttrs isNotebook {
            dim = {
              timeout = 150;
              action = "command";
              command = "${dimScript}";
              resume_command = "${undimScript}";
            };
          };
      };

      location = {
        auto_locate = true;
      };

      lockscreen = {
        enabled = true;
        blurred_desktop = true;
        blur_intensity = 0.5;
        tint_intensity = 0.3;
      };

      lockscreen_widgets = {
        enabled = false;
        schema_version = 2;
        # NOTE: widget_order + widget config below are hardcoded for a 1080p eDP-1
        # panel (notebooks). Adjust output + coordinates before enabling on pc
        # (dual DP monitors, no eDP-1).
        widget_order = [ "lockscreen-login-box@eDP-1" ];

        grid = {
          cell_size = 16;
          major_interval = 4;
          visible = true;
        };

        widget."lockscreen-login-box@eDP-1" = {
          box_height = 70.0;
          box_width = 400.0;
          cx = 960.0;
          cy = 961.0;
          output = "eDP-1";
          rotation = 0.0;
          type = "login_box";

          settings = {
            # Palette role was renamed upstream (validator: "surface_variant"
            # is now "surface_container").
            background_color = "surface_container";
            background_opacity = 0.88;
            background_radius = 12.0;
            input_opacity = 1.0;
            input_radius = 6.0;
            show_login_button = true;
          };
        };
      };

      plugins = {
        enabled = [ "noctalia/wallhaven" ];
      };

      shell = {
        screenshot = {
          save_to_file = true;
          directory = "";
          filename_pattern = "screenshot_%Y%m%d_%H%M%S";
          copy_to_clipboard = true;
          freeze_screen = false;
          confirm_region = false;
        };
      };

      theme = {
        community_palette = "GitHub Dark";
        source = "community";
      };

      widget.taskbar = {
        group_by_workspace = true;
        scale = 1.2;
        workspace_label_placement = "corner";
      };

      widget.wallhaven = {
        type = "noctalia/wallhaven:wallhaven";
      };

      # On-screen keyboard toggle (yoga convertible only). wvkbd starts
      # hidden in tablet mode; this button toggles it via SIGRTMIN.
      # `command` was replaced upstream by widget gesture actions — noctalia's
      # validator warns "command is now the left gesture binding", i.e. the
      # click action now lives under [widget.osk_toggle.actions] as `left`.
      widget.osk_toggle = lib.mkIf (osConfig.networking.hostName == "yoga") {
        type = "custom_button";
        glyph = "keyboard";
        tooltip = "Toggle on-screen keyboard";
        actions.left = "pkill -RTMIN wvkbd-mobintl 2>/dev/null || wvkbd-mobintl --bg 0D1117 --fg 21262D --fg-sp 30363D --press 1F6FEB --press-sp 388BFD --text C9D1D9 --text-sp F0F6FC --fn 'DejaVu Sans 22' -H 240 -L 320 --hidden &";
      };
    };
  };
}
