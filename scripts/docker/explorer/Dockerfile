# Build image
FROM alpine:20240606 as build

# set the --build-arg DEBUG=1 to build the executable with debug information
ARG DEBUG

# Install deps
WORKDIR /tmp/
RUN apk add --no-cache git autoconf clang libtool cmake ldc make automake

# Build
COPY . ./src
WORKDIR /tmp/src/
RUN echo DFLAGS+=--static >> local.mk && \
if [[ "$DEBUG" == "" ]]; then \
    echo DFLAGS+=--O3 >> local.mk; \
    echo DEBUG_ENABLE= >> local.mk; \
fi

RUN make install INSTALL=/usr/local/bin/ DC=ldc2

# Final image
FROM alpine:20240606
WORKDIR /usr/local/
ENV NODE_NUMBER=0
RUN apk add bash supervisor
RUN mkdir -p /tmp/webapp/static/explorer
COPY --from=build /tmp/src/build/x86_64-linux/tmp/nng/src/tools/nngcat/nngcat bin/
COPY --from=build /usr/local/bin bin/
COPY --from=build /tmp/src/scripts/create_wallets.sh /usr/local/bin/
COPY --from=build /tmp/src/scripts/docker/explorer/start.sh /usr/local/app/
COPY --from=build /tmp/src/scripts/docker/explorer/htdocs/* /tmp/webapp/static/explorer/
COPY --from=build /tmp/src/scripts/docker/explorer/supervisord.conf /usr/local/app/

WORKDIR /usr/local/app
HEALTHCHECK CMD hirpc -m dartBullseye | nngcat --req0 --dial abstract://node$NODE_NUMBER/DART_NEUEWELLE -F -
CMD create_wallets.sh
CMD ["/usr/bin/supervisord"]


