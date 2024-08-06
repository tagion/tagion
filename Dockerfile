# Build image
FROM ubuntu:24.10 as build

# Install deps
WORKDIR /tmp/
RUN apt-get update && apt-get install -y git autoconf build-essential libtool cmake wget
RUN wget https://downloads.dlang.org/releases/2024/dmd_2.108.1-0_amd64.deb
RUN dpkg -i dmd_2.108.1-0_amd64.deb

# Build
COPY . ./src
WORKDIR /tmp/src/
RUN make tagion install INSTALL=/usr/local/bin/
RUN strip /usr/local/bin/tagion
# RUN ./scripts/create_wallets.sh -b /usr/local/bin/ -k /usr/local/app/network -t /usr/local/app/wallets && cp keys /usr/local/app/


# Final image
FROM ubuntu:24.10
WORKDIR /usr/local/
COPY --from=build /usr/local/bin bin/
# COPY --from=build /usr/local/app app/

WORKDIR /usr/local/app
CMD neuewelle /usr/local/app/network/tagionwave.json --keys /usr/local/app/wallets < /usr/local/app/keys
