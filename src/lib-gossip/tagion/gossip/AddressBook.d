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
    protected shared(string[Pubkey]) addresses;

    /**
     * Init NodeAddress if public key exist
     * @param pkey - public key for check
     * @return initialized node address
     */
    immutable(string) opIndex(const Pubkey pkey) const pure nothrow {
        auto addr = pkey in addresses;
        if (addr) {
            return cast(immutable)(*addr);
        }
        return string.init;
    }

    /**
     * Create associative array addresses
     * @param addr - value
     * @param pkey - key
     */
    void opIndexAssign(const string addr, const Pubkey pkey)
    in ((pkey in addresses) is null, format("Address %s has already been set", pkey.encodeBase64))
    do {
        addresses[pkey] = addr;
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

    const(string) getAddress(const Pubkey pkey) const pure nothrow {
        return addresses[pkey];
    }

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
 * \struct NodeAddress
 * Struct for node addresses 
 */
@safe
@recordType("NNR")
struct NodeAddress {

    @label(StdNames.owner) Pubkey owner;
    @label("t") MultiAddrProto addr_type;
    @label("h") immutable(ubyte)[] host;
    @label("T") MultiAddrProto transport;
    @label("p") uint port;

    /**
     * Parse node address to string
     * @return string address
     */
    string toString() const {
        return toNNGString();
    }

    string toNNGString() const {
        ushort concat(const(ubyte)[] a)
        in (a.length == 2) {
            version (BigEndian) {
                return a[1] << 8 | a[0];
            }
            else version (LittleEndian) {
                return a[0] << 8 | a[1];
            }
            else {
                static assert(0, "no eggs specified");
            }
        }

        switch (addr_type) {
        case MultiAddrProto.ip4:
            return format("tcp://%(%d.%):%s", host, port);
        case MultiAddrProto.ip6:
            return format("tcp://%(%x:%):%s", host.chunks(2).map!(a => concat(a)), port);
        default:
            assert(0, "The address type is invalid and cannot be converted to an nng address string");
        }
    }

    bool isValid() const @trusted {
        bool isPortValid() {
            return port >= 1 && port <= 65_535;
        }

        if (!isPortValid) {
            return false;
        }

        if (transport !is MultiAddrProto.tcp) {
            return false;
        }

        enum ip4length = 32;
        enum ip6length = 128;

        // TODO: check that host is not loobpack 'n stuff
        with (MultiAddrProto) switch (addr_type) {
        case ip4:
            return host.length == ip4length / 8;
        case ip6:
            return host.length == ip6length / 8;
        default:
            return false;
        }
    }
}

unittest {
    NodeAddress nnr;
    nnr.addr_type = MultiAddrProto.ip4;
    nnr.host = [200, 185, 5, 5];
    nnr.port = 80;
    nnr.transport = MultiAddrProto.tcp;

    assert(nnr.toNNGString == "tcp://200.185.5.5:80");

    nnr.host = [200, 185, 5, 5, 200, 185, 5, 5, 200, 185, 0, 0, 200, 185, 5, 5];
    nnr.addr_type = MultiAddrProto.ip6;

    assert(nnr.toNNGString == "tcp://c8b9:505:c8b9:505:c8b9:0:c8b9:505:80");
}
