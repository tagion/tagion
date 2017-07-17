REPOROOT?=$(shell git root)
include $(REPOROOT)/command.mk

-include dfiles.mk

ifndef (DFILES)
include source.mk
endif
