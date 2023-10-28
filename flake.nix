{
  description = "Tagion is a decentrialized monetary system";

  inputs.nixpkgs.url = github:NixOS/nixpkgs/nixos-unstable;

  outputs = { self, nixpkgs }: {

    # packages.x86_64-linux.hello = nixpkgs.legacyPackages.x86_64-linux.hello;

    # packages.x86_64-linux.default = self.packages.x86_64-linux.hello;


    formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixpkgs-fmt;
    defaultPackage.x86_64-linux =
      # Notice the reference to nixpkgs here.
      with import nixpkgs { system = "x86_64-linux"; };
      stdenv.mkDerivation {

        buildInputs = [
          autoconf
          automake
          autoreconfHook
          cmake
          dub
          dmd
          dfmt
          dtools
          go
          git
          gnumake
          glibcLocales
          ldc
          libtool
          llvmPackages_15.clang-unwrapped
        ];

        name = "tagion";
        src = self;
        buildPhase = "make tagion";
      };
  };
}
