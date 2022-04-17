module tagion.gossip.AddressBook;

import tagion.basic.Basic : Pubkey;
import tagion.hibon.HiBONRecord;
import tagion.dart.DART : DART;
import tagion.dart.DARTOptions : DARTOptions;
import tagion.logger.Logger : log;

import std.file : exists;
import std.random;

// alias ActiveNodeAddressBookPub = immutable(AddressBook_deprecation);

// @safe
// immutable class AddressBook_deprecation {
//     this(const(NodeAddress[Pubkey]) addrs) @trusted {
//         addressbook.overwrite(addrs);
// //         this.data = cast(immutable) addrs.dup;
//     }

// //    immutable(NodeAddress[Pubkey]) data;

//     static immutable(NodeAddress[Pubkey]) data() @trusted {
//         return cast(immutable)addressbook._data;
//     }

// }

// @safe
// struct AddressDirecory {
//     private NodeAddress[Pubkey] addresses;
//     mixin HiBONRecord;
// }

@safe
synchronized class AddressBook {
    alias NodeAddresses = NodeAddress[Pubkey];
    // pragma(msg, "typeof(addresses.byKeyValue) ", typeof(NodeAddresses.byKeyValue));
    alias NodePair = typeof((cast(NodeAddresses) addresses).byKeyValue.front);
    static struct AddressDirectory {
        NodeAddresses addresses;
        mixin HiBONRecord;
    }

    protected {
        Random rnd;
    }
    this() {
        //        pragma(msg, "rnd ", typeof(rnd));
        rnd = shared(Random)(unpredictableSeed);
    }

    protected shared(NodeAddresses) addresses;

    immutable(NodeAddress[Pubkey]) _data() @trusted {
        pragma(msg, "fixme(cbr): AddressBook._data This function should be removed whne the addressbook has been implemented");
        NodeAddress[Pubkey] result;
        foreach(pkey, addr; addresses) {
            result[pkey] = addr;
        }
        return cast(immutable)result;
    }

    void overwrite(const(NodeAddress[Pubkey]) addrs) {
        addresses = null;
        foreach (pkey, addr; addrs) {
            addresses[pkey] = addr;
        }
    }

    void load(string filename) {
        if (filename.exists) {
            auto dir = filename.fread!AddressDirectory;
            overwrite(dir.addresses);
        }
    }

    void save(string filename) @trusted {
        AddressDirectory dir;
        dir.addresses = cast(NodeAddress[Pubkey]) addresses;
        filename.fwrite(dir);
    }

    immutable(NodeAddress) opIndex(const Pubkey pkey) const pure nothrow {
        auto addr = pkey in addresses;
        if (addr) {
            return cast(immutable)(*addr);
        }
        return NodeAddress.init;
    }

    void opIndexAssign(const NodeAddress addr, const Pubkey pkey)
    in {
        assert(pkey.length is 33);
        assert(!(pkey in addresses), "Temp check should be removed");
    }
    do { //pure nothrow {
        import std.stdio;
        import tagion.utils.Miscellaneous : cutHex;

        writefln("AddressBook.opIndexAssign %s:%d", pkey.cutHex, pkey.length);

        addresses[pkey] = addr;
        writefln("After AddressBook.opIndexAssign %s:%d", pkey.cutHex, pkey.length);

    }

    // void set(const Pubkey pkey) {//, const NodeAddress addr) {
    //     import std.stdio;
    //     import tagion.utils.Miscellaneous : cutHex;
    //     writefln("AddressBook.set %s", pkey.cutHex);
    // }

    void erase(const Pubkey pkey) pure nothrow {
        addresses.remove(pkey);
    }

    bool exists(const Pubkey pkey) const pure nothrow {
        return (pkey in addresses) !is null;
    }

    immutable(Pubkey[]) activeNodeChannels() @trusted const pure nothrow {
        import std.exception : assumeUnique;

        auto channels = (cast(NodeAddresses) addresses).keys;
        return assumeUnique(channels);
    }

    size_t numOfActiveNodes() const pure nothrow {
        return addresses.length;
    }

    size_t numOfNodes() const pure nothrow {
        return addresses.length;
    }

    import tagion.services.Options;

    bool ready(ref const(Options) opts) const pure nothrow {
        return addresses.length >= opts.nodes;
    }

    bool active(const Pubkey pkey) const pure nothrow {
        return (pkey in addresses) !is null;
    }

    immutable(NodePair) random() @trusted const pure {
        if (addresses.length) {
            import std.range : dropExactly;

            auto _addresses = cast(NodeAddresses) addresses;
            //   pragma(msg,
            const random_key_index = uniform(0, addresses.length, cast(Random) rnd);
            return _addresses.byKeyValue.dropExactly(random_key_index).front;
            //            return  _addresses.byKeyValue.front;

        }
        //assert(0);
        return NodePair.init;
    }

    //    pragma(msg, "random ", typeof(random()));
}

