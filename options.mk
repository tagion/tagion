
#
# To chnage the default options copy this file to local.mk
# and change the options
#

#
# BetterC
# Only like part for better C
#
# BETTERC=1

#
# Platforms
#

#
# Linux x86_64
# platform.linux-x86_64.mk
# Note: This is default platform you run
# You can check the current platform via the make taget
# make env-host
#
#PLATFORM?=linux-x86_64

#
# Linux x86
# platform.linux-x86.mk
#
#PLATFORM?=linux-x86
# Not supported it
#

#
#
#

#
# Android armv7a
# platform.armv7a-linux-androideabi.mk
#
#PLATFORM?=armv7a-linux-androideabi
#

#
# Android aarch64
# platform.aarch64-linux-android.mk
#
#PLATFORM?=aarch64-linux-android
#

#
# Android x86_64
# platform.x86_64-linux-android.mk
#
#PLATFORM?=x86_64-linux-android
#

#
# Android i686
# platform.i686-linux-android.mk
#
#PLATFORM?=i686-linux-android
#

INSTALL?=$(HOME)/bin
