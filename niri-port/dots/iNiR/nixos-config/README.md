# NixOS config (single source)

This directory is the **only** NixOS configuration you need. Point the global config here, then use the normal rebuild command.

## One-time: make it global

Pick the **absolute path** to this folder (the one that contains `flake.nix`).

```bash
sudo mv /etc/nixos /etc/nixos.bak-$(date +%Y%m%d)   # backup current
sudo ln -sfn /ABS/PATH/TO/nixos-config /etc/nixos
```

Example (adjust user name / repo layout):

```bash
sudo ln -sfn /home/akashbiswas/Desktop/control/nixos-config-end4/niri-port/dots/iNiR/nixos-config /etc/nixos
```

## Rebuild

With flakes (recommended — `flake.nix` is in this directory):

```bash
sudo nixos-rebuild switch
```

NixOS will use `/etc/nixos/flake.nix` and the **`nixos`** output (hostname in `configuration.nix` is `nixos`).

Explicit:

```bash
sudo nixos-rebuild switch --flake /etc/nixos#nixos
```

If evaluation errors about **forbidden absolute paths** (e.g. AppImages under `/home/...` in `configuration.nix`), rebuild with impure evaluation:

```bash
sudo nixos-rebuild switch --impure
```

## Contents

- `flake.nix` — entrypoint; pins **nixpkgs** and **iNiR** (`path:..`).
- `configuration.nix` — system + `programs.inir` + your packages.
- `hardware-configuration.nix` — disks / kernel modules from the installer (edit with care).

After changing **hardware**, run `sudo nixos-generate-config --no-filesystems --show-hardware-config` and merge updates if needed.
