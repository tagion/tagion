#
# Build for WASI-druntime
#

WASI_DRUNTIME_ROOT?=$(TOOLS)/wasi-druntime
WASI_DRUNTIME_REPO?=git@github.com:tagion/wasi-druntime.git 

test48:
	echo $(TOOLS)
	echo $(WASI_DRUNTIME_ROOT)

wasi: $(WASI_DRUNTIME_ROOT)/.git  
	$(MAKE) -C $(WASI_DRUNTIME_ROOT) prebuild 

wasi-%: $(WASI_DRUNTIME_ROOT)/.git 
	$(MAKE) -C $(WASI_DRUNTIME_ROOT) $*

env-wasi:
	$(PRECMD)
	$(call log.header, $@ :: env)
	$(call log.kvp, WASI_DRUNTIME_ROOT, $(WASI_DRUNTIME_ROOT))
	$(call log.kvp, WASI_DRUNTIME_REPO, $(WASI_DRUNTIME_REPO))
	$(call log.close)

.PHONY: env-wasi

env: env-wasi
		

help-wasi:
	$(PRECMD)
	$(call log.header, $@ :: help)
	$(call log.kvp, "make wasi", "Prebuild druntime")
	$(call log.kvp, "make wasi-<tag>", "Execute the make <tag> on the wasi-druntime")
	$(call log.kvp, "make wasi-run", "Will run the simple test program")
	$(call log.kvp, "make proper-wasi", "Will remove wasi-druntime for the build")
	$(call log.close)

.PHONY: help-wasi

help: help-wasi

$(WASI_DRUNTIME_ROOT)/.git: $(TOOLS)/.way
	$(PRECMD)
	cd $(TOOLS); git clone --recurse-submodules $(WASI_DRUNTIME_REPO)

proper-wasi:
	$(PRECMD)
	$(call log.header, $@ :: proper)
	$(RMDIR) $(WASI_DRUNTIME_ROOT)

.PHONY: proper-wasi

proper: proper-wasi

	
