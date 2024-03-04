# Developing with Nix

Nix is a package manager for building reproducible packages accross machines.  
You can see how to install nix at https://nixos.org/download

The tagion repo contains a `flake.nix` which means that it provides a variety of outputs.
Currently outputs are only defined for `x86_64-linux`

## Enabled Nix Flakes

Nix flakes are an experimental feature of Nix and need to be enabled.
You can see more about flakes and how they can be enabled here https://nixos.wiki/wiki/Flakes#Enable_flakes_temporarily

How you enable flakes may depend on how you use nix and how you want to use flakes.

The most universal way to enable them is like this.
```bash
$ echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
```

## Start A development shell

This will enter a new shell with all the tool needed to develop tagion

```bash
$ nix develop
```

## Build tagion

This will compile tagion, and output an executable in result/bin
```bash
$ nix build
```

## Run tests

```bash
$ nix flake check
```

## Automatic development shell

Install direnv. We recommend a variation of it called [nix-direnv](https://github.com/nix-community/nix-direnv?tab=readme-ov-file#installation)

Inside the tagion working directory type the command.

```bash
$ direnv allow
```

Now every time you enter the directory the development shell will automatically be activated.
