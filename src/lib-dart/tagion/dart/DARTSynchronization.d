module tagion.dart.DARTSynchronization;

import std.conv;
import std.stdio;
import p2plib = p2p.node;
import p2p.connection;
import p2p.callback;
import p2p.cgo.helper;
import std.random;
import std.concurrency;
import tagion.dart.DART;
import tagion.dart.DARTFile;
import tagion.dart.BlockFile;
import core.time;
import std.datetime;
import tagion.Options;
import std.typecons;
import tagion.basic.Basic;
import tagion.Keywords;
import tagion.crypto.secp256k1.NativeSecp256k1;
import tagion.hibon.HiBONJSON;
import tagion.hibon.Document;
import tagion.hibon.HiBON : HiBON;
import tagion.services.LoggerService;

import tagion.communication.HiRPC;
import tagion.utils.HandlerPool;

import tagion.services.MdnsDiscoveryService;

alias HiRPCSender = HiRPC.HiRPCSender;
alias HiRPCReceiver = HiRPC.HiRPCReceiver;

static T convertFromBuffer(T)(const ubyte[] data) {
    if(data == []) return 0;
    import std.bitmanip: bigEndianToNative;

    assert(data.length == T.sizeof);
    return bigEndianToNative!T(data[0 .. T.sizeof]);
}

mixin template StateT(T){
    protected T _state;
    protected bool checkState(T[] expected...) nothrow{
        import std.algorithm: canFind;
        return expected.canFind(_state);
    }
}

Buffer SetInitialDataSet(DART dart, ubyte ringWidth, int rings, int cores = 4) {
    import std.math: floor, ceil;
    static __gshared bool stop = false;
    static __gshared ulong all_iterations = 0;
    static __gshared ulong iteration = 0;
    static ulong local_iteration = 0;

    alias Sector = DART.SectorRange;
    import std.math: pow;
    import std.algorithm : count;
    auto dart_range = dart.sectors;
    all_iterations = count(dart_range) * pow(ringWidth, (rings-2));
    float angDiff = cast(float)count(dart_range) / cores;
    static void setRings(int ring, int rings, ubyte[] buffer, ubyte ringWidth,
            DARTFile.Recorder rec) {
        if(stop) return;
        auto rnd = Random(unpredictableSeed);
        bool randomChance(int proc) {
            const c = uniform(0, 100, rnd);
            if (c <= proc)
                return true;
            return false;
        }

        void fillRandomHash(ubyte[] buf) {
            for (int x = rings; x < ulong.sizeof; x++) {
                buf[x] = rnd.uniform!ubyte;
            }
        }
        immutable(ubyte[]) serialize(const ulong x) {
            auto hibon=new HiBON;
            hibon[MyFakeNet.fake]=x;
            import tagion.hibon.HiBONBase : Type;
            assert(hibon[MyFakeNet.fake].type == Type.UINT64);
            immutable data=hibon.serialize;
            auto doc=Document(data);
            assert(doc[MyFakeNet.fake].type == Type.UINT64);
            return hibon.serialize;
        }
        ubyte lowerByte = ring == 2 ? ubyte.min : ubyte.min + 1;
        for (ubyte j = lowerByte; j < ringWidth; j++) {
            fillRandomHash(buffer);
            buffer[ring] = j;
            ulong bufLong = convertFromBuffer!ulong(buffer);
            auto fakeDoc = MyFakeNet.serialize(bufLong);
            try {
                iteration++;
                local_iteration++;
                if (iteration % (all_iterations < 100 ? 1 : all_iterations / 100) == 0) {
                    writef("\r%d%%  ", ((iteration * 100) / all_iterations));
                }
                enum max_archive_in_recorder = 50;
                if(local_iteration%max_archive_in_recorder == 0){
                    ownerTid.send(cast(shared)rec, thisTid);
                    receiveOnly!bool;
                }
                rec.add(fakeDoc);
            } catch (Exception e) {
                writeln(e);
            }
            if (ring < rings - 1) {
                // if(randomChance(93))continue;
                setRings(ring + 1, rings, buffer.dup, ringWidth, rec);
            }
        }
    }

    static void setSectors(immutable Sector sector, ubyte rw, int rings, shared DARTFile.Recorder rec) {
        ubyte[ulong.sizeof] buf;
        foreach(j; cast(Sector)sector) {
            buf[0 .. ushort.sizeof] = convert_sector_to_rims(j);
            setRings(2, rings, buf.dup, rw, cast(DARTFile.Recorder) rec);
        }
        if(!stop) ownerTid.send(true, rec);
    }
    for(int i=0; i< cores; i++){
        auto recorder = dart.recorder();
        immutable sector = Sector(
            cast(ushort)(dart_range.from_sector + floor(angDiff*i)),
            cast(ushort)(dart_range.from_sector + floor(angDiff*(i+1)))
        );
        spawn(&setSectors, sector, ringWidth, rings, cast(shared) recorder);
    }

    Buffer last_result;
    auto active_threads = cores;
    do{
        receive(
            (Control control){
                if(control == Control.STOP){
                    stop = true;
                    send(ownerTid, Control.END);
                }
            },
            (bool flag, shared DARTFile.Recorder recorder){
                active_threads--;
                auto non_shared_recorder = cast(DARTFile.Recorder) recorder;
                last_result = dart.modify(non_shared_recorder);
            },
            (shared DARTFile.Recorder recorder, Tid sender){
                auto non_shared_recorder = cast(DARTFile.Recorder) recorder;
                dart.modify(non_shared_recorder);
                non_shared_recorder.clear();
                send(sender, true);
            }
        );
    }while(active_threads>0 && !stop);
    import core.stdc.stdlib: exit;
    if(stop) exit(0);   //TODO: bad solution
    return last_result;
}

