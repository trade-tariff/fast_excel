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
      self,
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
        reviewEnvironment = ''
          if [ "''${REVIEW_SANDBOX:-}" != 1 ] || [ "$PWD" != /workspace ]; then
            echo 'Run review commands inside a disposable review sandbox.' >&2
            exit 64
          fi
          export TMPDIR=/workspace/.bundle/review/tmp GEM_HOME=/workspace/.bundle/review/gems
          export GEM_PATH="$GEM_HOME''${REVIEW_GEM_CACHE:+:$REVIEW_GEM_CACHE}"
          export BUNDLE_IGNORE_CONFIG=1 BUNDLE_PATH__SYSTEM=true BUNDLE_WITHOUT=benchmarks
          export BUNDLE_LOCAL__CAXLSX=/deps/caxlsx BUNDLE_LOCAL__PROCESS_MEMORY=/deps/process_memory
          export BUNDLE_DISABLE_LOCAL_BRANCH_CHECK=true
          unset BUNDLE_PATH BUNDLE_APP_CONFIG
          mkdir -p "$TMPDIR" "$GEM_HOME"
        '';
      in
      {
        devShells.review = self.devShells.${system}.default.overrideAttrs (old: {
          shellHook = "";
          buildInputs = (old.buildInputs or [ ]) ++ [ pkgs.libffi ];
          nativeBuildInputs = [
            pkgs.nixfmt
            (pkgs.writeShellApplication {
              name = "review-bootstrap";
              text = reviewEnvironment + ''
                if [ -d /deps/gem-archives ]; then
                  for archive in /deps/gem-archives/*.gem; do
                    [ -f "$archive" ] || continue
                    gem install --local --no-document --ignore-dependencies "$archive"
                  done
                fi
                bundle check || bundle install --local
                make
                make install
              '';
            })
            (pkgs.writeShellApplication {
              name = "review-check";
              text = reviewEnvironment + ''
                nixfmt --check flake.nix
                PERFORMANCE_TESTS=true bundle exec rake test 2>&1 | tee "$TMPDIR/unit.log"
                ruby -e 'abort "Skipped unit tests" if File.read(ARGV[0]).match?(/[1-9][0-9]* (?:skips|pendings|omissions)/)' "$TMPDIR/unit.log"
                bundle exec rake examples
                bundle exec rake perf:validate
                git check-ignore -v "$GEM_HOME" | grep -q '^\.gitignore:'
                gem build uber_fast_excel.gemspec
                ruby -rrubygems/package -e 's = Gem::Package.new(Dir["uber_fast_excel-*.gem"].fetch(0)).spec; abort "Review inputs leaked into gem" if s.files.any? { |p| p.start_with?(".bundle/", ".review/") }'
              '';
            })
          ]
          ++ (old.nativeBuildInputs or [ ]);
          CPATH = "${pkgs.zlib.dev}/include";
          LIBRARY_PATH = "${pkgs.zlib.out}/lib";
          LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath [ pkgs.libyaml ];
          BUNDLE_BUILD__ZLIB = builtins.concatStringsSep " " zlibBuildFlags;
          TZDIR = "${pkgs.tzdata.outPath}/share/zoneinfo";
          SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
        });

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
