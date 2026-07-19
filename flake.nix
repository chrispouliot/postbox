{
  description = "Postbox development shell";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { nixpkgs, ... }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      devShells = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };

          pythonEnv = pkgs.python312.withPackages (pythonPackages: [
            pythonPackages.pygobject3
          ]);
        in
        {
          default = pkgs.mkShell {
            name = "postbox-dev";

            # Host-side commands used by the project's justfile.
            nativeBuildInputs = with pkgs; [
              just
              flatpak
              flatpak-builder

              # Native Meson/translation workflow (`just pot`) and validation.
              meson
              ninja
              pkg-config
              gettext
              blueprint-compiler
              desktop-file-utils
              appstream
              glib
              gobject-introspection

              # Source fetching and editor/developer tooling.
              git
              ruff
              pyright
            ];

            # `just build` and `just run` build the application using the
            # Flatpak GNOME SDK. These host-side libraries support editor
            # analysis, ad-hoc imports, and Flatpak export validation.
            buildInputs = with pkgs; [
              pythonEnv
              gtk4
              libadwaita
              webkitgtk_6_0
              libsecret

              # Flatpak Builder validates exported icons on the host. The SVG
              # loader is supplied separately by librsvg on NixOS.
              gdk-pixbuf
              librsvg
            ];

            shellHook = ''
              # Nixpkgs' gdk-pixbuf setup hook normally sets this variable.
              # Select librsvg's cache explicitly so flatpak-builder can
              # recognize and validate symbolic SVG application icons.
              for cache in ${pkgs.librsvg}/lib/gdk-pixbuf-2.0/*/loaders.cache; do
                if [ -f "$cache" ]; then
                  export GDK_PIXBUF_MODULE_FILE="$cache"
                  break
                fi
              done

              if [ -z "''${GDK_PIXBUF_MODULE_FILE:-}" ]; then
                echo "warning: librsvg GdkPixbuf loader cache was not found" >&2
              fi

              export PYTHONPATH="$PWD/src''${PYTHONPATH:+:$PYTHONPATH}"

              flatpakIndex="$HOME/.local/share/flatpak/exports/share/icons/hicolor/index.theme"

              if [ -f "$flatpakIndex" ] && [ ! -w "$flatpakIndex" ]; then
                chmod u+w "$flatpakIndex"
              fi

              echo "Postbox development shell"
              echo "  just init  # one-time Flatpak runtime/SDK setup"
              echo "  just run   # build and launch the Flatpak"
              echo "  just pot   # regenerate translations with host Meson tools"
            '';
          };
        }
      );
    };
}
