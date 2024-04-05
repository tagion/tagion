{ src
, gitRev
, stdenv
, nng
, secp256k1-zkp
, dmd
, gnumake
, pkg-config
}:

stdenv.mkDerivation {
  name = "tagion";

  buildInputs = [
    nng
    secp256k1-zkp
  ];

  nativeBuildInputs = [
    dmd
    gnumake
    pkg-config
  ];

  src = src;

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
}