class ModifyRequestHandler : ResponseHandler{
    private{
        Buffer response;
        HiRPC hirpc;
        const string task_name;
        HiRPCReceiver receiver;
    }
    this(HiRPC hirpc, const string task_name, const HiRPCReceiver receiver){
        this.hirpc = hirpc;
        this.task_name = task_name;
        this.receiver = receiver;
    }

    void setResponse(Buffer response){
        this.response = response;
        close();
    }

    bool alive(){
        return response.length is 0;
    }

    void close(){
        if(alive){
            log("ModifyRequestHandler: Close alive");
            // onFailed()?
        }else{
            auto tid = locate(task_name);
            if(tid != Tid.init){
                send(tid, response);
            }else{
                log("ModifyRequestHandler: couldn't locate task: %s", task_name);
            }
        }
    }
}

class ReadRequestHandler : ResponseHandler{
    private{
        Buffer[Buffer] fp_result;
        Buffer[] requested_fp;
        HiRPC hirpc;
        const string task_name;
        HiRPCReceiver receiver;
    }
    this(const Buffer[] fp, HiRPC hirpc, const string task_name, const HiRPCReceiver receiver){
        this.requested_fp = fp.dup;
        this.hirpc = hirpc;
        this.task_name = task_name;
        this.receiver = receiver;
    }

    void setResponse(Buffer response){
        const doc = Document(response); //TODO: check response
        auto received = hirpc.receive(doc);
        scope foreign_recoder=DARTFile.Recorder(hirpc.net, received.params);
        foreach(archive; foreign_recoder.archives){
            fp_result[archive.fingerprint] = archive.toHiBON.serialize;
            import std.algorithm: arrRemove = remove, countUntil;
            requested_fp = requested_fp.arrRemove(countUntil(requested_fp, archive.fingerprint));
        }
    }

    bool alive(){
        return requested_fp.length != 0;
    }

    void close(){
        if(alive){
            log("ReadRequestHandler: Close alive");
            // onFailed()?
        }else{
            auto empty_hirpc = HiRPC(null);
            auto recorder = DARTFile.Recorder(hirpc.net);
            foreach(fp, doc; fp_result){
                recorder.insert(new DARTFile.Recorder.Archive(hirpc.net, Document(doc)));
            }
            auto tid = locate(task_name);   //TODO: moveout outside
            if(tid != Tid.init){
                const result =  empty_hirpc.result(receiver, recorder.toHiBON);
                send(tid, empty_hirpc.toHiBON(result).serialize);
            }else{
                log("ReadRequestHandler: couldn't locate task: %s", task_name);
            }
        }
    }
}

