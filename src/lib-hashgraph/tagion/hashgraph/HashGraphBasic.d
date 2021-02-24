module tagion.hashgraph.HashGraphBasic;

import std.bitmanip;
import std.format;
import std.typecons : TypedefType;

import tagion.basic.Basic : Buffer, Signature, Pubkey, EnumText;
import tagion.hashgraph.Event;
import tagion.hibon.HiBON : HiBON;
import tagion.hibon.HiBONRecord;

import tagion.hibon.Document : Document;
import tagion.gossip.InterfaceNet;
import tagion.basic.ConsensusExceptions : convertEnum, GossipConsensusException;
enum minimum_nodes = 3;
/++
 + Calculates the majority votes
 + Params:
 +     voting    = Number of votes
 +     node_sizw = Total bumber of votes
 + Returns:
 +     Returns `true` if the votes are more thna 2/3
 +/
@safe @nogc
bool isMajority(const size_t voting, const size_t node_size) pure nothrow {
    return (node_size >= minimum_nodes) && (3*voting > 2*node_size);
}

@trusted
bool isMajority(scope const(BitArray) mask) pure nothrow {
    return isMajority(mask.count, mask.length);
}

// struct Tides {
//     int[Pubkey]
// }
// alias Tides=int[immutable(Pubkey)];


protected enum _params = [
    "type",
    "tidewave",
    "wavefront",
    "block"
    ];

mixin(EnumText!("Params", _params));

enum ExchangeState : uint {
    NONE,
        INIT_TIDE,
        TIDAL_WAVE,
        FIRST_WAVE,
        SECOND_WAVE,
        BREAKING_WAVE
        }


alias convertState=convertEnum!(ExchangeState, GossipConsensusException);

@safe
interface HashGraphI {
    enum int eva_altitude=-77;

    //  void request(scope immutable(Buffer) fingerprint);

    Event lookup(scope const(ubyte[]) fingerprint);

    void eliminate(scope const(ubyte[]) fingerprint);

    //Event registerEvent(immutable(EventPackage*) event_pack);

    //   void register(scope immutable(Buffer) fingerprint, Event event);

    bool isRegistered(scope immutable(Buffer) fingerprint) pure;

    size_t number_of_registered_event() const pure nothrow;

    //const(Document) buildPackage(const(HiBON) pack, const ExchangeState type);

    //Tides tideWave(HiBON hibon, bool build_tides);

    //void wavefront(Pubkey received_pubkey, Document doc, ref Tides tides);

    bool front_seat(Event event);

    //void register_wavefront();

    //HiBON[] buildWavefront(Tides tides, bool is_tidewave) const;

    const(Wavefront) wavefront_machine(const(Wavefront) receiver_wave);

    Round.Rounder rounds() pure nothrow;
    const(size_t) nodeId(scope Pubkey pubkey) const pure;
    const(size_t) node_size() const pure nothrow;

    bool add_node(const Pubkey pubkey) nothrow;

    bool remove_node(const Pubkey pubkey) nothrow;


}


@safe
@RecordType("EBODY")
struct EventBody {
    import tagion.basic.ConsensusExceptions;
    protected alias check=Check!HashGraphConsensusException;
    import std.traits : getUDAs, hasUDA, getSymbolsByUDA, OriginalType, Unqual, hasMember;

    @Label("$doc", true)  Document payload; // Transaction
    @Label("$m") Buffer mother; // Hash of the self-parent
    @Label("$f", true) Buffer father; // Hash of the other-parent
    @Label("$a") int altitude;

    @Label("$t") ulong time;
    mixin HiBONRecord!(
        q{
            this(
                Document payload,
                Buffer mother,
                Buffer father,
                immutable ulong time,
                immutable int altitude) inout {
                this.time      =    time;
                this.altitude  =    altitude;
                this.father    =    father;
                this.mother    =    mother;
                this.payload   =    payload;
                consensus();
            }
        });

