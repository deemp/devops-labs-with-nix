{ nixpkgs
, system
, my-codium
, json2md
, env2json
, app-python
, app-purescript
, rootDir
, drv-tools
, flakes-tools
, easy-purescript-nix
, python-tools
, terrafix
, my-devshell
}:
let
  pkgs = nixpkgs.legacyPackages.${system};
  inherit (my-codium.functions.${system})
    mkCodium
    ;
  inherit (my-codium.configs.${system})
    extensions
    ;
  inherit (drv-tools.functions.${system})
    toList
    mkShellApp
    mkShellApps
    mkDevShellsWithDefault
    mkBin
    framedBrackets
    ;
  inherit (flakes-tools.functions.${system})
    mkFlakesTools
    ;

  inherit (import ./data.nix)
    appPurescript
    appPython
    langPurescript
    langPython
    ;

  inherit (builtins) map attrValues;
  devshell = my-devshell.devshell.${system};
  inherit (my-devshell.functions.${system}) mkCommands;

  configWriters =
    (import ./write-configs.nix
      {
        inherit
          json2md system pkgs commands terrafix
          env2json drv-tools my-codium
          ;
      }
    );

  commands = import ./commands.nix {
    inherit pkgs mkShellApp system drv-tools;
    scripts = {
      ${langPurescript} = app-purescript.scripts.${system};
      ${langPython} = app-python.scripts.${system};
    };
  };

  dirs = [ appPurescript appPython ];
  flakesTools = mkFlakesTools [ appPurescript appPython "." ];

  codiumTools = attrValues ({
    inherit (pkgs)
      docker poetry direnv lorri
      rnix-lsp nixpkgs-fmt dhall-lsp-server
      geckodriver terraform terraform-ls
      kubernetes minikube
      ;
    inherit (pkgs.haskellPackages) hadolint;
  }
  //
  flakesTools
  //
  configWriters
  //
  commands.apps
  );

  codium = mkCodium {
    extensions = {
      inherit (extensions)
        nix markdown purescript github misc docker python toml fish yaml
        kubernetes
        # TODO enable terraform
        # terraform
        ;
    };
    runtimeDependencies = [
      (toList commands)
      codiumTools
    ];
  };

  scripts = (mkShellApps {
    lintDockerfiles =
      let
        dockerFile = "Dockerfile";
        dirs = [ appPython appPurescript ];
        inherit (pkgs.lib.strings) concatMapStringsSep concatStringsSep;
      in
      {
        runtimeInputs = [ pkgs.haskellPackages.hadolint ];
        text = ''
          set +e
          ${concatMapStringsSep
            ''printf "\n" ; ''
            (dir: '' ( printf "${framedBrackets "linting in ${dir}"}" ; hadolint ${dir}/${dockerFile});'')
            dirs
          }'';
        longDescription = ''Lint ${dockerFile}s in ${concatStringsSep ", " dirs}'';
      };
    monitor = {
      name = "monitor";
      text = ''
        set -a
        source .env
        cd monitoring
        source configs/datasources/.env
        docker compose up
      '';
      longDescription = "monitor via Prometheus";
    };
  })
  // {
    createVenvs = python-tools.functions.${system}.createVenvs [ appPython appPurescript "." ];
  };
  packages = codiumTools ++ [ codium ];
  devShells.default =
    devshell.mkShell
      {
        inherit packages;
        bash.extra = python-tools.snippets.${system}.activateVenv;
        commands = mkCommands "packages" packages;
      }
  ;
in
{
  inherit devShells packages flakesTools;
}
