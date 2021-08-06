# Will add support for cross compilation triplet and choose dest folder automatically.

NAME_P2P := libp2p-go-wrapper
PATH_P2P_SRC := ${call dir.self, src}
PATH_P2P_CGO := ${call dir.self, cgo}

check/p2p-go-wrapper:
	${call log.line, System check for libp2p is not implemented yet}

wrap/p2p-go-wrapper: ways $(DIR_BUILD)/wraps/$(NAME_P2P).a $(PATH_P2P_CGO)/libp2p.di

$(DIR_BUILD)/wraps/$(NAME_P2P).a: $(PATH_P2P_CGO)/libp2p.di
	$(PRECMD)cp $(PATH_P2P_CGO)/$(NAME_P2P).a $(DIR_BUILD)/wraps

$(PATH_P2P_CGO)/libp2p.di: $(PATH_P2P_CGO)/$(NAME_P2P).a
	$(PRECMD)dstep $(PATH_P2P_CGO)/$(NAME_P2P).h -o $(PATH_P2P_CGO)/libp2p.di --package p2p.cgo --global-import p2p.cgo.helper
	$(PRECMD)dstep $(PATH_P2P_CGO)/c_helper.h -o $(PATH_P2P_CGO)/helper.di --package p2p.cgo

$(PATH_P2P_CGO)/$(NAME_P2P).a:
	$(PRECMD)mkdir -p $(PATH_P2P_CGO)
	cp $(PATH_P2P_SRC)/c_helper.h $(PATH_P2P_CGO)
	$(PRECMD)cd $(PATH_P2P_SRC); go build -buildmode=c-archive -o $(PATH_P2P_CGO)/$(NAME_P2P).a