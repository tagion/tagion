/// Common tagion records
module tagion.script.common;

@safe:

// import std.algorithm;
import std.array;
import std.range;
import std.sumtype;
import tagion.basic.Types;
import tagion.basic.Types : Buffer;
import tagion.crypto.SecureInterfaceNet;
import tagion.crypto.Types;
import tagion.dart.DARTBasic;
import tagion.hibon.BigNumber;
import tagion.hibon.Document;
import tagion.hibon.HiBONRecord;
import tagion.script.ScriptException;
import tagion.script.TagionCurrency;
import tagion.script.standardnames;
import tagion.utils.StdTime;

/**
 * Tagion bill
 */
@recordType("TGN")
struct TagionBill {
    @label(StdNames.value) TagionCurrency value; /// Tagion bill 
    @label(StdNames.time) sdt_t time; /// Time stamp
    @label(StdNames.owner) Pubkey owner; /// owner key
    @label(StdNames.nonce) @optional Buffer nonce; /// extra nonce 
    mixin HiBONRecord!(
            q{
                this(const(TagionCurrency) value, const sdt_t time, Pubkey owner, Buffer nonce) pure nothrow {
                    this.value = value;
                    this.time = time;
                    this.owner = owner;
                    this.nonce = nonce;
        }});
}

/** 
 * Tagion contract
 * inputs will be consumed in the execution
 * Reads are extract optional data for the smart contract
 */
@recordType("SMC")
struct Contract {
    @label(StdNames.inputs) const(DARTIndex)[] inputs; /// Hash pointer to input (DART)
    @label(StdNames.reads) @optional @(filter.Initialized) const(DARTIndex)[] reads; /// Hash pointer to read-only input (DART)
    @label(StdNames.script) Document script; /// the Smart contract to be executed
    bool verify() const pure nothrow @nogc {
        return (inputs.length > 0);
    }

    mixin HiBONRecord!(
        q{
                this(const(DARTIndex)[] inputs, const(DARTIndex)[] reads, Document script) pure nothrow {
                    this.inputs = inputs;
                    this.reads = reads;
                    this.script = script; 
                }
                this(immutable(DARTIndex)[] inputs, immutable(DARTIndex)[] reads, immutable(Document) script) immutable pure nothrow {
                    this.inputs = inputs;
                    this.reads = reads;
                    this.script = script; 
                }
            });
}

/**
 *  Tagion SignedContract
 *  Includes the contract to be executed and the signatures of all inputs sorted by the dartIndex of the inputs
 */
@recordType("SSC")
struct SignedContract {
    @label(StdNames.signs) const(Signature)[] signs; /// Signature of all inputs
    @label(StdNames.contract) Contract contract; /// The contract must signed by all inputs
    mixin HiBONRecord!(
        q{
                this(const(Signature)[] signs, Contract contract) pure nothrow {
                    this.signs = signs;
                    this.contract = contract;
                }
                this(immutable(Signature)[] signs, immutable(Contract) contract) immutable pure nothrow {
                    this.signs = signs;
                    this.contract = contract;
                }
                this(const(Document) doc) immutable @trusted {
                    immutable _this=cast(immutable)SignedContract(doc);
                    this.signs=_this.signs;
                    this.contract=_this.contract;
                }
            });
}

/**
 * Tagion PayScript
 * builtin transfer script,
 * Included in a contract to eventually be outputs in the DART
 * The sum of the value of the outputs should be less than the sum of inputs + fees
 */
@recordType("pay")
struct PayScript {
    @label(StdNames.values) const(TagionBill)[] outputs; /// Outputs of the contract to be Stored in DART
    mixin HiBONRecord!(
        q{
                this(const(TagionBill)[] outputs) pure nothrow {
                    this.outputs = outputs;
                }
            });
}

unittest {
    import tagion.hibon.HiBONJSON;

    PayScript pay;
    pay.outputs = [
        TagionBill(TagionCurrency(1000), sdt_t(1234), Pubkey([1, 2, 3]), [
            14, 16, 17
        ]),
        TagionBill(TagionCurrency(2000), sdt_t(5678), Pubkey([2, 3, 4]), [
            42, 17, 3
        ])
    ];
    const hibon_serialize = pay.toHiBON.serialize;
    const serialize = pay.serialize;

    assert(hibon_serialize == serialize);
    const doc = pay.toDoc;
    const new_pay = PayScript(doc);
    assert(hibon_serialize == doc.serialize);
    assert(serialize == doc.serialize);
}

/** 
 * Create a signature for each input in a contract
 */
