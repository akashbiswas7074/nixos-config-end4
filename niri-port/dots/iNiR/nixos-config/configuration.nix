{ config, pkgs, ... }:

let
  # --- CURSOR DEB PACKAGE DEFINITION ---
  cursor-deb = pkgs.stdenv.mkDerivation rec {
    pname = "cursor";
    version = "3.1.17";
    
    src = /home/akashbiswas/Downloads/cursor_3.1.17_amd64.deb; 

    nativeBuildInputs = [ 
      pkgs.dpkg 
      pkgs.autoPatchelfHook 
      pkgs.makeWrapper
    ];

    buildInputs = with pkgs; [
      glibc
      nss
      nspr
      atk
      at-spi2-atk
      libdrm
      mesa
      gtk3
      pango
      cairo
      alsa-lib
      libsecret      # Added for credential storage
      libxkbcommon
      xorg.libX11
      xorg.libXcomposite
      xorg.libXdamage
      xorg.libXext
      xorg.libXfixes
      xorg.libXrandr
      xorg.libxkbfile  # FIXED: Added to resolve libxkbfile.so.1 error
      libgbm
      systemd
    ];

    unpackPhase = ''
      dpkg-deb --fsys-tarfile $src | tar x --no-same-permissions --no-same-owner
    '';

    installPhase = ''
      mkdir -p $out/bin $out/share/cursor
      
      # Automatically find the directory containing the 'cursor' binary
      APP_DIR=$(find . -type f -name "cursor" -printf '%h' -quit)
      
      if [ -n "$APP_DIR" ]; then
        cp -r $APP_DIR/* $out/share/cursor/
      else
        echo "Could not find cursor binary in the unpacked deb!"
        exit 1
      fi
      
      if [ -d "usr/share/icons" ]; then
        cp -r usr/share/icons $out/share/
      fi
      
      chmod +x $out/share/cursor/cursor
      ln -s $out/share/cursor/cursor $out/bin/cursor
    '';
  };
in
{
  imports = [ ./hardware-configuration.nix ];

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

  programs.niri.enable = true;
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
 cursor-deb
    vim
    wget
    git
    antigravity
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
  ];

  # Nix-LD for binary compatibility
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    stdenv.cc.cc
    zlib
  ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  services.power-profiles-daemon.enable = true;
  services.upower.enable = true;
  xdg.portal.enable = true;
  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
     #bloutooth
  hardware.bluetooth.enable = true;
services.blueman.enable = true;


  security.polkit.enable = true;
  system.stateVersion = "25.11";
}
