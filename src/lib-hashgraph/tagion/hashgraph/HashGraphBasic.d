module tagion.hashgraph.HashGraphBasic;

import std.stdio;
import std.format;
import std.typecons: TypedefType;
import std.exception: assumeWontThrow;

import tagion.basic.Basic: Buffer, Signature, Pubkey, EnumText;
import tagion.hashgraph.Event;
import tagion.hashgraph.HashGraph: HashGraph;
import tagion.utils.BitMask;
import tagion.hibon.HiBON: HiBON;
import tagion.communication.HiRPC: HiRPC;
import tagion.hibon.HiBONRecord;
import tagion.hibon.HiBONJSON: JSONString;
import tagion.utils.StdTime;

import tagion.hibon.Document: Document;
import tagion.crypto.SecureInterfaceNet: SecureNet;

import tagion.basic.ConsensusExceptions: convertEnum, GossipConsensusException, ConsensusException;

enum minimum_nodes = 3;
import tagion.utils.Miscellaneous: cutHex;

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
    return (node_size >= minimum_nodes) && (3 * voting > 2 * node_size);
}

@safe @nogc
bool isMajority(const(BitMask) mask, const HashGraph hashgraph) pure nothrow {
    return isMajority(mask.count, hashgraph.node_size);
}

@safe @nogc
bool isAllVotes(const(BitMask) mask, const HashGraph hashgraph) pure nothrow {
    return mask.count is hashgraph.node_size;
}

enum int eva_altitude = -77;
@safe @nogc
int nextAltitide(const Event event) pure nothrow {
    return (event) ? event.altitude + 1 : eva_altitude;
}

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
    BREAKING_WAVE,
    RIPPLE, /// Ripple is used the first time a node connects to the network
    COHERENT, /** Coherent state is when an the least epoch wavefront has been received or
                        if all the nodes isEva notes (This only occurs at genesis).
                     */

}

alias convertState = convertEnum!(ExchangeState, GossipConsensusException);

@safe
interface EventMonitorCallbacks {
    nothrow {
        void create(const(Event) e);
        void connect(const(Event) e);
        void witness(const(Event) e);
        void round_seen(const(Event) e);
        void round(const(Event) e);
        void round_decided(const(Round.Rounder) rounder);
        void round_received(const(Event) e);
        void famous(const(Event) e);
        void round(const(Event) e);
        void son(const(Event) e);
        void daughter(const(Event) e);
        void forked(const(Event) e);
        void epoch(const(Event[]) received_event);
        void send(const Pubkey channel, lazy const Document doc);
        final void send(T)(const Pubkey channel, lazy T pack) if (isHiBONRecord!T) {
            send(channel, pack.toDoc);
        }

        void receive(lazy const Document doc);
        final void receive(T)(lazy const T pack) if (isHiBONRecord!T) {
            receive(pack.toDoc);
        }
    }
}

// EventView is used to store event has a
struct EventView {
    enum eventsName = "$events";
    uint id;
    @Label("$m", true) @(Filter.Initialized) uint mother;
    @Label("$f", true) @(Filter.Initialized) uint father;
    @Label("$n") size_t node_id;
    @Label("$a") int altitude;
    @Label("$o") int order;
    @Label("$r") int round;
    @Label("$rec") int round_received;
    @Label("$w", true) @(Filter.Initialized) bool witness;
    @Label("$famous", true) @(Filter.Initialized) bool famous;
    @Label("witness") uint[] witness_mask;
    @Label("$strong") uint[] strongly_seeing_mask;
    @Label("$seen") uint[] round_seen_mask;
    @Label("$received") uint[] round_received_mask;
    bool father_less;

    mixin HiBONRecord!(
            q{
            this(const Event event, const size_t relocate_node_id=size_t.max) {
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
                node_id=(relocate_node_id is size_t.max)?event.node_id:relocate_node_id;
                altitude=event.altitude;
                order=event.received_order;
                witness=event.witness !is null;
                event.witness_mask[].each!((n) => witness_mask~=cast(uint)(n));
                round=(event.hasRound)?event.round.number:event.round.number.min;
                father_less=event.isFatherLess;
                if (witness) {
                    event.witness.strong_seeing_mask[].each!((n) => strongly_seeing_mask~=cast(uint)(n));
                    event.witness.round_seen_mask[].each!((n) => round_seen_mask~=cast(uint)(n));
                    famous = event.witness.famous;
                }
                if (!event.round_received_mask[].empty) {
                    event.round_received_mask[].each!((n) => round_received_mask~=cast(uint)(n));
                }
                round_received=(event.round_received)?event.round_received.number:int.min;
            }
        });

}

@safe
interface Authorising {

    const(sdt_t) time() pure const nothrow;

    bool isValidChannel(const(Pubkey) channel) const pure nothrow;

    void send(const(Pubkey) channel, const(Document) doc);

    alias ChannelFilter = bool delegate(const(Pubkey) channel) @safe;
    alias SenderCallBack = const(HiRPC.Sender) delegate() nothrow @safe;
    const(Pubkey) select_channel(ChannelFilter channel_filter);

    const(Pubkey) gossip(ChannelFilter channel_filter, SenderCallBack sender);