Signature[] sign(const(SecureNet[]) nets, const(Contract) contract) {
    import std.algorithm : map;

    const message = nets[0].calcHash(contract);
    return nets
        .map!(net => net.sign(message))
        .array;
}

/**
 * Create a SignedContract from a list of inputs, reads and a smartcontract
 */
const(SignedContract) sign(
        const(SecureNet[]) nets,
        DARTIndex[] inputs,
        const(Document[]) reads,
        const(Document) script) {
    import std.algorithm : map, sort;
    import tagion.hibon.HiBONException;

    check(nets.length > 0, "At least one input contract");
    check(nets.length == inputs.length, "Number of signature does not match the number of inputs");
    const net = nets[0];
    SignedContract result;
    auto sorted_inputs = inputs
        .enumerate
        .array
        .sort!((a, b) => a.value < b.value)
        .array;

    result.contract = Contract(
        sorted_inputs.map!((input) => input.value).array,
        reads.map!(doc => net.dartIndex(doc)).array,
        Document(script),
    );
    result.signs = sign(sorted_inputs.map!((input) => nets[input.index]).array, result.contract);
    return result;
}

/// ditto
const(SignedContract) sign(
    const(SecureNet[]) nets,
    const(Document[]) inputs,
    const(Document[]) reads,
    const(Document) script) {
    import std.algorithm : map;
    import tagion.hibon.HiBONException;

    check(nets.length > 0, "At least one input contract");
    const net = nets[0];
    return sign(nets, inputs.map!((input) => cast(DARTIndex) net.dartIndex(input))
            .array, reads, script);
}

/**
 * Verify a SignedContract from a list public keys
 */
bool verify(const(SecureNet) net, const(SignedContract*) signed_contract, const(Pubkey[]) owners) nothrow {
    import std.algorithm;

    try {
        if (!owners.empty && signed_contract.contract.inputs.length == owners.length) {
            const message = net.calcHash(signed_contract.contract);
            return zip(signed_contract.signs, owners)
                .all!((a) => net.verify(message, a[0], a[1]));
        }
    }
    catch (Exception e) {
        // ignore
    }
    return false;
}

/**
 * Verify a SignedContract from the inputs read from the inputs read from the DART
 */
bool verify(const(SecureNet) net, const(SignedContract*) signed_contract, const(Document[]) inputs) nothrow {
    import std.algorithm : map;

    try {
        return verify(net, signed_contract, inputs.map!(doc => doc[StdNames.owner].get!Pubkey)
                .array);
    }
    catch (Exception e) {
        //ignore
    }
    return false;
}

unittest {
    import tagion.crypto.SecureNet : StdSecureNet;

    const net = new StdSecureNet;
    const contract = new SignedContract;
    assert(!verify(net, contract, Document[].init), "Contract with no inputs should fail");
}

/**
 * The very first epoch
 */
@recordType("$@G")
struct GenesisEpoch {
    @label(StdNames.epoch) long epoch_number; /// should always be zero
    Pubkey[] nodes; /// Initial nodes
    Document testamony; /// blabber
    @label(StdNames.time) sdt_t time; /// Time of consensus for the epoch
    TagionGlobals globals; /// global statistics
    mixin HiBONRecord!(q{
        this(const(long) epoch_number, Pubkey[] nodes, const(Document) testamony, const(sdt_t) time, const(TagionGlobals) globals) {
            this.epoch_number = epoch_number;
            this.nodes = nodes;
            this.testamony = testamony;
            this.time = time;
            this.globals = globals;
        }
    });
}

/**
 * Epoch
 */
@recordType("$@E")
struct Epoch {
    @label(StdNames.epoch) long epoch_number; /// The epoch number
    @label(StdNames.time) sdt_t time; /// Time stamp
    @label(StdNames.bullseye) Fingerprint bullseye; /// bullseye of the DART at this epoch
    @label(StdNames.previous) Fingerprint previous; /// bullseye of the DART at the previous epoch
    @label(StdNames.signs) const(Signature)[] signs; /// Signature of all inputs
    @optional @(filter.Initialized) Pubkey[] active; /// Nodes which became active this epoch
    // Would inactive be more appropriate or activated+deactivated
    @optional @(filter.Initialized) Pubkey[] deactive; /// The nodes which deactivated this epoch
    @optional @(filter.Initialized) TagionGlobals globals; /// Global statistics

    mixin HiBONRecord!(q{
        this(long epoch_number,
            sdt_t time, 
            Fingerprint bullseye,
            Fingerprint previous,
            const(Signature)[] signs,
            Pubkey[] active,
            Pubkey[] deactive,
            const(TagionGlobals) globals) 
        {
            this.epoch_number = epoch_number;
            this.time = time;
            this.bullseye = bullseye;
            this.previous = previous;
            this.signs = signs;
            this.active = active;
            this.deactive = deactive;
            this.globals = globals;
        }
    });
}

