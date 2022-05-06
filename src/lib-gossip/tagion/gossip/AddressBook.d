module tagion.gossip.AddressBook;

import tagion.basic.Types : Pubkey;
import tagion.hibon.HiBONRecord;
import tagion.dart.DART : DART;
import tagion.dart.DARTOptions : DARTOptions;
import tagion.logger.Logger : log;
import tagion.utils.Miscellaneous : cutHex;

import std.file : exists;
import std.path : setExtension;
import core.thread : Thread;
import std.format;
import std.random;

import tagion.basic.TagionExceptions;

@safe class AddressBookException : TagionException {
    this(string msg, string file = __FILE__, size_t line = __LINE__) pure {
        super(msg, file, line);
    }
}

/// check function used in the HiBON package
alias check = Check!(AddressBookException);

enum lockext = "lock";
void lock(string filename) {
    import std.file : fwrite=write;
    immutable file_lock = filename.setExtension(lockext);
    file_lock.fwrite(null);
}

void unlock(string filename) nothrow {
    import std.file : remove;
    immutable file_lock = filename.setExtension(lockext);
    try {
        file_lock.remove;
    }
    catch (Exception e) {
        // ignore
    }
}

bool locked(string filename) {
    immutable file_lock = filename.setExtension(lockext);
    return file_lock.exists;
}

@safe
synchronized class AddressBook {
    import core.time;
    alias NodeAddresses = NodeAddress[Pubkey];
    // pragma(msg, "typeof(addresses.byKeyValue) ", typeof(NodeAddresses.byKeyValue));
    alias NodePair = typeof((cast(NodeAddresses) addresses).byKeyValue.front);
    static struct AddressDirectory {
        NodeAddresses addresses;
        mixin HiBONRecord;
    }

    enum max_count = 3;
    protected int timeout= 300; ///

    protected {
        Random rnd;
    }
    this() {
        //        pragma(msg, "rnd ", typeof(rnd));
        rnd = shared(Random)(unpredictableSeed);
    }

    protected shared(NodeAddresses) addresses;

    immutable(NodeAddress[Pubkey]) _data() @trusted {
        pragma(msg, "fixme(cbr): AddressBook._data This function should be removed when the addressbook has been implemented");
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

    void load(string filename, bool do_unlock=true) @trusted {
        void local_read() @safe {
            auto dir = filename.fread!AddressDirectory;
            overwrite(dir.addresses);
        }
        if (filename.exists) {
            int count_down = max_count;
            while (filename.locked) {
                Thread.sleep(timeout.msecs);
                count_down--;
                check(count_down > 0, format("The bootstrap file is locked. Timeout can't load file %s", filename));
            }
            filename.lock;
            local_read;
            if (do_unlock) {
                filename.unlock;
            }
        }
    }

    void save(string filename, bool nonelock=false) @trusted {
        void local_write() {
            AddressDirectory dir;
            dir.addresses = cast(NodeAddress[Pubkey]) addresses;
            filename.fwrite(dir);
        }
        int count_down = max_count;
        while (!nonelock && filename.locked) {
            Thread.sleep(timeout.msecs);
            count_down--;
            check(count_down > 0, format("The bootstrap file is locked. Timeout can't save file %s", filename));
        }
        filename.lock;
        local_write;
        filename.unlock;
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
        if ((pkey in addresses) !is null) {
            log.error(format("Address %s has already been set", pkey.cutHex));
        }
        assert((pkey in addresses) is null, format("Address %s has already been set", pkey.cutHex));
    }
    do { //pure nothrow {
        import std.stdio;
        import tagion.utils.Miscellaneous : cutHex;
        log.trace("AddressBook.opIndexAssign %s:%d", pkey.cutHex, pkey.length);
        addresses[pkey] = addr;
        log.trace("After AddressBook.opIndexAssign %s:%d", pkey.cutHex, pkey.length);

    }

    void erase(const Pubkey pkey) pure nothrow {
        addresses.remove(pkey);
    }

    bool exists(const Pubkey pkey) const nothrow {
        return (pkey in addresses) !is null;
    }

    bool isActive(const Pubkey pkey) const pure nothrow {
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

    immutable(NodePair) random() @trusted const pure {
        if (addresses.length) {
            import std.range : dropExactly;

            auto _addresses = cast(NodeAddresses) addresses;
            const random_key_index = uniform(0, addresses.length, cast(Random) rnd);
            return _addresses.byKeyValue.dropExactly(random_key_index).front;
        }
        return NodePair.init;
    }

    const(Pubkey) selectActiveChannel(const size_t index) @trusted const pure {
        import std.range : dropExactly;
        auto _addresses = cast(NodeAddresses) addresses;
        return _addresses.byKey.dropExactly(index).front;
    }
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
