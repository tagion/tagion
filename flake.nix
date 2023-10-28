{
  description = "Tagion is a decentrialized monetary system";

  outputs = { self, nixpkgs }: {

    inputs.nixpkgs.url = github:NixOS/nixpkgs/nixos-unstable;
    # packages.x86_64-linux.hello = nixpkgs.legacyPackages.x86_64-linux.hello;

    # packages.x86_64-linux.default = self.packages.x86_64-linux.hello;


    defaultPackage.x86_64-linux =
      # Notice the reference to nixpkgs here.
      with import nixpkgs { system = "x86_64-linux"; };
      stdenv.mkDerivation {

        configure = "";
        buildInputs = [
            autoconf
            automake
            autoreconfHook
            cmake
            dtools
            dfmt
            dub
            dmd
            go
            gnumake
            git
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
