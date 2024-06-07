.SUFFIXES:
.ONESHELL:
.NOTPARALLEL:

MMODULES=libnng

all: $(MMODULES)

clean: clean-$(MMODULES)

proper: proper-$(MMODULES)

$(MMODULES): 
	@echo "Making "$@ &&\
	$(MAKE) -C $@/ 

clean-%:
	$(MAKE) -C $*/ clean

proper-%:
	$(MAKE) -C $*/ clean
	$(MAKE) -C $*/ proper

.PHONY: all clean $(MMODULES)
