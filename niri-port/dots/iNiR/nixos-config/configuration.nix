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

  # Nix cannot read /home/.../Download in *pure* flake mode. Copy the files here, then
  #   git add -f local/Cursor-3.2.11-x86_64.AppImage local/Antigravity.tar.gz
  # (or your versions’ names) so the flake can see them. Otherwise skip these packages.
  localCursor = ./local/Cursor-3.2.11-x86_64.AppImage;
  localAntigrav = ./local/Antigravity.tar.gz;
  customApps = lib.optionals (builtins.pathExists localCursor) [
    (pkgs.appimageTools.wrapType2 {
      pname = "cursor";
      version = "3.2.11";
      src = localCursor;
      extraPkgs = p: with p; [ libsecret ];
    })
  ] ++ lib.optionals (builtins.pathExists localAntigrav) [
    (pkgs.stdenv.mkDerivation rec {
      pname = "antigravity";
      version = "current";
      src = localAntigrav;
      nativeBuildInputs = [ pkgs.autoPatchelfHook pkgs.makeWrapper ];
      buildInputs = with pkgs; [
        at-spi2-atk atk alsa-lib cairo cups dbus expat fontconfig freetype gdk-pixbuf glib gtk3 libGL xorg.libX11 xorg.libXcomposite xorg.libXcursor xorg.libXdamage xorg.libXext xorg.libXfixes xorg.libXi xorg.libXrandr xorg.libXrender xorg.libXtst libdrm libgbm libnotify libsecret libuuid xorg.libxcb libxkbcommon mesa nss nspr pango systemd libsoup_3 xorg.libxkbfile webkitgtk_4_1
      ];
      installPhase = ''
        mkdir -p $out/bin $out/opt/antigravity
        cp -r . $out/opt/antigravity/
        chmod +x $out/opt/antigravity/antigravity
        makeWrapper $out/opt/antigravity/antigravity $out/bin/antigravity \
          --prefix LD_LIBRARY_PATH : ${pkgs.lib.makeLibraryPath buildInputs}
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
    extraGroups = [ "networkmanager" "wheel" ];
  };

  programs.firefox.enable = true;
  nixpkgs.config.allowUnfree = true;

  # GUI for many GPUs/AIOs; Dell G laptops may need Dell G Series Controller (Mod+F9 / Super+F9) instead.
  programs.coolercontrol.enable = true;

  environment.systemPackages = with pkgs; [
    polkit_gnome
    dellGControllerLaunch
    # sensors, sensors-detect, pwmconfig, fancontrol — see README (fancontrol *service* needs hardware.fancontrol + pwmconfig output)
    lm_sensors
    vim
    wget
    git
    vscode
    # code-cursor
    google-chrome
    foot          
    kitty         
    rofi 
    swaybg        
    swayidle      
    swaylock      
    libnotify     
    wl-clipboard
    zstd
  ] ++ customApps;

  # Nix-LD for binary compatibility
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    stdenv.cc.cc
    zlib
    zstd
  ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  services.power-profiles-daemon.enable = true;
  services.upower.enable = true;
  xdg.portal.enable = true;
  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gtk ];

  programs.inir = {
    enable = true;
    enableNiri = true;
    enablePolkit = true;
    enableBluetooth = true;
    dellGSeries.enable = true;
  };

  system.stateVersion = "25.11";
}
