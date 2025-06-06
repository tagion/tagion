# Epoch

An epoch is the product of the hashgraph. It is an ordered list of EventPackages which contains payloads that clients have submitted to the graph. Epochs are created asynchronously on each node but are all deterministic meaning that each node will produce the same epoch at some point in time.
The epoch is used for the transcript which checks for double spend among other things.   
