# TODO
export GOOS=android

ifndef CROSS_GO_ARCH
${error CROSS_GO_ARCH must be defined}
endif

export GOARCH=$(CROSS_GO_ARCH)
