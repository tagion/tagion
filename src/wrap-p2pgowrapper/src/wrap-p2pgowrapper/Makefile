# Clone and make according to variables
# Will add support for crossc compilation triplet and choose dest folder automatically.

NAME_P2P := libp2p
PATH_SRC_GO_P2P := ${dir_self}/go-wrapper
PATH_SRC_D_P2P := ${dir_self}/src/d/p2p
PATH_OUT_C := ${dir_self}/c-out
PATH_OUT_D := ${dir_self}/d-out

check/p2p:
	${call log.line, System check for libp2p is not implemented yet}

wrap/p2p:
	mkdir -p $(PATH_OUT_C)
	mkdir -p $(PATH_OUT_D)
	cp $(PATH_SRC_GO_P2P)/c_helper.h $(PATH_OUT_C)
	cd $(PATH_SRC_GO_P2P); go build -buildmode=c-archive -o ../c-out/$(NAME_P2P).a
	dstep $(PATH_OUT_C)/libp2p.h -o $(PATH_OUT_D)/libp2p.di --package p2p.lib --global-import p2p.lib.helper
	dstep $(PATH_OUT_C)/c_helper.h -o $(PATH_OUT_D)/helper.di --package p2p.lib
	mv $(PATH_OUT_C)/$(NAME_P2P).a $(PATH_OUT_D)/$(NAME_P2P).a
	mkdir -p $(PATH_SRC_D_P2P)/lib
	cp $(PATH_OUT_D)/* $(PATH_SRC_D_P2P)/lib
	cd $(PATH_SRC_D_P2P); ldc2 -lib node connection go_helper callback lib/libp2p.di lib/helper.di lib/libp2p.a -L-framework -LCoreFoundation -L-framework -LSecurity -of ./libp2p.a
	mv $(PATH_SRC_D_P2P)/libp2p.a $(DIR_BUILD)/wraps/libp2p.a

# $(DIR_BUILD)/wraps/$(NAME_P2P).a