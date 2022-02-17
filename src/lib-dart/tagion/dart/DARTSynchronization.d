module tagion.dart.DARTSynchronization;

import std.conv;
import std.stdio;
import p2plib = p2p.node;
import p2p.callback;
import p2p.cgo.c_helper;
import std.random;
import std.concurrency;
import core.time;
import std.datetime;
import std.typecons;
import std.format;

import tagion.gossip.P2pGossipNet : NodeAddress, ConnectionPool;
import tagion.dart.DART;
import tagion.dart.DARTFile;
import tagion.dart.BlockFile;
import tagion.dart.DARTBasic;
import tagion.dart.Recorder;

import tagion.dart.DARTOptions : DARTOptions;
import tagion.basic.Basic;
import tagion.Keywords;
import tagion.crypto.secp256k1.NativeSecp256k1;
import tagion.hibon.HiBONJSON;
import tagion.hibon.Document;
import tagion.hibon.HiBON : HiBON;
import tagion.basic.Logger;

import tagion.communication.HiRPC;
import tagion.communication.HandlerPool;

//import tagion.services.MdnsDiscoveryService;

alias HiRPCSender = HiRPC.Sender;
alias HiRPCReceiver = HiRPC.Receiver;

mixin template StateT(T) {
    protected T _state;
    protected bool checkState(T[] expected...) nothrow {
        import std.algorithm : canFind;

        return expected.canFind(_state);
    }
}

@safe
class ModifyRequestHandler : ResponseHandler {
    private {
        Buffer response;
        HiRPC hirpc;
        const string task_name;
        HiRPCReceiver receiver;
    }
    this(HiRPC hirpc, const string task_name, const HiRPCReceiver receiver) {
        this.hirpc = hirpc;
        this.task_name = task_name;
        this.receiver = receiver;
    }

    void setResponse(Buffer response) {
        this.response = response;
        close();
    }

    bool alive() {
        return response.length is 0;
    }

    void close() @trusted {
        if (alive) {
            log("ModifyRequestHandler: Close alive");
            // onFailed()?
        }
        else {
            auto tid = locate(task_name);
            if (tid != Tid.init) {
                send(tid, response);
            }
            else {
                log("ModifyRequestHandler: couldn't locate task: %s", task_name);
            }
        }
    }
}

@safe
class ReadRequestHandler : ResponseHandler {
    private {
        pragma(msg, "Fixme: Why is this a Document[Buffer], why not just a Recorder? It seems to solve the same problem");
        Document[Buffer] fp_result;
        Buffer[] requested_fp;
        HiRPC hirpc;
        HiRPCReceiver receiver;
        RecordFactory manufactor;
    }
    immutable(string) task_name;
    this(const Buffer[] fp, HiRPC hirpc, const string task_name, const HiRPCReceiver receiver) {
        this.requested_fp = fp.dup;
        this.hirpc = hirpc;
        this.task_name = task_name;
        this.receiver = receiver;
        manufactor = RecordFactory(hirpc.net);
    }

    void setResponse(Buffer response) {
        const doc = Document(response); //TODO: check response
        pragma(msg, "fixme(alex): Add the Document check here (Comment abow)");
        auto received = hirpc.receive(doc);
        const foreign_recoder = manufactor.recorder(received.method.params);
        foreach (archive; foreign_recoder[]) {
            fp_result[archive.fingerprint] = archive.toDoc;
            import std.algorithm : arrRemove = remove, countUntil;

            requested_fp = requested_fp.arrRemove(countUntil(requested_fp, archive.fingerprint));
        }
    }

    bool alive() {
        return requested_fp.length != 0;
    }

    void close() @trusted {
        if (alive) {
            log("ReadRequestHandler: Close alive");
            // onFailed()?
        }
        else {
            auto empty_hirpc = HiRPC(null);
            auto recorder = manufactor.recorder;
            foreach (fp, doc; fp_result) {
                recorder.insert(doc);
            }
            auto tid = locate(task_name); //TODO: moveout outside
            if (tid != Tid.init) {
                const result = empty_hirpc.result(receiver, recorder);
                send(tid, result.toDoc.serialize);
            }
            else {
                log("ReadRequestHandler: couldn't locate task: %s", task_name);
            }
        }
    }
}

