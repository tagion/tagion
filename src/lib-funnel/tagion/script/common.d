module tagion.script.common;
@safe:

// import std.algorithm;
import std.array;
import std.range;
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

@recordType("TGN") struct TagionBill {
    @label(StdNames.value) TagionCurrency value; /// Tagion bill 
    @label(StdNames.time) sdt_t time; // Time stamp
    @label(StdNames.owner) Pubkey owner; // owner key
    @label(StdNames.nonce) @optional Buffer nonce; // extra nonce 
    alias enable_serialize = bool;
    mixin HiBONRecord!(
            q{
                this(const(TagionCurrency) value, const sdt_t time, Pubkey owner, Buffer nonce) pure nothrow {
                    this.value = value;
                    this.time = time;
                    this.owner = owner;
                    this.nonce = nonce;
                }
            });
}

unittest {
    import tagion.hibon.HiBONSerialize;

    pragma(msg, SupportingFullSizeFunction!(TagionCurrency, 0, true));
    pragma(msg, "--- --- ---");
    pragma(msg, SupportingFullSizeFunction!(TagionBill, 0, true));
    import tagion.hibon.HiBONRecord;
    import tagion.script.Currency;

    pragma(msg, "is Currency an HiBONRecord ", isHiBONRecord!(Currency!"NAP"));
    pragma(msg, "is TagionBill an HiBONRecord ", isHiBONRecord!(TagionBill));
    static assert(isHiBONRecord!(Currency!"NAP"));
    static assert(SupportingFullSizeFunction!(TagionBill, 0, true));
}

@recordType("SMC") struct Contract {
    @label("$in") const(DARTIndex)[] inputs; /// Hash pointer to input (DART)
    @label("$read") @optional @(filter.Initialized) const(DARTIndex)[] reads; /// Hash pointer to read-only input (DART)
    @label("$run") Document script; // Smart contract 
    alias enable_serialize = bool;
    bool verify() {
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

@recordType("SSC") struct SignedContract {
    @label("$signs") const(Signature)[] signs; /// Signature of all inputs
    @label("$contract") Contract contract; /// The contract must signed by all inputs
    alias enable_serialize = bool;
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

@recordType("pay")
struct PayScript {
    @label(StdNames.values) const(TagionBill)[] outputs;
    alias enable_serialize = bool;
    mixin HiBONRecord!(
            q{
                this(const(TagionBill)[] outputs) pure nothrow {
                    this.outputs = outputs;
                }
            });
}

unittest {
   import std.stdio;
    import tagion.hibon.HiBONJSON;
    PayScript pay;
    pay.outputs=[
        TagionBill(TagionCurrency(1000), sdt_t(1234), Pubkey([1,2,3]), [14,16,17]),
        TagionBill(TagionCurrency(2000), sdt_t(5678), Pubkey([2,3,4]), [42,17,3])
    ];
    const hibon_serialize=pay.toHiBON.serialize;
    const serialize = pay._serialize;
    writefln("hibon_serialize=%s", hibon_serialize);
    writefln("serialize      =%s", serialize);
    writefln("hibon=%s", pay.toHiBON.toPretty);
    writefln("doc  =%s", pay.toPretty);

    assert(hibon_serialize == serialize);
    const doc=pay.toDoc;
    const new_pay=PayScript(doc);
    writefln("doc.serialize  =%s", doc.serialize);
    assert(hibon_serialize == doc.serialize);
    assert(serialize == doc.serialize);
}

Signature[] sign(const(SecureNet[]) nets, const(Contract) contract) {
    import std.algorithm : map;

    const message = nets[0].calcHash(contract);
    return nets
        .map!(net => net.sign(message))
        .array;
}

const(SignedContract) sign(const(SecureNet[]) nets, DARTIndex[] inputs, const(Document[]) reads, const(
        Document) script) {
    import std.algorithm : map, sort;

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

const(SignedContract) sign(
        const(SecureNet[]) nets,
const(Document[]) inputs,
const(Document[]) reads,
const(Document) script) {
    import std.algorithm : map;

    check(nets.length > 0, "At least one input contract");
    const net = nets[0];
    return sign(nets, inputs.map!((input) => cast(DARTIndex) net.dartIndex(input))
            .array, reads, script);
}

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
    const  contract = new SignedContract;
    assert(!verify(net, contract, Document[].init), "Contract with no inputs should fail");
}

@recordType("$@G")
struct GenesisEpoch {
    @label(StdNames.epoch) long epoch_number; //should always be zero
    Pubkey[] nodes;
    Document testamony;
    @label(StdNames.time) sdt_t time;
    alias enable_serialize = bool;
    TagionGlobals globals;
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

@recordType("$@E")
struct Epoch {
    @label(StdNames.epoch) long epoch_number;
    @label(StdNames.time) sdt_t time; // Time stamp
    @label(StdNames.bullseye) Fingerprint bullseye;
    @label(StdNames.previous) Fingerprint previous;
    @label("$signs") const(Signature)[] signs; /// Signature of all inputs
    @optional @(filter.Initialized) Pubkey[] active; /// Sorted keys
    @optional @(filter.Initialized) Pubkey[] deactive;
    @optional @(filter.Initialized) TagionGlobals globals;
    alias enable_serialize = bool;

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

@recordType("$@Tagion")
struct TagionHead {
    @label(StdNames.name) string name; // Default name should always be "tagion"
    long current_epoch;
    alias enable_serialize = bool;
    mixin HiBONRecord!(q{
        this(const(string) name, const(long) current_epoch) {
            this.name = name;
            this.current_epoch = current_epoch;
        }

    });
}

struct TagionGlobals {
    @label("total") BigNumber total;
    @label("total_burned") BigNumber total_burned;
    @label("number_of_bills") long number_of_bills;
    @label("burnt_bills") long burnt_bills;
    alias enable_serialize = bool;

    mixin HiBONRecord!(q{
        this(const(BigNumber) total, const(BigNumber) total_burned, const(long) number_of_bills, const(long) burnt_bills) {
            this.total = total;
            this.total_burned = total_burned;
            this.number_of_bills = number_of_bills;
            this.burnt_bills = burnt_bills;
        }
    });
}

@recordType("@$Vote")
struct ConsensusVoting {
    long epoch;
    @label(StdNames.owner) Pubkey owner;
    @label(StdNames.signed) Signature signed_bullseye;
    alias enable_serialize = bool;

    mixin HiBONRecord!(q{
        this(long epoch, Pubkey owner, Signature signed_bullseye) pure {
            this.owner = owner;
            this.signed_bullseye = signed_bullseye;
            this.epoch = epoch;
        }
        this(const(Document) doc) @safe immutable {
            immutable _this = ConsensusVoting(doc);
            this.tupleof = _this.tupleof;
        }
    });

    bool verifyBullseye(const(SecureNet) net, const(Fingerprint) bullseye) const {
        return net.verify(bullseye, signed_bullseye, owner);
    }
}

@recordType("@Locked")
struct LockedArchives {
    @label(StdNames.locked_epoch) long epoch_number;
    @label("outputs") const(DARTIndex)[] locked_outputs;
    alias enable_serialize = bool;
    mixin HiBONRecord!(q{
        this(long epoch_number, const(DARTIndex)[] locked_outputs) {
            this.epoch_number = epoch_number;
            this.locked_outputs = locked_outputs;
        }


    });
}

version (WITHOUT_PAYMENT) {
    struct HashString {
        string name;
        mixin HiBONRecord!(q{this(string name) { this.name = name; }});
    }

    enum HashString snavs_record = HashString("snavs");
}
