# Docker container with testable network and tagionshell with explorer

## How to build

(from the repo root) 

docker build . -t tagion/tagion:explorer -f scripts/docker/explorer/Dockerfile

## How to run

docker run --publish 0.0.0.0:8080:8080 tagion/tagion:explorer

## How to watch

http://localhost:8080/static/explorer