    void add_channel(const(Pubkey) channel);
    void remove_channel(const(Pubkey) channel);
}

@safe
struct EventBody {
    enum int eva_altitude = -77;
    import tagion.basic.ConsensusExceptions;

    protected alias check = Check!HashGraphConsensusException;
    import std.traits: getUDAs, hasUDA, getSymbolsByUDA, OriginalType, Unqual, hasMember;

    @Label("$p", true) @Filter(q{!a.empty}) Document payload; // Transaction
    @Label("$m", true) @(Filter.Initialized) Buffer mother; // Hash of the self-parent
    @Label("$f", true) @(Filter.Initialized) Buffer father; // Hash of the other-parent
    @Label("$a") int altitude;
    @Label("$t") sdt_t time;

    bool verify() {
        return (father is null) ? true : (mother !is null);
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

            package this(
                Document payload,
                const Buffer mother_fingerprint,
                const Buffer father_fingerprint,
                const int altitude,
                lazy const sdt_t time) inout {
                this.time      =    time;
                this.mother    =    mother_fingerprint;
                this.father    =    father_fingerprint;
                this.payload   =    payload;
                this.altitude  =    altitude;
                consensus();
            }


        });

    invariant {
        if ((mother.length != 0) && (father.length != 0)) {
            assert(mother.length == father.length);
        }
    }

    @nogc
    bool isEva() pure const nothrow {
        return (mother.length == 0);
    }

    immutable(EventBody) eva();

    void consensus() inout {
        if (mother.length == 0) {
            // Seed event first event in the chain
            check(father.length == 0, ConsensusFailCode.NO_MOTHER);
        }
        else {
            if (father.length != 0) {
                // If the Event has a father
                check(mother.length == father.length, ConsensusFailCode.MOTHER_AND_FATHER_SAME_SIZE);
            }
            check(mother != father, ConsensusFailCode.MOTHER_AND_FATHER_CAN_NOT_BE_THE_SAME);
        }
    }

}

@safe
struct EventPackage {
    @Label("") Buffer fingerprint;
    @Label("$sign") Signature signature;
    @Label("$pkey") Pubkey pubkey;
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

            this(const SecureNet net, const Pubkey pkey, const Signature signature, immutable(EventBody) ebody) {
                pubkey=pkey;
                event_body=ebody;
                fingerprint=net.hashOf(event_body);
                this.signature=signature;
                consensus_check(net.verify(fingerprint, signature, pubkey), ConsensusFailCode.EVENT_BAD_SIGNATURE);
            }
        });
}

alias Tides = int[Pubkey];

@RecordType("Wavefront") @safe
struct Wavefront {
    @Label("$tides", true) @Filter(q{a.length is 0}) private Tides _tides;
    @Label("$events", true) @Filter(q{a.length is 0}) const(immutable(EventPackage)*[]) epacks;
    @Label("$state") ExchangeState state;
    enum tidesName = GetLabel!(_tides).name;
    enum epacksName = GetLabel!(epacks).name;
    enum stateName = GetLabel!(state).name;

    mixin HiBONRecordType;
    mixin JSONString;

    this(Tides tides) pure nothrow {
        _tides = tides;
        epacks = null;
        state = ExchangeState.TIDAL_WAVE;
    }

    this(immutable(EventPackage)*[] epacks, Tides tides, const ExchangeState state) pure nothrow {
        this.epacks = epacks;
        this._tides = tides;
        this.state = state;
    }

    private struct LoadTides {
        @Label(tidesName) Tides tides;
        mixin HiBONRecord!(
                q{
                this(const(Tides) _tides) const {
                    tides=_tides;
                }
            });
    }

    this(const SecureNet net, const Document doc) {
        state = doc[stateName].get!ExchangeState;
        immutable(EventPackage)*[] event_packages;
        if (doc.hasMember(epacksName)) {
            const sub_doc = doc[epacksName].get!Document;
            foreach (e; sub_doc[]) {
                (() @trusted {
                    immutable epack = cast(immutable)(new EventPackage(net, e.get!Document));
                    event_packages ~= epack;
                })();
            }
        }
        epacks = event_packages;
        if (doc.hasMember(tidesName)) {
            auto load_tides = LoadTides(doc);
            _tides = load_tides.tides;
        }
        update_tides;
    }

    const(Document) toDoc() const {
        auto h = new HiBON;
        h[stateName] = state;
        if (epacks.length) {
            auto epacks_hibon = new HiBON;
            foreach (i, epack; epacks) {
                epacks_hibon[i] = epack.toDoc;
            }
            h[epacksName] = epacks_hibon;
        }
        if (_tides.length) {
            const load_tides = const(LoadTides)(_tides);
            h[tidesName] = load_tides.toDoc[tidesName].get!Document;
        }
        return Document(h);
    }

    private void update_tides() pure nothrow {
        foreach (e; epacks) {
            _tides.update(e.pubkey,
            { return e.event_body.altitude; },
                    (int altitude) {
                return highest(altitude, e.event_body.altitude);
            });
        }
    }

    @nogc
    const(Tides) tides() const pure nothrow {
        return _tides;
    }
}

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
