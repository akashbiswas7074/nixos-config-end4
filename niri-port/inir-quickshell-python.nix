# Python environment for iNiR / Quickshell (replaces `uv pip install -r sdata/uv/requirements.txt`).
# Exposes a venv-like layout: $out/bin/python3, $out/bin/activate, $out/lib/...
{ symlinkJoin, python313 }:

let
  pyEnv = python313.withPackages (ps: with ps; [
    pillow
    numpy
    psutil
    tqdm
    loguru
    click
    pygobject3
    pycairo
    websockets
    opencv4
    kde-material-you-colors
    materialyoucolor
    material-color-utilities
  ]);
in
symlinkJoin {
  name = "inir-quickshell-python";
  paths = [ pyEnv ];
  postBuild = ''
    cat > $out/bin/activate <<'EOF'
    # Nix-managed env (PEP-405–style layout for iNiR scripts that `source …/bin/activate`)
    if [ -n "''${BASH_SOURCE-}" ]; then
      _inir_venv="$(cd "$(dirname "''${BASH_SOURCE[0]}")/.." && pwd)"
    else
      _inir_venv="$(cd "$(dirname "$0")/.." && pwd)"
    fi
    export VIRTUAL_ENV="$_inir_venv"
    export PATH="$_inir_venv/bin:$PATH"
    unset PYTHONHOME
    EOF
    chmod +x $out/bin/activate
  '';

  meta.description = "iNiR Quickshell Python dependencies (matches sdata/uv/requirements.txt via nixpkgs)";
}