static shared(AddressBook) addressbook;

shared static this() {
    addressbook = new shared(AddressBook);
}

@safe
struct NodeAddress {
    enum tcp_token = "/tcp/";
    enum p2p_token = "/p2p/";
    enum intrn_token = "/node/";
    string address;
    bool is_marshal;
    string id;
    uint port;
    DART.SectorRange sector;

    mixin HiBONRecord!(
            q{
            this(
            string address,
            immutable(DARTOptions) dart_opts,
            const ulong port_base,
            bool marshal = false) {
        import std.string;

        try {
            this.address = address;
            this.is_marshal = marshal;
            if (!marshal) {
                pragma(msg, "fixme(cbr): This code should be done with a regex");
                // enum message="fixme(cbr): This buried logic should be moved into the DART Synch (NodeAddress) should be a simple datatype";
                // assert(0, message);

                // pragma(msg, message);
                // version(none) {
                this.id = address[address.lastIndexOf(p2p_token) + 5 .. $];
                auto tcpIndex = address.indexOf(tcp_token) + tcp_token.length;
                this.port = to!uint(address[tcpIndex .. tcpIndex + 4]);

                const node_number = this.port - port_base;
                if (this.port >= dart_opts.sync.maxSlavePort) {
                    sector = DART.SectorRange(dart_opts.sync.netFromAng, dart_opts.sync.netToAng);
                }
                else {
                    const max_sync_node_count = dart_opts.sync.master_angle_from_port
                        ? dart_opts.sync.maxSlaves : dart_opts.sync.maxMasters;
                    sector = calcAngleRange(dart_opts, node_number, max_sync_node_count);
                }
                // }
            }
            else if (address[0..intrn_token.length] != intrn_token) {
                import std.json;
                auto json = parseJSON(address);
                this.id = json["ID"].str;
                auto addr = (() @trusted => json["Addrs"].array()[0].str())();
                auto tcpIndex = addr.indexOf(tcp_token) + tcp_token.length;
                this.port = to!uint(addr[tcpIndex .. tcpIndex + 4]);
            }
        }
        catch (Exception e) {
            // log(e.msg);
            log.fatal(e.msg);
        }
    }
        });

    static DART.SectorRange calcAngleRange(
            immutable(DARTOptions) dart_opts,
            const ulong node_number,
            const ulong max_nodes) {
        import std.math : ceil, floor;

        float delta = (cast(float)(dart_opts.sync.netToAng - dart_opts.sync.netFromAng)) / max_nodes;
        auto from_ang = to!ushort(dart_opts.from_ang + floor(node_number * delta));
        auto to_ang = to!ushort(dart_opts.from_ang + floor((node_number + 1) * delta));
        return DART.SectorRange(from_ang, to_ang);
    }

    static string parseAddr(string addr) {
        import std.string;

        pragma(msg, "fixme(cbr): change this to a more bust parse (use regex)");
        string result;
        const firstpartAddr = addr.indexOf('[') + 1;
        const secondpartAddr = addr[firstpartAddr .. $].indexOf(' ') + firstpartAddr;
        const firstpartId = addr.indexOf('{') + 1;
        const secondpartId = addr.indexOf(':');
        result = addr[firstpartAddr .. secondpartAddr] ~ p2p_token ~ addr[firstpartId .. secondpartId];
        // log("address: %s \n after: %s", addr, result);
        return result;
    }

    public string toString() {
        return address;
    }
}
