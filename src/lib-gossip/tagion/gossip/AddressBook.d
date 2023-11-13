module tagion.gossip.AddressBook;

import core.thread : Thread;
import std.file : exists;
import std.format;
import std.path : setExtension;
import std.random;
import tagion.basic.tagionexceptions;
import tagion.crypto.Types : Pubkey;
import tagion.dart.DART : DART;
import tagion.dart.DARTRim;
import tagion.hibon.HiBONFile;
import tagion.hibon.HiBONRecord;
import tagion.logger.Logger : log;
import tagion.utils.Miscellaneous : cutHex;

@safe class AddressBookException : TagionException {
    this(string msg, string file = __FILE__, size_t line = __LINE__) pure {
        super(msg, file, line);
    }
}

/** check function used in the HiBON package */
alias check = Check!(AddressBookException);

enum lockext = "lock";

/**
 * Lock file
 * @param filename - file to lock
 */
void lock(string filename) {
    import std.file : fwrite = write;

    immutable file_lock = filename.setExtension(lockext);
    file_lock.fwrite(null);
}

/**
 * Unlock file
 * @param filename - file to unlock
 */
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

/**
 * Check file is locked or unlocked
 * @param filename - file to check
 * @return true if locked
 */
bool locked(string filename) {
    immutable file_lock = filename.setExtension(lockext);
    return file_lock.exists;
}

