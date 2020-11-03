#
# DDOC Configuration
#
DDOCREPO:=$(REPOROOT)/../tagion_ddoc/
DDOCSCRIPT:=$(DDOCREPO)/scripts/ddocmodule.pl
DDOCBUILDER:=$(DDOCREPO)/ddoc_builder.mk

DDOCMODULES:=modules.ddoc
DDOCROOT?=$(REPOROOT)/ddoc/
DDOCFIGROOT:=$(REPOROOT)/candydoc/
#DDOCFILES+=$(DDOCFIGROOT)/candy.ddoc
DDOCFILES+=$(DDOCROOT)/candy.ddoc
DDOCFILES+=$(DDOCMODULES)

DDOCFLAGS+=-D -o-


WAYS+=$(REPOROOT)/ddoc
