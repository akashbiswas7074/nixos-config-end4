# Makefile for Niri Nix Dotfiles (iNiR)

.PHONY: all check switch install clean help

all: help

help:
	@echo "Usage:"
	@echo "  make check    - Check the flake syntax and inputs"
	@echo "  make switch   - Apply the Home Manager configuration"
	@echo "  make install  - Alias for 'make switch'"
	@echo "  make clean    - Remove result symlinks"

check:
	nix flake check --extra-experimental-features 'nix-command flakes'

switch:
	nix run --extra-experimental-features "nix-command flakes" nixpkgs#home-manager -- switch --flake .#akashbiswas

install: switch

clean:
	rm -f result