unittest{
    import std.bitmanip: nativeToBigEndian;
    {//ReadSynchronizer  match requested fp
        auto net = new MyFakeNet();
        net.generateKeyPair("testpassphrase");
        HiRPC hirpc = HiRPC(net);
        enum testfp = cast(Buffer)(nativeToBigEndian(0x20_21_22_36_40_50_80_90));
        Buffer[] fps = [testfp];
        auto sender = hirpc.dartRead(null);
        auto receiver = hirpc.receive(Document(hirpc.toHiBON(sender).serialize));
        auto readSync = new ReadRequestHandler(fps, hirpc, "", receiver);
        assert(readSync.alive);

        auto archive = new DARTFile.Recorder.Archive(net ,testfp, DARTFile.Recorder.Archive.Type.STUB);
        auto recorder = DARTFile.Recorder(net);
        recorder.insert(archive);
        auto nsender = hirpc.result(receiver, recorder.toHiBON);
        readSync.setResponse(nsender.toHiBON(net).serialize);
        assert(!readSync.alive);

        assert(readSync.fp_result.length == 1);
        assert(readSync.fp_result[testfp] == archive.toHiBON.serialize);
    }
}

import tagion.gossip.GossipNet;

@safe
class MyFakeNet: StdSecureNet{
    enum fake="fake";
    protected immutable(ubyte)[] fakeKey;
    this(){
        super();
    }
    import core.exception : SwitchError;

    @trusted
    override Buffer calcHash(scope const(ubyte[]) data) const {
        immutable size=*cast(uint*)(data.ptr);
        if ( size+uint.sizeof == data.length && size!=12 ) { //TODO: fix: size == 12 - two fp
            auto doc=Document(cast(immutable)data);
            import tagion.hibon.HiBONJSON: toJSON;
            if ( doc.hasElement(fake) ) {
                import tagion.hibon.HiBONBase : Type;
                assert(doc[fake].type == Type.UINT64);
                auto x=doc[fake].get!ulong;
                import std.bitmanip: nativeToBigEndian;
                return nativeToBigEndian(x).idup;
            }
        }
        import std.digest.sha : SHA256;
        import std.digest.digest: digest;
        return digest!SHA256(data).idup;
    }
    static immutable(ubyte[]) serialize(const ulong x) {
        auto hibon=new HiBON;
        hibon[fake]=x;
        import tagion.hibon.HiBONBase : Type;
        assert(hibon[fake].type == Type.UINT64);
        immutable data=hibon.serialize;
        auto doc=Document(data);
        assert(doc[fake].type == Type.UINT64);
        return hibon.serialize;
    }
}

import core.thread;
class ReplayPool(T){
    protected {
        void delegate(T) replayFunc;
        uint current_index;
        T[] modifications;
    }
    this(void delegate(T) replayFunc){
        this.replayFunc = replayFunc;
    }

    void execute()
    {
        try{
            if(!empty){
                log("%d i: %d", modifications.length, current_index);
                replayFunc(modifications[current_index]);
                current_index++;
            }
        }catch(Exception e){
            log("Replay fiber exception: %s", e);
        }
    }

    void insert(T value){
        modifications~=value;
    }

    void clear(){
        modifications = [];
        current_index = 0;
    }

    size_t count() const pure nothrow{
        return modifications.length;
    }

    bool empty() const pure nothrow{
        return count == 0;
    }

    bool isOver() const pure nothrow {
        return current_index >= count;
    }
}



interface SynchronizationFactory{
    bool canSynchronize();
    Tuple!(uint, ResponseHandler) syncSector(Buffer sector, void delegate(string) oncomplete, void delegate(Buffer sector) onfailure);
}

class P2pSynchronizationFactory: SynchronizationFactory{
    protected DART dart;
    protected shared ConnectionPool!(shared p2plib.Stream, ulong) connection_pool;
    protected shared p2plib.Node node;
    protected Random rnd;
    protected immutable(Options) opts;
    protected ulong[string] synchronizing;
    protected string task_name;
    protected immutable(Pubkey) pkey;

    this(DART dart, shared p2plib.Node node, shared ConnectionPool!(shared p2plib.Stream, ulong) connection_pool, const Options opts, immutable(Pubkey) pkey){
        this.dart = dart;
        this.rnd = Random(unpredictableSeed);
        this.node = node;
        this.connection_pool = connection_pool;
        this.opts = opts;
        this.pkey = pkey;
    }

