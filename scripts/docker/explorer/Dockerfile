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
RUN apk add --no-cache bash sed supervisor
RUN mkdir -p /usr/local/app/webapp/static/explorer
RUN ln -s /usr/local/app/webapp /tmp/
COPY --from=build /tmp/src/build/x86_64-linux/tmp/nng/src/tools/nngcat/nngcat bin/
COPY --from=build /usr/local/bin bin/
COPY --from=build /tmp/src/scripts/docker/explorer/create_wallets.sh /usr/local/app
COPY --from=build /tmp/src/scripts/docker/explorer/htdocs/* /usr/local/app/webapp/static/explorer
COPY --from=build /tmp/src/scripts/docker/explorer/supervisord.conf /usr/local/app/
COPY --from=build /tmp/src/scripts/docker/explorer/shell.json /usr/local/app/

WORKDIR /usr/local/app
HEALTHCHECK CMD hirpc -m dartBullseye | nngcat --req0 --dial abstract://node$NODE_NUMBER/DART_NEUEWELLE -F -

ENTRYPOINT ./create_wallets.sh -b /usr/local/bin/ -n 5 -w 5 -k ./network/ -t ./wallets/ &&\
    wallet -x 0001 --list /usr/local/app/wallets/wallet1.json |grep 2024 |tr -s ' ' |cut -d" " -f4 > pks.txt &&\ 
    sed -e '/help_valid_indices: `/r./pks.txt' /usr/local/app/webapp/static/explorer/wconfig.js > /usr/local/app/webapp/static/explorer/temp &&\ 
    mv /usr/local/app/webapp/static/explorer/temp /usr/local/app/webapp/static/explorer/wconfig.js &&\
    /usr/bin/supervisord