    invariant {
        if ( (mother.length != 0) && (father.length != 0 ) ) {
            assert( mother.length == father.length );
        }
    }


    @nogc
    bool isEva() pure const nothrow {
        return (mother.length == 0);
    }

    static immutable(EventBody) eva(GossipNet net) {
        auto hibon=new HiBON;
        hibon["pubkey"]=net.pubkey;
        pragma(msg, "fixme(cbr): The nonce should be unique maybe the dependend on the bulleye");
        hibon["nonce"]="Should be implemented:"; //~to!string(eva_count);
        immutable result=EventBody(Document(hibon), null, null, net.time, HashGraphI.eva_altitude);
        return result;
    }

    version(none)
    this(const Document doc) {
        static if (TYPE.length) {
            string _type=doc[TYPENAME].get!string;
            .check(_type == TYPE, format("Wrong %s type %s should be %s", TYPENAME, _type, type));
        }
    ForeachTuple:
        foreach(i, ref m; this.tupleof) {
            static if (__traits(compiles, typeof(m))) {
                static if (hasUDA!(this.tupleof[i], Label)) {
                    alias label=GetLabel!(this.tupleof[i])[0];
                    enum name=label.name;
                    enum optional=label.optional;
                    static if (label.optional) {
                        if (!doc.hasMember(name)) {
                            break;
                        }
                    }
                    static if (TYPE.length) {
                        static assert(TYPENAME != label.name,
                            format("Default %s is already definded to %s but is redefined for %s.%s",
                                TYPENAME, TYPE, typeof(this).stringof, basename!(this.tupleof[i])));
                    }
                }
                else {
                    enum name=basename!(this.tupleof[i]);
                    enum optional=false;
                }
                static if (name.length) {
                    enum member_name=this.tupleof[i].stringof;
                    enum code=format("%s=doc[name].get!BaseT;", member_name);
                    alias MemberT=typeof(m);
                    alias BaseT=TypedefType!MemberT;
                    alias UnqualT=Unqual!BaseT;
                    static if (is(BaseT : const(Document))) {
                        auto dub_doc = doc[name].get!Document;
                        m = dub_doc;
                    }
                    else static if (is(BaseT == struct)) {
                        auto dub_doc = doc[name].get!Document;
                        enum doc_code=format("%s=UnqualT(dub_doc);", member_name);
                        pragma(msg, doc_code, ": ", BaseT, ": ", UnqualT);
                        mixin(doc_code);
                    }
                    else static if (is(BaseT == class)) {
                        const dub_doc = Document(doc[name].get!Document);
                        m=new BaseT(dub_doc);
                    }
                    else static if (is(BaseT == enum)) {
                        alias EnumBaseT=OriginalType!BaseT;
                        m=cast(BaseT)doc[name].get!EnumBaseT;
                    }
                    else {
                        static if (is(BaseT:U[], U)) {
                            static if (hasMember!(U, "toHiBON")) {
                                MemberT array;
                                auto doc_array=doc[name].get!Document;
                                static if (optional) {
                                    if (doc_array.length == 0) {
                                        continue ForeachTuple;
                                    }
                                }
                                check(doc_array.isArray, message("Document array expected for %s member",  name));
                                foreach(e; doc_array[]) {
                                    const sub_doc=e.get!Document;
                                    array~=U(sub_doc);
                                }
                                enum doc_array_code=format("%s=array;", member_name);
                                mixin(doc_array_code);
                            }
                            else static if (Document.Value.hasType!U) {
                                MemberT array;
                                auto doc_array=doc[name].get!Document;
                                static if (optional) {
                                    if (doc_array.length == 0) {
                                        continue ForeachTuple;
                                    }
                                }
                                check(doc_array.isArray, message("Document array expected for %s member",  name));
                                foreach(e; doc_array[]) {
                                    array~=e.get!U;
                                }
                                m=array;
//                                static assert(0, format("Special handling of array %s", MemberT.stringof));
                            }
                            else {
                                static assert(is(U == immutable), format("The array must be immutable not %s but is %s",
                                        BaseT.stringof, cast(immutable(U)[]).stringof));
                                mixin(code);
                            }
                        }
                        else {
                            mixin(code);
                        }
                    }
                }
            }
        }
    }