version (none) unittest {
    pragma(msg, "Fixme(Alex); Why doesn't this unittest not compile anymore!!!");
    import std.bitmanip : nativeToBigEndian;
    import tagion.dart.DARTFakeNet;

    { //ReadSynchronizer  match requested fp
        auto net = new DARTFakeNet();
        net.generateKeyPair("testpassphrase");
        HiRPC hirpc = HiRPC(net);
        enum testfp = cast(Buffer)(nativeToBigEndian(0x20_21_22_36_40_50_80_90));
        Buffer[] fps = [testfp];
        auto sender = hirpc.dartRead(null);
        auto receiver = hirpc.receive(Document(sender.toDoc.serialize));
        auto readSync = new ReadRequestHandler(fps, hirpc, "", receiver);
        assert(readSync.alive);

        auto archive = new DARTFile.Recorder.Archive(net, Document(testfp), DARTFile
                .Recorder.Archive.Type.STUB);
        auto recorder = DARTFile.Recorder(net);
        recorder.insert(archive);
        auto nsender = hirpc.result(receiver, recorder.toHiBON);
        readSync.setResponse(nsender.toHiBON(net).serialize);
        assert(!readSync.alive);

        assert(readSync.fp_result.length == 1);
        assert(readSync.fp_result[testfp] == archive.toHiBON.serialize);
    }
}

// import tagion.gossip.GossipNet;

import core.thread;

@safe
class ReplayPool(T) {
    protected {
        void delegate(T) @safe replayFunc;
        uint current_index;
        T[] modifications;
    }
    this(void delegate(T) @safe replayFunc) {
        this.replayFunc = replayFunc;
    }

    void execute() {
        try {
            if (!empty) {
                log("%d i: %d", modifications.length, current_index);
                replayFunc(modifications[current_index]);
                current_index++;
            }
        }
        catch (Exception e) {
            log("Replay fiber exception: %s", e);
        }
    }

    void insert(T value) {
        modifications ~= value;
    }

    void clear() {
        modifications = [];
        current_index = 0;
    }

    size_t count() const pure nothrow {
        return modifications.length;
    }

    bool empty() const pure nothrow {
        return count == 0;
    }

    bool isOver() const pure nothrow {
        return current_index >= count;
    }
}

@safe
interface SynchronizationFactory {
    alias OnFailure = void delegate(const DART.Rims sector);
    bool canSynchronize();
    Tuple!(uint, ResponseHandler) syncSector(const DART.Rims sector, void delegate(string) oncomplete, OnFailure onfailure);
}

@safe
class P2pSynchronizationFactory : SynchronizationFactory {
    import tagion.dart.DARTOptions;

    protected {
        DART dart;
        shared ConnectionPool!(shared p2plib.Stream, ulong) connection_pool;
        shared p2plib.Node node;
        Random rnd;
        ulong[string] synchronizing;
        string task_name;
    }
    immutable(DARTOptions) dart_opts;
    immutable(ulong) own_port;
    immutable(Pubkey) pkey;

    this(DART dart, const ulong port, shared p2plib.Node node, shared ConnectionPool!(shared p2plib.Stream, ulong) connection_pool, immutable(
            DARTOptions) dart_opts, immutable(Pubkey) pkey) {
        this.dart = dart;
        this.rnd = Random(unpredictableSeed);
        this.node = node;
        this.connection_pool = connection_pool;
        this.dart_opts = dart_opts;
        this.own_port = port;
        this.pkey = pkey;
    }

    protected NodeAddress[Pubkey] node_address;
    void setNodeTable(NodeAddress[Pubkey] node_address) {
        this.node_address = node_address;
    }

    bool canSynchronize() {
        return node_address !is null && node_address.length > 0;
    }

