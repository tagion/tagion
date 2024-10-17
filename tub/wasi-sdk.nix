{ lib
, stdenv
, fetchFromGitHub
, ninja
, clang
, python3
, cmake
, git
}:

stdenv.mkDerivation {
  pname = "wasi-sdk";

  version = "22";

  src = fetchFromGitHub {
    owner = "WebAssembly";
    repo = "wasi-sdk";
    rev = "wasi-sdk-22";
    sha256 = "sha256-nkGmp5ZcNpWVL1E7OV/60UyiQxGDbjxTMFH+yvEv4MU=";
    leaveDotGit = true;
  };

  nativeBuildInputs = [ ninja clang cmake python3 git ];

  phases = [ "unpackPhase" "setupPhase" "buildPhase" "installPhase" ];

  setupPhase = ''
    ls .git
    git describe
    git submodule init
    git submodule update
    exit 1
  '';

  buildPhase = ''
    ls
    make package
  '';

  installPhase = ''
    cp -r . $out/
  '';

  doCheck = true;

  meta = with lib; {
    description = "WASI-enabled WebAssembly C/C++ toolchain";
    homepage = "https://github.com/WebAssembly/wasi-sdk";
    license = [ licenses.asl20 ];
    platforms = platforms.all;
  };
}

