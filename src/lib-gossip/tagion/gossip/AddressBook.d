module tagion.gossip.AddressBook;

@safe:

import core.thread : Thread;
import std.format;
import std.range;
import std.path : isValidFilename;
import std.conv;
import std.algorithm;
import std.exception;
import std.string;

import tagion.basic.tagionexceptions;
import tagion.basic.Types;
import tagion.crypto.Types : Pubkey;
import tagion.dart.DART : DART;
import tagion.dart.DARTRim;
import tagion.hibon.HiBONFile;
import tagion.hibon.HiBONRecord;
import tagion.logger.Logger : log;
import tagion.script.standardnames;
import tagion.script.namerecords;
import tagion.utils.Miscellaneous : cutHex;
import tagion.utils.Result;

/++
 + Exceptions used for the addressbook
 +/
@safe
class AddressException : TagionException {
    //    string task_name; /// Contains the name of the task when the execption has throw
    this(string msg, string file = __FILE__, size_t line = __LINE__) pure nothrow {
        super(msg, file, line);
    }
}

private alias check = Check!AddressException;

/** 
 * Address book for node p2p communication
 */
@safe
synchronized class AddressBook {
    /** Addresses for node */
    protected immutable(NetworkNodeRecord)*[Pubkey] addresses;

    alias NNRResult = Result!(immutable(NetworkNodeRecord)*, AddressException);

    /**
     * Init NodeAddress if public key exist
     * @param pkey - public key for check
     * @return initialized node address
     */
    NNRResult opIndex(const Pubkey pkey) const pure nothrow {
        auto addr = pkey in addresses;
        /* static assert(0, typeof(*addr)); */
        if (addr !is null) {
            return NNRResult(*addr);
        }
        return NNRResult(assumeWontThrow(format!("Address %s not found")(pkey.encodeBase64)));
    }

    /* 
     * Set an individual channel
     *
     * Params:
     *   nnr = The channel to set
     */
    void set(immutable(NetworkNodeRecord)* nnr) {
        Pubkey channel = nnr.channel;
        addresses[channel] = nnr;
    }

    /**
     * Remove addresses by public key
     * @param pkey - public key fo remove addresses
     */
    void remove(const Pubkey pkey) pure nothrow {
        addresses.remove(pkey);
    }

    /**
     * Check for a public key in network
     * @param pkey - public key fo check
     * @return true if public key exist
     */
    bool exists(const Pubkey pkey) const pure nothrow {
        return (pkey in addresses) !is null;
    }

    /**
     * Check for an active public key in network
     * @param pkey - public key fo check
     * @return true if pkey active
     */
    bool isActive(const Pubkey pkey) const pure nothrow {
        return exists(pkey) && assumeWontThrow(this[pkey].get).state is NetworkNodeRecord.State.ACTIVE;
    }

    /**
     * Return active node channels in network
     * @return active node channels
     */
    Pubkey[] keys() @trusted const pure nothrow {
        auto channels = (cast(NetworkNodeRecord*[Pubkey])addresses).keys;
        return channels;
    }

    /**
     * Return amount of nodes in networt
     * @return amount of nodes
     */
    size_t length() const pure nothrow {
        return addresses.length;
    }

    /**
     * Sets the Addresses from an array of NNR records
     * The addresses should be empty when set
    */
    void opAssign(immutable(NetworkNodeRecord)*[] nnrs) 
    in (addresses.empty, "Address have already been set, call clear() first if this is intended")
    do {
        foreach(nnr; nnrs) {
            addresses[nnr.channel] = nnr;
        }
    }

    void clear() {
        addresses = null;
    }
}


static shared(AddressBook) addressbook;

shared static this() {
    addressbook = new shared(AddressBook)();
}

// This function is used in dev mode when reading from an address file instead of the dart.
immutable(NetworkNodeRecord)*[] parseAddressFile(Range)(Range address_file_content) @trusted
if(isInputRange!Range && is(ElementType!Range : const(char[]))) {
    import std.format;
    import tagion.hibon.HiBONtoText;
    import tagion.basic.Types;

    immutable(NetworkNodeRecord)*[] nnrs;

    foreach (line; address_file_content) {
        if(line.empty) {
            continue;
        }
        auto pair = line.split(); // Split by whitespace
        check(pair.length == 2, format("Expected exactly 2 fields in addresbook line\n%s", line));
        const pkey = Pubkey(pair[0].strip.decode);
        check(pkey.length == 33, "Pubkey should have a length of 33 bytes");
        const addr = pair[1].strip;

        nnrs ~= new NetworkNodeRecord(pkey, addr.idup);
    }

    return nnrs;
}

/// AddressBook
@trusted 
unittest {
    import std.exception;
    import core.exception;
    import std.algorithm;

    enum address_content = `
        @AzZPqaMsYOwXVgitRRVe7XlyCCSdBeFK6b8mTnv8IDfU	node_3
        @AoL9_T3JJ09fnPKo7Y1in9mpKkjgxSQ_sD0t0CPCcLKk	node_4
        @AumexnPXMa0mKVsYQeEKvY4Y640DXNCuBU6XdzFOicWC	node_5
        @AxEDiWOgvaTLn-zMs62msv-54RwVNA7x7xE0rtLrCd3o	node_2
        @A5VO5-Nk5fUR7Yta7aSIpcXwWzN6cIkbKvg2-So0G52H	node_1`;

    immutable(NetworkNodeRecord)*[] nnrs = parseAddressFile(address_content.splitLines);

    shared(AddressBook) unitbook = new shared(AddressBook)();

    // Can set the address book from a list of nnr records
    unitbook = nnrs;
    assert(unitbook.length == 5);

    // It can only be set once
    assertThrown!AssertError(unitbook = nnrs);
    assert(unitbook.length == 5);

    // Otherwise it should be explicitly cleared before it can be set again
    unitbook.clear();
    assert(unitbook.length == 0);
    unitbook = nnrs;
    assert(unitbook.length == 5);

    // Get all of the active channels
    Pubkey[] channels = unitbook.keys;
    foreach(channel; channels) {
        assert(unitbook.exists(channel));
    }

    // We can update/add a channel
    {
        import tagion.utils.StdTime;
        auto nnr = nnrs[0];
        assert(!unitbook.isActive(nnr.channel));

        immutable mod_nnr = new NetworkNodeRecord(
            nnr.channel,
            "name",
            sdt_t(0),
            NetworkNodeRecord.State.ACTIVE,
            nnr.address
        );

        unitbook.set(mod_nnr);

        assert(unitbook.isActive(nnr.channel));
    }

    // Remove channels
    {
        Pubkey channel = nnrs[0].channel;
        assert(unitbook.exists(channel));
        unitbook.remove(channel);
        assert(!unitbook.exists(channel));
    }
}
