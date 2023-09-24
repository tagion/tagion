module tagion.script.common;

import tagion.script.TagionCurrency;
import tagion.utils.StdTime;
import tagion.basic.Types;
import tagion.crypto.Types;
import tagion.hibon.HiBONRecord;
import tagion.hibon.Document;
import tagion.dart.DARTBasic;

enum StdNames {
    owner = "$Y",
    value = "$V",
    time = "$t",
    values = "$vals",
}

@safe
@recordType("TGN") struct TagionBill {
    @label(StdNames.value) TagionCurrency value; // Bill type
    @label(StdNames.time) sdt_t time; // Time stamp
    @label(StdNames.owner) Pubkey owner; // owner key
    mixin HiBONRecord!(
            q{
                this(TagionCurrency value, const sdt_t time, Pubkey owner) pure {
                    this.value = value;
                    this.time = time;
                    this.owner = owner; 
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
                this(immutable(DARTIndex)[] inputs, immutable(DARTIndex)[] reads, immutable(Document) script) @safe immutable nothrow {
                    this.inputs = inputs;
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
                this(immutable(Signature)[] signs, immutable(Contract) contract) @safe nothrow immutable {
                    this.signs = signs;
                    this.contract = contract;
                }
            });
}

@safe
@recordType("pay")
struct PayScript {
    @label(StdNames.values) TagionCurrency[] outputs;
    mixin HiBONRecord!(
            q{
                this(TagionCurrency[] outputs) @safe pure nothrow {
                    this.outputs = outputs;
                }
            });
}
