# graphview
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

## Large graph generation ( In case of OOM in graphviz )
Since graphviz is fails to generate large graphs we can use [hirep](/docs/tools/hirep) and [hibonutil](/docs/tools/hibonutil) in order to select only the newest events.

First see how many events are in the HiBONRange:

```
cat graph.hibon|hibonutil -pc|grep "event_view"|wc -l
143000
```
Generate the graph from a slice of the newest events. We need to include the first element in the graph since it contains the node_amount.
```
cat graph.hibon|hirep -l 0..1,120000..-1|graphview|neato -Tsvg -o graph.svg
```
