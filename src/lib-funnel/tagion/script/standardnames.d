/// standardnames for archives and communication
module tagion.script.standardnames;

///
enum StdNames {
    owner = "$Y", // Public key
    value = "$V", // Tagion currency
    time = "$t", // i64, Sdt time
    nonce = "$x", // random ubyte array
    values = "$vals", // TagionBill array
    derive = "$D",
    epoch = "#$epoch", // i64, hash record pointing at epoch specific data
    epoch_number = "$epoch",
    locked_epoch = "#$locked_epoch",
    bullseye = "$eye",
    domain_name = "#name", // string, domain name hash record for project information
    name = "$name", // string, a name
    previous = "$prev", // Fingerprint
    nodekey = "#$node", // Public key
    active = "#$active",
    sign = "$sign", // Signature
    signs = "$signs", // Signature array
    archive_type = "$T",
    archive = "$a",
    hash_contract = "#contract", // DARTIndex of a contract
    contract = "$contract", // Contract(SMC)
    msg = "$msg",
    inputs = "$in", // DARTIndex array
    reads = "$read", // DARTIndex array
    script = "$run", // Document, smart contract script
    address = "$addr", // String, address in 'multiaddr' format
    state = "$state", // An enumerated value indicating the state, contextual to the record which it is stored in 
}

enum TagionDomain = "tagion";
enum TRTLabel = "#" ~ StdNames.owner;