/// A genesis epoch or a standard epoch
alias GenericEpoch = SumType!(GenesisEpoch, Epoch);

/**
 * Name record to get the current epoch
 * The record is updated on each epoch
 */
@recordType("$@Tagion")
struct TagionHead {
    @label(StdNames.domain_name) string name = TagionDomain; /// Default name should always be "tagion"
    long current_epoch;
    mixin HiBONRecord!(q{
        this(const(string) name, const(long) current_epoch) {
            this.name = name;
            this.current_epoch = current_epoch;
        }

    });
}

/**
 * Global tagion statistics
 */
struct TagionGlobals {
    @label("total") BigNumber total; /// The sum of value at the epoch
    @label("total_burned") BigNumber total_burned; /// Burned this epoch
    @label("number_of_bills") long number_of_bills; /// Total number of bills this epoch
    @label("burnt_bills") long burnt_bills; /// Number of bills spent this epoch

    mixin HiBONRecord!(q{
        this(const(BigNumber) total, const(BigNumber) total_burned, const(long) number_of_bills, const(long) burnt_bills) {
            this.total = total;
            this.total_burned = total_burned;
            this.number_of_bills = number_of_bills;
            this.burnt_bills = burnt_bills;
        }
    });
}

/**
 * Gossiped through the graph for votes on the bullseye of next epochs
 */
@recordType("$@Vote")
struct ConsensusVoting {
    @label(StdNames.epoch_number) long epoch; /// The epoch being voted on
    @label(StdNames.owner) Pubkey owner; /// The signee
    @label(StdNames.sign) Signature signed_bullseye; /// Signature of the bullseye

    mixin HiBONRecord!(q{
        this(long epoch, Pubkey owner, Signature signed_bullseye) pure nothrow {
            this.owner = owner;
            this.signed_bullseye = signed_bullseye;
            this.epoch = epoch;
        }
        this(const(Document) doc) @safe immutable {
            immutable _this = ConsensusVoting(doc);
            this.tupleof = _this.tupleof;
        }
    });

    bool verifyBullseye(const(SecureNet) net, const(Fingerprint) bullseye) const pure {
        return net.verify(bullseye, signed_bullseye, owner);
    }
}

version(RESERVED_ARCHIVES_FIX) {
/**
 * Output which did not reach consensus at this epoch
 */
@recordType("$@Locked")
struct LockedArchives {
    @label(StdNames.locked_epoch) long epoch_number; ///
    @label("outputs") const(DARTIndex)[] locked_outputs; ///
    mixin HiBONRecord!(q{
        this(long epoch_number, const(DARTIndex)[] locked_outputs) pure nothrow {
            this.epoch_number = epoch_number;
            this.locked_outputs = locked_outputs;
        }
    });
}
} else {
pragma(msg, "Why is Locked not reserved?");
///
@recordType("@Locked")
struct LockedArchives {
    @label(StdNames.locked_epoch) long epoch_number;
    @label("outputs") const(DARTIndex)[] locked_outputs;
    mixin HiBONRecord!(q{
        this(long epoch_number, const(DARTIndex)[] locked_outputs) pure nothrow {
            this.epoch_number = epoch_number;
            this.locked_outputs = locked_outputs;
        }
    });
}
}

/**
 * Create the DARTindices for the LockedArchives from a range of epochs
 */
DARTIndex[] lockedArchiveIndices(Range)(Range epochs, SecureNet net) 
if (isInputRange!Range && is(ElementType!Range : long)) {
    DARTIndex[] indices;
    foreach(epoch; epochs) {
        indices ~= net.dartKey(StdNames.locked_epoch, epoch);
    }
    return indices;
}

/**
 * The currently active nodes
 * This record is updated each time a node state changes
 */
@recordType("$@Active") 
struct Active {
    @label(StdNames.active)string name = TagionDomain; /// Default name should always be "tagion"
    @label("nodes") const(Pubkey)[] nodes; /// All of the active nodes
    mixin HiBONRecord!(q{
        this(const(Pubkey)[] nodes) pure nothrow {
            this.nodes = nodes;
        }
    });

    bool verify() const pure nothrow {
        import std.algorithm : isSorted;
        return nodes.isSorted;
    }
}

version (WITHOUT_PAYMENT) {
    struct HashString {
        string name;
        mixin HiBONRecord!(q{this(string name) { this.name = name; }});
    }

    enum HashString snavs_record = HashString("snavs");
}
