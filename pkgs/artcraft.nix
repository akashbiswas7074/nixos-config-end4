{ pkgs }:

let
  mkArtCraftApp = { pname, version, url, hash }:
    let
      src = pkgs.fetchurl {
        inherit url hash;
      };
      appimageContents = pkgs.appimageTools.extract {
        inherit pname version src;
      };
    in
    pkgs.appimageTools.wrapType2 {
      inherit pname version src;

      extraInstallCommands = ''
        install -m 444 -D ${appimageContents}/ai.storyteller.${pname}.desktop $out/share/applications/${pname}.desktop
        install -m 444 -D ${appimageContents}/ai.storyteller.${pname}.png $out/share/icons/hicolor/512x512/apps/${pname}.png
        install -m 444 -D ${appimageContents}/ai.storyteller.${pname}.png $out/share/pixmaps/${pname}.png
        
        substituteInPlace $out/share/applications/${pname}.desktop \
          --replace-fail "Exec=${pname} %F" "Exec=$out/bin/${pname} %F" \
          --replace-fail "Icon=ai.storyteller.${pname}" "Icon=${pname}" || true
      '';
    };

  apps = {
    # Adobe Suite Alternatives (Crafting Apps)
    photocraft = mkArtCraftApp {
      pname = "photocraft";
      version = "0.10.0";
      url = "https://github.com/storytold/photocraft/releases/download/v0.10.0/photocraft-0.10.0-linux-x86_64.AppImage";
      hash = "sha256-zRozyXnopdqU3tgddkjnecuAabd+Ssp0PI0XfKUnDXc=";
    };

    vectorcraft = mkArtCraftApp {
      pname = "vectorcraft";
      version = "0.13.1";
      url = "https://github.com/storytold/vectorcraft/releases/download/v0.13.1/vectorcraft-0.13.1-linux-x86_64.AppImage";
      hash = "sha256-lUV7ubSLxjRBJMK/MqEGAGVIqllLG40djKR9UqMOV34=";
    };

    filmcraft = mkArtCraftApp {
      pname = "filmcraft";
      version = "0.9.0";
      url = "https://github.com/storytold/filmcraft/releases/download/v0.9.0/filmcraft-0.9.0-linux-x86_64.AppImage";
      hash = "sha256-eE5M29iYLxe07IHK9TZ/0wjXChI6eqdLzNdCAhTAxEc=";
    };

    lightcraft = mkArtCraftApp {
      pname = "lightcraft";
      version = "0.9.1";
      url = "https://github.com/storytold/lightcraft/releases/download/v0.9.1/lightcraft-0.9.1-linux-x86_64.AppImage";
      hash = "sha256-vQAoUalSQ0nJ2JIq4rhcmMJX3hZIDTt/iFgBo7ZLbRg=";
    };

    pdfcraft = mkArtCraftApp {
      pname = "pdfcraft";
      version = "0.9.0";
      url = "https://github.com/storytold/pdfcraft/releases/download/v0.9.0/pdfcraft-0.9.0-linux-x86_64.AppImage";
      hash = "sha256-+FaMh5BtloRhBS8LVwl8C4S3Cze/ZJybUE2MHretDPo=";
    };

    effectcraft = mkArtCraftApp {
      pname = "effectcraft";
      version = "0.11.1";
      url = "https://github.com/storytold/effectcraft/releases/download/v0.11.1/effectcraft-0.11.1-linux-x86_64.AppImage";
      hash = "sha256-Ix5g82czTX6FiR/mU8SkNKoJPCExPh7Mj+FFm2/Vg3k=";
    };

    designcraft = mkArtCraftApp {
      pname = "designcraft";
      version = "0.9.0";
      url = "https://github.com/storytold/designcraft/releases/download/v0.9.0/designcraft-0.9.0-linux-x86_64.AppImage";
      hash = "sha256-5atgOZuSMnEjWUARiRjW8MRgowgqCQsPb+TZ0EkNqbU=";
    };

    # Interface & Collaborative Design
    figcraft = mkArtCraftApp {
      pname = "figcraft";
      version = "0.7.0";
      url = "https://github.com/storytold/figcraft/releases/download/v0.7.0/figcraft-0.7.0-linux-x86_64.AppImage";
      hash = "sha256-M+JvmVLm9m6QclbFZhmo9168KmH8PHj8M5ba4hC9PIU=";
    };

    # Microsoft Office Suite Alternatives
    wordcraft = mkArtCraftApp {
      pname = "wordcraft";
      version = "0.8.0";
      url = "https://github.com/storytold/wordcraft/releases/download/v0.8.0/wordcraft-0.8.0-linux-x86_64.AppImage";
      hash = "sha256-ffezpQFyug7ehaLEuDw2CvkrHDdnyLMMOWPr8F02q5w=";
    };

    gridcraft = mkArtCraftApp {
      pname = "gridcraft";
      version = "0.8.0";
      url = "https://github.com/storytold/gridcraft/releases/download/v0.8.0/gridcraft-0.8.0-linux-x86_64.AppImage";
      hash = "sha256-lCCWoppTSqJQPp56oYFulS9yUOc9VfjzKv0HdUdhf3c=";
    };

    deckcraft = mkArtCraftApp {
      pname = "deckcraft";
      version = "0.8.0";
      url = "https://github.com/storytold/deckcraft/releases/download/v0.8.0/deckcraft-0.8.0-linux-x86_64.AppImage";
      hash = "sha256-XCTgw9UscQIZ+2uJfL8uhW4PbdTcebeizvwdLVUTTtA=";
    };

    # Audio & Technical Design
    soundcraft = mkArtCraftApp {
      pname = "soundcraft";
      version = "0.8.0";
      url = "https://github.com/storytold/soundcraft/releases/download/v0.8.0/soundcraft-0.8.0-linux-x86_64.AppImage";
      hash = "sha256-nDj40aXIGPZzoX9oqVLqiXLOpKtHIFkL2345NQSGZ2g=";
    };

    cadcraft = mkArtCraftApp {
      pname = "cadcraft";
      version = "0.8.0";
      url = "https://github.com/storytold/cadcraft/releases/download/v0.8.0/cadcraft-0.8.0-linux-x86_64.AppImage";
      hash = "sha256-JPd+NyvwcjP3JnJFi8aRNdVLyfa7Y3ntc3hwp8EVK9I=";
    };

    # Suite Launcher
    artcraft-launcher = mkArtCraftApp {
      pname = "artcraft-launcher";
      version = "0.5.1";
      url = "https://github.com/storytold/craft-launcher/releases/download/v0.5.1/artcraft-launcher-0.5.1-linux-x86_64.AppImage";
      hash = "sha256-1CmJcpVdHtbF/XdZ/dLk3EvFIbPQQM97SJG3hweDH3M=";
    };
  };

  # Combined bundle containing all applications
  artcraft-all = pkgs.symlinkJoin {
    name = "artcraft-suite";
    paths = builtins.attrValues apps;
  };

in
apps // {
  artcraft = artcraft-all;
  artcraft-all = artcraft-all;
}
