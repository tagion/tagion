REPOROOT?=${shell git root}

SCRIPTROOT:=${REPOROOT}/scripts/

WAVMROOT:=${REPOROOT}/../WAVM/
# WAVM C-header file
WAVM_H:=${WAVMROOT}/Include/WAVM/wavm-c/wavm-c.h
WAVM_DI:=wavm/c/wavm.di
WAVM_PACKAGE:=wavm.c
# Change c-array to pointer
WAVMa2p:=${SCRIPTROOT}/wasm_array2pointer.pl

WAYS+=wavm/c/