/** Address book for libp2p */
@safe
synchronized class AddressBook {
    import core.time;

    alias NodeAddresses = NodeAddress[Pubkey];
    alias NodePair = typeof((() @trusted => (cast(NodeAddresses) addresses).byKeyValue.front)());

    /** \struct AddressDirectory
     * Storage for node addresses
     */
    static struct AddressDirectory {
        /* associative array with node addresses 
         * node address - value, public key - key
         */
        NodeAddresses addresses;
        mixin HiBONRecord;
    }

    /** used for lock, unlock file */
    enum max_count = 3;
    /** used for lock, unlock file */
    protected int timeout = 300;
    /** nodes amount */
    protected size_t nodes;

    /**
     * Set number of active nodes
     * @param nodes - number of active nodes
     */
    void number_of_active_nodes(const size_t nodes) pure nothrow
    in {
        debug log.trace("this.nodes %s set to %s", this.nodes, nodes);
        assert(this.nodes is size_t.init);
    }
    do {
        this.nodes = nodes;
    }

    protected {
        Random rnd;
    }
    this() {
        rnd = shared(Random)(unpredictableSeed);
    }

    /** Addresses for node */
    protected shared(NodeAddresses) addresses;

    /**
     * Create associative array with public keys and addresses of nodes
     * @return addresses of nodes
     */
    immutable(NodeAddress[Pubkey]) _data() @trusted {
        pragma(msg, "fixme(cbr): AddressBook._data This function should be removed when the addressbook has been implemented");
        NodeAddress[Pubkey] result;
        foreach (pkey, addr; addresses) {
            result[pkey] = addr;
        }
        return cast(immutable) result;
    }

    /**
     * Overwrite node addresses associative array
     * @param addrs - array to overwrite
     */
    private void overwrite(const(NodeAddress[Pubkey]) addrs) {
        addresses = null;
        foreach (pkey, addr; addrs) {
            addresses[pkey] = addr;
        }
    }

    /**
     * Load file if it's exist
     * @param filename - file to load
     * @param do_unlock - flag for unlock file
     */
    void load(string filename, bool do_unlock = true) @trusted {
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

    /**
     * Save addresses to file
     * @param filename - file to save addresses
     * @param nonelock - flag tolock file for save operation
     */
    void save(string filename, bool nonelock = false) @trusted {
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

    /**
     * Init NodeAddress if public key exist
     * @param pkey - public key for check
     * @return initialized node address
     */
    immutable(NodeAddress) opIndex(const Pubkey pkey) const pure nothrow {
        auto addr = pkey in addresses;
        if (addr) {
            return cast(immutable)(*addr);
        }
        return NodeAddress.init;
    }

    /**
     * Create associative array addresses
     * @param addr - value
     * @param pkey - key
     */
    void opIndexAssign(const NodeAddress addr, const Pubkey pkey)
    in ((pkey in addresses) is null, format("Address %s has already been set", pkey.cutHex))

    do {
        import std.stdio;
        import tagion.utils.Miscellaneous : cutHex;

        log.trace("AddressBook.opIndexAssign %s:%d", pkey.cutHex, pkey.length);
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
        import std.exception : assumeUnique;

        auto channels = (cast(NodeAddresses) addresses).keys;
        return channels;
    }

    const(string) getAddress(const Pubkey pkey) const pure nothrow {
        return addresses[pkey].address;
    }

    /**
     * Return amount of active nodes in network
     * @return amount of active nodes
     */
    size_t numOfActiveNodes() const pure nothrow {
        return addresses.length;
    }

    /**
     * Return amount of nodes in networt
     * @return amount of nodes
     */
    size_t numOfNodes() const pure nothrow {
        return addresses.length;
    }

    /**
     * Check that nodes >= 4 and addresses >= nodes
     * @return true if network ready
     */
    bool isReady() const pure nothrow {
        return (nodes >= 4) && (addresses.length >= nodes);
    }

    /**
     * For random generation node pair
     * @return node pair
     */
    immutable(NodePair) random() @trusted const pure {
        if (addresses.length) {
            import std.range : dropExactly;

            auto _addresses = cast(NodeAddresses) addresses;
            const random_key_index = uniform(0, addresses.length, cast(Random) rnd);
            return _addresses.byKeyValue.dropExactly(random_key_index).front;
        }
        return NodePair.init;
    }

    /**
     * Select active channel by index
     * @param index - index to select active channel
     * @return active channel
     */
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

/** 
 * \struct NodeAddress
 * Struct for node addresses 
 */
@safe
@recordType("NNR")
struct NodeAddress {
    enum tcp_token = "/tcp/";
    enum p2p_token = "/p2p/";
    enum intrn_token = "/node/";
    /** node address */
    string address;
    /** If true, then struct with node addresses is used as an address
     * If false, then the local address used 
     */
    bool is_marshal;
    /** node id */
    string id;
    /** node port */
    uint port;
    /** DART sector */
    SectorRange sector;

    mixin HiBONRecord!(
            q{
            this(string address) {
                pragma(msg, "fixme(pr): addressbook for mode0 should be created instead");
                this.address = address;
            }
            this(string address, const ulong port_base, bool marshal = false) {
        import std.string;

        try {
            this.address = address;
            this.is_marshal = marshal;
            if (!marshal) {
                pragma(msg, "fixme(cbr): This code should be done with a regex");
                this.id = address[address.lastIndexOf(p2p_token) + 5 .. $];
                auto tcpIndex = address.indexOf(tcp_token) + tcp_token.length;
                this.port = to!uint(address[tcpIndex .. tcpIndex + 4]);

                const node_number = this.port - port_base;
                
                sector = SectorRange(0, 0);
                
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
            log.fatal(e.msg);
        }
    }
        });

    /**
     * Parse node address
     * @param addr - address to parse
     * @return parsed address
     */
    static string parseAddr(string addr) {
        import std.string;

        pragma(msg, "fixme(cbr): change this to a more bust parse (use regex)");
        string result;
        const firstpartAddr = addr.indexOf('[') + 1;
        const secondpartAddr = addr[firstpartAddr .. $].indexOf(' ') + firstpartAddr;
        const firstpartId = addr.indexOf('{') + 1;
        const secondpartId = addr.indexOf(':');
        result = addr[firstpartAddr .. secondpartAddr] ~ p2p_token ~ addr[firstpartId .. secondpartId];
        return result;
    }

    /**
     * Parse node address to string
     * @return string address
     */
    public string toString() {
        return address;
    }
}
