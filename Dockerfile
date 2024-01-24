# Use a base image with Nix and necessary dependencies
FROM nixos/nix:latest

# Set the working directory
WORKDIR /app

# Copy the Nix expressions into the container
COPY . /app

# Run Nix to build the Tagion project
RUN nix build --extra-experimental-features nix-command --extra-experimental-features flakes 

# Set the entry point for the container
ENTRYPOINT ["/app/result/bin/tagion"]
