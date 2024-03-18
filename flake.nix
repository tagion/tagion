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

      # Disable mbedtls override is broken upstream see if merged
      # https://github.com/NixOS/nixpkgs/pull/285518
      nng_no_tls = with pkgs;
        stdenv.mkDerivation {
          pname = "nng";
          version = "git";

          src = fetchFromGitHub {
            owner = "nanomsg";
            repo = "nng";
            rev = "c5e9d8acfc226418dedcf2e34a617bffae043ff6";
            hash = "sha256-bFsL3IMmJzjSaVfNBSfj5dStRD/6e7QOkTo01RSUN6g=";
          };

          nativeBuildInputs = [ cmake ninja ];
          cmakeFlags = [ "-G Ninja" ];
        };

      # BlockstreamResearch secp256k1-zkp fork
      secp256k1-zkp = with pkgs;
        stdenv.mkDerivation {
          pname = "secp256k1-zkp";

          version = "0.3.2";

          src = fetchFromGitHub {
            owner = "BlockstreamResearch";
            repo = "secp256k1-zkp";
            rev = "d575ef9aca7cd1ed79735c95ec9f296554ea1df7";
            sha256 = "sha256-Z8TrMxlNduPc4lEzA34jjo75sUJYh5fLNBnXg7KJy8I=";
          };

          nativeBuildInputs = [ autoreconfHook ];

          configureFlags = [
            "--enable-experimental"
            "--enable-benchmark=no"
            "--enable-module-recovery"
            "--enable-module-schnorrsig"
            "--enable-module-musig"
          ];

          doCheck = true;

        };
    in
    {
      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixpkgs-fmt;

      packages.x86_64-linux.default =
        # Notice the reference to nixpkgs here.
        pkgs.stdenv.mkDerivation {
          name = "tagion";

          buildInputs = [
            nng_no_tls
            secp256k1-zkp
          ];

          nativeBuildInputs = with pkgs; [
            dmd
            gnumake
            pkg-config
          ];

          src = self;

          configurePhase = ''
            echo DC=dmd >> local.mk
            echo USE_SYSTEM_LIBS=1 >> local.mk
            echo INSTALL=$out/bin >> local.mk
            echo XDG_DATA_HOME=$out/.local/share >> local.mk
            echo XDG_CONFIG_HOME=$out/.config >> local.mk
          '';

          buildPhase = ''
            make GIT_HASH=${gitRev} tagion
          '';

          installPhase = ''
            mkdir -p $out/bin; make install
          '';
        };

      devShells.x86_64-linux.default =
        # Notice the reference to nixpkgs here.
        pkgs.mkShell {
          inherit (self.checks.x86_64-linux.pre-commit-check) shellHook;
          buildInputs = with pkgs; [
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
          ];
        };

      checks.x86_64-linux.pre-commit-check = pre-commit-hooks.lib.x86_64-linux.run {
        src = ./.;
        hooks = {
          shellcheck = {
            enable = true;
            types_or = [ "sh" ];
          };
          typos.enable = true;
          actionlint.enable = true;
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

      docker = pkgs.dockerTools.buildLayeredImage {
          name = "tagion";
          tag = "latest";
          config.Cmd = "${self.packages.x86_64-linux.default}/bin/tagion";
      };

      packages.x86_64-linux.dockerImage =
        pkgs.dockerTools.buildImage {
          name = "tagion-docker";
          tag = "latest";
          fromImage = pkgs.dockerTools.pullImage {
            imageName = "alpine";
            imageDigest = "sha256:13b7e62e8df80264dbb747995705a986aa530415763a6c58f84a3ca8af9a5bcd";
            sha256 = "sha256-6tIIMFzCUPRJahTPoM4VG3XlD7ofFPfShf3lKdmKSn0=";
            finalImageName = "alpine";
            os = "linux";
            arch = "x86_64";
          };
          copyToRoot = pkgs.buildEnv {
            name = "image-root";
            paths = [ self.packages.x86_64-linux.default ];
            pathsToLink = [ "/bin" ];
          };

          # contents = [ self.packages.x86_64-linux.default];
          config = {
            Cmd = [ "/bin/sh" ];
            Env = [ ];
            Volumes = { };
          };
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
