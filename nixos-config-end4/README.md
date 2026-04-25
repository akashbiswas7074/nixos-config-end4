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

**Do not run `sudo nixos-rebuild` inside the Cursor (or VS Code) integrated terminal** on Linux. Those terminals often run with the kernel **“no new privileges”** flag set, so you get:

`sudo: The "no new privileges" flag is set, which prevents sudo from running as root.`

That is **not** a broken NixOS or a bad `sudo` path. **Fix:** run the same command in a normal terminal **outside** the editor — e.g. **Kitty**, **Foot**, **Alacritty**, **GNOME Terminal**, or a **virtual console** (**Ctrl+Alt+F3**, log in, run it there). `nix develop` and `nix build` (no `sudo`) are fine in Cursor; only **privileged** commands need a real TTY.

**With `/etc/nixos` linked:**

```bash
sudo nixos-rebuild switch --flake /etc/nixos#nixos
```

**By path (no `/etc/nixos` link):** replace the placeholder with the **absolute path to your clone** (it is not a real directory on disk):

```bash
# Example: replace with your clone, e.g. $HOME/Desktop/control/nixos-config-end4
sudo nixos-rebuild switch --flake /path/to/nixos-config-end4#nixos
```

Or `cd` into the repo (where `flake.nix` lives) and use `.` for the flake:

```bash
cd /path/to/nixos-config-end4
sudo nixos-rebuild switch --flake .#nixos
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

**`home-manager: command not found`:** this machine does not have the Home Manager CLI on your **login** `PATH` (that is normal until you install it or use a dev shell). From the repo root, use either:

```bash
cd /path/to/nixos-config-end4
nix run nixpkgs#home-manager -- switch --flake .#akashbiswas
```

or enter the default dev shell (it includes `home-manager`) and run the same `switch` there:

```bash
cd /path/to/nixos-config-end4
nix develop
home-manager switch --flake .#akashbiswas
```

If you are not that user, duplicate the block in `flake.nix` and add a new `homeConfigurations.*` name.

**“command not found” for `nix`, `home-manager`, user packages** — often **PATH**. Home Manager’s `~/.nix-profile` and system `sw` may be missing in **non-login** or **IDE** (e.g. Cursor) terminals. This flake sets **`home.sessionPath = [ "/run/wrappers/bin" ]`** for login sessions.

- **Check which shell you are in:** `echo $SHELL` and the prompt. **Cursor’s default is often `bash`**, not Fish — **do not** paste Fish-only APIs into bash (`fish_add_path` and Fish `set` syntax will error).

- **Bash / sh (e.g. Cursor):** run once, or add to `~/.bashrc`:

```bash
for d in /run/wrappers/bin "$HOME/.nix-profile/bin" /run/current-system/sw/bin "/etc/profiles/per-user/$USER/bin"; do
  [ -d "$d" ] && PATH="$d:$PATH"
done
export PATH
```

- **Fish only** — put at the start of the `if status is-interactive` block in **`~/.config/fish/config.fish`** (not in the terminal as bash):

```fish
    test -d /run/wrappers/bin && fish_add_path -m /run/wrappers/bin
    test -d $HOME/.nix-profile/bin && fish_add_path -m $HOME/.nix-profile/bin
    test -d /run/current-system/sw/bin && fish_add_path -m /run/current-system/sw/bin
    set -l _u (whoami)
    test -d /etc/profiles/per-user/$_u/bin && fish_add_path -m /etc/profiles/per-user/$_u/bin
