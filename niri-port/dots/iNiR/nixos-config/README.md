# NixOS system modules (`configuration.nix` here)

**Flake entrypoint (single, repo root):** `nixos-config-end4/flake.nix` defines **`nixosConfigurations.nixos`**, optional **`homeConfigurations.akashbiswas`**, and re-exports iNiR packages. This directory **only** holds NixOS modules; it no longer has its own `flake.nix`.

`configuration.nix` receives **`inirFlake`** from the root flake so `programs.inir` can import the iNiR NixOS module (`niri-port/dots/iNiR`).

| Path | Role |
|------|------|
| **`…/nixos-config-end4/flake.nix`** (repository root) | **Only** NixOS/Home-Manager entry for this repo. |
| `…/iNiR/inir-outputs.nix` | iNiR packages and NixOS/HM modules; `import`ed from the **repo root** `flake.nix` and exposed as **`lib.inir`**. There is no separate iNiR `flake.nix` in this tree. |

What breaks is expecting **`nixos-rebuild`** to update **`~/.config/niri/config.kdl`**: it only updates the **system** (e.g. `dell-g-controller-launch` in `/run/current-system/sw/bin`). Niri keybinds live in **`$HOME`**.

**After changing the template** `iNiR/dots/.config/niri/config.kdl`, sync into your session:

```bash
./scripts/sync-niri-config-kdl.sh
```

(Or copy that file to `~/.config/niri/config.kdl` and run `niri msg action load-config-file`.)

If you use **Home Manager** (or Nix) to install `~/.config/niri/config.kdl` as a **symlink into `/nix/store`**, a plain `cp` onto that path fails with **read-only file system**. The script **removes the symlink** and writes a real file in `$HOME` (after backup). If you need the file to stay declarative, instead add the same KDL to **`home.file` / `xdg.configFile."niri/config.kdl"`** in your HM config and **do not** use the script, or use `mkOutOfStoreSymlink` to this repo.

Check the unified flake (repo root):

```bash
nix flake show /path/to/nixos-config-end4
# expect: nixosConfigurations.nixos, homeConfigurations.akashbiswas, …
```

Point `/etc/nixos` at the **repository root** (see below), not this subdirectory.

## One-time: make it global

Link **`/etc/nixos` to the repository root** (where `flake.nix` lives), not to this folder.

```bash
sudo mv /etc/nixos /etc/nixos.bak-$(date +%Y%m%d)   # backup current
sudo ln -sfn /home/akashbiswas/Desktop/control/nixos-config-end4 /etc/nixos
```

(Adjust the path if your clone lives elsewhere.)

## Rebuild

```bash
sudo nixos-rebuild switch --flake /etc/nixos#nixos
```

If you are not using `/etc/nixos` yet, call the flake by path:

```bash
sudo nixos-rebuild switch --flake /path/to/nixos-config-end4#nixos
```

Hostname / attr is still **`nixos`** (`networking.hostName` in `configuration.nix`).

**Home Manager (optional):** `home-manager switch --flake /path/to/nixos-config-end4#akashbiswas`

**Cursor + Antigravity (optional, pure):** do **not** point Nix at `~/Download/...` — pure evaluation will fail. Put the same files in **`local/`** next to `configuration.nix`, with these names (or adjust the names in `configuration.nix`):

- `local/Cursor-3.2.11-x86_64.AppImage`
- `local/Antigravity.tar.gz`

Then add them to git so the flake can see them (binaries are large; this is expected):

```bash
cd /path/to/.../iNiR/nixos-config
cp ~/path/to/Cursor-3.2.11-x86_64.AppImage local/
cp ~/path/to/Antigravity.tar.gz local/
git add -f local/Cursor-3.2.11-x86_64.AppImage local/Antigravity.tar.gz
```

If the files are **absent**, the system is built without those two packages (you can still use VS Code / Chrome from `environment.systemPackages`).

**Legacy:** if you insist on only paths under `/home/...` and not `local/`, use `sudo nixos-rebuild switch --impure` (not recommended for flakes).

## Contents

- **`<repo>/flake.nix`** (four levels up from this directory to `nixos-config-end4/`) — unified **nixos** + optional **home** + devShells.
- `configuration.nix` — system + `programs.inir` + your packages.
- `hardware-configuration.nix` — disks / kernel modules from the installer (edit with care).

After changing **hardware**, run `sudo nixos-generate-config --no-filesystems --show-hardware-config` and merge updates if needed.

## Fans, sensors, GUI

- **CoolerControl** is enabled (`programs.coolercontrol`). After rebuild, run **`coolercontrol`** or open the **CoolerControl** app. The **`coolercontrold`** daemon is a system service: `systemctl status coolercontrold.service`.
- **`lm_sensors`** is on the system profile: `sensors`, `sudo sensors-detect`, `sudo pwmconfig`. The classic **`fancontrol` systemd unit** is **not** enabled until you set `hardware.fancontrol.enable = true` **and** fill `hardware.fancontrol.config` with the text `pwmconfig` prints (many laptops report *no pwm-capable sensors*).
- **Dell G** laptops: use **Dell G Series Controller** — **Mod+F9** in Niri (with `mod-key "Super"`, that is **Windows + F9**; do not duplicate `Super+F9` in the same `binds` block). Install the system launcher with **nixos-rebuild**, then **sync** `iNiR/dots/.config/niri/config.kdl` to `~/.config/niri/config.kdl` (see `scripts/sync-niri-config-kdl.sh`). CoolerControl / `fancontrol` may not see your fans.
- **`coretemp`** is in `boot.kernelModules` for Intel CPU temperature in `sensors`.

## Layout (Dell G controller + iNiR)

`configuration.nix` expects **`Dell-G-Series-Controller/`** next to **`niri-port/`** (siblings under the same parent directory). NixOS then installs `dell-g-controller-launch` in **`/run/current-system/sw/bin/`**. The **Mod+F9** keybind is **not** installed by nixos-rebuild — it is in the **git** `iNiR/dots/.config/niri/config.kdl`; use **`./scripts/sync-niri-config-kdl.sh`** (or copy manually) so **`~/.config/niri/config.kdl`** matches. If you split the tree, adjust `dellControllerRoot` in `configuration.nix` to point at the controller directory.

## After rebuild (Dell G15 + iNiR)

1. `sudo nixos-rebuild switch` from a **normal** terminal (not IDE-embedded) if `sudo` fails with “no new privileges.”
2. `sudo modprobe acpi_call` once per boot, or ensure `dellGSeries` / `boot.kernelModules` in `programs.inir` (already on when enabled).
3. `systemctl --user status polkit-gnome-authentication-agent-1` should be **active** (iNiR `enablePolkit`).
4. Sync Niri KDL (keybinds): **`./scripts/sync-niri-config-kdl.sh`** (or hand-copy `iNiR/dots/.config/niri/config.kdl` → `~/.config/niri/config.kdl`), then **`niri msg action load-config-file`** if the script is not in a Niri session.
5. Open **Foot/Kitty** on Niri, run `/run/current-system/sw/bin/dell-g-controller-launch` or press **Mod+F9** (Windows + F9), and **accept** the polkit prompt.
