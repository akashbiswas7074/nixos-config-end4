# NixOS dependency installer for iNiR
# This script is meant to be sourced.
#
# shellcheck shell=bash

if ! command -v nix &>/dev/null; then
  log_error "nix command not found. This installer is for NixOS only."
  return 1
fi

tui_info "Installing NixOS dependencies for iNiR..."

# Map command names (used by doctor/setup) to installable Nix flake attrs.
# NOTE:
# - `awww` is not available in nixpkgs, so we install our local compatibility
#   package that proxies to `swww` while keeping the same command names.
declare -A nix_attr_for_cmd=(
  [qs]="nixpkgs#quickshell"
  [niri]="nixpkgs#niri"
  [nmcli]="nixpkgs#networkmanager"
  [wpctl]="nixpkgs#wireplumber"
  [jq]="nixpkgs#jq"
  [rsync]="nixpkgs#rsync"
  [curl]="nixpkgs#curl"
  [git]="nixpkgs#git"
  [python3]="nixpkgs#python3"
  [fish]="nixpkgs#fish"
  [magick]="nixpkgs#imagemagick"
  [grim]="nixpkgs#grim"
  [cliphist]="nixpkgs#cliphist"
  [wl-copy]="nixpkgs#wl-clipboard"
  [wl-paste]="nixpkgs#wl-clipboard"
  [fuzzel]="nixpkgs#fuzzel"
  [awww]=".#awww-compat"
  [awww-daemon]=".#awww-compat"
  [hyprpicker]="nixpkgs#hyprpicker"
  [playerctl]="nixpkgs#playerctl"
  [notify-send]="nixpkgs#libnotify"
  [flock]="nixpkgs#util-linux"
  [go]="nixpkgs#go"
  [cc]="nixpkgs#gcc"
  [pkg-config]="nixpkgs#pkg-config"
  [meson]="nixpkgs#meson"
  [ninja]="nixpkgs#ninja"
  [dbus-daemon]="nixpkgs#dbus"
  [bluetoothctl]="nixpkgs#bluez"
  [blueman-manager]="nixpkgs#blueman"
  # Recommended extras used by shell integration.
  [uv]="nixpkgs#uv"
  [starship]="nixpkgs#starship"
  [eza]="nixpkgs#eza"
  [slurp]="nixpkgs#slurp"
  [wf-recorder]="nixpkgs#wf-recorder"
  [ffmpeg]="nixpkgs#ffmpeg"
  [swappy]="nixpkgs#swappy"
  [tesseract]="nixpkgs#tesseract"
  [qalc]="nixpkgs#libqalculate"
  [brightnessctl]="nixpkgs#brightnessctl"
  [socat]="nixpkgs#socat"
  [yt-dlp]="nixpkgs#yt-dlp"
  [swaylock]="nixpkgs#swaylock-effects"
  [swayidle]="nixpkgs#swayidle"
  [wlsunset]="nixpkgs#wlsunset"
  [ddcutil]="nixpkgs#ddcutil"
  [kwriteconfig6]="nixpkgs#kdePackages.kconfig"
  [nm-connection-editor]="nixpkgs#networkmanagerapplet"
  [xdg-settings]="nixpkgs#xdg-utils"
  [mpv]="nixpkgs#mpv"
)

# Build-only dev libraries are intentionally NOT added to the user profile.
# They are pulled in transiently by install-python-packages via `nix shell`
# to avoid profile collisions across *.dev outputs (e.g. xorgproto vs libX11).
runtime_extra_targets=(
  "nixpkgs#qt6.qt5compat"
  "nixpkgs#qt6.qtmultimedia"
  "nixpkgs#kdePackages.kirigami.unwrapped"
)

required_cmds=(
  qs niri nmcli wpctl jq rsync curl git python3 fish magick grim cliphist
  wl-copy wl-paste fuzzel awww awww-daemon hyprpicker playerctl notify-send
  flock go cc pkg-config meson ninja dbus-daemon bluetoothctl blueman-manager
)

optional_cmds=(
  uv starship eza slurp wf-recorder ffmpeg swappy tesseract qalc brightnessctl
  socat yt-dlp swaylock swayidle wlsunset ddcutil kwriteconfig6
  nm-connection-editor xdg-settings mpv
)

cmds_to_check=()
if [[ -n "${ONLY_MISSING_DEPS:-}" ]]; then
  # setup update passes command identifiers in ONLY_MISSING_DEPS.
  read -r -a cmds_to_check <<< "${ONLY_MISSING_DEPS}"
else
  cmds_to_check=("${required_cmds[@]}" "${optional_cmds[@]}")
fi

targets=()
for cmd in "${cmds_to_check[@]}"; do
  if command -v "$cmd" &>/dev/null; then
    continue
  fi

  attr="${nix_attr_for_cmd[$cmd]:-}"
  if [[ -z "$attr" ]]; then
    log_warning "No Nix mapping for command '$cmd' (skipping)"
    continue
  fi

  already_added=false
  for existing in "${targets[@]}"; do
    if [[ "$existing" == "$attr" ]]; then
      already_added=true
      break
    fi
  done

  if [[ "$already_added" == false ]]; then
    targets+=("$attr")
  fi
done

for target in "${runtime_extra_targets[@]}"; do
  already_added=false
  for existing in "${targets[@]}"; do
    if [[ "$existing" == "$target" ]]; then
      already_added=true
      break
    fi
  done
  if [[ "$already_added" == false ]]; then
    targets+=("$target")
  fi
done

if [[ ${#targets[@]} -eq 0 ]]; then
  log_success "NixOS dependencies already present"
  return 0
fi

echo ""
log_info "Will install Nix profile packages:"
for target in "${targets[@]}"; do
  echo "  - $target"
done
echo ""

if $ask; then
  if ! tui_confirm "Install these packages to your user profile now?"; then
    log_warning "Skipped Nix dependency install"
    return 0
  fi
fi

if nix profile add --extra-experimental-features "nix-command flakes" "${targets[@]}"; then
  log_success "NixOS dependency installation complete"
  log_info "Restart your shell or run: exec $SHELL -l"
else
  log_warning "Some dependencies failed to install via nix profile"
  log_info "You can retry manually:"
  echo "  nix profile install --extra-experimental-features \"nix-command flakes\" ${targets[*]}"
fi

# NixOS users should still prefer declarative config for persistence.
echo ""
log_info "Tip: For a reproducible setup, add the same packages to Home Manager or configuration.nix."
