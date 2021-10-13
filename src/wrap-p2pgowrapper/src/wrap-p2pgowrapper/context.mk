REPO_P2PGOWRAPPER ?= git@github.com:tagion/p2pgowrapper.git
VERSION_P2PGOWRAPPER := dfc77c04e0395e09652c0daa25f9f19b77c2b1d6

DIR_P2PGOWRAPPER := $(DIR_BUILD_WRAPS)/p2pgowrapper

DIR_P2PGOWRAPPER_PREFIX := $(DIR_P2PGOWRAPPER)/lib
DIR_P2PGOWRAPPER_SRC := $(DIR_P2PGOWRAPPER)/src

define unit.dep.wrap-p2pgowrapper
${eval UNIT_WRAPS_TARGETS += wrap-p2pgowrapper}
${eval UNIT_WRAPS_INCFLAGS += -I$(DIR_P2PGOWRAPPER_PREFIX)}
${eval UNIT_WRAPS_LINKFILES += $(DIR_P2PGOWRAPPER_PREFIX)/libp2pgowrapper.a}
endef

wrap-p2pgowrapper: $(DIR_P2PGOWRAPPER_PREFIX)/p2p/cgo/libp2p.di $(DIR_P2PGOWRAPPER_PREFIX)/p2p/cgo/libp2pgowrapper.di $(DIR_P2PGOWRAPPER_PREFIX)/libp2pgowrapper.a
	@

clean-wrap-p2pgowrapper:
	${call unit.dep.wrap-p2pgowrapper}
	${call rm.dir, $(DIR_BUILD_WRAPS)}

$(DIR_P2PGOWRAPPER_PREFIX)/%: $(DIR_P2PGOWRAPPER_PREFIX)/.way $(DIR_P2PGOWRAPPER_PREFIX)/p2p/cgo/.way
	$(PRECMD)git clone --depth 1 $(REPO_P2PGOWRAPPER) $(DIR_P2PGOWRAPPER_SRC) 2> /dev/null || true
	$(PRECMD)git -C $(DIR_P2PGOWRAPPER_SRC) fetch --depth 1 $(REPO_P2PGOWRAPPER) $(VERSION_P2PGOWRAPPER) &> /dev/null || true
	$(PRECMD)cp $(DIR_P2PGOWRAPPER_SRC)/c_helper.h $(DIR_P2PGOWRAPPER_PREFIX)
	$(PRECMD)cd $(DIR_P2PGOWRAPPER_SRC); go build -buildmode=c-archive -o $(DIR_P2PGOWRAPPER_PREFIX)/libp2pgowrapper.a
	$(PRECMD)dstep $(DIR_P2PGOWRAPPER_PREFIX)/libp2pgowrapper.h -o $(DIR_P2PGOWRAPPER_PREFIX)/p2p/cgo/libp2p.di --package p2p.cgo --global-import p2p.cgo.helper
	$(PRECMD)dstep $(DIR_P2PGOWRAPPER_SRC)/c_helper.h -o $(DIR_P2PGOWRAPPER_PREFIX)/p2p/cgo/helper.di --package p2p.cgo