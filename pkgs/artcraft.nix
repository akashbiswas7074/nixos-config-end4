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
      version = "0.7.0";
      url = "https://github.com/storytold/photocraft/releases/download/v0.7.0/photocraft-0.7.0-linux-x86_64.AppImage";
      hash = "sha256-h+vONrzfazHRapyiLOKfmtjbaBheTZgRiADRwt54rEI=";
    };

    vectorcraft = mkArtCraftApp {
      pname = "vectorcraft";
      version = "0.9.0";
      url = "https://github.com/storytold/vectorcraft/releases/download/v0.9.0/vectorcraft-0.9.0-linux-x86_64.AppImage";
      hash = "sha256-d+76LBynaB5Lmu3mONsxRjbajVBK6hB9SPszZ7b2Ejg=";
    };

    filmcraft = mkArtCraftApp {
      pname = "filmcraft";
      version = "0.6.0";
      url = "https://github.com/storytold/filmcraft/releases/download/v0.6.0/filmcraft-0.6.0-linux-x86_64.AppImage";
      hash = "sha256-wLWl0PDnEXaqgGyJX4ylE/LVBbcP74W4dLviPJEjK8c=";
    };

    lightcraft = mkArtCraftApp {
      pname = "lightcraft";
      version = "0.6.0";
      url = "https://github.com/storytold/lightcraft/releases/download/v0.6.0/lightcraft-0.6.0-linux-x86_64.AppImage";
      hash = "sha256-V37wGNzuyNSYDS+bIHguw3hIFYuOZBnMkNMcK1gMGRk=";
    };

    pdfcraft = mkArtCraftApp {
      pname = "pdfcraft";
      version = "0.6.0";
      url = "https://github.com/storytold/pdfcraft/releases/download/v0.6.0/pdfcraft-0.6.0-linux-x86_64.AppImage";
      hash = "sha256-FzFK9UQ/WB9FFt6u/avB5w+DGZphQSoQ3q9nOtrvAow=";
    };

    effectcraft = mkArtCraftApp {
      pname = "effectcraft";
      version = "0.8.0";
      url = "https://github.com/storytold/effectcraft/releases/download/v0.8.0/effectcraft-0.8.0-linux-x86_64.AppImage";
      hash = "sha256-MSIdq2Mf7zo40UBUb/wqaVVFm4WYd4RagoLZqXI5s3M=";
    };

    designcraft = mkArtCraftApp {
      pname = "designcraft";
      version = "0.6.0";
      url = "https://github.com/storytold/designcraft/releases/download/v0.6.0/designcraft-0.6.0-linux-x86_64.AppImage";
      hash = "sha256-+2Ln56mt7i/X9ACyuiYJO5aoA0cKfY1HbjkZbwXEwDQ=";
    };

    # Microsoft Office Suite Alternatives
    wordcraft = mkArtCraftApp {
      pname = "wordcraft";
      version = "0.5.0";
      url = "https://github.com/storytold/wordcraft/releases/download/v0.5.0/wordcraft-0.5.0-linux-x86_64.AppImage";
      hash = "sha256-lHfqkt2e3yq5dL3jJZWEWyc3snskx6QGWctdzieydVE=";
    };

    gridcraft = mkArtCraftApp {
      pname = "gridcraft";
      version = "0.5.0";
      url = "https://github.com/storytold/gridcraft/releases/download/v0.5.0/gridcraft-0.5.0-linux-x86_64.AppImage";
      hash = "sha256-+XqC0PIdM4H7sZoK4JKNZcXNxAL6pekgCDEs5Jh0XOI=";
    };

    deckcraft = mkArtCraftApp {
      pname = "deckcraft";
      version = "0.5.0";
      url = "https://github.com/storytold/deckcraft/releases/download/v0.5.0/deckcraft-0.5.0-linux-x86_64.AppImage";
      hash = "sha256-Zi9iNqHAqBwyboCxJq/VXdaNwqEsM7vDAJ8G2fObMR4=";
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
