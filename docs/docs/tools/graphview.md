# Graphview
> Tool for generating hashgraph graph visualisations with graphviz neato. 
The tool takes a HiBONRange and returns the corresponding dot hashgraph format.

## Generating dot files
```
graphview graph.hibon > file.dot
```

## Generate svg with graphviz neato. 
```
graphview graph.hibon | neato -Tsvg -o graph.svg
```

