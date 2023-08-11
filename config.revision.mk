REVISION_FILE?=$(DBUILD)/revision.mixin
GIT_BRANCH:=${shell git rev-parse --abbrev-ref HEAD}
GIT_HASH:=${shell git rev-parse HEAD}
GIT_INFO:=${shell git  config --get remote.origin.url}
GIT_REVNO:=${shell git log --pretty=format:'%h'|wc -l}
GIT_DATE:=${shell date +'%F %H:%M'}
GIT_USER:=${shell git config user.name}
GIT_EMAIL:=${shell git config user.email}
CC_VERSION:=${shell ${CC} --version | head -1}
DC_VERSION:=${shell ${DC} --version | head -1}

DFLAGS+=$(DIMPORTFILE)$(DBUILD)
