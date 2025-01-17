{
  nixConfig.bash-prompt = "[nix-develop-osl:] ";
  description = "Open Specification Language compiler";
  inputs = {
    flake-utils = {
      url = "github:numtide/flake-utils";
    };
    flake-compat-ci.url = "github:hercules-ci/flake-compat-ci";
    lint-utils = {
      url = "git+https://gitlab.homotopic.tech/nix/lint-utils";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    horizon-platform = {
      url = "git+https://gitlab.homotopic.tech/horizon/horizon-platform";
    };
    sydtest-src = {
      url = "git+https://github.com/NorfairKing/sydtest";
      flake = false;
    };
    validity-src = {
      url = "git+https://github.com/NorfairKing/validity";
      flake = false;
    };
  };
  outputs =
    inputs@
    { self
    , flake-utils
    , flake-compat-ci
    , horizon-platform
    , lint-utils
    , nixpkgs
    , sydtest-src
    , validity-src
    , ...
    }:
    flake-utils.lib.eachSystem [ "x86_64-linux" ] (system:
    let
      pkgs = import nixpkgs { inherit system; };
      lintPkgs = import lint-utils.inputs.nixpkgs { inherit system; };
      hsPkgs =
        with pkgs.haskell.lib;
        pkgs.haskell.packages.ghc942.override
          {
            overrides = hfinal: hprev:
              horizon-platform.packages.x86_64-linux // {
                osl = dontHaddock (dontCheck (disableLibraryProfiling (hprev.callCabal2nix "osl" ./. { })));
                osl-spec = disableLibraryProfiling (hprev.callCabal2nix "osl:spec" ./. { });
                sydtest = dontCheck (hprev.callCabal2nix "sydtest" (sydtest-src + /sydtest) { });
                genvalidity-sydtest = dontCheck (hprev.callCabal2nix "genvalidity-sydtest" (validity-src + /genvalidity-sydtest) { });
                genvalidity-sydtest-aeson = dontCheck (hprev.callCabal2nix "genvalidity-sydtest-aeson" (validity-src + /genvalidity-sydtest-aeson) { });
              };
          };
      ormolu-check =
        pkgs.stdenv.mkDerivation {
          name = "ormolu-check";
          src = ./.;
          doCheck = true;
          buildPhase = ''
            ${pkgs.git.outPath}/bin/git init
            ${pkgs.git.outPath}/bin/git add -A
            ${pkgs.git.outPath}/bin/git config user.email "foo@bar.com"
            ${pkgs.git.outPath}/bin/git config user.name "Foobar"
            ${pkgs.git.outPath}/bin/git commit -m "initial commit"
            ${pkgs.ormolu.outPath}/bin/ormolu -m inplace $(find ./. -type f -name '*.hs')
            if [ -z "$(${pkgs.git.outPath}/bin/git status --porcelain)" ]; then
              echo "ok"
            else
              echo "ormolu check failed"
              exit 1
            fi
          '';
          installPhase = ''
            mkdir -p $out
          '';
        };
    in
    {
      devShells.default = hsPkgs.osl.env.overrideAttrs (attrs: {
        buildInputs = attrs.buildInputs ++ [
          hsPkgs.cabal-install
          pkgs.nixpkgs-fmt
          hsPkgs.ghcid
          pkgs.ormolu
          hsPkgs.hlint
        ];
      });
      packages.default = hsPkgs.osl;
      packages.ormolu-check = ormolu-check;
      ciNix = flake-compat-ci.lib.recurseIntoFlakeWith {
        flake = self;
        systems = [ "x86_64-linux" ];
      };
      checks =
        with lint-utils.outputs.linters.${system};
        {
          hlint = hlint self;
          hpack = hpack self;
          inherit ormolu-check;
          spec = hsPkgs.osl-spec;
        };
    });

}
