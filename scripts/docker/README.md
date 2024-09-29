# How to build the docker image with explorer

- from the repo root 
`docker build . -t tagion/tagion:explorer -f scripts/docker/explorer/Dockerfile`

- run
`docker run --publish 0.0.0.0:8080:8080 tagion/tagion:explorer`

- open explorer at http://127.0.0.1:8080/static/explorer


