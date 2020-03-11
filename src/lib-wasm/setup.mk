REPOROOT?=${shell git root}

WAVMROOT:=${REPOROOT}/../WAVM/
# WAVM C-header file
WAVM_H:=${WAVMROOT}/Include/WAVM/wavm-c/wavm-c.h
WAVM_DI:=wavm/c/wavm.di
WAVM_PACKAGE:=wavm.c

WAYS+=wavm/c/
