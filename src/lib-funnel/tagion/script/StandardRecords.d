module tagion.script.StandardRecords;

import std.meta : AliasSeq;

import tagion.basic.Basic : Buffer, Pubkey;
import tagion.hibon.HiBON;
import tagion.hibon.Document;
import tagion.hibon.HiBONRecord;
import tagion.hibon.HiBONException;
import tagion.script.ScriptBase : Number;
import tagion.utils.StdTime;

@safe {
    struct StandardBill {
        @Label("$V") ulong value;      /// Bill type
        @Label("$k") uint epoch;       /// Epoch number
        // @Label("$T", true) string bill_type; /// Bill type if no time is defiend
        //                                      /// then it is a Tagion
        @Label("$T") string bill_type; /// Bill type
        @Label("$Y") Buffer owner;     /// Double hashed owner
        mixin HiBONRecord!("BIL");
    }

    /++
     This is Name Card Label is a part of Network Name Card and
     always store together with
     Network Name card
     +/
    struct NameCardLabel {
        @Label("#name") string name;      /// Tagion domain name
        @Label("$lang") string lang;      /// Language id
        @Label("$time") sdt_t  time;      /// Epoch time stamp
        @Label("$pkey") Pubkey pubkey;    /// The owner of the record
        @Label("$sign") Buffer sign;      /// Signature of the record
        @Label("$record") Buffer record;  /// This is the hashpointer to the Name Card Record
        mixin HiBONRecord!("NCL");
    }

    struct NameCardRecord {
        @Label("$name")  Buffer name;        /// Hashpointer to the Name Card Label
        @Label("$prev")  Buffer previous;    /// Hashpointer
        @Label("$time")  sdt_t  time;        /// Epoch time stamp
        @Label("$index") uint   index;        /// NCR number
        @Label("$node", true)   Buffer node;  /// Hashpointer to the node record
        @Label("$payload", true) Document payload;  /// Optional Document
        mixin HiBONRecord!("NCR");
    }

    struct NetworkNodeRecord {
        enum State {
            PROSPECT,
            STANDBY,
            ACTIVE,
            STERILE
        }
        @Label("#node")  Buffer node;
        @Label("$name")  Buffer name;
        @Label("$time")  ulong  time;
        @Label("$sign")  uint   sign;
        @Label("$state") State  state;
        @Label("$gene")  Buffer gene;
        mixin HiBONRecord!("NNR");
    }


    struct ActiveNode {
        @Label("$node") Buffer node; /// Pointer to the NNC
        @Label("$drive") Buffer drive; /// The tweak of the used key
        @Label("$sign")  Buffer signed; /// Signed bulleye of the DART
        mixin HiBONRecord!("active0");

    }

    struct EpochBlock {
        @Label("$epoch")    int epoch;            /// Epoch number
        @Label("$prev")     Buffer previous;      /// Hashpoint to the previous epoch block
        @Label("$recorder") Buffer recoder;       /// Fingerprint of the recorder
        @Label("$global")   Document global;      /// Gloal nerwork paremeters
        @Label("$actives")  ActiveNode[] actives; /// List of active nodes Sorted by the $node
        mixin HiBONRecord!("$epoch0");
    }

    struct GenesisEpoch {
//    @Label("$
    }

    struct MasterGlobals {
//    @Label("$total") Number total;    /// Total tagions in the network
        @Label("$rewards") ulong rewards; /// Epoch rewards
        mixin HiBONRecord!("$master0");
    }

    struct Contract {
        @Label("$in")   Buffer[] input;      /// Hash pointer to input (DART)
        @Label("$read", true) Buffer[] read; /// Hash pointer to read-only input (DART)
        @Label("$out")  Buffer[] output; // pubkey of the output
        @Label("$script") string script;
//    @Label("$params", true)  Document params;
        mixin HiBONRecord!("SMC");
        bool valid() {
            return
                (input.length > 0) ||
                (output.length > 0);
        }
    }

    struct SignedContract {
        @Label("$signs")    Buffer[] signs;       /// Signature of all inputs
        @Label("$contract") Contract contract;    /// The contract must signed by all inputs
        @Label("$in", true) StandardBill[] input; /// The actual inputs
        mixin HiBONRecord!("SSC");
        bool valid() {
            return contract.valid;
        }
    }


    alias ListOfRecords=AliasSeq!(
        StandardBill,
        NameCardLabel,
        NameCardRecord,
        NetworkNodeRecord,
        Contract,
        SignedContract
        );

    /++

+/
    struct Wallet {
        import tagion.wallet.KeyRecover : KeyRecover;
        KeyRecover.RecoverSeed seed;
        Pubkey pubkey;
        Buffer Y;
        Buffer check;
        mixin HiBONRecord;
    }


    struct Invoice {
        string name;
        ulong  amount;
        Buffer pkey;
        mixin HiBONRecord;
    }
}
