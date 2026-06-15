{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs-ruby = {
      url = "github:bobvanderlinden/nixpkgs-ruby";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };
  };

  outputs =
    {
      nixpkgs,
      flake-utils,
      nixpkgs-ruby,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ nixpkgs-ruby.overlays.default ];
        };

        rubyVersion = builtins.head (builtins.split "\n" (builtins.readFile ./.ruby-version));
        ruby = pkgs."ruby-${rubyVersion}";

        zlibBuildFlags = with pkgs; [
          "--with-zlib-include=${zlib.dev}/include"
          "--with-zlib-lib=${zlib.out}/lib"
        ];
      in
      {
        devShells.default = pkgs.mkShell {
          shellHook = ''
            export CPATH="${pkgs.zlib.dev}/include:''${CPATH:-}"
            export LIBRARY_PATH="${pkgs.zlib.out}/lib:''${LIBRARY_PATH:-}"
            export BUNDLE_BUILD__ZLIB="${builtins.concatStringsSep " " zlibBuildFlags}"

            ruby_version="$(${ruby}/bin/ruby -e "puts RUBY_VERSION")"
            export GEM_HOME="$PWD/.nix/ruby/$ruby_version"
            export GEM_PATH="$GEM_HOME"
            export BUNDLE_IGNORE_CONFIG=1
            export BUNDLE_PATH="$PWD/.nix/bundle/$ruby_version"
            export BUNDLE_APP_CONFIG="$PWD/.nix/bundle/config"
            export BUNDLE_WITHOUT="benchmarks"
            export PATH="${ruby}/bin:$GEM_HOME/bin:$PATH"
            mkdir -p "$GEM_HOME" "$BUNDLE_PATH" "$BUNDLE_APP_CONFIG"
          '';

          buildInputs = [
            pkgs.gcc
            pkgs.git
            pkgs.gnumake
            pkgs.pkg-config
            pkgs.zlib
            ruby
          ];
        };
      }
    );
}