    Tuple!(uint, ResponseHandler) syncSector(const DART.Rims sector, void delegate(string) @safe oncomplete, OnFailure onfailure) {
        Tuple!(uint, ResponseHandler) syncWith(NodeAddress address) @safe {
            import p2p.go_helper;

            ulong connect() {
                if (address.address in synchronizing) {
                    return synchronizing[address.address];
                }
                auto stream = node.connect(address.address, address.is_marshal, [dart_opts.sync.protocol_id]);
                connection_pool.add(stream.Identifier, stream, true);
                stream.listen(&StdHandlerCallback,
                        dart_opts.sync.task_name, dart_opts.sync.host.timeout.msecs, dart_opts.sync.host.max_size);
                synchronizing[address.address] = stream.Identifier;
                return stream.Identifier;
            }

            try {
                auto stream_id = (() @trusted => connect())();
                auto filename = format("%s_%s", tempfile, sector);
                pragma(msg, "fixme(alex): Why 0x80");
                enum BLOCK_SIZE = 0x80;
                BlockFile.create(filename, DART.stringof, BLOCK_SIZE);
                auto sync = new P2pSynchronizer(filename, stream_id, oncomplete, onfailure);
                auto db_sync = dart.synchronizer(sync, sector);
                (() @trusted { db_sync.call; })();
                return tuple(db_sync.id, cast(ResponseHandler) sync);
            }
            catch (GoException e) {
                log("Error, connection failed with code: %s", e.Code); //TODO: add address to blacklist
            }
            catch (Exception e) {
                log("Error: %s", e);
            }
            return Tuple!(uint, ResponseHandler)(0, null);
        }

        auto iteration = 0;
        do {
            iteration++;
            // writeln(node_address.length);
            import std.range : dropExactly;

            const random_key_index = uniform(0, node_address.length, rnd);
            const node_addr = node_address.byKeyValue.dropExactly(random_key_index).front; //uniform(0, node_address.length, rnd)];
            if (node_addr.value.sector.inRange(sector)) {
                const node_port = node_addr.value.port;
                //const own_port = opts.port;
                if (node_addr.key == pkey)
                    continue;
                if (dart_opts.master_from_port) {
                    enum isSlave = (ulong port) => port < dart_opts.sync.maxSlavePort;
                    if (isSlave(own_port) && isSlave(node_port))
                        continue; //ignore slave nodes
                    if (!isSlave(own_port) && !isSlave(node_port))
                        continue; //ignore master nodes
                }
                auto response = syncWith(node_addr.value);
                if (response[1] is null)
                    continue;
                return response;
            }
            pragma(msg, "fixme(alex): Why 20?");
        }
        while (iteration < 20);
        return Tuple!(uint, ResponseHandler)(0, null);
    }

    @safe
    class P2pSynchronizer : DART.StdSynchronizer, ResponseHandler {
        protected const ulong key;
        protected Buffer response;
        protected void delegate(string journal_filename) @safe oncomplete;
        protected OnFailure onfailure;
        string filename;
        void setResponse(Buffer resp) @trusted {
            response = resp;
            fiber.call;
        }

        bool alive() @trusted {
            import core.thread : Fiber;

            return fiber.state != Fiber.State.TERM && connection_pool.contains(key);
        }

        this(string journal_filename, const ulong key, void delegate(string) @safe oncomplete, OnFailure onfailure) {
            filename = journal_filename;
            this.key = key;
            this.oncomplete = oncomplete;
            this.onfailure = onfailure;
            super(journal_filename);
        }

        const(HiRPCReceiver) query(ref const(HiRPCSender) request) {
            scope (failure) {
                close();
            }
            void send_request_to_forien_dart(const Document doc) @trusted {
                const sended = connection_pool.send(key, doc.serialize);
                if (!sended) {
                    log("P2pSynchronizer: connection closed");
                    close();
                }
            }
            //immutable foreign_data = hirpc.toHiBON(request).serialize;
            const foreign_doc = request.toDoc;
            import p2p.go_helper;

            try {
                send_request_to_forien_dart(foreign_doc);
            }
            catch (GoException e) {
                log("P2pSynchronizer: Exception on sending request: %s", e);
                close();
            }
            (() @trusted { fiber.yield; })();
            assert(response);
            auto doc = Document(response);
            auto received = hirpc.receive(doc);
            return received;
        }

        void close() @trusted {
            scope (exit) {
                finish;
            }
            if (alive) {
                log("P2pSynchronizer: close alive. Sector: %d", convertFromBuffer!ushort(
                        fiber.root_rims.rims));
                onfailure(fiber.root_rims);
                fiber.reset();
            }
            else {
                log("P2pSynchronizer: Synchronization Completed! Sector: %d", convertFromBuffer!ushort(
                        fiber.root_rims.rims));
                oncomplete(filename);
            }
            // connection_pool.close(key); //TODO: if one connnection used for one synchronization
        }
    }
}

