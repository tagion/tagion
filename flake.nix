{
  description = "Tagion is a decentrialized monetary system";

  inputs.nixpkgs.url = github:NixOS/nixpkgs/nixos-unstable;

  outputs = { self, nixpkgs }: {

    formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixpkgs-fmt;

    defaultPackage.x86_64-linux =
      # Notice the reference to nixpkgs here.
      with import nixpkgs { system = "x86_64-linux"; };
      stdenv.mkDerivation rec {

        buildInputs = [
            wolfssl
            nng
            secp256k1
        ];

        nativeBuildInputs = [
          dub
          dmd
          dtools
          go
          git
          gnumake
          glibcLocales
          ldc
          libtool
          llvmPackages_15.clang-unwrapped
          autoconf
          automake
          autoreconfHook
          cmake
        ];

        src = self;
        name = "tagion";
        buildPhase = ''
            make DC=dmd tagion
        '';
      };
  };
}
