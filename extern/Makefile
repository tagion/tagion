
ifeq ($(NNG_WITH_MBEDTLS),ON)
	DOMBEDTLS=mk-mbedtls
	NNGFLAGS=-D NNG_ENABLE_TLS=ON -D MBEDTLS_ROOT_DIR=$(abspath mbedtls/build) -D CMAKE_INSTALL_PREFIX:PATH=.
else
	DOMBEDTLS=
	NNGFLAGS=-D CMAKE_INSTALL_PREFIX:PATH=.
endif

.ONESHELL:

all: $(DOMBEDTLS) mk-nng

clean: clean-mbedtls clean-nng

mk-mbedtls:
	mkdir -p mbedtls/build
	cd mbedtls/build
	cmake ..
	cmake --build .
	rm -f library/library
	ln -s library lib
mk-nng:
	mkdir -p nng/build
	cd nng/build
	cmake $(NNGFLAGS) ..
	cmake --build . --target install --config Release

clean-nng:
	rm -rf nng/build

clean-mbedtls:
	rm -rf mbedtls/build

.PHONY: mk-mbedtls mk-nng

