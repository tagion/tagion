module tagion.script.namerecords;

//import tagion.script.common;
import tagion.script.standardnames;
import tagion.basic.Types : Buffer;
import tagion.crypto.Types : Pubkey, Signature, Fingerprint;
import tagion.hibon.HiBONRecord;
import tagion.hibon.Document;
import tagion.dart.DARTBasic;
import tagion.utils.StdTime;

@safe:
@recordType("NNC") struct NetworkNameCard {
    @label(StdNames.name) string name; /// Tagion domain name (TDN) 
    @label(StdNames.owner) Pubkey pubkey; /// NNC pubkey
    @label("$lang") string lang; /// Language used for the #name
    @label(StdNames.time) ulong time; /// Time-stamp of
    @label("$record") DARTIndex record; /// Hash pointer to NRC
    mixin HiBONRecord;
}

@recordType("NRC") struct NetworkNameRecord {
    @label("$name") string name; /// Hash of the NNC.name
    @label(StdNames.previous) Fingerprint previous; /// Hash pointer to the previuos NRC
    @label("$index") uint index; /// Current index previous.index+1
    @label("$payload", true) Document payload;
    mixin HiBONRecord;
}

@recordType("$@NNR")
struct NetworkNodeRecord {
    enum State {
        PROSPECT,
        STANDBY,
        LOCKED,
        STERILE
    }

    @label(StdNames.nodekey) Pubkey channel; /// Node public 
    @label("$name") string name; /// TDN lookup 
    @label(StdNames.time) sdt_t time; /// Consensus time of the last update
    @label("$state") State state; /// Node state
    @label("$addr") string address; /// Network address
    mixin HiBONRecord;
}
