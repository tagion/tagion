#
# Build for WASI-druntime
#

WASI_DRUNTIME_ROOT?=$(TOOLS)/wasi-druntime
WASI_DRUNTIME_REPO?=git@github.com:tagion/wasi-druntime.git 

test48:
	echo $(TOOLS)
	echo $(WASI_DRUNTIME_ROOT)

wasi: $(WASI_DRUNTIME_ROOT)/.git  
	$(MAKE) -C $(WASI_DRUNTIME_ROOT) prebuild run

$(WASI_DRUNTIME_ROOT)/.git: $(TOOLS)/.way
	$(PRECMD)
	cd $(TOOLS); git clone --recurse-submodules $(WASI_DRUNTIME_REPO) 
	
