{ config, lib, pkgs, ... } @ args:

let
  # Flake: `specialArgs` from repo `flake.nix`, or the unified repo-root flake's `lib.inir`.
  inirFlake = args.inirFlake or (builtins.getFlake (toString ../../../../.)).lib.inir;
  # Sibling of niri-port/ — installs "dell-g-controller-launch" (see README: Niri keybind is ~/.config, use scripts/sync-niri-config-kdl.sh).
  dellControllerRoot =
    let
      p = ../../../../Dell-G-Series-Controller;
    in
    if builtins.pathExists p then p
    else builtins.throw "Dell-G-Series-Controller/ must be next to niri-port/ (same parent dir as this repo).";
  # Same env as Dell-G-Series-Controller/shell.nix — do not call run-nixos.sh here: flake copies of that
  # tree often omit uncommitted files, so shell.nix can be missing under /nix/store/...-Dell-G-Series-Controller/.
  dellGControllerPython = pkgs.python313.withPackages (ps: with ps; [ pyside6 pyusb pexpect ]);
  dellGControllerLaunch = pkgs.writeShellScriptBin "dell-g-controller-launch" ''
    set -euo pipefail
    if [ -z "''$XDG_RUNTIME_DIR" ]; then
      XDG_RUNTIME_DIR="/run/user/$(id -u)"
    fi
    export XDG_RUNTIME_DIR
    if [ -z "''$DBUS_SESSION_BUS_ADDRESS" ] && [ -S "''$XDG_RUNTIME_DIR/bus" ]; then
      export DBUS_SESSION_BUS_ADDRESS="unix:path=''$XDG_RUNTIME_DIR/bus"
    fi
    if command -v systemctl >/dev/null 2>&1; then
      if ! systemctl --user is-active --quiet polkit-gnome-authentication-agent-1 2>/dev/null; then
        systemctl --user start polkit-gnome-authentication-agent-1 2>/dev/null || true
      fi
      sleep 0.3
    fi
    export PATH="/run/wrappers/bin:''$PATH"
    if [ -n "''$WAYLAND_DISPLAY" ]; then
      export QT_QPA_PLATFORM=wayland
    else
      export QT_QPA_PLATFORM=xcb
    fi
    export QT_STYLE_OVERRIDE=Fusion
    cd ${dellControllerRoot}
    exec ${dellGControllerPython}/bin/python3 main.py
  '';

  # Use files directly from Download folder to avoid large binary commits.
  # Note: These absolute paths require --impure flag during nixos-rebuild.
  localCursor = builtins.path { path = /home/akashbiswas/Desktop/control/Download/Cursor-3.2.16-x86_64.AppImage; name = "Cursor.AppImage"; };
  localAntigrav = builtins.path { path = /home/akashbiswas/Desktop/control/Download/Antigravity.tar.gz; name = "Antigravity.tar.gz"; };
  localCode = builtins.path { path = /home/akashbiswas/Desktop/control/Download/code-stable-x64-1776814219.tar.gz; name = "code-stable.tar.gz"; };
  discordWrapped = pkgs.symlinkJoin {
    name = "discord-wrapped";
    paths = [ pkgs.vesktop ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      if [ -x "$out/bin/vesktop" ]; then
        makeWrapper "$out/bin/vesktop" "$out/bin/discord" \
          --add-flags "--disable-gpu"
      fi

      mkdir -p "$out/share/applications"
      cat > "$out/share/applications/discord.desktop" <<'EOF'
[Desktop Entry]
Name=Discord
Exec=discord
Icon=discord
Type=Application
Categories=Network;InstantMessaging;
StartupWMClass=vesktop
EOF
      if [ -f "$out/share/applications/vesktop.desktop" ]; then
        rm -f "$out/share/applications/vesktop.desktop"
      fi
    '';
  };
  customApps = let
    appimageContents = if builtins.pathExists localCursor then pkgs.appimageTools.extractType2 {
      pname = "cursor";
      version = "3.2.16";
      src = localCursor;
    } else null;
  in lib.optionals (builtins.pathExists localCursor) [
    (pkgs.stdenv.mkDerivation {
      pname = "cursor";
      version = "3.2.16";
      src = appimageContents;
      nativeBuildInputs = [ pkgs.makeWrapper ];
      buildInputs = with pkgs; [
        glib nss nspr at-spi2-atk at-spi2-core atk cups libdrm gtk3 mesa
        libsecret pango cairo alsa-lib dbus expat fontconfig freetype
        gdk-pixbuf xorg.libX11 xorg.libXcomposite xorg.libXcursor xorg.libXdamage xorg.libXext
        xorg.libXfixes xorg.libXi xorg.libXrandr xorg.libXrender xorg.libXtst libuuid xorg.libxcb
        xorg.libxshmfence libxkbcommon libgbm systemd
      ];
      installPhase = ''
        mkdir -p $out/bin $out/share/applications $out/share/cursor
        cp -r . $out/share/cursor
        
        makeWrapper $out/share/cursor/usr/bin/cursor $out/bin/cursor \
          --prefix LD_LIBRARY_PATH : ${pkgs.lib.makeLibraryPath (with pkgs; [
            stdenv.cc.cc.lib zlib zstd openssl curl expat libxml2 xz icu
            libglvnd mesa libGL xorg.libX11 xorg.libXext xorg.libXrender xorg.libXinerama
            xorg.libXcursor xorg.libXcomposite xorg.libXdamage xorg.libXrandr xorg.libXfixes
            xorg.libXi xorg.libXtst libsecret at-spi2-atk atk alsa-lib cairo cups dbus
            fontconfig freetype gdk-pixbuf glib gtk3 libdrm libgbm libnotify libuuid
            xorg.libxcb xorg.libxshmfence libxkbcommon nss nspr pango systemd libsoup_3 libxkbfile
          ])} \
          --add-flags "--no-sandbox"
          
        install -m 444 -D $out/share/cursor/cursor.desktop -t $out/share/applications
        substituteInPlace $out/share/applications/cursor.desktop \
          --replace 'Exec=AppRun' 'Exec=cursor' \
          --replace 'Exec=cursor %F' 'Exec=cursor' || true
        cp -r $out/share/cursor/usr/share/icons $out/share || true
      '';
    })
  ] ++ lib.optionals (builtins.pathExists localAntigrav) [
    (pkgs.stdenv.mkDerivation rec {
      pname = "antigravity";
      version = "current";
      src = localAntigrav;
      nativeBuildInputs = [ pkgs.autoPatchelfHook pkgs.makeWrapper ];
      buildInputs = with pkgs; [
        at-spi2-atk atk alsa-lib cairo cups dbus expat fontconfig freetype gdk-pixbuf glib gtk3 libGL libx11 libxcomposite libxcursor libxdamage libxext libxfixes libxi libxrandr libxrender libxtst libdrm libgbm libnotify libsecret libuuid libxcb libxkbcommon mesa nss nspr pango systemd libsoup_3 libxkbfile webkitgtk_4_1
      ];
      installPhase = ''
        mkdir -p $out/bin $out/opt/antigravity $out/share/applications $out/share/pixmaps
        cp -r . $out/opt/antigravity/
        chmod +x $out/opt/antigravity/antigravity
        makeWrapper $out/opt/antigravity/antigravity $out/bin/antigravity \
          --prefix LD_LIBRARY_PATH : ${pkgs.lib.makeLibraryPath (with pkgs; [ at-spi2-atk atk alsa-lib cairo cups dbus expat fontconfig freetype gdk-pixbuf glib gtk3 libGL libx11 libxcomposite libxcursor libxdamage libxext libxfixes libxi libxrandr libxrender libxtst libdrm libgbm libnotify libsecret libuuid libxcb libxkbcommon mesa nss nspr pango systemd libsoup_3 libxkbfile webkitgtk_4_1 ])}

        # Icon
        cp $out/opt/antigravity/resources/app/resources/linux/code.png $out/share/pixmaps/antigravity.png

        # Desktop Entry
        cat > $out/share/applications/antigravity.desktop <<EOF
[Desktop Entry]
Name=Antigravity
Exec=antigravity
Icon=antigravity
Type=Application
Categories=Development;
EOF
      '';
    })
  ] ++ lib.optionals (builtins.pathExists localCode) [
    (pkgs.stdenv.mkDerivation {
      pname = "vscode-local";
      version = "stable";
      src = localCode;
      nativeBuildInputs = [ pkgs.autoPatchelfHook pkgs.makeWrapper ];
      buildInputs = with pkgs; [
        at-spi2-atk atk alsa-lib cairo cups dbus expat fontconfig freetype gdk-pixbuf glib gtk3 libGL libx11 libxcomposite libxcursor libxdamage libxext libxfixes libxi libxrandr libxrender libxtst libdrm libgbm libnotify libsecret libuuid libxcb libxkbcommon mesa nss nspr pango systemd libsoup_3 libxkbfile webkitgtk_4_1
      ];
      installPhase = ''
        mkdir -p $out/bin $out/opt/vscode $out/share/applications $out/share/pixmaps
        cp -r . $out/opt/vscode/
        chmod +x $out/opt/vscode/code
        makeWrapper $out/opt/vscode/code $out/bin/code-local \
          --prefix LD_LIBRARY_PATH : ${pkgs.lib.makeLibraryPath (with pkgs; [ at-spi2-atk atk alsa-lib cairo cups dbus expat fontconfig freetype gdk-pixbuf glib gtk3 libGL libx11 libxcomposite libxcursor libxdamage libxext libxfixes libxi libxrandr libxrender libxtst libdrm libgbm libnotify libsecret libuuid libxcb libxkbcommon mesa nss nspr pango systemd libsoup_3 libxkbfile ])} \
          --add-flags "--no-sandbox"

        # Icon
        cp $out/opt/vscode/resources/app/resources/linux/code.png $out/share/pixmaps/vscode-local.png

        # Desktop Entry
        cat > $out/share/applications/vscode-local.desktop <<EOF
[Desktop Entry]
Name=VS Code (Local)
Exec=code-local
Icon=vscode-local
Type=Application
Categories=Development;TextEditor;
EOF
      '';
    })
  ];
in
{
  imports = [
    ./hardware-configuration.nix
    inirFlake.nixosModules.default
  ];

  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "nixos"; 
  networking.networkmanager.enable = true;

  time.timeZone = "Asia/Kolkata";
  i18n.defaultLocale = "en_IN";

  # Display Manager Syntax
  services.xserver.enable = true;
  services.displayManager.gdm.enable = true;
  services.xserver.desktopManager.xfce.enable = true;

  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # CPU temp for `sensors` (Intel). Add more modules only after `sudo sensors-detect` suggests them.
  boot.kernelModules = [ "coretemp" ];
  # Avoid spd5118 suspend/resume loop seen in kernel logs.
  boot.blacklistedKernelModules = [ "spd5118" ];

  # NVIDIA Setup
  boot.kernelParams = ["nvidia_drm.modeset=1" "nvidia_drm.fbdev=1"];
  hardware.graphics.enable = true;
  services.xserver.videoDrivers = ["nvidia"];

  hardware.nvidia = {
    modesetting.enable = true;
    open = false; 
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    prime = {
      offload = {
        enable = true;
        enableOffloadCmd = true;
      };
      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:1:0:0";
    };
  };

  services.printing.enable = true;

  # Audio
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  users.users.akashbiswas = {
    isNormalUser = true;
    description = "akash Biswas";
    # "video" — brightnessctl / backlight; "i2c" — ddcutil for external monitor brightness
    extraGroups = [ "networkmanager" "wheel" "video" "i2c" ];
  };

  programs.firefox.enable = true;
  nixpkgs.config.allowUnfree = true;

  # GUI for many GPUs/AIOs; Dell G laptops may need Dell G Series Controller (Mod+F9 / Super+F9) instead.
  programs.coolercontrol.enable = true;

  environment.systemPackages = with pkgs; [
    polkit_gnome
    dellGControllerLaunch
    ntfs3g
    thunar
    # sensors, sensors-detect, pwmconfig, fancontrol — see README (fancontrol *service* needs hardware.fancontrol + pwmconfig output)
    lm_sensors
    vim
    wget
    git
    github-cli
    # These are installed via customApps below
    # vscode-local
    # cursor
    # antigravity
    google-chrome
    discordWrapped
    telegram-desktop
    vlc
    foot          
    kitty         
    rofi 
    swaybg        
    swayidle      
    swaylock      
    libnotify     
    wl-clipboard
    tesseract
    wf-recorder
    ffmpeg
    slurp
    zstd
  ] ++ customApps;

  # Nix-LD for binary compatibility
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    stdenv.cc.cc
    zlib
    zstd
    openssl
    curl
    expat
    libxml2
    xz
    icu
    libglvnd
    mesa
    libGL
    libx11
    libxext
    libxrender
    libxinerama
    libxcursor
    libxcomposite
    libxdamage
    libxrandr
    libsecret
  ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  services.envfs.enable = true;
  services.power-profiles-daemon.enable = true;
  services.upower.enable = true;
  services.logind.settings.Login = {
    HandleLidSwitch = "hibernate";
    HandleLidSwitchExternalPower = "hibernate";
    HandleLidSwitchDocked = "ignore";
    LidSwitchIgnoreInhibited = "no";
    HoldoffTimeoutSec = "10s";
  };
  systemd.sleep.settings.Sleep = {
    AllowSuspend = "yes";
    AllowHibernation = "yes";
    AllowSuspendThenHibernate = "yes";
    SuspendState = "mem";
    HibernateDelaySec = "10min";
  };
  # Guarantee session lock before any sleep transition.
  environment.etc."systemd/system-sleep/10-lock-before-sleep".text = ''
    #!/bin/sh
    case "$1/$2" in
      pre/*)
        /run/current-system/sw/bin/loginctl lock-sessions || true
        # Niri sessions can reject logind lock-session calls; invoke the compositor locker as the user.
        for sid in $(/run/current-system/sw/bin/loginctl list-sessions --no-legend | ${pkgs.gawk}/bin/awk '{print $1}'); do
          user="$(/run/current-system/sw/bin/loginctl show-session "$sid" -p Name --value 2>/dev/null || true)"
          [ -n "$user" ] || continue
          /run/current-system/sw/bin/runuser -u "$user" -- /run/current-system/sw/bin/env \
            XDG_RUNTIME_DIR="/run/user/$(/run/current-system/sw/bin/id -u "$user")" \
            DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(/run/current-system/sw/bin/id -u "$user")/bus" \
            sh -lc '
              export XDG_RUNTIME_DIR="/run/user/$(id -u)"
              export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"
              export WAYLAND_DISPLAY="''${WAYLAND_DISPLAY:-wayland-1}"
              if command -v inir >/dev/null 2>&1; then
                ( inir lock activate >/dev/null 2>&1 & ) || true
                exit 0
              fi
              if command -v swaylock >/dev/null 2>&1; then
                ( swaylock -f >/dev/null 2>&1 & ) || true
                exit 0
              fi
              if command -v loginctl >/dev/null 2>&1; then
                loginctl lock-sessions || true
              fi
            '
        done
        # Give lock surface enough time to render before hibernate/suspend.
        ${pkgs.coreutils}/bin/sleep 2
        ;;
    esac
  '';
  environment.etc."systemd/system-sleep/10-lock-before-sleep".mode = "0755";

  # Turn off radios before suspend so BT/WiFi cannot wake the system; restore after resume.
  environment.etc."systemd/system-sleep/15-quiet-suspend".text = ''
    #!/bin/sh
    RFKILL="${pkgs.util-linux}/bin/rfkill"
    SYSTEMCTL="/run/current-system/sw/bin/systemctl"
    MODPROBE="/run/current-system/sw/bin/modprobe"
    case "$1/$2" in
      pre/*)
        "$RFKILL" block wlan 2>/dev/null || true
        "$RFKILL" block bluetooth 2>/dev/null || true
        ;;
      post/*)
        "$RFKILL" unblock wlan 2>/dev/null || true
        "$RFKILL" unblock bluetooth 2>/dev/null || true
        # Some Intel BT USB controllers need driver bounce after resume.
        "$MODPROBE" -r btusb 2>/dev/null || true
        "$MODPROBE" btusb 2>/dev/null || true
        # Re-init BlueZ after driver recovery.
        "$SYSTEMCTL" restart bluetooth.service 2>/dev/null || true
        ;;
    esac
  '';
  environment.etc."systemd/system-sleep/15-quiet-suspend".mode = "0755";

  # Keep noisy ACPI wake sources disabled across boots. On many Intel laptops,
  # Bluetooth wakeups are routed through XHCI/TXHC and can cause instant resume.
  systemd.services.disable-acpi-wakeup-sources = {
    description = "Disable noisy ACPI wake sources";
    wantedBy = [ "multi-user.target" ];
    after = [ "local-fs.target" ];
    serviceConfig.Type = "oneshot";
    script = ''
      for dev in XHCI TXHC RP07; do
        if grep -q "^$dev" /proc/acpi/wakeup; then
          status="$(grep "^$dev" /proc/acpi/wakeup | ${pkgs.gawk}/bin/awk '{print $3}')"
          if [ "$status" = "*enabled" ]; then
            echo "$dev" > /proc/acpi/wakeup
          fi
        fi
      done
    '';
  };
  services.gnome.gnome-keyring.enable = true;
  xdg.portal.enable = true;
  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  xdg.mime.defaultApplications = {
    "inode/directory" = "thunar.desktop";
  };

  programs.inir = {
    enable = true;
    enableNiri = true;
    enablePolkit = true;
    enableBluetooth = true;
    dellGSeries.enable = true;
  };

  # Keep blueman applet startable and avoid duplicate ExecStart collisions from drop-ins.
  systemd.user.services.blueman-applet = {
    serviceConfig.ExecStart = lib.mkForce [
      ""
      "${pkgs.blueman}/bin/blueman-applet"
    ];
    serviceConfig.ExecStartPre = lib.mkForce [
      "-${pkgs.procps}/bin/pkill -x blueman-applet"
    ];
  };

  # Enforce stable idle timeouts on each nixos-rebuild switch (flake apply).
  # This keeps runtime config aligned even if UI/local edits drift.
  system.activationScripts.enforceInirIdleConfig.text = ''
    USER_HOME="/home/akashbiswas"
    CFG_DIR="$USER_HOME/.config/illogical-impulse"
    CFG_FILE="$CFG_DIR/config.json"
    mkdir -p "$CFG_DIR"

    if [ ! -f "$CFG_FILE" ]; then
      printf '{}\n' > "$CFG_FILE"
      chown akashbiswas:users "$CFG_FILE" || true
    fi

    ${pkgs.python3}/bin/python3 - <<'PY'
import json
from pathlib import Path

p = Path("/home/akashbiswas/.config/illogical-impulse/config.json")
try:
    data = json.loads(p.read_text() or "{}")
except Exception:
    data = {}

idle = data.setdefault("idle", {})
idle["suspendTimeout"] = 900
idle["suspendCooldownSec"] = 120
idle.setdefault("lockTimeout", 600)
idle.setdefault("screenOffTimeout", 300)
idle.setdefault("lockBeforeSleep", True)

p.write_text(json.dumps(data, indent=4, ensure_ascii=False) + "\n")
PY

    chown akashbiswas:users "$CFG_FILE" || true
  '';

  system.stateVersion = "25.11";
}
