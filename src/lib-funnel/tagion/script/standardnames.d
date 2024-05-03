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
    sign = "$sign",
    signs = "$signs",
    archive_type = "$T",
    archive = "$a",
    hash_contract = "#contract",
    contract = "$contract",
    msg = "$msg",
    inputs = "$in",
    reads = "$read",
    script = "$run",
}

enum TagionDomain = "tagion";
enum TRTLabel = "#" ~ StdNames.owner;
