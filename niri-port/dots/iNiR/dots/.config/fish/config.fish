if status is-interactive
    # No greeting
    set fish_greeting

    # Use starship prompt
    if command -v starship &>/dev/null
        starship init fish | source
    end

    # Apply terminal color sequences (Material You from wallpaper)
    if test -f ~/.local/state/quickshell/user/generated/terminal/sequences.txt
        cat ~/.local/state/quickshell/user/generated/terminal/sequences.txt
    end

    # Aliases
    alias clear "printf '\033[2J\033[3J\033[1;1H'" # fix: kitty doesn't clear scrollback properly
    alias celar "printf '\033[2J\033[3J\033[1;1H'"
    alias claer "printf '\033[2J\033[3J\033[1;1H'"
    if command -v eza &>/dev/null
        alias ls 'eza --icons'
    end

    alias q 'qs -c ii'

    # >>> mamba initialize >>>
    # !! Contents within this block are managed by 'micromamba shell init' !!
    set -gx MAMBA_EXE "/nix/store/11105gqwz8ki86j3qspqhyykxddwyibq-micromamba-2.4.0/bin/micromamba"
    set -gx MAMBA_ROOT_PREFIX "/home/akashbiswas/micromamba"
    $MAMBA_EXE shell hook --shell fish --root-prefix $MAMBA_ROOT_PREFIX | source
    # <<< mamba initialize <<<
end
