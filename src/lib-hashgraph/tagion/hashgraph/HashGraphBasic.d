module tagion.hashgraph.HashGraphBasic;

import std.stdio;
//import std.bitmanip;
import std.format;
import std.typecons : TypedefType;

import tagion.basic.Basic : Buffer, Signature, Pubkey, EnumText;
import tagion.hashgraph.Event;
import tagion.hashgraph.HashGraph : HashGraph;
import tagion.hashgraph.BitMask;
import tagion.hibon.HiBON : HiBON;
import tagion.communication.HiRPC : HiRPC;
import tagion.hibon.HiBONRecord;
import tagion.hibon.HiBONJSON : JSONString;
import tagion.utils.StdTime;

import tagion.hibon.Document : Document;
import tagion.crypto.SecureInterfaceNet : SecureNet;
//import tagion.gossip.InterfaceNet;
import tagion.basic.ConsensusExceptions : convertEnum, GossipConsensusException, ConsensusException;
enum minimum_nodes = 3;
import  tagion.utils.Miscellaneous : cutHex;
import std.exception : assumeWontThrow;
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

@safe @nogc
bool isMajority(const(BitMask) mask, const HashGraph hashgraph) pure nothrow {
    return isMajority(mask.count, hashgraph.node_size);
}

@safe @nogc
bool isAllVotes(const(BitMask) mask, const HashGraph hashgraph) pure nothrow {
    return mask.count is hashgraph.node_size;
}


enum int eva_altitude=-77;
@safe @nogc
int nextAltitide(const Event event) pure nothrow {
    return (event)?event.altitude+1:eva_altitude;
}
// struct Tides {
//     int[Pubkey]
// }
// alias Tides=int[immutable(Pubkey)];

