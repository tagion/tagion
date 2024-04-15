module tagion.script.standardnames;

enum StdNames {
    owner = "$Y",
    value = "$V",
    time = "$t",
    nonce = "$x",
    values = "$vals",
    derive = "$D",
    epoch = "#$epoch",
    epoch_number = "$epoch",
    locked_epoch = "#$locked_epoch",
    bullseye = "$eye",
    name = "#name",
    previous = "$prev",
    nodekey = "#$node",
    active = "#$active",
    signed = "$signed",
    archive_type = "$T",
    archive = "$a",
    contract = "#contract",
    msg = "$msg",
}

enum TagionDomain = "tagion";
enum TRTLabel = "#" ~ StdNames.owner;
