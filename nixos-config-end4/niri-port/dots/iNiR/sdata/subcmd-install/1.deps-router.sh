# Dependency installation router for iNiR
# This script is meant to be sourced.

# shellcheck shell=bash

printf "${STY_CYAN}[$0]: 1. Install dependencies${STY_RST}\n"

#####################################################################################
# Route to the appropriate installer based on OS
#####################################################################################

case "$OS_GROUP_ID" in
  arch)
    printf "${STY_GREEN}Using Arch Linux installer${STY_RST}\n"
    source ./sdata/dist-arch/install-deps.sh
    ;;
    
  fedora)
    printf "${STY_GREEN}Using Fedora installer${STY_RST}\n"
    source ./sdata/dist-fedora/install-deps.sh
    ;;
    
  debian|ubuntu)
    printf "${STY_GREEN}Using Debian/Ubuntu installer${STY_RST}\n"
    source ./sdata/dist-debian/install-deps.sh
    ;;
    
  opensuse)
    printf "${STY_YELLOW}openSUSE support is experimental${STY_RST}\n"
    printf "${STY_YELLOW}Using generic installer with guidance${STY_RST}\n"
    source ./sdata/dist-generic/install-deps.sh
    ;;
    
  void)
    printf "${STY_YELLOW}Void Linux support is experimental${STY_RST}\n"
    printf "${STY_YELLOW}Using generic installer with guidance${STY_RST}\n"
    source ./sdata/dist-generic/install-deps.sh
    ;;
    
  gentoo)
    printf "${STY_YELLOW}Gentoo support requires manual configuration${STY_RST}\n"
    printf "${STY_YELLOW}Using generic installer with guidance${STY_RST}\n"
    source ./sdata/dist-generic/install-deps.sh
    ;;
    
  nixos)
    printf "${STY_GREEN}Using NixOS installer${STY_RST}\n"
    source ./sdata/dist-nixos/install-deps.sh
    ;;
    
  alpine)
    printf "${STY_YELLOW}Alpine Linux support is experimental${STY_RST}\n"
    printf "${STY_YELLOW}Using generic installer with guidance${STY_RST}\n"
    source ./sdata/dist-generic/install-deps.sh
    ;;
    
  generic|*)
    printf "${STY_YELLOW}Using generic installer${STY_RST}\n"
    source ./sdata/dist-generic/install-deps.sh
    ;;
esac