    protected NodeAddress[Pubkey] node_addrses;
    void setNodeTable(NodeAddress[Pubkey] node_addrses){
        this.node_addrses = node_addrses;
    }

    bool canSynchronize(){
        return node_addrses !is null && node_addrses.length > 0;
    }
    Tuple!(uint, ResponseHandler) syncSector(Buffer sector, void delegate(string) oncomplete, void delegate(Buffer sector) onfailure){
        Tuple!(uint, ResponseHandler) syncWith(NodeAddress address){
            import p2p.go_helper;
            ulong connect(){
                if(address.address in synchronizing){
                    return synchronizing[address.address];
                }
                auto stream = node.connect(address.address, address.is_marshal, [opts.dart.sync.protocol_id]);
                connection_pool.add(stream.Identifier, stream, true);
                stream.listen(&StdHandlerCallback,
                    opts.dart.sync.task_name, opts.dart.sync.host.timeout.msecs, opts.dart.sync.host.max_size);
                synchronizing[address.address] = stream.Identifier;
                return stream.Identifier;
            }
            try{
                auto stream_id = connect();
                auto filename = tempfile~(std.conv.to!string(sector));
                enum BLOCK_SIZE=0x80;
                BlockFile.create(filename, DART.stringof, BLOCK_SIZE);
                auto sync = new P2pSynchronizer(filename, stream_id, oncomplete, onfailure);
                auto db_sync = dart.synchronizer(sync, sector);
                db_sync.call;
                return tuple(db_sync.id, cast(ResponseHandler)sync);
            }
            catch(GoException e){
                log("Error, connection failed with code: %s", e.Code);//TODO: add address to blacklist
            }
            catch(Exception e){
                log("Error: %s", e);
            }
            return Tuple!(uint, ResponseHandler)(0, null);
        }

        auto iteration = 0;
        do{
            iteration++;
            // writeln(node_addrses.length);
            auto selectedNode = node_addrses.keys[uniform(0, node_addrses.length, rnd)];
            if(node_addrses[selectedNode].sector.inRange(sector)){
                const node_port = node_addrses[selectedNode].port;
                const own_port = opts.port;
                if(selectedNode == pkey) continue;
                if(opts.dart.master_from_port){
                    enum isSlave = (ulong port) => port < opts.dart.sync.maxSlavePort;
                    if(isSlave(own_port) && isSlave(node_port)) continue;  //ignore slave nodes
                    if(!isSlave(own_port) && !isSlave(node_port)) continue;    //ignore master nodes
                }
                auto response = syncWith(node_addrses[selectedNode]);
                if(response[1] is null) continue;
                return response;
            }
        }while(iteration < 20);
        return Tuple!(uint, ResponseHandler)(0, null);
    }

    class P2pSynchronizer : DART.StdSynchronizer, ResponseHandler {
        protected const ulong key;
        protected Buffer response;
        protected void delegate(string journal_filename) oncomplete;
        protected void delegate(Buffer sector) onfailure;
        string filename;
        void setResponse(Buffer resp) {
            response = resp;
            fiber.call;
        }

        bool alive(){
            import core.thread: Fiber;
            return fiber.state != Fiber.State.TERM && connection_pool.contains(key);
        }

        this(string journal_filename, const ulong key, void delegate(string) oncomplete, void delegate(Buffer) onfailure) {
            filename = journal_filename;
            this.key = key;
            this.oncomplete = oncomplete;
            this.onfailure = onfailure;
            super(journal_filename);
        }
        const(HiRPCReceiver) query(ref scope const(HiRPCSender) request) {
            scope(failure){
                close();
            }
            void send_request_to_forien_dart(Buffer data) {
                const sended = connection_pool.send(key, data);
                if(!sended){
                    log("P2pSynchronizer: connection closed");
                    close();
                }
            }
            immutable foreign_data = hirpc.toHiBON(request).serialize;
            import p2p.go_helper;
            try{
                send_request_to_forien_dart(foreign_data);
            }catch(GoException e){
                log("P2pSynchronizer: Exception on sending request: %s", e);
                close();
            }
            fiber.yield;
            assert(response);
            auto doc = Document(response);
            auto received = hirpc.receive(doc);
            return received;
        }