```

Or in Cursor run **`fish`** once to get a Fish shell, then the Fish block applies if it is already in your `config.fish`.

Use **Kitty/Foot** (or a real TTY) for `sudo` / `nixos-rebuild` if the editor terminal shows **“no new privileges”**; PATH fixes do not remove that restriction.

---

## Development shell (repo)

```bash
cd /path/to/nixos-config-end4
nix develop
# or: nix develop /path/to/nixos-config-end4
```

Brings in `home-manager` and the iNiR Quickshell Python env (see `devShells` in `flake.nix`).

**Conda-style envs (Micromamba):** the full Anaconda installer is not what you want on NixOS; this repo uses **`micromamba`** from nixpkgs (conda-compatible, works with conda-forge). It is on **Home Manager** `home.packages` for `akashbiswas` *after* you run `home-manager switch` with this flake. There is also a **dev shell** you can use without Home Manager:

Replace **`/path/to/nixos-config-end4`** everywhere in this file with the real path to the repo (the directory that contains `flake.nix`), or use **`.`** after `cd` into that directory:

```bash
cd /path/to/nixos-config-end4    # e.g. ~/Desktop/control/nixos-config-end4
nix develop .#conda
```

`nix develop` needs a path to a flake, not a bare `#conda`. Wrong: `nix develop #conda` — that looks for a flake in the current directory, which only works if your shell’s cwd is the repo **root** (the folder with `flake.nix`). If you are under `.../iNiR/nixos-config`, go up to the root or pass it explicitly, e.g. `nix develop ~/Desktop/control/nixos-config-end4#conda`.

First-time setup (inside the dev shell):

```bash
export MAMBA_ROOT_PREFIX="$HOME/micromamba"   # devShell sets this by default
micromamba create -y -n py -c conda-forge python=3.12
micromamba activate py
# optional: eval "$(micromamba shell hook --shell fish)"  # for fish
```

**`micromamba: command not found`:** run `home-manager switch --flake <repo>#akashbiswas` first, *or* use `nix develop <repo-root>#conda` (micromamba is in that shell even if it is not on your normal `PATH` yet).

**Brightness / game mode / night light do not run inside `nix develop`:** those are **iNiR + Niri + Quickshell** features. The `conda` dev shell only adds **micromamba**, **inir**, **brightnessctl**, and **wlsunset** for quick tests; the real OSD, gamemode toggles, and night schedule need your normal graphical session with `inir` / quickshell. After `sudo nixos-rebuild switch`, this config adds your user to the **`video`** and **`i2c`** groups so `brightnessctl` and `ddcutil` can work — **log out and back in** (or reboot) for group membership to apply.

**`sudo: … must be owned by uid 0` (e.g. in Kitty or Fish):** the **setuid** `sudo` is **`/run/wrappers/bin/sudo`**. The file **`/run/current-system/sw/bin/sudo`** is a **non-setuid** symlink into the Nix store; if it appears **earlier** in `PATH` than `/run/wrappers/bin`, every terminal (including Kitty) will break `sudo`. This repo’s **Home Manager** config sets **`home.sessionPath = [ "/run/wrappers/bin" ]`** so login sessions get the right order — run **`home-manager switch`** to apply, then open a **new** Kitty window. **Until then**, run once in Fish: `fish_add_path -m /run/wrappers/bin` or one-off: `/run/wrappers/bin/sudo nixos-rebuild ...`. The `nix develop` shells in `flake.nix` also prepend `/run/wrappers/bin`.

**`sudo: The "no new privileges" flag is set`:** the **Cursor / VS Code** integrated terminal (see the note at **NixOS rebuild** above). Use **Kitty, Foot,** or **Ctrl+Alt+F3** — **no** flake or `sudo` path change fixes this inside that terminal.

**“Quickshell has crashed” (iNiR) — that is not a `sudo` error.** The dialog is from **Quickshell** (the UI engine iNiR uses). Fixes for **`sudo`** are the paragraphs above (wrappers on `PATH`, no new privileges, etc.) and do **not** live in the Quickshell crash window.

