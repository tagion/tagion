module p2p.interfaces;
public import p2p.cgo.c_helper : ControlCode;
import p2p.cgo.c_helper : DBuffer;
import tagion.services.Options;
import tagion.services.Options : DefaultOptions;
alias Buffer = immutable(ubyte[]);


import core.time;
import p2p.callback : HandlerCallback;

@safe
synchronized interface StreamI {
    bool alive() pure const nothrow;
    void writeBytes(Buffer data);
    void writeString(string data);
    @property ulong identifier();
    void close();
}

@safe
synchronized interface RequestStreamI : StreamI {
    void reset();
    void listen(
            HandlerCallback handler,
            string tid,
            Duration timeout = DefaultOptions.timeout,
            int maxSize = DefaultOptions.maxSize);
}

@safe synchronized interface NodeI {
    // this(string addr, int seed);
    void listen(
            string pid,
            HandlerCallback handler,
            string tid,
            Duration timeout = DefaultOptions.timeout,
            int maxSize = DefaultOptions.maxSize);
    void listenMatch(
            string pid,
            HandlerCallback handler,
            string tid,
            string[] pids,
            Duration timeout = DefaultOptions.timeout,
            int maxSize = DefaultOptions.maxSize);
    void closeListener(string pid);
    shared(RequestStreamI) connect(
            string addr,
            bool addrInfo,
            string[] pids...);

    void connect(
            string addr,
            bool addrInfo = false);

    MdnsServiceI startMdns(
            string randezvous,
            Duration interval = DefaultOptions.mdnsInterval);
    //    AutoNatInterface startAutoNAT();
    @property string Id();
    @property string Addresses();
    @property string PublicAddress();
    string AddrInfo();
    @property string LlistenAddress();
    // Subscription SubscribeToRechabilityEvent(string taskName);
    // Subscription SubscribeToAddressUpdated(string taskName);
    void close();
}

@safe
interface MdnsNotifeeI {
    // this(const void* ptr, const MdnsServiceInterface mdns);

}

@safe
interface MdnsServiceI {
    MdnsNotifeeI registerNotifee(
            HandlerCallback callback,
            string tid);
    void close();
}

// @safe
// interface AutoNatInterface {
//     pragma(msg, "fixme(cbr): This void poiter (const void* ptr) should be buried (Mayby via a this(T)(ref T somename)");
// //    this(const void* ptr);
//     string address();
//     NATStatus status();
//     void close();

// }
