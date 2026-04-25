# NixOS dependency installer for iNiR
# This script is meant to be sourced.
#
# shellcheck shell=bash

if ! command -v nix &>/dev/null; then
  log_error "nix command not found. This installer is for NixOS only."
  return 1
fi

tui_info "Installing NixOS dependencies for iNiR..."

# Walk up from REPO_ROOT to find a flake.nix (e.g. unified nixos-config monorepo). The
# iNiR tree itself has no flake; `.#awww-compat` would otherwise always fail.
inir_find_parent_nix_flake() {
  local d cur
  cur="${REPO_ROOT:-$(pwd)}"
  d="$(cd -- "$cur" && pwd)" || return 1
  local i
  for ((i=0; i<10; i++)); do
    if [[ -f "$d/flake.nix" ]]; then
      echo "$d"
      return 0
    fi
    d="$(cd -- "$d/.." && pwd)" || return 1
  done
  return 1
}

# Map command names (used by doctor/setup) to installable Nix flake attrs.
# NOTE: `awww` / `awww-daemon` come from the monorepo's `packages.<system>.awww-compat` when
# a parent flake exists; otherwise skip (use NixOS inir module or install swww yourself).
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
  [gum]="nixpkgs#gum"
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
  [satty]="nixpkgs#satty"
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

_flake_parent="$(inir_find_parent_nix_flake 2>/dev/null || true)"
if [[ -n "$_flake_parent" ]]; then
  _fsys="x86_64-linux"
  case "$(uname -m 2>/dev/null)" in
    aarch64|arm64) _fsys="aarch64-linux" ;;
  esac
  nix_attr_for_cmd[awww]="path:$_flake_parent#packages.$_fsys.awww-compat"
  nix_attr_for_cmd[awww-daemon]="path:$_flake_parent#packages.$_fsys.awww-compat"
else
  nix_attr_for_cmd[awww]=""
  nix_attr_for_cmd[awww-daemon]=""
fi

# Optional Qt/KDE QML support for *impure* nix profile installs (no inir NixOS package).
# These overlap files (e.g. metatypes/*.json) with `home-manager-path` — `nix profile add`
# then fails the whole batch. Home Manager + programs.inir already bring Qt/Quickshell.
runtime_extra_targets=(
  "nixpkgs#qt6.qt5compat"
  "nixpkgs#qt6.qtmultimedia"
  "nixpkgs#kdePackages.kirigami.unwrapped"
)

inir_nix_profile_includes_home_manager() {
  nix profile list 2>/dev/null | grep -q 'home-manager-path'
}

required_cmds=(
  qs niri nmcli wpctl jq rsync curl git python3 fish magick grim cliphist
  wl-copy wl-paste fuzzel awww awww-daemon hyprpicker playerctl notify-send
  flock go cc pkg-config meson ninja dbus-daemon bluetoothctl blueman-manager
)

optional_cmds=(
  gum uv starship eza slurp wf-recorder ffmpeg swappy satty tesseract qalc brightnessctl
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
    if [[ "$cmd" == "awww" || "$cmd" == "awww-daemon" ]]; then
      if ! command -v awww &>/dev/null; then
        log_info "Skipping nix profile for '$cmd' (no parent flake with awww-compat). Use the iNiR NixOS/Home-Manager module, or run setup from a monorepo that includes flake.nix with packages.<system>.awww-compat."
      fi
    else
      log_warning "No Nix mapping for command '$cmd' (skipping)"
    fi
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

if inir_nix_profile_includes_home_manager; then
  log_info "Skipping nix profile Qt/KDE extras (they conflict with home-manager-path; Qt/Quickshell is already provided via Home Manager + programs.inir or nixos-rebuild)."
else
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
fi

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
