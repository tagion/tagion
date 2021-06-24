define LIBMAKE
ALL_LIBS+=${call GETLIB,$(1)}
#ifeq (${call GETLIB,$(1)} ,$(LIBRARY) )
${call GETLIB,$(1)}:
	cd $(DIR_LAB); $(MAKE) -C $(2) lib
	echo $(LIBS)
#endif
endef

define SUBLIBS
${call LIBMAKE,tagion_basic,tagion_basic}
${call LIBMAKE,tagion_utils,tagion_utils}
${call LIBMAKE,tagion_hibon,tagion_hibon}
${call LIBMAKE,tagion_gossip,tagion_gossip}
${call LIBMAKE,tagion_hashgraph,tagion_hashgraph}
${call LIBMAKE,tagion_communication,tagion_communication}
${call LIBMAKE,tagion_dart,tagion_dart}
${call LIBMAKE,tagion_crypto,tagion_crypto}
${call LIBMAKE,tagion_script,tagion_funnel}
${call LIBMAKE,tagion_services,tagion_services}
${call LIBMAKE,tagion_wasm,tagion_wasm}
endef

${eval $(SUBLIBS)}


sublib: $(LIBS)

INFO+=info-libs
info-libs:
	@echo "# Sublibs info"
	@echo "ALL_LIBS = $(ALL_LIBS)"
