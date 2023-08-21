{ pkgs ? import <nixpkgs> {} }:

  pkgs.mkShell {
    # nativeBuildInputs is usually what you want -- tools you need to run
    nativeBuildInputs = with pkgs; [ cmake autoreconfHook dub ldc dtools dmd gnumake autoconf automake libtool go llvmPackages_15.clang-unwrapped git glibcLocales ];
}
