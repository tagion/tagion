module tagion.script.standardnames;

import tagion.communication.HiRPC;

@safe:
enum StdNames {
    owner = "$Y",
    value = "$V",
    time = "$t",
    nonce = "$x",
    values = "$vals",
    derive = "$D",
    epoch = "#$epoch",
    locked_epoch = "#$locked_epoch",
    bullseye = "$eye",
    name = "#name",
    previous = "$prev",
    nodekey = "#$node",
    signed = "$signed",
}

enum TagionDomain = "tagion";
