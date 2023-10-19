.ONESHELL:


all: mk-nng

clean: clean-nng

mk-nng: 
	mkdir -p nng/build 
	cd nng/build 
	cmake -DNNG_ENABLE_TLS=ON -DMBEDTLS_ROOT_DIR= -DCMAKE_INSTALL_PREFIX:PATH=. .. 
	cmake --build . --target install --config Release

clean-nng:
	rm -rf nng/build

.PHONY: mk-nng

