# Tagil Maker

Component of [Tagil](https://github.com/tagion/tagil) build system.

Maker consist of useful [GNU Make](https://www.gnu.org/software/make/) scripts that will help you compile and test Tagion core libraries.

## Getting Started

```bash
make help # Will show available commands
make add/lib/[core lib name] # Will add library module
make add/bin/[core lib name] # Will add binary module
make add/wrap/[core lib name] # Will add external library wrapper module
```

## Troubleshooting

> Please, report bugs using GitHub Issues. As problems appear, we will add solutions in this section.

### No rule to make target
It means you don't have the required dependency.

1. Define the type of dependency: `lib` or `wrap`
1. Do `make add/lib/[library]` or `make add/wrap/[wrapper]`

Try to compile again.

## Maintainers

- [@vladpazych](https://github.com/vladpazych)