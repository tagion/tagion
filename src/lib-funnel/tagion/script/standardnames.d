module tagion.script.standardnames;

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
    active = "#$active",
    signed = "$signed",
    archive_type = "$T",
    archive = "$a",
    hash = "#hash",
}

enum TagionDomain = "tagion";
enum TRTLabel = "#" ~ StdNames.owner;
