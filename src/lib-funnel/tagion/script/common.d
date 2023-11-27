module tagion.script.common;
@safe:

import std.algorithm;
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

@recordType("SMC") struct Contract {
    @label("$in") const(DARTIndex)[] inputs; /// Hash pointer to input (DART)
    @label("$read") @optional const(DARTIndex)[] reads; /// Hash pointer to read-only input (DART)
    @label("$run") Document script; // Smart contract 
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
                this(immutable(DARTIndex)[] inputs, immutable(DARTIndex)[] reads, immutable(Document) script) immutable nothrow {
                    this.inputs = inputs;
                    this.reads = reads;
                    this.script = script; 
                }
            });
}

@recordType("SSC") struct SignedContract {
    @label("$signs") const(Signature)[] signs; /// Signature of all inputs
    @label("$contract") Contract contract; /// The contract must signed by all inputs
    mixin HiBONRecord!(
            q{
                this(const(Signature)[] signs, Contract contract) pure nothrow {
                    this.signs = signs;
                    this.contract = contract;
                }
                this(immutable(Signature)[] signs, immutable(Contract) contract) nothrow immutable {
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
    mixin HiBONRecord!(
            q{
                this(const(TagionBill)[] outputs) pure nothrow {
                    this.outputs = outputs;
                }
            });
}

Signature[] sign(const(SecureNet[]) nets, const(Contract) contract) {
    const message = nets[0].calcHash(contract);
    return nets
        .map!(net => net.sign(message))
        .array;
}

const(SignedContract) sign(const(SecureNet[]) nets, const(Document[]) inputs, const(Document[]) reads, const(Document) script) {
    check(nets.length > 0, "At least one input contract");
    check(nets.length == inputs.length, "Number of signature does not match the number of inputs");
    const net = nets[0];
    SignedContract result;
    auto sorted_inputs = inputs
        .map!((input) => cast(DARTIndex) net.dartIndex(input))
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

bool verify(const(SecureNet) net, const(SignedContract*) signed_contract, const(Pubkey[]) owners) nothrow {
    try {
        if (signed_contract.contract.inputs.length == owners.length) {
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
    try {
        return verify(net, signed_contract, inputs.map!(doc => doc[StdNames.owner].get!Pubkey).array);
    }
    catch (Exception e) {
        //ignore
    }
    return false;
}

@recordType("$@G")
struct GenesisEpoch {
    @label(StdNames.epoch) long epoch_number; //should always be zero
    Pubkey[] nodes;
    Document testamony;
    @label(StdNames.time) sdt_t time;
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
    @optional Pubkey[] active; /// Sorted keys
    @optional Pubkey[] deactive;
    TagionGlobals globals;

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
    mixin HiBONRecord!(q{
        this(long epoch_number, const(DARTIndex)[] locked_outputs) {
            this.epoch_number = epoch_number;
            this.locked_outputs = locked_outputs;
        }


    });
}
