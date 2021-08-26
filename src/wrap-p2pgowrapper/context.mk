DIR_P2P_SRC := ${call dir.self, src}
DIR_P2P_CGO := ${call dir.self, cgo}
DIR_P2P_BUILD := $(DIR_BUILD)/wraps/p2p-go-wrapper

WAYS += $(DIR_P2P_BUILD)/.way
wrap/p2p-go-wrapper: $(DIR_P2P_BUILD)/libp2p-go-wrapper.a
	${eval WRAPS += p2p-go-wrapper}
	${eval WRAPLIBS += $(DIR_P2P_BUILD)/libp2p-go-wrapper.a}

$(DIR_P2P_BUILD)/libp2p-go-wrapper.a: | ways $(DIR_P2P_CGO)/libp2p.di
	$(PRECMD)cp -r $(DIR_P2P_CGO)/ $(DIR_P2P_BUILD)/

$(DIR_P2P_CGO)/libp2p.di: $(DIR_P2P_CGO)/libp2p-go-wrapper.a
	$(PRECMD)dstep $(DIR_P2P_CGO)/libp2p-go-wrapper.h -o $(DIR_P2P_CGO)/libp2p.di --package p2p.cgo --global-import p2p.cgo.helper
	$(PRECMD)dstep $(DIR_P2P_CGO)/c_helper.h -o $(DIR_P2P_CGO)/helper.di --package p2p.cgo

$(DIR_P2P_CGO)/libp2p-go-wrapper.a:
	$(PRECMD)mkdir -p $(DIR_P2P_CGO)
	cp $(DIR_P2P_SRC)/c_helper.h $(DIR_P2P_CGO)
	$(PRECMD)cd $(DIR_P2P_SRC); go build -buildmode=c-archive -o $(DIR_P2P_CGO)/libp2p-go-wrapper.a