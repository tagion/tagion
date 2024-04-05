{
  description = "Tagion is a decentrialized monetary system";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    pre-commit-hooks.url = "github:cachix/pre-commit-hooks.nix";
    pre-commit-hooks.inputs.nixpkgs.follows = "nixpkgs";
    dfmt-pull.url = "github:jtbx/nixpkgs/d-dfmt";
  };

  outputs = { self, nixpkgs, pre-commit-hooks, dfmt-pull }:
    let
      gitRev = self.rev or "dirty";

      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      secp256k1-zkp = pkgs.callPackage ./tub/secp256k1-zkp.nix { };

      # Disable mbedtls override is broken upstream see if merged
      # https://github.com/NixOS/nixpkgs/pull/285518
      nng = pkgs.callPackage ./tub/nng.nix { };
    in
    {
      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixpkgs-fmt;

      packages.x86_64-linux.default = pkgs.callPackage ./tub/tagion.nix { 
          src = self;
          gitRev = gitRev; 
          secp256k1-zkp = secp256k1-zkp;
          nng = nng; 
      };

      _devShell =
        pkgs.mkShell {
          inherit (self.checks.x86_64-linux.pre-commit-check) shellHook;
          buildInputs = with pkgs; [
            # This is a bit misleading now but should this work fine
            self.packages.x86_64-linux.default.buildInputs
            self.packages.x86_64-linux.default.nativeBuildInputs
            dub
            ldc
            gcc
            git
            libtool
            autoconf
            automake
            autoreconfHook
            cmake
            libz
            dtools
            dfmt-pull.legacyPackages.x86_64-linux.dlang-dfmt
            graphviz
          ];
        };

      devShells.x86_64-linux.default = self._devShell;
      devShells.aarch64-linux.default = self._devShell;
      # devShells.x86_64-darwin.default = self._devShell;
      # devShells.aarch64-darwin.default = self._devShell;
      checks.x86_64-linux.pre-commit-check = pre-commit-hooks.lib.x86_64-linux.run {
        src = ./.;
        settings.typos.configPath = ".typos.toml";
        hooks = {
          shellcheck = {
            enable = true;
            types_or = [ "sh" ];
          };
          typos.enable = true;
          typos.pass_filenames = false;
          # actionlint.enable = true;
          dlang-format = {
            # does not work :-( we have to define a proper commit
            enable = true;
            name = "format d code";
            entry = "make format";
            language = "system";
          };
        };
      };

      checks.x86_64-linux.unittest = with pkgs;
        stdenv.mkDerivation {
          name = "unittest";
          doCheck = true;

          buildInputs = self.packages.x86_64-linux.default.buildInputs;

          nativeBuildInputs = self.packages.x86_64-linux.default.nativeBuildInputs;

          src = self;

          configurePhase = ''
            echo DC=dmd >> local.mk
            echo USE_SYSTEM_LIBS=1 >> local.mk
          '';

          buildPhase = ''
            make proto-unittest-build
          '';

          checkPhase = ''
            ./build/x86_64-linux/bin/unittest
          '';

          installPhase = ''
            # No install target available for unittest
            mkdir -p $out/bin; cp ./build/x86_64-linux/bin/unittest $out/bin/
          '';
        };
      checks.x86_64-linux.commit = with pkgs;
        stdenv.mkDerivation {
          name = "commit";
          doCheck = true;

          buildInputs = [
            self.packages.x86_64-linux.default.buildInputs
            which
          ];

          nativeBuildInputs = self.packages.x86_64-linux.default.nativeBuildInputs;

          src = self;

          configurePhase = ''
            echo DC=dmd >> local.mk
            echo USE_SYSTEM_LIBS=1 >> local.mk
            mkdir -p build/x86_64-linux/
            echo "
                  ${gitRev}\n
                  git@github.com:tagion/tagion.git\n
                  wowo
                  wowo
                  wowo
                  wowo
                  wowo
                  wowo
                  $(dmd --version|head -n 1)" >> build/x86_64-linux/revision.mixin
          '';

          buildPhase = ''
            make bddinit
          '';

          checkPhase = ''
            make bddrun bddreport TEST_STAGE=commit
          '';

          installPhase = ''
            mkdir -p $out/bin; cp ./build/x86_64-linux/bin/collider $out/bin/
          '';
        };

      packages.x86_64-linux.dockerImage = pkgs.dockerTools.buildLayeredImage {
        name = "tagion";
        tag = "latest";
        config.Cmd = "${self.packages.x86_64-linux.default}/bin/tagion";
      };

      nixosModules.default = with pkgs.lib; { config, ... }:
        let cfg = config.tagion.services;
        in {
          options.tagion.services = {
            tagionwave = {
              enable = mkEnableOption "Enable the tagionwave service";
            };

            tagionshell = {
              enable = mkEnableOption "Enable the tagionshell service";
            };
          };

          config = {
            systemd.services."tagionwave" = mkIf cfg.tagionwave.enable {
              wantedBy = [ "multi-user.target" ];
              wants = [ "network-online.target" ];
              after = [ "network-online.target" ];
              serviceConfig =
                let pkg = self.packages.${pkgs.system}.default;
                in {
                  Restart = "on-failure";
                  ExecStart = "${pkg}/bin/tagion wave";
                };
            };
            systemd.services."tagionshell" = mkIf cfg.tagionshell.enable {
              wantedBy = [ "multi-user.target" ];
              wants = [ "network-online.target" ];
              after = [ "network-online.target" ];
              serviceConfig =
                let pkg = self.packages.${pkgs.system}.default;
                in {
                  Restart = "on-failure";
                  ExecStart = "${pkg}/bin/tagion shell";
                };
            };
          };
        };

      nixosConfigurations = {
        #  qa = nixpkgs.lib.nixosSystem {
        #   system = "x86_64-linux";
        #   modules = [
        #     ./tub/qa-config.nix
        #   ];
        # };
        # System configuration for a test network running in mode0
        tgn-m0-test = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            self.nixosModules.default
            ({ pkgs, ... }: {
              # environment.systemPackages = with pkgs; [ packages.x86_64-linux.default ];
              # Only allow this to boot as a container
              boot.isContainer = true;
              networking.hostName = "tgn-m0-test";
              tagion.services.tagionwave.enable = true;
              tagion.services.tagionshell.enable = true;
              system.stateVersion = "24.05";
            })
          ];
        };
      };
    };
}
