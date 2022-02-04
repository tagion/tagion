# Define commands for copy, remove and create file/dir
ifeq ($(OS),windows)
RM ?= del /Q
RMDIR ?= del /Q
CP ?= copy /Y
MKDIR ?= mkdir
MV ?= move
LN ?= mklink
GETOS?=Unknow-get-os
GETARCH?=Unknow-get-arch
DLLEXT ?= dll
OBJEXT ?= obj
else ifeq ($(OS),linux)

else ifeq ($(OS),freebsd)

else ifeq ($(OS),solaris)

else ifeq ($(OS),darwin)
DLLEXT ?= dylib

endif

# Default posix commands
GETOS?=${shell uname | tr A-Z a-z}
GETARCH?=${shell uname -m}
RM ?= rm -f
RMDIR ?= rm -rf
CP ?= cp -a
MKDIR ?= mkdir -p
MV ?= mv
LN ?= ln -s
TOUCH ?= touch
DLLEXT ?= so
LIBEXT ?= a
OBJEXT ?= o

CD ?= cd

# D step
# TODO: Clone local dstep
DSTEP?=${shell which dstep}

GO?=${shell which go}


env-commands:
	$(PRECMD)
	$(call log.header, $@ :: commands ($(OS)))
	${call log.kvp, "Those macros list came be change from the command line make"}
	$(call log.kvp, CD, "$(CD)")
	$(call log.kvp, CP, "$(CP)")
	$(call log.kvp, MV, $(MV))
	$(call log.kvp, LN, "$(LN)")
	$(call log.kvp, RM, "$(RM)")
	$(call log.kvp, RMDIR, "$(RMDIR)")
	$(call log.kvp, MKDIR, "$(MKDIR)")
	$(call log.kvp, TOUCH, "$(TOUCH)")
	$(call log.kvp, LIBEXT, $(LIBEXT))
	$(call log.kvp, DLLEXT, $(DLLEXT))
	$(call log.kvp, OBJEXT, $(OBJEXT))
	$(call log.kvp, DSTEP,  "$(DSTEP)")
	$(call log.kvp, GO,  "$(GO)")
	$(call log.close)

env: env-commands