        void close(){
            scope(exit){
                finish;
            }
            if(alive){
                log("P2pSynchronizer: close alive. Sector: %d", convertFromBuffer!ushort(fiber.root_rims));
                onfailure(fiber.root_rims);
                fiber.reset();
            }else{
                // pool.close(key);
                log("P2pSynchronizer: Synchronization Completed! Sector: %d", convertFromBuffer!ushort(fiber.root_rims));
                oncomplete(filename);
            }
            // connection_pool.close(key); //TODO: if one connnection used for one synchronization
        }
    }
}
version(none)
unittest{
    @trusted
    synchronized
    class FakeRequestStream : p2plib.RequestStream {
        public static ulong id = 1;
        this(){
            super(null, id);
        }
        private uint write_counter = 0;
        private bool throwException = false;
        override void writeBytes(Buffer data) {
            import core.atomic;
            atomicOp!"+="(this.write_counter, 1);
            if(throwException){
                import p2p.go_helper;
                throw new GoException(ErrorCode.InternalError);
            }
        }
        override  void listen(p2plib.HandlerCallback handler, string tid,
            Duration timeout, int maxSize){

            }
        ~this(){
            disposed = true;
        }
    }

    @trusted
    synchronized
    class FakeNode: p2plib.Node{
        this(){
            fake_stream = new shared FakeRequestStream();
            super();
        }
        private uint connect_counter = 0;
        private FakeRequestStream fake_stream;
        override shared(p2plib.RequestStream) connect(string addr, string[] pids ...) {
            import core.atomic;
            atomicOp!"+="(this.connect_counter, 1);
            return fake_stream;
        }
        ~this(){
            disposed = true;
            destroy(fake_stream);
        }
    }

    auto net=new MyFakeNet;
    net.generateKeyPair("testkey");
    auto hirpc = HiRPC(net);
    immutable filename=fileId!DART.fullpath;
    Options opts;
    setDefaultOption(opts);
    opts.dart.sync.host.timeout = 50;
    opts.dart.sync.master_angle_from_port = false;

    NodeAddress[string] address_table;
    auto addr1 = NodeAddress();
    addr1.sector = DART.SectorRange(0, 5);
    addr1.port = 4021;
    auto pkey = cast(immutable(Pubkey))[0,0,0,1];
    address_table[[pkey]] = addr1;

    DART.create_dart(filename);
    auto dart = new DART(net, filename, 0, 5); // 5 P2p Synchronizers

    template controlFuncs(){
        bool completedCalled = false;
        void oncomplete(string journal){
            completedCalled = true;
        }
        bool failedCalled = false;
        void onfailed(Buffer sector){
            failedCalled = true;
        }
    }

    {//P2pSynchronizationFactory: can synchronize after address table is set
        auto node = new shared FakeNode();
        auto connectionPool = new shared(ConnectionPool!(shared  p2plib.Stream, ulong))(10.msecs);
        auto sync_factory = new P2pSynchronizationFactory(dart,node, connectionPool, opts, pkey);
        assert(!sync_factory.canSynchronize);

        sync_factory.setNodeTable(address_table);

        assert(sync_factory.canSynchronize);
        destroy(node);
    }
    {//P2pSynchronizationFactory: connect and start synchronization if node found
        auto node = new shared FakeNode();
        auto connectionPool = new shared(ConnectionPool!(shared  p2plib.Stream, ulong))(10.msecs);
        auto sync_factory = new P2pSynchronizationFactory(dart,node, connectionPool, opts, pkey);
        sync_factory.setNodeTable(address_table);
        mixin controlFuncs;
        auto result = sync_factory.syncSector([], &oncomplete, &onfailed);
        assert(result[1] !is null);
        assert(node.connect_counter == 1);
        assert(node.fake_stream.write_counter == 1);
        destroy(node);
    }
    {//P2pSynchronizationFactory: return null if synchronize node not found
        auto node = new shared FakeNode();
        auto connectionPool = new shared(ConnectionPool!(shared  p2plib.Stream, ulong))(10.msecs);
        auto sync_factory = new P2pSynchronizationFactory(dart,node, connectionPool, opts, pkey);

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
class DartSynchronizationPool(THandlerPool: HandlerPool!(ResponseHandler, uint)): Fiber{    //TODO: move fiber inside as a field
    enum root = [];
    bool fast_load;
    protected enum State{
        READY,
        FIBER_RUNNING,
        RUNNING,
        ERROR,
        OVER,
        STOP
    }
    mixin StateT!State;

    bool isReady() nothrow{
        return checkState(State.READY);
    }
    bool isOver() nothrow{
        return checkState(State.OVER);
    }
    bool isError() nothrow{
        return checkState(State.ERROR);
    }

    void stop(){
        if(!checkState(State.STOP)){
            log("Stop dart sync pool");
            if(handlerTid != Tid.init){
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
    protected Options opts; //TODO: moveout!
    protected Tid handlerTid;
    protected SynchronizationFactory sync_factory;
    protected ReplayPool!string journal_replay;

    protected bool[Buffer] sync_sectors;
    protected Buffer[] failed_sync_sectors;
    this(DART.SectorRange sectors, ReplayPool!string journal_replay, immutable(Options) opts){
        this.fast_load = opts.dart.fast_load;
        // writefln("Fast load: %s", fast_load);
        if(fast_load){
            assert(fast_load && sectors.isFullRange, "Fast load will load full dart");
        }
        _state = State.READY;
        this.journal_replay = journal_replay;
        this.opts = opts;
        this.handlerPool = new THandlerPool(opts.dart.sync.host.timeout.msecs);
        if(!fast_load){
            foreach(i;sectors){
                sync_sectors[convert_sector_to_rims(i)] = false;
            }
        }else{
            sync_sectors[root] = false;
        }

        super(&run);
    }

    protected void run(){
        import std.algorithm: filter,reduce;
        import std.array : array;
        if(fast_load){
            auto result = sync_factory.syncSector([], &onComplete, &onFailure);
            if(result[1] is null) {
                // log("Couldn't synchronize root");
                onFailure(root); //TODO: or just ignore?
            }else{
                handlerPool.add(result[0], result[1], true);
                sync_sectors[root] = true;
            }
        }else{
            foreach(sector, is_synchronized; sync_sectors){
                if(is_synchronized) continue;
                // writef("\rSync: %d%%", (reduce!((a,b)=>a+b?0:1)(0,sync_sectors.byValue)*100)/sync_sectors.length);
                auto result = sync_factory.syncSector(sector, &onComplete, &onFailure);
                if(result[1] is null) {
                    // log("Couldn't synchronize sector: %d", sector);
                    onFailure(sector); //TODO: or just ignore?
                }else{
                    sync_sectors[sector] = true;
                    handlerPool.add(result[0], result[1], true);
                }
                yield();
            }
        }
        if(failed_sync_sectors.length > 0){
            _state = State.ERROR;
        }else{
            _state = State.RUNNING;
        }
    }

    void start(SynchronizationFactory factory)  //restart with new factory
    in{
        assert(checkState(State.STOP, State.READY, State.ERROR));
    }
    do{
        this.sync_factory = factory;
        if(factory.canSynchronize){
            if(state == Fiber.State.TERM){
                reset();
            }
            if(checkState(State.ERROR) && failed_sync_sectors.length > 0){
                foreach(sector; failed_sync_sectors){
                    sync_sectors[sector] = false;
                }
                failed_sync_sectors = [];
            }
            _state = State.FIBER_RUNNING;
            call;
        }
    }

    void setResponse(Response!(ControlCode.Control_RequestHandled) resp)
    in{
        assert(checkState(State.RUNNING, State.FIBER_RUNNING, State.ERROR));
    }
    do{
        auto doc = Document(resp.data);
        import tagion.hibon.HiBONJSON;
        auto message_doc = doc[Keywords.message].get!Document;
        auto response = ResponseHandler.Response!uint(message_doc[Keywords.id].get!uint, resp.data);
        handlerPool.setResponse(response);
    }

    private void onComplete(string journal_filename){
        journal_replay.insert(journal_filename);
    }

    private void onFailure(Buffer sector){
        // writeln("Failed synchronize sector");
        if(checkState(State.FIBER_RUNNING)){
            failed_sync_sectors ~= sector;
        }else{
            sync_sectors[sector] = false;
            _state = State.ERROR;
        }
    }

    void tick()
    {
        if(checkState(State.RUNNING, State.FIBER_RUNNING, State.ERROR)){
            handlerPool.tick;
        }
        if(checkState(State.FIBER_RUNNING)){
            if(handlerPool.size<=opts.dart.sync.max_handlers || opts.dart.sync.max_handlers == 0)
            {
                call;
            }
        }
        if(checkState(State.RUNNING)){
            if(handlerPool.empty){
                // writeln("Synchronization pool over");
                _state = State.OVER;
            }
        }
    }
}

unittest{
    import std.algorithm : count;
    static class FakeResponseHandler:ResponseHandler{
        void setResponse(Buffer response){}
        bool alive(){return true; }
        void close(){}
    }

    static class FakeSynchronizationFactory: SynchronizationFactory{
        private bool _canSynchronize = true;
        bool canSynchronize(){
            return _canSynchronize;
        }

        private Tuple!(uint, ResponseHandler) mockReturn;
        private uint sync_counter = 0;
        Tuple!(uint, ResponseHandler) syncSector(Buffer sector, void delegate(string) oncomplete, void delegate(Buffer sector) onfailure){
            sync_counter++;
            return mockReturn;
        }
    }

    static class FakeHandlerPool(TValue: ResponseHandler, TKey): StdHandlerPool!(TValue, TKey){
        this(const Duration timeout){
            super(timeout);
        }
        static TKey[] keys;
        static bool set_expired = false;
        static bool is_empty = false;

        override void add(const TKey key, ref TValue value, bool long_lived = false){
            keys~=key;
            super.add(key, value,long_lived);
        }
        override void tick(){
            if(set_expired){
                foreach(key,activeHandler; handlers){
                    remove(key);
                }
            }
        }

        override bool empty(){
            return is_empty;
        }
    }

    Options opts;
    setDefaultOption(opts);
    opts.dart.sync.host.timeout = 50;
    opts.dart.sync.master_angle_from_port = false;
    void emptyFunc(string jf){ return ;}
    auto journal_replay = new ReplayPool!string(&emptyFunc);
    opts.dart.fast_load = false;

    {//DartSynchronizationPool: reconect on synchronizer failed after fiber finish
        auto pool = new DartSynchronizationPool!(FakeHandlerPool!(ResponseHandler, uint))(DART.SectorRange(0, 5), journal_replay,opts);
        auto sync_factory = new FakeSynchronizationFactory();
        sync_factory.mockReturn = tuple(1, new FakeResponseHandler());
        pool.start(sync_factory);
        auto iterations = 0;
        do{
            iterations++;
            pool.tick;
        }while(iterations <= 5);

        pool.onFailure(convert_sector_to_rims(0));

        assert(sync_factory.sync_counter == 5);
        assert(pool.isError);

        pool.start(sync_factory);
        assert(sync_factory.sync_counter == 6);
        assert(!pool.isError);
        pool.tick;
        assert(!pool.isError);
    }

    {//DartSynchronizationPool: reconect on synchronizer failed before fiber finish
        auto pool = new DartSynchronizationPool!(FakeHandlerPool!(ResponseHandler, uint))(DART.SectorRange(0, 5), journal_replay,opts);
        auto sync_factory = new FakeSynchronizationFactory();
        sync_factory.mockReturn = tuple(1, new FakeResponseHandler());
        pool.start(sync_factory);
        auto iterations = 0;
        do{
            iterations++;
            if(iterations == 2){
                pool.onFailure(convert_sector_to_rims(0));
            }
            pool.tick;
        }while(iterations <= 5);

        assert(sync_factory.sync_counter == 5);
        assert(pool.isError);

        pool.start(sync_factory);
        assert(sync_factory.sync_counter == 6);
        assert(!pool.isError);
        pool.tick;
        assert(!pool.isError);
    }

    {//DartSynchronizationPool: synchronization over
        auto pool = new DartSynchronizationPool!(FakeHandlerPool!(ResponseHandler, uint))(DART.SectorRange(0, 5), journal_replay, opts);
        auto sync_factory = new FakeSynchronizationFactory();
        sync_factory.mockReturn = tuple(1, new FakeResponseHandler());
        pool.start(sync_factory);
        auto iterations = 0;
        do{
            iterations++;
            pool.tick;
        }while(iterations <= 5);

        assert(sync_factory.sync_counter == 5);
        assert(!pool.isError);
        assert(!pool.isOver);

        FakeHandlerPool!(ResponseHandler, uint).is_empty = true;
        pool.tick;
        FakeHandlerPool!(ResponseHandler, uint).is_empty = false;
        assert(pool.isOver);
    }
}
