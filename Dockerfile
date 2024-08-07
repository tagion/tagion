# Build image
FROM alpine:20240606 as build

# Install deps
WORKDIR /tmp/
RUN apk add --no-cache git autoconf clang libtool cmake dmd make automake

# Build
COPY . ./src
WORKDIR /tmp/src/
RUN make tagion install INSTALL=/usr/local/bin/
RUN strip /usr/local/bin/tagion
# RUN ./scripts/create_wallets.sh -b /usr/local/bin/ -k /usr/local/app/network -t /usr/local/app/wallets && cp keys /usr/local/app/


# Final image
FROM alpine:20240606
WORKDIR /usr/local/
RUN apk add libunwind
RUN ln -s libunwind.so.8.1.0 /usr/lib/libunwind.so.1
COPY --from=build /usr/local/bin bin/
COPY ./scripts/create_wallets.sh /usr/local/bin/
# COPY --from=build /usr/local/app app/

WORKDIR /usr/local/app
CMD neuewelle /usr/local/app/network/tagionwave.json --keys /usr/local/app/wallets < /usr/local/app/keys
