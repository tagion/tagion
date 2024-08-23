## Build the docker image

```bash
$ docker build -t tagion --network=host
```

## Run mode0 network

Prebuilt images are hosted on docker hub under tagion/tagion name.
The image includes a statically linked tagion executable. By default it will run the `create_wallets.sh` To create a mode0 testing network with random wallets and a set amount of bills.

The `--rm` will ensure that the container is automatically removed when it's stopped

```
$ docker run --rm tagion/tagion:current
```

## Run mode1 network

The `gen_docker_compose.sh` generates a `docker-compose.yml` file and allows specifying a custom number number of nodes and a custom image to use.
View the help page for the script with `-h` for more info.  

```
# ./scripts/gen_docker_compose.sh
```

Start the network in different containers for a mode1 network.
Use a custom prefix name `-p` flag. Default is to use the name of the directory you're in.

```
$ docker compose -p tgn_test up
```

To stop & remove all containers + volumes run

```
$ docker compose -p tgn_test down -v
```
