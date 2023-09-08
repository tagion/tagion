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
    @label(StdNames.time) sdt_t time; // Epoch number
    @label(StdNames.owner) Pubkey owner; // owner key
    mixin HiBONRecord!(
            q{
                this(TagionCurrency value, const sdt_t time, Pubkey owner, Buffer gene) {
                    this.value = value;
                    this.time = time;
                    this.owner = owner;
                }
            });
}

@safe
@recordType("SMC") struct Contract {
    @label("$in") DARTIndex[] inputs; /// Hash pointer to input (DART)
    @label("$read", true) DARTIndex[] reads; /// Hash pointer to read-only input (DART)
    @label("$run") Document script; // Smart contract 
    bool verify() {
        return (inputs.length > 0);
    }

    mixin HiBONRecord;
}

@safe
@recordType("SSC") struct SignedContract {
    @label("$signs") Signature[] signs; /// Signature of all inputs
    @label("$contract") Contract contract; /// The contract must signed by all inputs
    mixin HiBONRecord;
}

@safe
@recordType("PAY")
struct PayScript {
    @label(StdNames.values) TagionCurrency[] values;
    mixin HiBONRecord;
}
