module tagion.script.namerecords;

@safe:

import std.format;
import std.array;

//import tagion.script.common;
import tagion.basic.Types : Buffer;
import tagion.crypto.Types : Fingerprint, Pubkey, Signature;
import tagion.dart.DARTBasic;
import tagion.hibon.Document;
import tagion.hibon.HiBONRecord;
import tagion.script.standardnames;
import tagion.utils.StdTime;

@safe:
@recordType("$@NNC")
struct NetworkNameCard {
    @label(StdNames.name) string name; /// Tagion domain name (TDN) 
    @label(StdNames.owner) Pubkey owner; /// NNC pubkey
    @label("$lang") string lang; /// Language used for the #name
    @label(StdNames.time) sdt_t time; /// Time-stamp of
    @label("$record") DARTIndex record; /// Hash pointer to NRC
    mixin HiBONRecord;
}

@recordType("$@NRC")
struct NetworkNameRecord {
    @label("$name") string name; /// Hash of the NNC.name
    @label(StdNames.previous) Fingerprint previous; /// Hash pointer to the previous NRC
    @label("$index") uint index; /// Current index previous.index+1
    @label("$payload") @optional Document payload;
    mixin HiBONRecord;
}

@recordType("$@NNR")
struct NetworkNodeRecord {
    enum State {
        STERILE,
        LOCKED,
        PROSPECT,
        STANDBY,
        ACTIVE,
    }

    @label(StdNames.nodekey) Pubkey channel; /// Node public key
    @label("$name") string name; /// TDN lookup 
    @label(StdNames.time) sdt_t time; /// Consensus time of the last update
    @label("$state") State state; /// Node state
    @label("$addr") string address; /// Network address

    string toNNGString() const {
        auto s = address.split("/");
        const type = s[0];
        const host = s[1];
        if (type == "ip4" || type == "ip6") {
            const proto = s[2];
            const port = s[3];
            return proto ~ "://" ~ host ~ ":" ~ port;
        }
        else if (type == "abstract" || type == "unix") {
            const name = s[2];
            return type ~ name;
        }
        // Probably should not assert in the future, or atleast validate the address ahead of time in the constructor
        assert(0, format("don't know how to convert %s to nng address", address));
    }

    mixin HiBONRecord!(q{
        this(Pubkey _channel, string _addr) nothrow pure {
            channel = _channel;
            address = _addr;
        }
        this(Pubkey channel, string name, sdt_t time, State state, string address) nothrow pure {
            this.channel = channel;
            this.name = name;
            this.time = time;
            this.state = state;
            this.address = address;
        }
    });
}

unittest {
    NetworkNodeRecord nnr;
    nnr.address = "ip4/200.185.5.5/tcp/80";
    assert(nnr.toNNGString == "tcp://200.185.5.5:80");

    NetworkNodeRecord nnr2;
    nnr2.address = "ip6/c8b9:505:c8b9:505:c8b9:0:c8b9:505/tcp/80";
    assert(nnr2.toNNGString == "tcp://c8b9:505:c8b9:505:c8b9:0:c8b9:505:80");
}
