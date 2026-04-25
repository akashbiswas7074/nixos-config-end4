#!/usr/bin/env python3
"""
Sync live NixOS/iNiR config files into this repository.

Default behavior copies common live files:
- ~/.config/niri/**                -> defaults/niri/**
- ~/.config/systemd/user/inir.service -> assets/systemd/inir.service
- ~/.local/bin/inir               -> scripts/inir
- ~/.config/foot/foot.ini         -> dots/.config/foot/foot.ini
- ~/.config/kitty/kitty.conf      -> dots/.config/kitty/kitty.conf
"""

from __future__ import annotations

import argparse
import os
import pwd
import shutil
import sys
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class SyncTask:
    name: str
    src: Path
    dst: Path
    is_dir: bool
    may_need_sudo: bool = False


def _repo_root() -> Path:
    return Path(__file__).resolve().parents[1]


def _invoking_user_home() -> Path:
    sudo_user = os.environ.get("SUDO_USER")
    if sudo_user:
        try:
            return Path(pwd.getpwnam(sudo_user).pw_dir)
        except KeyError:
            pass
    return Path.home()


def _default_tasks(repo_root: Path) -> list[SyncTask]:
    home = _invoking_user_home()
    return [
        SyncTask(
            name="niri-config",
            src=home / ".config" / "niri",
            dst=repo_root / "defaults" / "niri",
            is_dir=True,
        ),
        SyncTask(
            name="inir-service",
            src=home / ".config" / "systemd" / "user" / "inir.service",
            dst=repo_root / "assets" / "systemd" / "inir.service",
            is_dir=False,
        ),
        SyncTask(
            name="inir-launcher",
            src=home / ".local" / "bin" / "inir",
            dst=repo_root / "scripts" / "inir",
            is_dir=False,
        ),
        SyncTask(
            name="foot-config",
            src=home / ".config" / "foot" / "foot.ini",
            dst=repo_root / "dots" / ".config" / "foot" / "foot.ini",
            is_dir=False,
        ),
        SyncTask(
            name="kitty-config",
            src=home / ".config" / "kitty" / "kitty.conf",
            dst=repo_root / "dots" / ".config" / "kitty" / "kitty.conf",
            is_dir=False,
        ),
        SyncTask(
            name="system-nixos",
            src=Path("/etc/nixos"),
            dst=repo_root / "nixos-config",
            is_dir=True,
            may_need_sudo=True,
        ),
    ]


def _copy_file(src: Path, dst: Path, dry_run: bool) -> None:
    if dry_run:
        return
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)


def _copy_dir(src: Path, dst: Path, dry_run: bool) -> None:
    if dry_run:
        return
    dst.mkdir(parents=True, exist_ok=True)

    # Remove files in destination that do not exist in source to keep parity.
    dst_entries = {p.relative_to(dst) for p in dst.rglob("*")}
    src_entries = {p.relative_to(src) for p in src.rglob("*")}
    stale_entries = sorted(dst_entries - src_entries, reverse=True)
    for rel in stale_entries:
        stale = dst / rel
        if stale.is_file() or stale.is_symlink():
            stale.unlink(missing_ok=True)
        elif stale.is_dir():
            stale.rmdir()

    for item in src.rglob("*"):
        rel = item.relative_to(src)
        target = dst / rel
        if item.is_dir():
            target.mkdir(parents=True, exist_ok=True)
        elif item.is_file():
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(item, target)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Copy live NixOS/iNiR config files into this repo."
    )
    parser.add_argument(
        "--only",
        nargs="+",
        choices=[
            "niri-config",
            "inir-service",
            "inir-launcher",
            "foot-config",
            "kitty-config",
            "system-nixos",
        ],
        help="Sync only specific targets.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print planned actions without writing files.",
    )
    args = parser.parse_args()

    repo_root = _repo_root()
    tasks = _default_tasks(repo_root)
    if args.only:
        requested = set(args.only)
        tasks = [task for task in tasks if task.name in requested]

    copied = 0
    skipped = 0
    for task in tasks:
        if not task.src.exists():
            print(f"[skip] {task.name}: source not found -> {task.src}")
            skipped += 1
            continue

        if task.may_need_sudo and os.geteuid() != 0:
            print(f"[skip] {task.name}: may need sudo to read some files in {task.src}")
            print(
                "       Run with sudo to include this task, for example:\n"
                f"       sudo -E {sys.executable} {Path(__file__).resolve()}"
            )
            skipped += 1
            continue

        print(f"[sync] {task.name}")
        print(f"       {task.src} -> {task.dst}")
        if task.is_dir:
            _copy_dir(task.src, task.dst, args.dry_run)
        else:
            _copy_file(task.src, task.dst, args.dry_run)
        copied += 1

    if args.dry_run:
        print(f"\nDry run complete: {copied} target(s) would be synced, {skipped} skipped.")
    else:
        print(f"\nDone: {copied} target(s) synced, {skipped} skipped.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
