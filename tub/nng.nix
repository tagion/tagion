{ lib, stdenv, fetchFromGitHub, cmake, ninja }:

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

  meta = with lib; {
    homepage = "https://nng.nanomsg.org/";
    description = "Nanomsg next generation";
    license = licenses.mit;
    mainProgram = "nngcat";
    platforms = platforms.unix;
  };
}
