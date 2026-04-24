# nixos-config-end4

Single **Nix flake** at the **repository root** for **NixOS** (hostname `nixos`), optional **Home Manager**, **iNiR** (Niri + Quickshell), and a **Dell G Series Controller** integration. The iNiR package and modules live in `niri-port/dots/iNiR/inir-outputs.nix` (imported by `flake.nix`); there is no second `flake.nix` under iNiR.

**GitHub:** [akashbiswas7074/nixos-config-end4](https://github.com/akashbiswas7074/nixos-config-end4)

---

## Clone

```bash
git clone https://github.com/akashbiswas7074/nixos-config-end4.git
cd nixos-config-end4
```

Use the path to your clone everywhere below instead of `/path/to/nixos-config-end4` if it differs.

---

## One-time: point `/etc/nixos` at this repo (recommended)

Nix must see a **git-tracked** `flake.nix` at the path you pass to `nixos-rebuild --flake`. Link the **repo root** (not `.../iNiR/nixos-config` only):

```bash
sudo mv /etc/nixos /etc/nixos.bak-"$(date +%Y%m%d)"   # optional backup
sudo ln -sfn /path/to/nixos-config-end4 /etc/nixos
```

---

## Flake inspection

```bash
cd /path/to/nixos-config-end4
nix flake show
nix flake check
nix flake lock          # update flake.lock from flake.nix inputs
nix flake update        # refresh inputs to latest within constraints
```

---

## NixOS rebuild

**With `/etc/nixos` linked:**

```bash
sudo nixos-rebuild switch --flake /etc/nixos#nixos
```

**By path (no `/etc/nixos` link):**

```bash
sudo nixos-rebuild switch --flake /path/to/nixos-config-end4#nixos
```

**Build without switching (test evaluation):**

```bash
nixos-rebuild build --flake /path/to/nixos-config-end4#nixos
```

**Impure (only if you have a good reason, e.g. local paths outside the flake):**

```bash
sudo nixos-rebuild switch --flake /path/to/nixos-config-end4#nixos --impure
```

The system configuration is `flake.nix` → `niri-port/dots/iNiR/nixos-config/configuration.nix` (plus `hardware-configuration.nix` there).

---

## Home Manager (optional)

The flake defines `homeConfigurations.akashbiswas` (username and home path are set in `flake.nix` — change them for your user if you fork).

```bash
home-manager switch --flake /path/to/nixos-config-end4#akashbiswas
```

If you are not that user, duplicate the block in `flake.nix` and add a new `homeConfigurations.*` name.

---

## Development shell (repo)

```bash
cd /path/to/nixos-config-end4
nix develop
# or: nix develop /path/to/nixos-config-end4
```

Brings in `home-manager` and the iNiR Quickshell Python env (see `devShells` in `flake.nix`).

**Build a package from the flake (example):**

```bash
nix build /path/to/nixos-config-end4#packages.x86_64-linux.default
nix build /path/to/nixos-config-end4#packages.x86_64-linux.inir-quickshell-python
```

---

## Niri: sync `config.kdl` (keybinds, Mod+F9, etc.)

`nixos-rebuild` does **not** update `~/.config/niri/config.kdl`. After editing the template in the repo, sync and reload:

```bash
cd /path/to/nixos-config-end4/niri-port/dots/iNiR/nixos-config
./scripts/sync-niri-config-kdl.sh
```

Or copy `niri-port/dots/iNiR/dots/.config/niri/config.kdl` to `~/.config/niri/config.kdl` and run:

```bash
niri validate
niri msg action load-config-file
```

---

## Dell G Series Controller (optional)

- **NixOS:** `dell-g-controller-launch` is provided by this config (see `configuration.nix`). After rebuild it should be on `PATH` as `/run/current-system/sw/bin/dell-g-controller-launch` when you use the system profile.
- **From the app directory** (dev / non-system): see `Dell-G-Series-Controller/README.md`:

```bash
cd /path/to/nixos-config-end4/Dell-G-Series-Controller
./run-nixos.sh check
./run-nixos.sh doctor
./run-nixos.sh run
```

---

## `lib.inir` (advanced)

If you import `configuration.nix` without `specialArgs` from the **root** flake, it falls back to:

`builtins.getFlake` on the **repo root** and uses `lib.inir` (same iNiR packages and NixOS/Home Manager modules as in `flake.nix`).

---

## Machine-specific files

- **`niri-port/dots/iNiR/nixos-config/hardware-configuration.nix`**: from the installer; edit with care. Regenerate pieces with:  
  `sudo nixos-generate-config --no-filesystems --show-hardware-config`
- **`local/`** under `nixos-config/`: optional AppImage/tarball for Cursor/Antigravity (see `configuration.nix` and the detailed notes in `niri-port/dots/iNiR/nixos-config/README.md`).

---

## Layout (short)

| Path | Role |
|------|------|
| `flake.nix` / `flake.lock` | **Only** flake entry — NixOS, HM, `packages`, `devShells`, `lib` + `inir` |
| `niri-port/dots/iNiR/inir-outputs.nix` | iNiR packages and NixOS / HM modules (no separate flake) |
| `niri-port/dots/iNiR/nixos-config/configuration.nix` | Your NixOS system config |
| `Dell-G-Series-Controller/` | PySide6 Dell controller; layout expects it **next to** `niri-port/` (see that README + `configuration.nix`) |

More detail: `niri-port/dots/iNiR/nixos-config/README.md` (fans, sensors, CoolerControl, polkit, Dell G, etc.).

---

## License

See per-component files (e.g. `Dell-G-Series-Controller` is GPL-3, iNiR is MIT, etc.).
