/// standardnames for archives and communication
module tagion.script.standardnames;

///
enum StdNames {
    owner = "$Y", /// Public key
    value = "$V", /// Tagion currency
    time = "$t", /// i64, Sdt time
    nonce = "$x", /// random ubyte array
    values = "$vals", /// TagionBill array
    derive = "$D",
    epoch_number = "$epoch",
    bullseye = "$eye",
    name = "$name", /// string, a name
    previous = "$prev", /// Fingerprint
    sign = "$sign", /// Signature
    signs = "$signs", /// Signature array
    archive_type = "$T",
    archive = "$a",
    contract = "$contract", /// Contract(SMC)
    msg = "$msg",
    inputs = "$in", /// DARTIndex array
    reads = "$read", /// DARTIndex array
    script = "$run", /// Document, smart contract script
    address = "$addr", /// String, address in 'multiaddr' format
    state = "$state", /// An enumerated value indicating the state, contextual to the record which it is stored in 
}

///
enum HashNames {
    domain_name = "#name", /// string, domain name hash record for project information
    hash_contract = "#contract", /// DARTIndex of a contract
    nodekey = "#$node", /// Public key
    active = "#$active",
    locked_epoch = "#$locked_epoch",
    epoch = "#$epoch", /// i64, hash record pointing at epoch specific data
    trt_owner = "#$Y",
}

/// The name used for the #name record for the tagion network
enum TagionDomain = "tagion";