version (none) unittest {
    @trusted
    synchronized
    class FakeRequestStream : p2plib.RequestStream {
        public static ulong id = 1;
        this() {
            super(null, id);
        }

        private uint write_counter = 0;
        private bool throwException = false;
        override void writeBytes(Buffer data) {
            import core.atomic;

            atomicOp!"+="(this.write_counter, 1);
            if (throwException) {
                import p2p.go_helper;

                throw new GoException(ErrorCode.InternalError);
            }
        }

        override void listen(p2plib.HandlerCallback handler, string tid,
                Duration timeout, int maxSize) {

        }

        ~this() {
            disposed = true;
        }
    }

    @trusted
    synchronized
    class FakeNode : p2plib.Node {
        this() {
            fake_stream = new shared FakeRequestStream();
            super();
        }

        private uint connect_counter = 0;
        private FakeRequestStream fake_stream;
        override shared(p2plib.RequestStream) connect(string addr, string[] pids...) {
            import core.atomic;

            atomicOp!"+="(this.connect_counter, 1);
            return fake_stream;
        }

        ~this() {
            disposed = true;
            destroy(fake_stream);
        }
    }

    auto net = new MyFakeNet;
    net.generateKeyPair("testkey");
    auto hirpc = HiRPC(net);
    immutable filename = fileId!DART.fullpath;
    Options opts;
    setDefaultOption(opts);
    dart_opts.sync.host.timeout = 50;
    dart_opts.sync.master_angle_from_port = false;

    NodeAddress[string] address_table;
    auto addr1 = NodeAddress();
    addr1.sector = DART.SectorRange(0, 5);
    addr1.port = 4021;
    auto pkey = cast(immutable(Pubkey))[0, 0, 0, 1];
    address_table[[pkey]] = addr1;

    DART.create_dart(filename);
    auto dart = new DART(net, filename, 0, 5); // 5 P2p Synchronizers

    template controlFuncs() {
        bool completedCalled = false;
        void oncomplete(string journal) {
            completedCalled = true;
        }

        bool failedCalled = false;
        void onfailed(Buffer sector) {
            failedCalled = true;
        }
    }

    { //P2pSynchronizationFactory: can synchronize after address table is set
        auto node = new shared FakeNode();
        auto connectionPool = new shared(ConnectionPool!(shared p2plib.Stream, ulong))(10.msecs);
        auto sync_factory = new P2pSynchronizationFactory(dart, node, connectionPool, opts, pkey);
        assert(!sync_factory.canSynchronize);

        sync_factory.setNodeTable(address_table);

        assert(sync_factory.canSynchronize);
        destroy(node);
    }
    { //P2pSynchronizationFactory: connect and start synchronization if node found
        auto node = new shared FakeNode();
        auto connectionPool = new shared(ConnectionPool!(shared p2plib.Stream, ulong))(10.msecs);
        auto sync_factory = new P2pSynchronizationFactory(dart, node, connectionPool, opts, pkey);
        sync_factory.setNodeTable(address_table);
        mixin controlFuncs;
        auto result = sync_factory.syncSector(DART.Rims(), &oncomplete, &onfailed);
        assert(result[1]!is null);
        assert(node.connect_counter == 1);
        assert(node.fake_stream.write_counter == 1);
        destroy(node);
    }
    { //P2pSynchronizationFactory: return null if synchronize node not found
        auto node = new shared FakeNode();
        auto connectionPool = new shared(ConnectionPool!(shared p2plib.Stream, ulong))(10.msecs);
        auto sync_factory = new P2pSynchronizationFactory(dart, node, connectionPool, opts, pkey);

        sync_factory.setNodeTable(address_table);
        mixin controlFuncs;
        auto result = sync_factory.syncSector(convert_sector_to_rims(6), &oncomplete, &onfailed);
        assert(result[1] is null);
        assert(node.connect_counter == 0);
        assert(node.fake_stream.write_counter == 0);
        destroy(node);
    }
}

/++
    THandlerPool - handler pool type
    fast_load - load full dart
+/
@safe
class DARTSynchronizationPool(THandlerPool : HandlerPool!(ResponseHandler, uint)) : Fiber { //TODO: move fiber inside as a field
    enum root = DART.Rims.root;
    bool fast_load;
    protected enum State {
        READY,
        FIBER_RUNNING,
        RUNNING,
        ERROR,
        OVER,
        STOP
    }

    mixin StateT!State;

    bool isReady() nothrow {
        return checkState(State.READY);
    }

    bool isOver() nothrow {
        return checkState(State.OVER);
    }

    bool isError() nothrow {
        return checkState(State.ERROR);
    }

    void stop() @trusted {
        if (!checkState(State.STOP)) {
            log("Stop dart sync pool");
            if (handlerTid != Tid.init) {
                send(handlerTid, Control.STOP);
                const control = receiveOnly!Control;
                assert(control == Control.END);
            }
            _state = State.STOP;
        }
    }

