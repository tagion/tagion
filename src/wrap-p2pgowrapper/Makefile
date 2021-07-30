# Will add support for cross compilation triplet and choose dest folder automatically.

NAME_P2P := libp2p
PATH_P2P_SRC_GO := ${realpath ${dir_self}/go/p2p}
PATH_P2P_SRC_D := ${realpath ${dir_self}/d/p2p}
PATH_P2P_CGO := ${PATH_P2P_SRC_D}/cgo

DFILES := ${PATH_P2P_SRC_D}/node ${PATH_P2P_SRC_D}/connection ${PATH_P2P_SRC_D}/go_helper ${PATH_P2P_SRC_D}/callback
GOLIBFILES := $(PATH_P2P_CGO)/libp2pgo.di $(PATH_P2P_CGO)/helper.di $(PATH_P2P_CGO)/libp2pgo.a

ifeq ($(OS),Darwin)
LDCFLAGS += -L-framework -LCoreFoundation -L-framework -LSecurity
endif

check/p2p:
	${call log.line, System check for libp2p is not implemented yet}

wrap/p2p: $(PATH_P2P_CGO)/$(NAME_P2P)go.di
	cd $(PATH_P2P_SRC_D); ldc2 -lib $(DFILES) $(GOLIBFILES) $(LDCFLAGS) -of $(DIR_BUILD)/wraps/$(NAME_P2P).a

$(PATH_P2P_CGO)/$(NAME_P2P)go.di: $(PATH_P2P_CGO)/$(NAME_P2P)go.a
	dstep $(PATH_P2P_CGO)/$(NAME_P2P)go.h -o $(PATH_P2P_CGO)/$(NAME_P2P)go.di --package p2p.cgo --global-import p2p.cgo.helper
	dstep $(PATH_P2P_CGO)/c_helper.h -o $(PATH_P2P_CGO)/helper.di --package p2p.cgo

$(PATH_P2P_CGO)/$(NAME_P2P)go.a:
	mkdir -p $(PATH_P2P_CGO)
	cp $(PATH_P2P_SRC_GO)/c_helper.h $(PATH_P2P_CGO)
	cd $(PATH_P2P_SRC_GO); go build -buildmode=c-archive -o $(PATH_P2P_CGO)/$(NAME_P2P)go.a