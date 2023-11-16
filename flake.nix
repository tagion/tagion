{
  description = "Tagion is a decentrialized monetary system";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    secp256k1-zkp.url = "github:tagion/secp256k1-zkp";
  };

  outputs = { self, nixpkgs, secp256k1-zkp }: {

    formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixpkgs-fmt;

    packages.x86_64-linux.default =
      # Notice the reference to nixpkgs here.
      with import nixpkgs { system = "x86_64-linux"; };
      stdenv.mkDerivation {
        name = "tagion";

        buildInputs = [
          nng
          secp256k1-zkp.defaultPackage.x86_64-linux
          mbedtls
        ];

        nativeBuildInputs = [
          dmd
          dtools
          gnumake
          pkg-config
        ];

        src = self;

        buildPhase = ''
          make DC=dmd USE_SYSTEM_LIBS=1 tagion
        '';

        installPhase = ''
          mkdir -p $out/bin; make INSTALL=$out/bin install
        '';
      };

    devShell.x86_64-linux =
      # Notice the reference to nixpkgs here.
      with import nixpkgs { system = "x86_64-linux"; };
      mkShell {
        buildInputs = [
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
        ];
      };

  };
}
