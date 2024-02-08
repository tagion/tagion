module tagion.gossip.AddressBook;

@safe:

import core.thread : Thread;
import std.format;
import std.range;
import std.path : isValidFilename;
import std.conv;
import std.algorithm;

import tagion.basic.tagionexceptions;
import tagion.basic.Types;
import tagion.crypto.Types : Pubkey;
import tagion.dart.DART : DART;
import tagion.dart.DARTRim;
import tagion.hibon.HiBONFile;
import tagion.hibon.HiBONRecord;
import tagion.logger.Logger : log;
import tagion.script.standardnames;
import tagion.utils.Miscellaneous : cutHex;

/** Address book for node p2p communication */
@safe
synchronized class AddressBook {
    /** Addresses for node */
    protected NodeInfo[Pubkey] addresses;

    /**
     * Init NodeAddress if public key exist
     * @param pkey - public key for check
     * @return initialized node address
     */
    const(NodeInfo) opIndex(const Pubkey pkey) const pure nothrow @trusted {
        auto addr = pkey in addresses;
        if (addr) {
            return cast(NodeInfo)*addr;
        }
        return NodeInfo.init;
    }

    /**
     * Create associative array addresses
     * @param addr - value
     * @param pkey - key
     */
    void opIndexAssign(const NodeInfo info, const Pubkey pkey)
    in ((pkey in addresses) is null, format("Address %s has already been set", pkey.encodeBase64))
    do {
        addresses[pkey] = info;
    }

    /**
     * Remove addresses by public key
     * @param pkey - public key fo remove addresses
     */
    void erase(const Pubkey pkey) pure nothrow {
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
    Pubkey[] activeNodeChannels() @trusted const pure nothrow {
        auto channels = (cast(string[Pubkey]) addresses).keys;
        return channels;
    }

    alias getAddress = opIndex;

    /**
     * Return amount of nodes in networt
     * @return amount of nodes
     */
    size_t numOfNodes() const pure nothrow {
        return addresses.length;
    }
}

static shared(AddressBook) addressbook;

shared static this() {
    addressbook = new shared(AddressBook)();
}

/// https://github.com/multiformats/multiaddr/blob/master/protocols.csv
enum MultiAddrProto {
    ip4 = 4,
    tcp = 6,
    ip6 = 41,
}

/** 
 * Node Name Record
 * Holds the information for communicating with a node.
 */
@safe
@recordType("NNR")
struct NodeInfo {

    private @label(StdNames.nodekey) Buffer _owner;
    @label("a") string address;

    this(Pubkey __owner, string _addr) nothrow pure {
        _owner = cast(Buffer) __owner;
        address = _addr;
    }

    Pubkey owner() => Pubkey(_owner);

    /**
     * Parse node address to string
     * @return string address
     */
    string toString() const {
        return address;
    }

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
}

unittest {
    immutable nnr = NodeInfo(Pubkey(), "ip4/200.185.5.5/tcp/80");
    assert(nnr.toNNGString == "tcp://200.185.5.5:80");

    immutable nnr2 = NodeInfo(Pubkey(), "ip6/c8b9:505:c8b9:505:c8b9:0:c8b9:505/tcp/80");
    assert(nnr2.toNNGString == "tcp://c8b9:505:c8b9:505:c8b9:0:c8b9:505:80");
}
