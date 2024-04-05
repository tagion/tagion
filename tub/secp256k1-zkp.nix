{ lib
, stdenv
, fetchFromGitHub
, autoreconfHook
}:

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

  meta = with lib; {
    description = "secp256k1 library zkp fork";
    longDescription = ''
      Optimized C library for EC operations on curve secp256k1. Part of
      Bitcoin Core. This library is a work in progress and is being used
      to research best practices. Use at your own risk.
    '';
    homepage = "https://github.com/BlockstreamResearch/secp256k1-zkp";
    license = with licenses; [ mit ];
    platforms = with platforms; all;
  };
}