protected enum _params = [
    "events",
    "size",
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
interface EventScriptCallbacks {
    void epoch(const(Event[]) received_event, const sdt_t  epoch_time);
    void send(ref Document[] payloads, const sdt_t epoch_time); // Should be execute when and epoch is finished

    void send(immutable(EventBody) ebody);
    bool stop(); // Stops the task
}


@safe
interface EventMonitorCallbacks {
    nothrow {
        void create(const(Event) e);
        void connect(const(Event) e);
        void witness(const(Event) e);
//        void witness_mask(const(Event) e);
//        void strongly_seeing(const(Event) e);
//        void strong_vote(const(Event) e, immutable uint vote);
        void round_seen(const(Event) e);
//        void looked_at(const(Event) e);
        void round(const(Event) e);
        void round_decided(const(Round.Rounder) rounder);
        void round_received(const(Event) e);
//        void coin_round(const(Round) r);
        void famous(const(Event) e);
        void round(const(Event) e);
        void son(const(Event) e);
        void daughter(const(Event) e);
        void forked(const(Event) e);
//        void remove(const(Round) r);
        void epoch(const(Event[]) received_event);
//        void iterations(const(Event) e, const uint count);
    //void received_tidewave(immutable(Pubkey) sending_channel, const(Tides) tides);
//    void wavefront_state_receive(const(Document) wavefron_doc);
//        void exiting(const(Pubkey) owner_key, const(HashGraphI) hashgraph);

        void send(const Pubkey channel, lazy const Document doc);
        final void send(T)(const Pubkey channel, lazy T pack) if(isHiBONRecord!T) {
            send(channel, pack.toDoc);
        }

        void receive(lazy const Document doc);
        final void receive(T)(lazy const T pack) if(isHiBONRecord!T) {
            receive(pack.toDoc);
        }

        //void consensus_failure(const(ConsensusException) e);
    }
}

// EventView is used to store event has a
struct EventView {
    enum eventsName="$events";
    uint id;
    @Label("$m", true) @(Filter.Initialized) uint mother;
    @Label("$f", true) @(Filter.Initialized) uint father;
    @Label("$n") size_t node_id;
    @Label("$a") int altitude;
    @Label("$o") int order;
    @Label("$r") int round;
    @Label("$w") bool witness;
    @Label("witness") uint[] witness_mask;
    @Label("$strong") uint[] strongly_seeing_mask;
    @Label("$seen") uint[] round_seen_mask;
    //@Label("*", true) @(Filter.Initialized)
    bool father_less;

    mixin HiBONRecord!(
        q{
            this(const Event event) {
                import std.algorithm : each;
                id=event.id;
                if (event.isGrounded) {
                    mother=father=uint.max;
                }
                else {
                    if (event.mother) {
                        mother=event.mother.id;
                    }
                    if (event.father) {
                        father=event.father.id;
                    }
                }
                node_id=event.node_id;
                altitude=event.altitude;
                order=event.received_order;
                witness=event.witness !is null;
                event.witness_mask[].each!((n) => witness_mask~=cast(uint)(n));
                round=(event.hasRound)?event.round.number:event.round.number.min;
                father_less=event.isFatherLess;
                if (witness) {
                    event.witness.strong_seeing_mask[].each!((n) => strongly_seeing_mask~=cast(uint)(n));
                    event.witness.round_seen_mask[].each!((n) => round_seen_mask~=cast(uint)(n));

                }
                // if (event.isFatherLess) {
                //     (() @trusted {
                //         writefln("EventView isFatherLess %s node_id=%s id=%d mother_id=%d %s m=%s f=%s",
                //             witness_mask, event.node_id, event.id, mother, event.fingerprint.cutHex,
                //             event.event_package.event_body.mother.cutHex,
                //             event.event_package.event_body.mother.cutHex);
                //     })();
                // }
            }
        });

}


@safe
interface Authorising {
//    void time(const(sdt_t) t);

    const(sdt_t) time() pure const nothrow;

    bool isValidChannel(const(Pubkey) channel) const pure nothrow;

    void send(const(Pubkey) channel, const(Document) doc);

    // final void send(T)(const(Pubkey) channel, T pack) if(isHiBONRecord!T) {
    //     send(channel, pack.toDoc);
    // }

    alias ChannelFilter=bool delegate(const(Pubkey) channel) @safe;
    const(Pubkey) gossip(ChannelFilter channel_filter, const Document);

    final const(Pubkey) gossip(T)(ChannelFilter channel_filter, const T pack) if(isHiBONRecord!T) {
        return gossip(channel_owner, pack.toDoc);
    }

    // final const(Pubkey) gossip(T)(const(Pubkey) channel_owner, const T pack) nothrow if(isHiBONRecord!T) {
    //     return gossip(channel_owner, pack.toDoc);
    // }

    void add_channel(const(Pubkey) channel);
    void remove_channel(const(Pubkey) channel);
}

@safe
//@RecordType("EBODY")
struct EventBody {
    enum int eva_altitude=-77;
    import tagion.basic.ConsensusExceptions;
    protected alias check=Check!HashGraphConsensusException;
    import std.traits : getUDAs, hasUDA, getSymbolsByUDA, OriginalType, Unqual, hasMember;

    @Label("$doc", true)  @Filter(q{!a.empty}) Document payload; // Transaction
    @Label("$m", true) @(Filter.Initialized) Buffer mother; // Hash of the self-parent
    @Label("$f", true) @(Filter.Initialized) Buffer father; // Hash of the other-parent
    @Label("$a") int altitude;
    @Label("$t") sdt_t time;

    bool verify() {
        return (father is null)?true:(mother !is null);
    }
    mixin HiBONRecord!(
        q{
            this(
                Document payload,
                const Event mother,
                const Event father,
                lazy const sdt_t time) inout {
                this.time      =    time;
                this.mother    =    (mother is null)?null:mother.fingerprint;
                this.father    =    (father is null)?null:father.fingerprint;
                this.payload   =    payload;
                this.altitude  =    mother.nextAltitide;
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

    immutable(EventBody) eva();

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

//@RecordType("EPACK") @safe
pragma(msg, "fixme(cbr): Should be a HiRPC");
@safe
struct EventPackage {
    @Label("") Buffer fingerprint;
    @Label("$sign", true) Signature signature;
    @Label("$pkey", true) Pubkey pubkey;
    @Label("$body") EventBody event_body;

    mixin HiBONRecord!(
        q{
            import tagion.basic.ConsensusExceptions: ConsensusCheck=Check, EventConsensusException, ConsensusFailCode;
            protected alias consensus_check=ConsensusCheck!EventConsensusException;
            import std.stdio;
            /++
             Used when a Event is receved from another node
             +/
            this(const SecureNet net, const(Document) doc_epack) {
                this(doc_epack);
                consensus_check(pubkey.length !is 0, ConsensusFailCode.EVENT_MISSING_PUBKEY);
                consensus_check(signature.length !is 0, ConsensusFailCode.EVENT_MISSING_SIGNATURE);
                fingerprint=net.hashOf(event_body);
                consensus_check(net.verify(fingerprint, signature, pubkey), ConsensusFailCode.EVENT_BAD_SIGNATURE);
            }

            /++
             Create a EventPackage from a body
             +/
            this(const SecureNet net, immutable(EventBody) ebody) {
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
    @Label("$tides", true) @Filter(q{a.length is 0}) private Tides _tides;
    @Label("$events", true) @Filter(q{a.length is 0}) const(immutable(EventPackage)*[]) epacks;
    @Label("$state") ExchangeState state;
    enum tidesName=GetLabel!(_tides).name;
    enum epacksName=GetLabel!(epacks).name;
    enum stateName=GetLabel!(state).name;

    mixin HiBONRecordType;
    mixin JSONString;

    // mixin HiBONRecord!(
    //     q{
    this(Tides tides) pure nothrow {
        _tides=tides;
        epacks=null;
        state=ExchangeState.TIDAL_WAVE;
    }

    this(immutable(EventPackage)*[] epacks, const ExchangeState state) pure nothrow {
        this.epacks=epacks;
        this.state=state;
    }
    private  struct LoadTides {
        @Label(tidesName) Tides tides;
        mixin HiBONRecord!(
            q{
                this(const(Tides) _tides) const {
                    tides=_tides;
                }
            });

    }

    this(const SecureNet net, const Document doc) {
        state=doc[stateName].get!ExchangeState;
        immutable(EventPackage)*[] event_packages;
        if (doc.hasMember(epacksName)) {
            const sub_doc=doc[epacksName].get!Document;
            foreach(e; sub_doc[]) {
                (() @trusted {
                    immutable epack=cast(immutable)(new EventPackage(net, e.get!Document));
                    event_packages~=epack;
                })();
            }
        }
        epacks=event_packages;
        if (doc.hasMember(tidesName)) {
            auto load_tides=LoadTides(doc);
            _tides=load_tides.tides;
        }
    }

    const(Document) toDoc() const {
        auto h=new HiBON;
        h[stateName]=state;
        if (_tides.length) {
            const load_tides=const(LoadTides)(_tides);
            h[tidesName]=load_tides.toDoc[tidesName].get!Document;
        }
        if (epacks.length) {
            auto epacks_hibon=new HiBON;
            foreach(i, epack; epacks) {
                epacks_hibon[i]=epack.toDoc;
            }
            h[epacksName]=epacks_hibon;
        }
        return Document(h);
    }

    const(Tides) tides() const pure nothrow {
        if (_tides) {
            return _tides;
        }
        Tides result;
        foreach(e; epacks) {
            result.update(e.pubkey,
                {
                    return e.event_body.altitude;
                },
                (int altitude)
                {
                    return highest(altitude, e.event_body.altitude);
                });
        }
        return result;
    }

}

//@RecordType("Eva")
@safe
struct EvaPayload {
    @Label("$channel") Pubkey channel;
    @Label("$nonce") Buffer nonce;
    mixin HiBONRecord!(
        q{
            this(const Pubkey channel, const Buffer nonce) pure {
                this.channel=channel;
                this.nonce=nonce;
            }
        }
        );
}

static assert(isHiBONRecord!Wavefront);
static assert(isHiBONRecord!(EventPackage));

static assert(isHiBONRecord!(immutable(EventPackage)));
