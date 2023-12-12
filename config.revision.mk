REVISION_FILE?=$(DBUILD)/revision.mixin
DFLAGS+=$(DIMPORTFILE)$(DBUILD)

GIT_BRANCH:=${shell git rev-parse --abbrev-ref HEAD}
GIT_HASH:=${shell git rev-parse HEAD}
GIT_INFO:=${shell git  config --get remote.origin.url}
GIT_REVNO:=${shell git log --pretty=format:'%h'|wc -l}
GIT_USER:=${shell git config user.name}
GIT_EMAIL:=${shell git config user.email}
CC_VERSION:=${shell ${CC} --version | head -1}
DC_VERSION:=${shell ${DC} --version | head -1}

# Finds the newest git version tag eg v.1.0.1
VERSION_REF:=$(shell git tag -l 'v[0-9]*.[0-9]*.[0-9]*' --sort=-v:refname | head -n 1)
VERSION_HASH:=${shell git rev-parse $(VERSION_REF)}

ifneq ($(VERSION_HASH),$(GIT_HASH))
# Not exactly sure what to call this, so now it's dev
DEVSTRING:=+dev
endif

UNSTAGED_CHANGES:=$(shell git status --porcelain)
ifneq ($(strip $(UNSTAGED_CHANGES)),)
DIRTYSTRING:=+dirty
endif

VERSION_STRING:=$(VERSION_REF)$(DEVSTRING)$(DIRTYSTRING)

test-32:
	@echo $(VERSION_STRING)
	@echo $(VERSION_REF)
	@echo $(VERSION_HASH)
