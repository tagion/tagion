# Will add support for cross compilation triplet and choose dest folder automatically.

NAME_P2P := libp2p
PATH_P2P_SRC := ${realpath ${dir.self}/src}
PATH_P2P_CGO := ${dir.self}/cgo

check/p2p:
	${call log.line, System check for libp2p is not implemented yet}

wrap/p2p: $(DIR_BUILD)/wraps/$(NAME_P2P).a

$(DIR_BUILD)/wraps/$(NAME_P2P).a: $(PATH_P2P_CGO)/$(NAME_P2P).di
	$(PRECMD)cp $(PATH_P2P_CGO)/$(NAME_P2P).a $(DIR_BUILD)/wraps

$(PATH_P2P_CGO)/$(NAME_P2P).di: $(PATH_P2P_CGO)/$(NAME_P2P).a
	$(PRECMD)dstep $(PATH_P2P_CGO)/$(NAME_P2P).h -o $(PATH_P2P_CGO)/$(NAME_P2P).di --package p2p.cgo --global-import p2p.cgo.helper
	$(PRECMD)dstep $(PATH_P2P_CGO)/c_helper.h -o $(PATH_P2P_CGO)/helper.di --package p2p.cgo

$(PATH_P2P_CGO)/$(NAME_P2P).a:
	$(PRECMD)mkdir -p $(PATH_P2P_CGO)
	cp $(PATH_P2P_SRC)/c_helper.h $(PATH_P2P_CGO)
	$(PRECMD)cd $(PATH_P2P_SRC); go build -buildmode=c-archive -o $(PATH_P2P_CGO)/$(NAME_P2P).a