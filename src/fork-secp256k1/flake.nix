{
  description = "BlockstreamResearch fork of secp256k1";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }: {

    defaultPackage.x86_64-linux =

      with import nixpkgs { system = "x86_64-linux"; };
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
  };
}
