REPO_DSTEP ?= git@github.com:tagion/fork-dstep.git
VERSION_DSTEP := bc5cda92a97f44c333c493cda4e4cf686b7244f5

DSRC_DSTEP := $(DIR_TUB)/dstep




MAKETOOLS += dstep
dstep: $(DSRC_DSTEP)/.src
	$(PRECMD)cd $(DSRC_DSTEP);


$(DSRC_DSTEP)/.src:
	$(PRECMD)git clone --depth 1 $(REPO_DSTEP) $(DSRC_DSTEP) 2> /dev/null || true
	$(PRECMD)git -C $(DSRC_DSTEP) fetch --depth 1 $(DSRC_DSTEP) $(VERSION_DSTEP) &> /dev/null || true
	$(PRECMD)touch $@