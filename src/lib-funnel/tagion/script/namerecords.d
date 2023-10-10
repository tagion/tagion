module tagion.script.namerecords;

//import tagion.script.common;
import tagion.script.standardnames;
import tagion.basic.Types : Buffer;
import tagion.crypto.Types : Pubkey, Signature, Fingerprint;
import tagion.hibon.HiBONRecord;
import tagion.hibon.Document;
import tagion.dart.DARTBasic;

@safe
@recordType("NNC") struct NetworkNameCard {
    @label(StdNames.name) string name; /// Tagion domain name
    @label(StdNames.owner) Pubkey pubkey; /// NNC pubkey
    @label("$lang") string lang; /// Language used for the #name
    @label(StdNames.time) ulong time; /// Time-stamp of
    @label("$record") DARTIndex record; /// Hash pointer to NRC
    mixin HiBONRecord;

    import tagion.crypto.SecureInterfaceNet : HashNet;

    static DARTIndex dartHash(const(HashNet) net, string name) {
        pragma(msg, "fixme(cbr): Should just used dartIndex");
        NetworkNameCard nnc;
        nnc.name = name;
        return net.dartIndex(nnc);
    }
}

@safe
@recordType("NRC") struct NetworkNameRecord {
    @label("$name") DARTIndex name; /// Hash of the NNC.name
    @label(StdNames.previous) Buffer previous; /// Hash pointer to the previuos NRC
    @label("$index") uint index; /// Current index previous.index+1
    @label("$payload", true) Document payload;
    mixin HiBONRecord;
}

version (none) @safe
@recordType("HL") struct HashLock {
    import tagion.crypto.SecureInterfaceNet;

    @label("$lock") Buffer lock; /// Of the NNC with the pubkey
    mixin HiBONRecord!(q{
                @disable this();
                import tagion.crypto.SecureInterfaceNet : HashNet;
                import tagion.script.ScriptException : check;
                import tagion.hibon.HiBONRecord : isHiBONRecord, hasHashKey;
                this(const(HashNet) net, const(Document) doc) {
                    check(doc.hasHashKey, "Document should have a hash key");
                    lock = net.rawCalcHash(doc.serialize);
                }
                this(T)(const(HashNet) net, ref const(T) h) if (isHiBONRecord!T) {
                    this(net, h.toDoc);
                }
            });

    bool verify(const(HashNet) net, const(Document) doc) const {
        return lock == net.rawCalcHash(doc.serialize);
    }

    bool verify(T)(const(HashNet) net, ref T h) const if (isHiBONRecord!T) {
        return verify(net, h.toDoc);
    }

}

version (none) @safe
unittest {
    import tagion.crypto.SecureNet : StdHashNet;
    import tagion.script.ScriptException : ScriptException;
    import std.exception : assertThrown, assertNotThrown;
    import std.string : representation;

    const net = new StdHashNet;
    NetworkNameCard nnc;
    {
        import tagion.crypto.SecureNet : StdSecureNet;

        auto good_net = new StdSecureNet;
        good_net.generateKeyPair("very secret correct password");
        nnc.name = "some_name";
        nnc.pubkey = good_net.pubkey;
    }
    NetworkNameCard bad_nnc;
    bad_nnc.name = "some_other_name";
    static struct NoHash {
        string name;
        mixin HiBONRecord!(q{
                    this(string name) {
                        this.name = name;
                    }
                });
    }
    // Invalid HR
    const nohash = NoHash("no hash");
    //        const x=HashLock(net, nohash);
    assertThrown(HashLock(net, nohash));
    // Correct HR
    const hr = assertNotThrown(HashLock(net, nnc));

    { // Verify that the NNC has been signed correctly
        // Bad NNC
        assert(!hr.verify(net, bad_nnc));
        // Good NNC
        assert(hr.verify(net, nnc));
    }

}

version (none) @recordType("$@NNR") struct NetworkNodeRecord {
    enum State {
        PROSPECT,
        STANDBY,
        LOCKED,
        STERILE
    }

    @label("$name") string name;
    @label(StdNames.time) ulong time;
    //  @label("$sign") uint sign; /// Signature of
    @label("$state") State state;
    @label("$addr") string address;
    mixin HiBONRecord;
}
