module tagion.script.common;
import std.algorithm;
import std.range;
import std.array;
import tagion.script.TagionCurrency;
import tagion.utils.StdTime;
import tagion.basic.Types;
import tagion.crypto.Types;
import tagion.crypto.SecureInterfaceNet;
import tagion.hibon.HiBONRecord;
import tagion.hibon.Document;
import tagion.dart.DARTBasic;
import tagion.script.ScriptException;

enum StdNames {
    owner = "$Y",
    value = "$V",
    time = "$t",
    nonce = "$x",
    values = "$vals",
    derive = "$D",
}

@safe
@recordType("TGN") struct TagionBill {
    @label(StdNames.value) TagionCurrency value; /// Tagion bill 
    @label(StdNames.time) sdt_t time; // Time stamp
    @label(StdNames.owner) Pubkey owner; // owner key
    @label(StdNames.nonce, true) Buffer nonce; // extra nonce 
    mixin HiBONRecord!(
            q{
                this(TagionCurrency value, const sdt_t time, Pubkey owner, Buffer nonce) pure {
                    this.value = value;
                    this.time = time;
                    this.owner = owner;
                    this.nonce = nonce;
                }
            });
}

@safe
@recordType("SMC") struct Contract {
    @label("$in") const(DARTIndex)[] inputs; /// Hash pointer to input (DART)
    @label("$read", true) const(DARTIndex)[] reads; /// Hash pointer to read-only input (DART)
    @label("$run") Document script; // Smart contract 
    bool verify() {
        return (inputs.length > 0);
    }

    mixin HiBONRecord!(
            q{
                this(const(DARTIndex)[] inputs, const(DARTIndex)[] reads, Document script) @safe pure nothrow {
                    this.inputs = inputs;
                    this.reads = reads;
                    this.script = script; 
                }
            });
}

@safe
@recordType("SSC") struct SignedContract {
    @label("$signs") const(Signature)[] signs; /// Signature of all inputs
    @label("$contract") Contract contract; /// The contract must signed by all inputs
    mixin HiBONRecord!(
            q{
                this(const(Signature)[] signs, Contract contract) @safe pure nothrow {
                    this.signs = signs;
                    this.contract = contract;
                }
            });
}

@safe
@recordType("pay")
struct PayScript {
    @label(StdNames.values) TagionBill[] outputs;
    mixin HiBONRecord!(
            q{
                this(TagionBill[] outputs) @safe pure nothrow {
                    this.outputs = outputs;
                }
            });
}

@safe
Signature[] sign(const(SecureNet[]) nets, const(Contract) contract) {
    const message = nets[0].calcHash(contract);
    return nets
        .map!(net => net.sign(message))
        .array;
}

@safe
const(SignedContract) sign(const(SecureNet[]) nets, const(Document[]) inputs, const(Document[]) reads, const(Document) script) {
    check(nets.length == inputs.length, "Number of signature does not match the number of inputs");
    const net = nets[0];
    SignedContract result;
    const x = net.dartIndex(inputs[0]);
    result.contract = Contract(
            inputs
            .map!(doc => net.dartIndex(doc))
            .array,
            reads
            .map!(doc => net.dartIndex(doc))
            .array,
            Document(script.data)
    );
    const message = net.calcHash(result.contract);
    result.signs = sign(nets, result.contract);
    return result;
}

@safe
bool verify(const(SecureNet) net, const(SignedContract) signed_contract, const(Pubkey[]) owners) nothrow {
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

@safe
bool verify(const(SecureNet) net, const(SignedContract) signed_contract, const(Document[]) inputs) nothrow {
    try {
        return verify(net, signed_contract, inputs.map!(doc => doc[StdNames.owner].get!Pubkey).array);
    }
    catch (Exception e) {
        //ignore
    }
    return false;
}
