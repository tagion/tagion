/// HashGraph basic support functions
module tagion.hashgraph.HashGraphBasic;

import std.stdio;
import std.format;
import std.typecons : TypedefType;
import std.exception : assumeWontThrow;

import tagion.basic.Types : Buffer;
import tagion.basic.basic : EnumText;
import tagion.crypto.Types : Signature, Pubkey, Fingerprint;
import tagion.hashgraph.Event;
import tagion.hashgraph.HashGraph : HashGraph;
import tagion.utils.BitMask;
import tagion.hibon.HiBON : HiBON;
import tagion.communication.HiRPC : HiRPC;
import tagion.hibon.HiBONRecord;
import tagion.hibon.HiBONJSON : JSONString;
import tagion.utils.StdTime;

import tagion.hibon.Document : Document;
import tagion.crypto.SecureInterfaceNet : SecureNet;

import tagion.basic.ConsensusExceptions : convertEnum, GossipConsensusException, ConsensusException;

enum minimum_nodes = 3;
import tagion.utils.Miscellaneous : cutHex;

/// check function used in the Event package
// Returns the highest altitude
@safe @nogc
int highest(int a, int b) pure nothrow {
    if (higher(a, b)) {
        return a;
    }
    else {
        return b;
    }
}

// Is a higher or equal to b
@safe @nogc
bool higher(int a, int b) pure nothrow {
    return a - b > 0;
}

@safe
unittest { // Test of the altitude measure function
    int x = int.max - 10;
    int y = x + 20;
    assert(x > 0);
    assert(y < 0);
    assert(highest(x, y) == y);
    assert(higher(y, x));
    assert(!higher(x, x));
}

/**
 * Calculates the majority votes
 * Params:
 *     voting    = Number of votes
 *     node_size = Total number of votes
 * Returns:
 *     Returns `true` if the votes are more than 2/3
 */
@safe @nogc
bool isMajority(const size_t voting, const size_t node_size) pure nothrow {
    return (node_size >= minimum_nodes) && (3 * voting > 2 * node_size);
}

@safe
bool isMajority(const(BitMask) mask, const HashGraph hashgraph) pure nothrow {
    import tagion.basic.basic;
    import tagion.basic.Debug;
    const test_mask = mask - hashgraph.excluded_nodes_mask;
    // __write("MASK: %s TEST MASK: %s", mask, test_mask);
    const vote_mask = mask;//  hashgraph.excluded_nodes_mask;
    return isMajority(vote_mask.count, hashgraph.node_size);
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
struct EventBody {
    enum int eva_altitude = -77;
    import tagion.basic.ConsensusExceptions;

    protected alias check = Check!HashGraphConsensusException;
    import std.traits : getSymbolsByUDA, OriginalType, Unqual, hasMember;

    @label("$p", true) @filter(q{!a.empty}) Document payload; // Transaction
    @label("$m", true) @(filter.Initialized) Buffer mother; // Hash of the self-parent
    @label("$f", true) @(filter.Initialized) Buffer father; // Hash of the other-parent
    @label("$a") int altitude;
    @label("$t") sdt_t time;
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
    @label("") Buffer fingerprint;
    @label("$sign") Signature signature;
    @label("$pkey") Pubkey pubkey;
    @label("$body") EventBody event_body;

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
                auto _fingerprint=net.calcHash(event_body);
                fingerprint = cast(Buffer) _fingerprint;
                consensus_check(net.verify(_fingerprint, signature, pubkey), ConsensusFailCode.EVENT_BAD_SIGNATURE);
            }

            /++
             Create a EventPackage from a body
             +/
            this(const SecureNet net, immutable(EventBody) ebody) {
                pubkey=net.pubkey;
                event_body=ebody;
                auto _fingerprint=net.calcHash(event_body);
                fingerprint = cast(Buffer) _fingerprint;
                signature=net.sign(_fingerprint);
            }

            this(const SecureNet net, const Pubkey pkey, const Signature signature, immutable(EventBody) ebody) {
                pubkey=pkey;
                event_body=ebody;
                auto _fingerprint=net.calcHash(event_body);
                fingerprint = cast(Buffer) _fingerprint;
                this.signature=signature;
                consensus_check(net.verify(_fingerprint, signature, pubkey), 
                ConsensusFailCode.EVENT_BAD_SIGNATURE);
            }
        });
}

alias Tides = int[Pubkey];

@recordType("Wavefront") @safe
struct Wavefront {
    @label("$tides", true) @filter(q{a.length is 0}) private Tides _tides;
    @label("$events", true) @filter(q{a.length is 0}) const(immutable(EventPackage)*[]) epacks;
    @label("$state") ExchangeState state;
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
        @label(tidesName) Tides tides;
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
                    (int altitude) { return highest(altitude, e.event_body.altitude); });
        }
    }

    @nogc
    const(Tides) tides() const pure nothrow {
        return _tides;
    }
}

@safe
struct EvaPayload {
    @label("$channel") Pubkey channel;
    @label("$nonce") Buffer nonce;
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
