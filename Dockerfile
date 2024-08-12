# Build image
FROM alpine:20240606 as build

# Install deps
WORKDIR /tmp/
RUN apk add --no-cache git clang cmake ldc make ninja

# Build
COPY . ./src
WORKDIR /tmp/src/
RUN echo DFLAGS+=--static --O3 >> local.mk
RUN make tagion install CMAKE_GENERATOR=Ninja INSTALL=/usr/local/bin/ DC=ldc2 DEBUG_ENABLE=
RUN strip /usr/local/bin/tagion


# Final image
FROM alpine:20240606
WORKDIR /usr/local/
RUN apk add bash
COPY --from=build /usr/local/bin bin/
COPY ./scripts/create_wallets.sh /usr/local/bin/

WORKDIR /usr/local/app
CMD create_wallets.sh && neuewelle /usr/local/app/mode0/tagionwave.json --keys /usr/local/app/mode0 < /usr/local/app/keys
