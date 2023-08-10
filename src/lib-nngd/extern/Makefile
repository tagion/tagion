.SUFFIXES:
.ONESHELL:
.NOTPARALLEL:

MMODULES=libnng

all: $(MMODULES)

clean: clean-$(MMODULES)

$(MMODULES): 
	@echo "Making "$@ &&\
	$(MAKE) -C $@/ 

clean-%:
	$(MAKE) -C $*/ clean

.PHONY: all clean $(MMODULES)
