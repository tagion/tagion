FROM ubuntu:18.04

RUN apt-get update
RUN apt-get upgrade -y
RUN apt-get install libssl1.1 -y
ENV GODEBUG=cgocheck=0

WORKDIR /usr/src/app/

COPY ./bin/dtest .

# CMD ["./p2pwave"]

ENTRYPOINT ["./dtest"]
# CMD ["./tagiondart-master.sh"]