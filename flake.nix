{
  description = "Tagion is a decentrialized monetary system";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      gitRev = self.rev or "dirty";

      # nng_no_tls = self.inputs.nng.packages.${nixpkgs.system}.default.override {
      #     mbedtlsSupport = false;
      # };

      # BlockstreamResearch secp256k1-zkp fork
      secp256k1-zkp = with import nixpkgs { system = "x86_64-linux"; };
        stdenv.mkDerivation rec {
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

      system = "x86_64-linux"; 
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixpkgs-fmt;

      packages.x86_64-linux.default =
        # Notice the reference to nixpkgs here.
        pkgs.stdenv.mkDerivation {
          name = "tagion";

          buildInputs = with pkgs; [
            nng
            secp256k1-zkp
            mbedtls
          ];

          nativeBuildInputs = with pkgs; [
            dmd
            dtools
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
            echo NNG_ENABLE_TLS=1 >> local.mk
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
          buildInputs = with pkgs; [
            self.packages.x86_64-linux.default.nativeBuildInputs
            self.packages.x86_64-linux.default.buildInputs
            dub
            ldc
            gcc
            git
            libtool
            autoconf
            automake
            autoreconfHook
            cmake
          ];
        };

      # Experimental work on nix unittest build. execute using nix build .#unittest
      # Idea is to use this along with nix run in order to run unittests with nix
      packages.x86_64-linux.unittest =
        with pkgs;
        stdenv.mkDerivation {
          name = "unittest";

          buildInputs = [
            nng
            secp256k1-zkp
            mbedtls
          ];

          nativeBuildInputs = [
            dmd
            dtools
            gnumake
            pkg-config
          ];

          src = self;
          configurePhase = ''
            echo DC=dmd >> local.mk
            echo INSTALL=$out/bin >> local.mk
            echo XDG_DATA_HOME=$out/.local/share >> local.mk
            echo XDG_CONFIG_HOME=$out/.config >> local.mk
            echo NNG_ENABLE_TLS=1 >> local.mk
          '';

          buildPhase = ''
            make GIT_HASH=${gitRev} proto-unittest-build
          '';

          installPhase = ''
            mkdir -p $out/bin; make install
          '';
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
    };
}
