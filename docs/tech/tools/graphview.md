# graphview
> Tool for generating hashgraph graph visualisations and produces a .svg or .html file. 
The tool takes a HiBONRange and produced from the 
[EventView](https://ddoc.tagion.org/tagion.hashgraphview.EventView.fwrite.html).

```
Documentation: https://docs.tagion.org/

Usage:
graphview [<option>...] <in-file>

Where:
<in-file>           Is an input file in .hibon format

Example:
# SVG
graphview Alice.hibon index.svg
# HTML multi-graph
graphview *_graph.hibon index.html
<option>:
   --version display the version
-v --verbose Prints more debug information
       --svg Generate raw svg to stdout else html
-s --segment Segment of graph (from:to)
-S   --order Segment by order
-h    --help This help information.
```


## Generate a svg file
This will generate a single svg file
```
graphview Node_00_graph.hibon index.svg
```
## Generate a html file
The same as with the .svg just change the file extension to .html
```
graphview Node_00_graph.hibon index.html
```
To display more than one graph the the same page just a a list of files.
```
graphview *_00_graph.hibon index.html
```

## Generate a segment of the graph
To cut out a segment of the graph is done by.
This will only produces a graph with the event from [10..16[.
```
graphview Node_00_graph.hibon -s10:16 index.svg
```
The high of the graph can also be cut out with the `--order` switch like.
```
graphview Node_00_graph.hibon -s200:332 --order index.svg
```

## Large graph generation 
Because the graph takes a hibon-stream the command [hirep](/docs/tools/hirep) can be used to grep out events.

First see how many events are in the HiBONRange with [hibonutil](/docs/tools/hibonutil):

```
hirep -r event_view Node_00_graph.hibon|hibonutil -ct|wc -l
75533
```
Generate the graph from a slice of the newest events. We need to include the first element in the graph since it contains the node_amount.
```
hirep -r event_view Node_00_graph.hibon -l74000..-1|graphview index.svg
```

### SVG example

```
graphview Node_00_graph.hibon -s642:656 --order index.svg
```

![SVG example](/figs/graphview_example_1.svg)

### HTML example

```
graphview *_graph.hibon -s4..6 index.html
```
<iframe src="/docs/figs/graphview_example_2.html" title="Graphview html example"></iframe>

