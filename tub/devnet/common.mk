TAGIONCMD_DOCKER := docker run -t --rm --workdir /tgn/node/data -v $(DDEVNET):/tgn/node/data tagion/playnet
TAGIONCMD := $(TAGIONCMD_DOCKER)

define tagioncmd
$(TAGIONCMD) bash -c '${strip $1}' 
endef

DEVNET_PIN := 1111
DEVNET_QUESTIONS := 1,1,1,1
DEVNET_ANSWERS := 1,1,1,1