**Stability (Qt / GPU):** this repo sets **`QSG_RENDER_LOOP=basic`**, **`QSG_RHI_BACKEND=gl`**, and **`__GL_THREADED_OPTIMIZATIONS=0`** in `iNiR/shell.qml` and the Nix **`inir` wrapper** (threaded render and some Vulkan paths can crash on **NVIDIA + Wayland**). After `nixos-rebuild`, if you still have an old `~/.config/quickshell/inir/shell.qml` (iNiR prefers it over the Nix store), **refresh that file** so the new pragmas apply, e.g. from a working shell:

```bash
# Use the system inir from the NixOS profile — it lives next to share/quickshell/inir/.
# If you have ~/.local/bin/inir, `command -v inir` may point there and break this path.
inir_bin="/run/current-system/sw/bin/inir"
[[ -x "$inir_bin" ]] || inir_bin="$(readlink -f "$(command -v inir)")"
inir_path="$(readlink -f "$inir_bin")"
cp -f "$(dirname "$inir_path")/../share/quickshell/inir/shell.qml" \
  "${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/inir/shell.qml"
inir restart
```

If the copy still fails, your `~/.local/bin/inir` may be a stub without that layout: temporarily use **only** the system binary: `PATH="/run/current-system/sw/bin:$PATH" inir restart`, or remove/rename the `~/.local/bin/inir` launcher and rely on `/run/current-system/sw/bin` from this flake’s `programs.inir`.

**`~/.local/bin/inir` and `inir.service`:** an upstream iNiR script in `~/.local/bin` expects `~/.local/share/quickshell/inir/` (FHS layout). On NixOS the real payload is under the **Nix-wrapped** `inir` at `/run/current-system/sw/bin/inir`, which also sets `INIR_SYSTEM_RUNTIME_DIR` and the Qt env above. If you ever ran `inir service install` with `~/.local/bin` **first** in `PATH`, `~/.config/systemd/user/inir.service` may point at the **wrong** `inir` and you can get missing-path errors. Fix: edit the unit (or reinstall with a clean `PATH`):

`ExecStart=` and `ExecStopPost=` should use `/run/current-system/sw/bin/inir` (or run `PATH="/run/current-system/sw/bin:$PATH" inir service install` after renaming `~/.local/bin/inir`), then `systemctl --user daemon-reload` and `systemctl --user restart inir.service`.