    protected DART dart;
    protected HandlerPool!(ResponseHandler, uint) handlerPool;
    protected string masterNodeId;
    protected DARTOptions dart_opts; //TODO: moveout!
    protected Tid handlerTid;
    protected SynchronizationFactory sync_factory;
    protected ReplayPool!string journal_replay;

    protected bool[DART.Rims] sync_sectors;
    protected DART.Rims[] failed_sync_sectors;
    HiRPC hirpc;
    this(DART.SectorRange sectors, ReplayPool!string journal_replay, immutable(DARTOptions) dart_opts) @trusted {
        this.fast_load = dart_opts.fast_load;
        // writefln("Fast load: %s", fast_load);
        if (fast_load) {
            assert(fast_load && sectors.isFullRange, "Fast load will load full dart");
        }
        hirpc = HiRPC();
        _state = State.READY;
        this.journal_replay = journal_replay;
        this.dart_opts = dart_opts;
        this.handlerPool = new THandlerPool(dart_opts.sync.host.timeout.msecs);
        if (!fast_load) {
            foreach (i; sectors) {
                sync_sectors[DART.Rims(i)] = false;
            }
        }
        else {
            sync_sectors[root] = false;
        }
        super(&run);
    }

    protected void run() {
        import std.algorithm : filter, reduce;
        import std.array : array;

        if (fast_load) {
            auto result = sync_factory.syncSector(DART.Rims.root, &onComplete, &onFailure);
            if (result[1] is null) {
                // log("Couldn't synchronize root");
                onFailure(root); //TODO: or just ignore?
            }
            else {
                handlerPool.add(result[0], result[1], true);
                sync_sectors[root] = true;
            }
        }
        else {
            foreach (sector, is_synchronized; sync_sectors) {
                if (is_synchronized)
                    continue;
                // writef("\rSync: %d%%", (reduce!((a,b)=>a+b?0:1)(0,sync_sectors.byValue)*100)/sync_sectors.length);
                auto result = sync_factory.syncSector(sector, &onComplete, &onFailure);
                if (result[1] is null) {
                    // log("Couldn't synchronize sector: %d", sector);
                    onFailure(sector); //TODO: or just ignore?
                }
                else {
                    sync_sectors[sector] = true;
                    handlerPool.add(result[0], result[1], true);
                }
                (() @trusted { yield(); })();
            }
        }
        if (failed_sync_sectors.length > 0) {
            _state = State.ERROR;
        }
        else {
            _state = State.RUNNING;
        }
    }

    void start(SynchronizationFactory factory) //restart with new factory

    

    in {
        assert(checkState(State.STOP, State.READY, State.ERROR));
    }
    do {
        this.sync_factory = factory;
        if (factory.canSynchronize) {
            if (state == Fiber.State.TERM) {
                (() @trusted { reset(); })();
            }
            if (checkState(State.ERROR) && failed_sync_sectors.length > 0) {
                foreach (sector; failed_sync_sectors) {
                    sync_sectors[sector] = false;
                }
                failed_sync_sectors = [];
            }
            _state = State.FIBER_RUNNING;
            (() @trusted { call; })();
        }
    }

    void setResponse(Response!(ControlCode.Control_RequestHandled) resp)
    in {
        assert(checkState(State.RUNNING, State.FIBER_RUNNING, State.ERROR));
    }
    do {
        auto doc = Document(resp.data);
        import tagion.hibon.HiBONJSON;

        auto received = hirpc.receive(doc);
        auto response = ResponseHandler.Response!uint(received.response.id, resp.data);
        handlerPool.setResponse(response);
    }

    private void onComplete(string journal_filename) {
        journal_replay.insert(journal_filename);
    }

    private void onFailure(const DART.Rims sector) {
        // writeln("Failed synchronize sector");
        if (checkState(State.FIBER_RUNNING)) {
            failed_sync_sectors ~= sector;
        }
        else {
            sync_sectors[sector] = false;
            _state = State.ERROR;
        }
    }

    void tick() {
        if (checkState(State.RUNNING, State.FIBER_RUNNING, State.ERROR)) {
            handlerPool.tick;
        }
        if (checkState(State.FIBER_RUNNING)) {
            if (handlerPool.size <= dart_opts.sync.max_handlers || dart_opts.sync.max_handlers == 0) {
                (() @trusted { call; })();
            }
        }
        if (checkState(State.RUNNING)) {
            if (handlerPool.empty) {
                // writeln("Synchronization pool over");
                _state = State.OVER;
            }
        }
    }
}

