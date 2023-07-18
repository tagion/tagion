

all: nng

clean: clean-nng

nng: 
	mkdir -p nng/build && \
	cd nng/build && \
	cmake -DCMAKE_INSTALL_PREFIX:PATH=. .. && \
	cmake --build . --target install --config Release

clean-nng:
	rm -rf nng/build



