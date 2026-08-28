#!/usr/bin/env bash
set -euo pipefail
export PATH="/run/wrappers/bin:$PATH"
unset LD_LIBRARY_PATH

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "--- Applying NixOS Configuration (System) ---"
sudo ./result/bin/switch-to-configuration switch

echo ""
echo "--- Applying Home Manager Configuration (User) ---"
# We check if home-manager is in the path; if not, we use nix run to run it
if command -v home-manager >/dev/null 2>&1; then
    home-manager switch --flake "$SCRIPT_DIR#akashbiswas" --impure
else
    echo "home-manager not found in PATH, using nix run..."
    nix run github:nix-community/home-manager -- switch --flake "$SCRIPT_DIR#akashbiswas" --impure
fi

echo ""
echo "Done! All configurations (System + User) have been applied."
