module tagion.hashgraph.HashGraphBasic;

enum minimum_nodes = 3;
/++
 + Calculates the majority votes
 + Params:
 +     voting    = Number of votes
 +     node_sizw = Total bumber of votes
 + Returns:
 +     Returns `true` if the votes are more thna 2/3
 +/
@safe @nogc
bool isMajority(const uint voting, const uint node_size) pure nothrow {
    return (node_size >= minimum_nodes) && (3*voting > 2*node_size);
}
