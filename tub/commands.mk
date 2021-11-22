# Define commands for copy, remove and create file/dir
ifeq ($(OS),windows)
RM := del /Q
RMDIR := del /Q
CP := copy /Y
MKDIR := mkdir
MV := move
LN := mklink
else ifeq ($(OS),linux)
RM := rm -f
RMDIR := rm -rf
CP := cp -fr
MKDIR := mkdir -p
MV := mv
LN := ln -s
else ifeq ($(OS),freebsd)
RM := rm -f
RMDIR := rm -rf
CP := cp -fr
MKDIR := mkdir -p
MV := mv
LN := ln -s
else ifeq ($(OS),solaris)
RM := rm -f
RMDIR := rm -rf
CP := cp -fr
MKDIR := mkdir -p
MV := mv
LN := ln -s
else ifeq ($(OS),darwin)
RM := rm -f
RMDIR := rm -rf
CP := cp -fr
MKDIR := mkdir -p
MV := mv
LN := ln -s
endif

MAKE_ENV += env-commands
env-commands:
	$(call log.header, env :: commands ($(OS)))
	$(call log.kvp, RM, $(RM))
	$(call log.kvp, RMDIR, $(RMDIR))
	$(call log.kvp, MKDIR, $(MKDIR))
	$(call log.kvp, MV, $(MV))
	$(call log.kvp, LN, $(LN))
	$(call log.close)