@safe
unittest {
    import std.algorithm : count;

    @safe
    static class FakeResponseHandler : ResponseHandler {
        void setResponse(Buffer response) {
        }

        bool alive() {
            return true;
        }

        void close() {
        }
    }

    @safe
    static class FakeSynchronizationFactory : SynchronizationFactory {
        private bool _canSynchronize = true;
        bool canSynchronize() {
            return _canSynchronize;
        }

        private Tuple!(uint, ResponseHandler) mockReturn;
        private uint sync_counter = 0;
        Tuple!(uint, ResponseHandler) syncSector(const DART.Rims sector, void delegate(string) oncomplete, OnFailure onfailure) {
            sync_counter++;
            return mockReturn;
        }
    }

    @safe
    static class FakeHandlerPool(TValue : ResponseHandler, TKey) : StdHandlerPool!(TValue, TKey) {
        this(const Duration timeout) {
            super(timeout);
        }

        static TKey[] keys;
        static bool set_expired = false;
        static bool is_empty = false;

        override void add(const TKey key, ref TValue value, bool long_lived = false) {
            keys ~= key;
            super.add(key, value, long_lived);
        }

        override void tick() {
            if (set_expired) {
                foreach (key, activeHandler; handlers) {
                    remove(key);
                }
            }
        }

        override bool empty() {
            return is_empty;
        }
    }

    DARTOptions dart_opts;
    //    setDefaultOption(opts);
    dart_opts.sync.host.timeout = 50;
    dart_opts.sync.master_angle_from_port = false;
    void emptyFunc(string jf) {
        return;
    }

    auto journal_replay = new ReplayPool!string(&emptyFunc);
    dart_opts.fast_load = false;

    { //DARTSynchronizationPool: reconect on synchronizer failed after fiber finish
        auto pool = new DARTSynchronizationPool!(FakeHandlerPool!(ResponseHandler, uint))(
                DART.SectorRange(0, 5), journal_replay, dart_opts);
        auto sync_factory = new FakeSynchronizationFactory();
        sync_factory.mockReturn = tuple(1, new FakeResponseHandler());
        pool.start(sync_factory);
        auto iterations = 0;
        do {
            iterations++;
            pool.tick;
        }
        while (iterations <= 5);

        pool.onFailure(DART.Rims(0));

        assert(sync_factory.sync_counter == 5);
        assert(pool.isError);

        pool.start(sync_factory);
        assert(sync_factory.sync_counter == 6);
        assert(!pool.isError);
        pool.tick;
        assert(!pool.isError);
    }

    { //DARTSynchronizationPool: reconect on synchronizer failed before fiber finish
        auto pool = new DARTSynchronizationPool!(
                FakeHandlerPool!(ResponseHandler, uint))(DART.SectorRange(0, 5), journal_replay, dart_opts);
        auto sync_factory = new FakeSynchronizationFactory();
        sync_factory.mockReturn = tuple(1, new FakeResponseHandler());
        pool.start(sync_factory);
        auto iterations = 0;
        do {
            iterations++;
            if (iterations == 2) {
                pool.onFailure(DART.Rims(0));
            }
            pool.tick;
        }
        while (iterations <= 5);

        assert(sync_factory.sync_counter == 5);
        assert(pool.isError);

        pool.start(sync_factory);
        assert(sync_factory.sync_counter == 6);
        assert(!pool.isError);
        pool.tick;
        assert(!pool.isError);
    }

    { //DARTSynchronizationPool: synchronization over
        auto pool = new DARTSynchronizationPool!(FakeHandlerPool!(ResponseHandler, uint))(
                DART.SectorRange(0, 5), journal_replay, dart_opts);
        auto sync_factory = new FakeSynchronizationFactory();
        sync_factory.mockReturn = tuple(1, new FakeResponseHandler());
        pool.start(sync_factory);
        auto iterations = 0;
        do {
            iterations++;
            pool.tick;
        }
        while (iterations <= 5);

        assert(sync_factory.sync_counter == 5);
        assert(!pool.isError);
        assert(!pool.isOver);

        FakeHandlerPool!(ResponseHandler, uint).is_empty = true;
        pool.tick;
        FakeHandlerPool!(ResponseHandler, uint).is_empty = false;
        assert(pool.isOver);
    }
}