If it still crashes, for a one-off test you can try software GL (slow, but helps narrow driver issues): `LIBGL_ALWAYS_SOFTWARE=1 inir run` in **Foot/Kitty**, then use the dialog’s **Open report page** for upstream: [Quickshell crash](https://github.com/quickshell-mirror/quickshell/issues/new?template=crash.yml), and check `~/.cache/quickshell/crashes/*/info.txt`. For more logs: `inir run` in **Foot/Kitty** and watch **stderr**; `journalctl --user -b` for related lines.

**Still seeing `SIGSEGV` in `quickshell` under `inir.service`:** that usually means a **Quickshell/Qt bug or a GPU/driver interaction**, not a bad `shell.qml` path, even when `QSG_*` is set correctly.

**Diagnostics drop-in (software GL + coredumps):** a ready-made fragment is in the tree at `niri-port/dots/iNiR/assets/systemd/inir.service.d/50-quickshell-diagnostics.conf` — it sets `Environment=LIBGL_ALWAYS_SOFTWARE=1` (uses LLVMpipe; **much slower** — good for “does it still crash off the NVIDIA GL path?”) and `LimitCORE=infinity` so `coredumpctl` and crash reports can include stacks (files under `/var/lib/systemd/coredump/` can be large). **Install** by copying to `~/.config/systemd/user/inir.service.d/50-quickshell-diagnostics.conf`, then `systemctl --user daemon-reload && systemctl --user restart inir.service`. **Remove** the file and the same two commands to go back to GPU rendering and the original `LimitCORE=0` from the main `inir.service`. If **software** is stable but **hardware** is not, say so in the [Quickshell crash](https://github.com/quickshell-mirror/quickshell/issues/new?template=crash.yml) report. One-off without systemd: `systemctl --user stop inir.service` and `LIBGL_ALWAYS_SOFTWARE=1 /run/current-system/sw/bin/inir run` in **Foot/Kitty**.

**Do not** keep a second `inir` at `~/.local/bin/inir` (upstream launcher) if you use the NixOS one — it breaks `.../share/quickshell/...` paths. Rename it (e.g. to `~/.local/bin/inir.upstream-bak`) so `PATH` resolves to `/run/current-system/sw/bin/inir`, and re-run `PATH=…/sw/bin:$PATH inir service install` if the unit had pointed at the wrong binary.

**Do not install a second `quickshell` via Home Manager** if this flake’s `programs.inir` is enabled: the iNiR `inir` package already pulls in the matching `quickshell` for its wrapper. A duplicate `qs` in `~/.nix-profile` can link a **different Qt** than the system `inir` (e.g. 6.10 vs 6.11) and cause **SIGSEGV**. This repo’s iNiR HM module no longer adds `pkgs.quickshell`; after `home-manager switch`, `readlink -f "$(command -v qs)"` should follow the `inir` closure or be absent — use `inir run` / `inir restart`, not a bare `qs` from an old profile.

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

**Screenshots / region tools (Mod+Shift+S) “do nothing”:** iNiR uses **`grim`**, **`slurp`**, and often **`swappy`** (in NixOS they are pulled in by **`programs.inir`** / this flake). If those fail, check **`inir region screenshot`** in a normal terminal (Foot/Kitty) for errors.

**Keybinds still pointing at `~/.local/bin/inir`:** if you removed the upstream launcher, Niri must call the **NixOS** binary: **`/run/current-system/sw/bin/inir`**, or rely on **`spawn "inir" ...`** after the `environment { PATH ... }` block in `config.kdl` adds `/run/current-system/sw/bin`. Old modular files under **`~/.config/niri/config.d/70-binds.kdl`** may still list `.local/bin/inir` — those spawns **fail silently**. The repo’s `defaults/niri/config.d/70-binds.kdl` now uses the system path. Also fix **`$HOME/.config/inir/scripts/`** → **`$HOME/.config/quickshell/inir/scripts/`** for `launch-terminal.sh` (Nix layout).

**Print / native Niri screenshots** use Niri’s built-in `screenshot` action and **`screenshot-path`** in `config.kdl`; they do not go through `inir`.

**Controls panel: color picker / eyedropper** — upstream iNiR used **`hyprpicker`**, which is aimed at **Hyprland** and was not on Quickshell’s `PATH` reliably. On **Niri**, the shell now uses **`niri msg action pick-color`** (and the `inir` Nix wrapper’s `PATH` includes the **`niri`** binary). Rebuild, sync `shell.qml` if you track the repo, then `inir restart` / relog. **Sliders and Wi‑Fi/Bluetooth** use separate services (PipeWire, UPower, NetworkManager, etc.); if only those fail, it is not the region/color scripts.

**“Nothing works” in the shell (sliders, mic, vol, no `id` / `pgrep` / `wpctl`):** if **`~/.config/niri/config.kdl`** used `PATH "$PATH:…"` in the `environment` block, **`$PATH` can be empty** when Niri starts, so **`journalctl --user-unit=inir.service`** shows *binary could not be found* for `id`, `pgrep`, `wpctl`. Fix: put **wrappers + system `sw` first** and **drop the leading `"$PATH:"`**, e.g. `PATH "/run/wrappers/bin:/run/current-system/sw/bin:$HOME/.nix-profile/bin:/etc/profiles/per-user/$USER/bin"`, then `niri msg action load-config-file` and **`systemctl --user restart inir.service`**. Optional: a systemd drop-in `inir.service.d/60-nixos-path.conf` with `Environment=PATH=/run/wrappers/bin:/run/current-system/sw/bin:…` (see `niri-port/dots/iNiR/assets/systemd/inir.service.d/60-nixos-path.conf.example`).

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
