module tagion.gossip.AddressBook;

@safe:

import core.thread : Thread;
import std.format;
import std.range;
import std.path : isValidFilename;
import std.conv;
import std.algorithm;
import std.exception;

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

    /**
     * Create associative array addresses
     * @param addr - value
     * @param pkey - key
     */
    void opIndexAssign(immutable(NetworkNodeRecord)* info, const Pubkey pkey) pure nothrow
    in ((pkey in addresses) is null, assumeWontThrow(format!("Address %s has already been set")(pkey.encodeBase64)))
    do {
        addresses[pkey] = info;
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
    bool exists(const Pubkey pkey) const nothrow {
        return (pkey in addresses) !is null;
    }

    /**
     * Check for an active public key in network
     * @param pkey - public key fo check
     * @return true if pkey active
     */
    bool isActive(const Pubkey pkey) const pure nothrow {
        return (pkey in addresses) !is null;
    }

    /**
     * Return active node channels in network
     * @return active node channels
     */
    Pubkey[] activeNodeChannels() @trusted const pure nothrow 
    out (channels; !channels.empty, "No channels were set") {
        auto channels = (cast(NetworkNodeRecord*[Pubkey])addresses).keys;
        return channels;
    }

    /**
     * Return amount of nodes in networt
     * @return amount of nodes
     */
    size_t numOfNodes() const pure nothrow {
        return addresses.length;
    }

    /**
     * Sets the Addresses from an array of NNR records
     * The addresses should be empty when set
    */
    void set(immutable(NetworkNodeRecord)*[] nnrs) 
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
