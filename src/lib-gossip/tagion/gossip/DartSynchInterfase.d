module tagion.gossip.DartSynchInterfase;
import p2plib = p2p.node;
import tagion.services.P2pTagionService;
import lib = p2p.cgo.libp2pgowrapper;
import p2p.interfaces;
import tagion.services.Options;
import std.stdio;
import core.time;
import std.algorithm;
import std.array;
import p2p.cgo.c_helper: DBuffer;
import p2p.go_helper;
import p2p.cgo.c_helper;
import tagion.services.Options;
import std.typecons;
import p2p.callback;

/*
alias HandlerCallback = extern (C) void function(DBuffer, DBuffer, void*, ulong, ControlCode); //dublicate (options?)

@trusted synchronized class TestTest: BlackHole!NodeI {

    protected shared const void* node;

    override void listen(
            string pid,
            HandlerCallback handler,
            string tid,
            Duration timeout = DefaultOptions.timeout,
            int maxSize = DefaultOptions.maxSize) { //TODO: check if disposed
        DBuffer pidStr = pid.ToDString();
        DBuffer tidStr = tid.ToDString();
        lib.listenApi(cast(void*) node, pidStr, handler, tidStr, //////////
                cast(int)(timeout.total!"msecs"), maxSize).cgocheck;
    }

    override void closeListener(string pid) {
        DBuffer pidStr = pid.ToDString();
        lib.closeListenerApi(cast(void*) node, pidStr).cgocheck; ///////////
    }
    
    override shared(RequestStreamI) connect(
            string addr,
            bool addrInfo,
            string[] pids...) {
        DBuffer addrStr = addr.ToDString();
        DBuffer[] pidStr = pids.map!(pid => pid.ToDString).array;
        auto listenerResponse = lib.handleApi(cast(void*) node, addrStr, ///////
                pidStr.ToGoSlice, addrInfo).cgocheck;
        return new shared RequestStream(listenerResponse.r0, listenerResponse.r1);
    }

}//RequestStream todo   implem p2pWraper func (conc send rec)
*/
unittest {
    import std.stdio;
    writeln("<______________START_______________>");
    assert(1);
    Options opts;
   // writeln(opts);
    setDefaultOption(opts);
   // writeln(opts);
    shared(p2plib.Node) p2pnode_1;
    shared(p2plib.Node) p2pnode_2;
    p2pnode_1 = initialize_node(opts);
  //  writeln("ID: ", p2pnode_1.Id());
   // writeln("ADDRESSES: ", p2pnode_1.Addresses());
  //  writeln("ADDRESSES_PUB: ", p2pnode_1.PublicAddress());
    writeln("ADDRESSES_INFO: ", p2pnode_1.AddrInfo());


    writeln("-------------------------");
    opts.port = 4002;
    p2pnode_2 = initialize_node(opts);
  //  writeln("ID: ", p2pnode_2.Id());
   // writeln("ADDRESSES: ", p2pnode_2.Addresses());
   // writeln("ADDRESSES_PUB: ", p2pnode_2.PublicAddress());
    writeln("ADDRESSES_INFO: ", p2pnode_2.AddrInfo());

    p2pnode_1.listen("my_pid", &StdHandlerCallback, opts.dart.sync.task_name);

    string[] pid;
    pid ~= "my_pid";
    writeln("-------", p2pnode_1.Addresses);
    string addr = "/ip4/127.0.0.1/tcp/4001";
    addr = p2pnode_1.addIdentityy(addr);
    writeln(addr, " +++++++++++++++");
    auto stream = p2pnode_2.connect(addr, false, pid);
    writeln(typeid(stream));
    Buffer buf = cast(Buffer) "ffffffffffff";
    stream.writeBytes(buf);
   // p2pnode_1.connect("/ip4/192.168.31.88/tcp/4002");//p2pnode_2.Addresses
    writeln("<______________FINISH_________________>");
}
// test p2p with 3 nodes
// cheak for whitepointers