    void consensus() inout {
        if ( mother.length == 0 ) {
            // Seed event first event in the chain
            check(father.length == 0, ConsensusFailCode.NO_MOTHER);
        }
        else {
            if ( father.length != 0 ) {
                // If the Event has a father
                check(mother.length == father.length, ConsensusFailCode.MOTHER_AND_FATHER_SAME_SIZE);
            }
            check(mother != father, ConsensusFailCode.MOTHER_AND_FATHER_CAN_NOT_BE_THE_SAME);
        }
    }

}

version(none)
@trusted
static immutable(EventPackage*) buildEventPackage(Args...)(Args args) {
    immutable result=cast(immutable)(new EventPackage(args));
    return result;
}


//@RecordType("EPACK") @safe
pragma(msg, "fixme(cbr): Should be a HiRPC");
@safe
class EventPackage {
    @Label("") Buffer fingerprint;
    @Label("$sign", true) Signature signature;
    @Label("$pkey", true) Pubkey pubkey;
    @Label("$body") EventBody event_body;

    mixin HiBONRecord!(
        q{
            import tagion.basic.ConsensusExceptions: ConsensusCheck=Check, EventConsensusException, ConsensusFailCode;
            protected alias consensus_check=ConsensusCheck!EventConsensusException;
            /++
             Used when a Event is receved from another node
             +/
            this(const GossipNet net, const(Document) doc_epack)
                in {
                    assert(!doc_epack.hasMember(Event.Params.fingerprint), "Fingerprint should not be a part of the event body");
                }
            do {
                this(doc_epack);
                consensus_check(pubkey.length !is 0, ConsensusFailCode.EVENT_MISSING_PUBKEY);
                consensus_check(signature.length !is 0, ConsensusFailCode.EVENT_MISSING_SIGNATURE);
                fingerprint=net.hashOf(event_body);
                consensus_check(net.verify(fingerprint, signature, pubkey), ConsensusFailCode.EVENT_BAD_SIGNATURE);
            }

            /++
             Create a
             +/
            this(GossipNet net, immutable(EventBody) ebody)  {
                pubkey=net.pubkey;
                event_body=ebody;
                fingerprint=net.hashOf(event_body);
                signature=net.sign(fingerprint);
            }

        });
}

alias Tides=int[Pubkey];
@RecordType("Wavefront") @safe
struct Wavefront {
    @Label("$tides", true) private Tides _tides;
    @Label("$events", true) EventPackage[] epacks;
    @Label("$state", true) ExchangeState state;
    mixin HiBONRecord!(
        q{
            this(Tides tides) pure nothrow {
                this.tides=tides;
                epacks.length=0;
                state=ExchangeState.TIDEL_WAVE;
            }
            this(EventPackage[] epacks, const ExchangeState state) pure nothrow
            in {
                assert(state is ExchangeState.FIRST_WAVE || state is ExchangeState.SECOND_WAVE);
            }
            do {
                this.epacks;
                this.state=state;
            }
        });
    const(int[Pubkey]) tides() const pure nothrow {
        if (tides.length is 0) {
            foreach(ref e; epacks) {
                if (e.pubkey in _tides) {
                    _tides[e.pubkey]=highest(_tides[e.pubkey], event_package.event_body.altitude);
                }
                else {
                    _tides[e.pubkey]=e.event_body.altitude;
                }
            }
        }
        return _tides;
    }
}

static assert(isHiBON!(EventPackage));

static assert(isHiBON!(immutable(EventPackage)));
