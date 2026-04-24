#!/usr/bin/env bash
set -euo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
REPO_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
SHELL_NIX="$REPO_DIR/shell.nix"
MODE="${1:-run}"

# So pkexec / polkit GUI works when the parent strips the environment (e.g. IDE terminal).
: "${XDG_RUNTIME_DIR:=/run/user/$(id -u)}"
export XDG_RUNTIME_DIR
if [[ -z "${DBUS_SESSION_BUS_ADDRESS:-}" && -S "${XDG_RUNTIME_DIR}/bus" ]]; then
  export DBUS_SESSION_BUS_ADDRESS="unix:path=${XDG_RUNTIME_DIR}/bus"
fi

# Polkit must be running in this user session before pkexec can show a password window.
if command -v systemctl >/dev/null 2>&1; then
  if ! systemctl --user is-active --quiet polkit-gnome-authentication-agent-1 2>/dev/null; then
    systemctl --user start polkit-gnome-authentication-agent-1 2>/dev/null || true
  fi
  # Give the agent a moment to register with the bus (best-effort).
  sleep 0.3
fi

if [[ ! -f "$SHELL_NIX" ]]; then
  echo "Missing $SHELL_NIX" >&2
  exit 1
fi

# Prefer nix develop if flake exists next to shell.nix (optional future); otherwise classic nix-shell.
run_in_shell() {
  if command -v nix-shell &>/dev/null; then
    nix-shell "$SHELL_NIX" --run "$1"
  else
    echo "nix-shell not found" >&2
    exit 1
  fi
}

ok() { echo "  OK: $*"; }
warn() { echo "  !! $*" >&2; }
fail() { echo "  NO: $*" >&2; }

case "$MODE" in
  check)
    run_in_shell 'python3 -c "import PySide6, usb, pexpect; print(\"Dell controller runtime OK\")"'
    ;;
  doctor)
    echo "Dell G Series Controller — prerequisite check"
    echo ""
    echo "1) Nix PySide6 runtime"
    if run_in_shell 'python3 -c "import PySide6, usb, pexpect"'; then
      ok "python imports"
    else
      fail "import failed — run: $0 check"
    fi
    echo ""
    echo "2) acpi_call (power/fan ACPI path)"
    if [[ -e /proc/acpi/call ]]; then
      ok "/proc/acpi/call present"
    else
      fail "/proc/acpi/call missing — run: sudo modprobe acpi_call"
    fi
    if [[ -r /proc/modules ]] && grep -q '^acpi_call[[:space:]]' /proc/modules 2>/dev/null; then
      ok "acpi_call module loaded"
    else
      warn "acpi_call not in lsmod (optional if you only need keyboard RGB)"
    fi
    echo ""
    echo "3) Polkit (pkexec must show a password dialog on startup)"
    if [[ -x /run/wrappers/bin/pkexec ]]; then
      ok "pkexec at /run/wrappers/bin/pkexec"
    elif command -v pkexec >/dev/null 2>&1; then
      ok "pkexec: $(command -v pkexec)"
    else
      fail "pkexec not found"
    fi
    if pgrep -x polkitd >/dev/null 2>&1; then
      ok "polkitd running"
    else
      warn "polkitd not running — enable security.polkit on NixOS"
    fi
    if systemctl --user is-active --quiet polkit-gnome-authentication-agent-1 2>/dev/null; then
      ok "polkit-gnome user agent active"
    else
      warn "polkit-gnome agent not running — we try to start it in run; log in to a graphical session"
    fi
    echo ""
    echo "4) Privilege / sandbox (sudo/pkexec need a normal desktop terminal)"
    if [[ -r /proc/self/status ]]; then
      nnp=$(awk '/^NoNewPrivs:/ {print $2}' /proc/self/status 2>/dev/null || true)
      if [[ "$nnp" == "1" ]]; then
        warn "this shell has NoNewPrivs=1 — use Foot/Kitty, not a locked-down IDE terminal"
      elif [[ -n "$nnp" ]]; then
        ok "NoNewPrivs=$nnp"
      fi
    fi
    echo ""
    echo "5) USB keyboard LED (awelc), optional"
    if [[ -e /dev/awelc ]] || (command -v lsusb >/dev/null 2>&1 && lsusb -d 187c:0550 2>/dev/null | grep -q .); then
      ok "Dell/Alienware LED device looks present"
    else
      warn "187c:0550 not seen — iNiR udev (dellGSeries) or cable"
    fi
    echo ""
    echo "6) App log"
    ok "after run:  tail -50 /tmp/dell-g-series-controller.log"
    echo "Done."
    ;;
  debug-ldd)
    run_in_shell "python3 -c \"
import os, glob
from pathlib import Path
import PySide6
root = Path(PySide6.__file__).parent
cands = list(root.glob('Qt/plugins/platforms/libq*.so'))
print('plugins:', cands)
for so in cands[:1]:
    os.system('ldd ' + str(so) + ' | awk \\\"/not found/\\\"')
\""
    ;;
  run)
    run_in_shell "cd \"$REPO_DIR\" && python3 main.py"
    ;;
  *)
    echo "Usage: $0 [run|check|doctor|debug-ldd]" >&2
    exit 2
    ;;
esac
