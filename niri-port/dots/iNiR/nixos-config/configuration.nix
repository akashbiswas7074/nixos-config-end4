{ config, pkgs, ... } @ args:

let
  # Flake: passed via specialArgs from flake.nix. Legacy: resolve parent iNiR flake.
  inirFlake = args.inirFlake or (builtins.getFlake (toString ../.));
  # --- CURSOR APPIMAGE DEFINITION ---
  cursor-appimage = pkgs.appimageTools.wrapType2 {
    pname = "cursor";
    version = "3.2.11";
    src = /home/akashbiswas/Desktop/control/Download/Cursor-3.2.11-x86_64.AppImage;
    extraPkgs = pkgs: with pkgs; [ libsecret ];
  };

  # --- ANTIGRAVITY BINARY DEFINITION ---
  antigravity-bin = pkgs.stdenv.mkDerivation rec {
    pname = "antigravity";
    version = "current";
    src = /home/akashbiswas/Desktop/control/Download/Antigravity.tar.gz;
    
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
  };
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

  environment.systemPackages = with pkgs; [
    polkit_gnome
    cursor-appimage
    vim
    wget
    git
    antigravity-bin
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
  ];

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
