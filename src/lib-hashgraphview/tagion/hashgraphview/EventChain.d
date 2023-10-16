module tagion.hashgraphview.EventChain;

version (none) {

    import std.algorithm : map;
    import std.array : array;
    import std.range : iota;

    import tagion.basic.Types : Buffer;
    import tagion.crypto.Types : Pubkey, Signature;
    import tagion.utils.StdTime : sdt_t;
    import tagion.hibon.HiBONRecord;
    import tagion.hibon.HiBON : HiBON;
    import tagion.hibon.Document : Document;
    import tagion.crypto.SecureInterfaceNet : SecureNet;
    import tagion.hashgraph.Event : Event;
    import tagion.hashgraph.HashGraphBasic : EventPackage, EventBody;

    enum NIL = -1; // Defines an unconected Event

    @safe
    struct EventBodyCompact {
        @label("p", true) @filter(q{!a.empty}) Document payload; // Transaction
        @label("m") @filter(q{a != -1}) @fixed(q{-1}) int mother; // Hash of the self-parent
        @label("f") @filter(q{a != -1}) @fixed(q{-1}) int father; // Hash of the other-parent
        @label("a") int altitude;
        @label("t") sdt_t time;
        @label("M", true) @(filter.Initialized) Buffer mother_fingerprint; /// This event is connect to the previous mother
        @label("F", true) @(filter.Initialized) Buffer father_fingerprint; /// This event is connect to the previous father
        @label("C", true) @(filter.Initialized) Pubkey channel; /// Event Channel (Pubkey of the node);
        mixin HiBONRecord;
    }

    @safe
    struct EventCompact {
        @label("s") Signature signature; // Signature
        @label("b") EventBodyCompact ebody; // Event Body
        mixin HiBONRecord;
    }

    @safe
    struct EventEpochChunk {
        @label("epacks") EventCompact[] epacks;
        @label("chain") Buffer chain;
        mixin HiBONRecord!(
                q{
            this(EventCompact[] epacks, Buffer chain) pure nothrow {
                this.epacks=epacks;
                this.chain=chain;
            }
        });
    }

    @safe
    struct HashGraphRecorver {
        const SecureNet net;
        this(const SecureNet net) {
            this.net = net;
        }

        immutable(EventEpochChunk) opCall(const(Event[]) events, Buffer chain) const pure {
            int[Buffer] event_ids;
            foreach (i, e; events) {
                event_ids[e.fingerprint] = cast(int) i;
            }
            EventCompact event_body_compact(const(Event) e) pure {
                EventBodyCompact ebody;
                ebody.altitude = e.event_body.altitude;
                ebody.time = sdt_t(e.event_body.time);
                ebody.payload = e.event_body.payload;
                if (e.mother) {
                    ebody.mother = event_ids.get(e.event_body.mother, NIL);
                    if (!(e.event_body.mother in event_ids)) {
                        ebody.mother_fingerprint = e.event_body.mother;
                        ebody.channel = Pubkey(e.channel);
                    }
                }
                if (e.father) {
                    ebody.father = event_ids.get(e.event_body.father, NIL);
                    if (!(e.event_body.father in event_ids)) {
                        ebody.father_fingerprint = e.event_body.father;
                    }
                }
                EventCompact epack;
                epack.ebody = ebody;
                epack.signature = Signature(e.event_package.signature);
                return epack;
            }

            auto epacks =
                events
                    .map!((e) => event_body_compact(e))
                    .array;
            return (() @trusted { return cast(immutable) EventEpochChunk(epacks, chain); })();
        }

        const(immutable(EventPackage)*[]) opCall(const(EventEpochChunk) epoch_chunk) const {
            auto result_epacks = new immutable(EventPackage)*[epoch_chunk.epacks.length];
            immutable(EventPackage)* reconstruct_epack(const int event_id) {
                immutable(EventPackage)* result;
                if (event_id !is NIL) {
                    if (result_epacks[event_id]) {
                        return result_epacks[event_id];
                    }
                    const ebody_compact = epoch_chunk.epacks[event_id];
                    Buffer mother_fingerprint;
                    Pubkey channel;
                    if (ebody_compact.ebody.mother_fingerprint) {
                        mother_fingerprint = ebody_compact.ebody.mother_fingerprint;
                        channel = Pubkey(ebody_compact.ebody.channel);
                    }
                    else {
                        const mother = reconstruct_epack(ebody_compact.ebody.mother);
                        mother_fingerprint = mother.fingerprint;
                        channel = Pubkey(mother.pubkey);
                    }
                    Buffer father_fingerprint;
                    if (ebody_compact.ebody.father_fingerprint) {
                        father_fingerprint = ebody_compact.ebody.father_fingerprint;
                    }
                    else {
                        const father = reconstruct_epack(ebody_compact.ebody.father);
                        if (father) {
                            father_fingerprint = father.fingerprint;
                        }
                    }
                    immutable ebody = EventBody(
                            ebody_compact.ebody.payload,
                            mother_fingerprint,
                            father_fingerprint,
                            ebody_compact.ebody.altitude,
                            ebody_compact.ebody.time);

                    result = cast(immutable) new EventPackage(net, channel, ebody_compact.signature, ebody);
                }
                return result;
            }
            // auto result=iota(cast(int)epoch_chunk.epacks.length)
            //     .map!((event_id) => reconstruct_epack(event_id))
            //     .array;
            return (() @trusted {
                return iota(cast(int) epoch_chunk.epacks.length)
                    .map!((event_id) => reconstruct_epack(event_id))
                    .array;
            })();
        }

    }

}
