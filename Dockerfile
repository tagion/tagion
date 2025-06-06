# Build image
FROM alpine:3.21 as build

# Install deps
WORKDIR /tmp/
RUN apk add --no-cache git autoconf clang libtool cmake ldc make automake

# Build
COPY . ./src
WORKDIR /tmp/src/
RUN echo DFLAGS+=--static >> local.mk

RUN make tagion install SYMBOLS_ENABLE=1 DEBUG_ENABLE=1 RELEASE=1 INSTALL=/usr/local/bin/ DC=ldc2

# Final image
FROM alpine:3.21
WORKDIR /usr/local/
ENV NODE_NUMBER=0
RUN apk add bash
COPY --from=build /tmp/src/build/x86_64-linux/tmp/nng/src/tools/nngcat/nngcat bin/
COPY --from=build /usr/local/bin bin/
COPY ./scripts/create_wallets.sh /usr/local/bin/

WORKDIR /usr/local/app
HEALTHCHECK CMD hirpc -m dartBullseye | nngcat --req0 --dial abstract://node$NODE_NUMBER/DART_NEUEWELLE -F -
CMD create_wallets.sh && neuewelle /usr/local/app/mode0/tagionwave.json --keys /usr/local/app/mode0 < /usr/local/app/keys
