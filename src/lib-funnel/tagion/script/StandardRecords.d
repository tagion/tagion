module tagion.script.StandardRecords;

import std.meta: AliasSeq;

import tagion.basic.Basic: Buffer, Pubkey, Signature;
import tagion.hibon.HiBON;
import tagion.hibon.Document;
import tagion.hibon.HiBONRecord;
import tagion.hibon.HiBONException;
import tagion.script.ScriptBase: Number;
import tagion.script.TagionCurrency;
@safe {
    @RecordType("BIL") struct StandardBill {
        @Label("$V") TagionCurrency value; // Bill type
        @Label("$k") uint epoch; // Epoch number
//        @Label("$T", true) string bill_type; // Bill type
        @Label("$Y") Pubkey owner; // Double hashed owner key
        @Label("$G") Buffer gene; // Bill gene
        mixin HiBONRecord;
    }

    @RecordType("NNC") struct NetworkNameCard {
        @Label("#name") string name; // Tagion domain name
        @Label("$lang") string lang;
        @Label("$time") ulong time;
        @Label("$pkey") Pubkey pubkey;
        @Label("$sign") Buffer sign;
        @Label("$record") Buffer record;
        mixin HiBONRecord;
    }

    @RecordType("NRC") struct NetworkNameRecord {
        @Label("$name") Buffer name;
        @Label("$prev") Buffer previous;
        @Label("$index") uint index;
        @Label("$node") Buffer node;
        @Label("$payload", true) Document payload;
        mixin HiBONRecord;
    }

    @RecordType("NNR") struct NetworkNodeRecord {
        enum State {
            PROSPECT,
            STANDBY,
            ACTIVE,
            STERILE
        }

        @Label("#node") Buffer node;
        @Label("$name") Buffer name;
        @Label("$time") ulong time;
        @Label("$sign") uint sign;
        @Label("$state") State state;
        @Label("$gene") Buffer gene;
        @Label("$addr") string address;
        mixin HiBONRecord;
    }

    @RecordType("active0") struct ActiveNode {
        @Label("$node") Buffer node; /// Pointer to the NNC
        @Label("$drive") Buffer drive; /// The tweak of the used key
        @Label("$sign") Buffer signed; /// Signed bulleye of the DART
        mixin HiBONRecord;

    }

    @RecordType("$epoch0") struct EpochBlock {
        @Label("$epoch") uint epoch; /// Epoch number
        @Label("$prev") Buffer previous; /// Hashpoint to the previous epoch block
        @Label("$recorder") Buffer recoder; /// Fingerprint of the recorder
        @Label("$global") Globals global; /// Gloal nerwork paremeters
        @Label("$actives") ActiveNode[] actives; /// List of active nodes Sorted by the $node
        mixin HiBONRecord;
    }

    struct Globals {
        @Label("$fee") TagionCurrency fixed_fees; /// Fixed fees per Transcation
        @Label("$mem") TagionCurrency storage_fee; /// Fees per byte
        TagionCurrency fees(const TagionCurrency topay, const size_t size) pure const {
            return fixed_fees + size * storage_fee;
        }
        mixin HiBONRecord;
    }

    struct GenesisEpoch {
        //    @Label("$
    }

    @RecordType("$master0") struct MasterGlobals {
        //    @Label("$total") Number total;    /// Total tagions in the network
        @Label("$rewards") ulong rewards; /// Epoch rewards
        mixin HiBONRecord;
    }

    @RecordType("SMC") struct Contract {
        @Label("$in") Buffer[] input; /// Hash pointer to input (DART)
        @Label("$read", true) Buffer[] read; /// Hash pointer to read-only input (DART)
        @Label("$out") Document[Pubkey] output; // pubkey of the output
        @Label("$run") Script script; // TVM-links / Wasm binary
        mixin HiBONRecord;
        bool verify() {
            return (input.length > 0) &&
                (output.length > 0);
        }
    }

    @RecordType("PAY") struct PayContract {
        @Label("$bills", true) StandardBill[] bills; /// The actual inputs
        mixin HiBONRecord;
    }

    @RecordType("SSC") struct SignedContract {
        @Label("$signs") Signature[] signs; /// Signature of all inputs
        @Label("$contract") Contract contract; /// The contract must signed by all inputs
        @Label("$in", true) Document input; /// The actual inputs
        mixin HiBONRecord;
    }

    struct Script {
        @Label("$name") string name;
        @Label("$env", true) Buffer link; // Hash pointer to smart contract object;
        mixin HiBONRecord!(
            q{
                this(string name, Buffer link=null) {
                    this.name = name;
                    this.link = link;
                }
            });
        // bool verify() {
        //     return (wasm.length is 0) ^ (link.empty);
        // }

    }
    alias ListOfRecords = AliasSeq!(
            StandardBill,
            NetworkNameCard,
            NetworkNameRecord,
            NetworkNodeRecord,
            Contract,
            SignedContract
    );

}

static Globals globals;

static this() {
    globals.fixed_fees = 50.TGN; // Fixed fee
    globals.storage_fee = 1.TGN / 200; // Fee per stored byte
}
