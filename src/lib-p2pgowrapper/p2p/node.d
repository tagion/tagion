module p2p.node;

import lib = p2p.cgo.libp2pgowrapper;
import p2p.cgo.c_helper;
import p2p.go_helper;
import p2p.interfaces;
import core.time;
import std.algorithm;
import std.array;
import std.stdio;

import p2p.connection;
import p2p.callback;

static void EnableLogger() {
    lib.enableLogger();
}

pragma(msg, "fixme(cbr): Reduces the scope of @trusted in the module");

@trusted class Subscription {
    protected const void* ptr;
    protected shared bool disposed = false;
    @disable this();
    package this(const void* subs) {
        ptr = subs;
    }

    void close() {
        if (!disposed) {
            // lib.unsubscribeApi(cast(void*) ptr).cgocheck;
            lib.destroyApi(cast(void*) ptr).cgocheck;
            disposed = true;
        }
    }

    ~this() {
        close();
    }
}

@trusted synchronized class Node : NodeI {
    protected shared const void* node;
    protected shared const void* context;
    // OPTIONS
    protected shared bool disposed = false;
    protected immutable string listenAddr;
    // @disable this();
    version (unittest) {
        this() {
            node = null;
            context = null;
            listenAddr = null;
        }
    }
    else {
        @disable this();
    }
    this(string addr, int seed) {
        this.listenAddr = addr;
        DBuffer addrStr = addr.ToDString();
        this.context = cast(shared) lib.createBackgroundContextApi().cgocheck;
        void* addrPtr = lib.optAddressApi(addrStr).cgocheck;
        void* identityPtr = lib.optIdentityApi(seed).cgocheck;
        void* enableAutonatServicePtr = lib.optEnableAutoNATServiceApi().cgocheck;
        void* optEnableAutoRelayApi = lib.optEnableAutoRelayApi().cgocheck;
        void* optEnableNATPortMapApi = lib.optEnableNATPortMapApi().cgocheck;
        scope (exit) {
            lib.destroyApi(addrPtr);
            lib.destroyApi(identityPtr);
            lib.destroyApi(enableAutonatServicePtr);
            lib.destroyApi(optEnableAutoRelayApi);
            lib.destroyApi(optEnableNATPortMapApi);
        }
        void*[] arr;
        arr ~= addrPtr;
        arr ~= identityPtr;
        arr ~= enableAutonatServicePtr;
        arr ~= optEnableAutoRelayApi;
        arr ~= optEnableNATPortMapApi;
        lib.GoSlice opts = arr.ToGoSlice();
        this.node = cast(shared) lib.createNodeApi(cast(void*) context, opts).cgocheck;
    }

    this(string addr) {
        this.listenAddr = addr;
        DBuffer addrStr = addr.ToDString();
        this.context = cast(shared) lib.createBackgroundContextApi().cgocheck;
        void* enableAutonatServicePtr = lib.optEnableAutoNATServiceApi().cgocheck;
        void* addrPtr = lib.optAddressApi(addrStr).cgocheck;
        scope (exit) {
            lib.destroyApi(addrPtr);
            lib.destroyApi(enableAutonatServicePtr);
        }
        void*[] arr;
        arr ~= addrPtr;
        arr ~= enableAutonatServicePtr;
        lib.GoSlice opts = arr.ToGoSlice();
        this.node = cast(shared) lib.createNodeApi(cast(void*) context, opts).cgocheck;
    }

    void listen(
            string pid,
            HandlerCallback handler,
            string tid,
            Duration timeout = DefaultOptions.timeout,
            int maxSize = DefaultOptions.maxSize) { //TODO: check if disposed
        DBuffer pidStr = pid.ToDString();
        DBuffer tidStr = tid.ToDString();
        lib.listenApi(cast(void*) node, pidStr, handler, tidStr,
                cast(int)(timeout.total!"msecs"), maxSize).cgocheck;
    }

    void listenMatch(
            string pid,
            HandlerCallback handler,
            string tid,
            string[] pids,
            Duration timeout = DefaultOptions.timeout,
            int maxSize = DefaultOptions.maxSize) { //TODO: check if disposed
        DBuffer pidStr = pid.ToDString();
        DBuffer tidStr = tid.ToDString();
        DBuffer[] pidsStr = pids.map!(protocolId => protocolId.ToDString).array;
        lib.listenMatchApi(cast(void*) node, pidStr, handler, tidStr,
                cast(int)(timeout.total!"msecs"), maxSize, pidsStr.ToGoSlice).cgocheck;
    }

    void closeListener(string pid) {
        DBuffer pidStr = pid.ToDString();
        lib.closeListenerApi(cast(void*) node, pidStr).cgocheck;
    }

    shared(RequestStreamI) connect(
            string addr,
            bool addrInfo,
            string[] pids...) {
        DBuffer addrStr = addr.ToDString();
        DBuffer[] pidStr = pids.map!(pid => pid.ToDString).array;
        auto listenerResponse = lib.handleApi(cast(void*) node, addrStr,
                pidStr.ToGoSlice, addrInfo).cgocheck;
        return new shared RequestStream(listenerResponse.r0, listenerResponse.r1);
    }

    void connect(
            string addr,
            bool addrInfo = false) {
        DBuffer addrStr = addr.ToDString();
        lib.connectApi(cast(void*) node, cast(void*) context, addrStr, addrInfo);
    }

    MdnsService startMdns(
            string randezvous,
            Duration interval =
            DefaultOptions.mdnsInterval) {
        DBuffer randezvousStr = randezvous.ToDString();
        return new MdnsService(lib.createMdnsApi(cast(void*) context,
                cast(void*) node, cast(int)(interval.total!"msecs"), randezvousStr).cgocheck);
    }

    AutoNAT startAutoNAT() {
        lib.GoSlice opts;
        const dialback = lib.createNodeApi(cast(void*) context, opts).cgocheck;
        // DBuffer addrStr = listenAddr.ToDString();
        // void* addrPtr = lib.optAddressApi(addrStr).cgocheck;
        // opts ~= addrPtr;
        // const service = lib.createNodeApi(cast(void*) context, opts).cgocheck;
        auto enableOpt = lib.optEnableServiceApi(cast(void*) dialback).cgocheck;
        // auto noStartupOpt = lib.optWithoutStartupDelayApi().cgocheck;
        auto scheduleOpt = lib.optWithScheduleApi(cast(int)(1.seconds.total!"msecs"),
                cast(int)(1.seconds.total!"msecs")).cgocheck;
        scope (exit) {
            lib.destroyApi(enableOpt);
            // lib.destroyApi(noStartupOpt);
            lib.destroyApi(scheduleOpt);
        }
        void*[] arr;
        arr ~= cast(void*) enableOpt;
        // arr ~= cast(void*)noStartupOpt;
        arr ~= cast(void*) scheduleOpt;
        opts = arr.ToGoSlice();
        const natPtr = (lib.createAutoNATApi(cast(void*) node, cast(void*) context, opts).cgocheck);
        return new AutoNAT(natPtr);
    }

    @property string Id() {
        CopyCallback cb;
        lib.getNodeIdApi(cast(void*) node, &(CopyCallback.callbackFunc), &cb).cgocheck;
        return cast(string)(cb.buffer);
    }

    @property string Addresses() {
        CopyCallback cb;
        lib.getNodeAddressesApi(cast(void*) node, &(CopyCallback.callbackFunc), &cb).cgocheck;
        return cast(string)(cb.buffer);
    }

    @property string PublicAddress() {
        CopyCallback cb;
        lib.getNodePublicAddressApi(cast(void*) node, &(CopyCallback.callbackFunc), &cb).cgocheck;
        const addr = cast(string)(cb.buffer);
        if (addr.length > 0) {
            return addIdentity(addr);
        }
        else {
            return "";
        }
    }

    string AddrInfo() {
        CopyCallback cb;
        lib.getNodeAddrInfoMarshalApi(cast(void*) node,
                &(CopyCallback.callbackFunc), &cb).cgocheck;
        const addr = cast(string)(cb.buffer);
        return addr;
    }

    @property string LlistenAddress() {
        return addIdentity(listenAddr);
    }

    protected string addIdentity(string addr) {
        return addr ~ "/p2p/" ~ this.Id;
    }

    Subscription SubscribeToRechabilityEvent(string taskName) {
        auto tid = taskName.ToDString();
        auto ptr = lib.subscribeToRechabiltyEventApi(cast(void*) node,
                &AsyncCopyCallback, tid).cgocheck;
        return new Subscription(ptr);
    }

    Subscription SubscribeToAddressUpdated(string taskName) {
        auto tid = taskName.ToDString();
        auto ptr = lib.subscribeToAddressUpdatedEventApi(cast(void*) node,
                &AsyncCopyCallback, tid).cgocheck;
        return new Subscription(ptr);
    }

    void close() {
        if (!disposed) {
            writeln("!!NODE!! DESTROY NODE");
            lib.destroyApi(cast(void*) context).cgocheck;
            lib.closeNodeApi(cast(void*) node).cgocheck;
            lib.destroyApi(cast(void*) node).cgocheck;
            disposed = true;
        }
    }

    ~this() {
        close();
    }
}

@trusted synchronized class Stream : StreamI {
    protected shared const void* stream;
    protected shared const ulong _identifier;

    protected shared bool disposed = false;

    @property bool alive() pure const nothrow {
        return !disposed;
    }

    @disable this();
    package this(const void* ptr, const ulong id) {
        stream = cast(shared) ptr;
        _identifier = id;
    }

    @property ulong identifier() {
        return _identifier;
    }

    void writeBytes(Buffer data) {
        lib.writeApi(cast(void*) stream, cast(void*) data, cast(int)(data.length)).cgocheck;
    }

    void writeString(string data) {
        lib.writeApi(cast(void*) stream, cast(void*) data.ptr, cast(int)(data.length)).cgocheck;
    }

    void close() {
        if (!disposed) {
            writeln("!!NODE!! CLOSE STREAM ", _identifier);
            lib.closeStreamApi(cast(void*) stream).cgocheck;
            lib.destroyApi(cast(void*) stream).cgocheck;
            disposed = true;
        }
    }

    ~this() {
        writeln("!!NODE!! DESTROY STREAM ", _identifier);
        // close();
        if (!disposed) {
            lib.destroyApi(cast(void*) stream).cgocheck;
            disposed = true;
        }
    }
}

@trusted synchronized class RequestStream : Stream, RequestStreamI {
    @disable this();
    private this(const void* ptr, const ulong id) {
        super(ptr, id);
    }

    void listen(
            HandlerCallback handler,
            string tid,
            Duration timeout = DefaultOptions.timeout,
            int maxSize = DefaultOptions.maxSize) {
        DBuffer tidStr = tid.ToDString();
        lib.listenStreamApi(cast(void*) stream, cast(int) _identifier, handler,
                tidStr, cast(int)(timeout.total!"msecs"), maxSize).cgocheck;
    }

    void reset() {
        writeln("!!NODE!! RESET RequestStream", _identifier);
        lib.resetStreamApi(cast(void*) stream).cgocheck;
    }

    override void close() {
        if (!disposed) {
            writeln("!!NODE!! DESTROY RequestStream", _identifier);
            reset();
            lib.destroyApi(cast(void*) stream).cgocheck;
            disposed = true;
        }
    }

    ~this() {
        writeln("!!NODE!! destructor DESTROY RequestStream", _identifier);
        close();
    }
}

@trusted class MdnsService : MdnsServiceI {
    protected shared const void* service;
    protected shared bool disposed = false;

    @disable this();
    this(const void* ptr) {
        service = cast(shared) ptr;
    }

    MdnsNotifee registerNotifee(
            HandlerCallback callback,
            string tid) {
        DBuffer tidStr = tid.ToDString();
        auto notifee = lib.registerNotifeeApi(cast(void*) service, callback, tidStr).cgocheck;
        return new MdnsNotifee(notifee, this);
    }

    private void unregisterNotifee(const void* notifeePtr) {
        lib.unregisterNotifeeApi(cast(void*) service, cast(void*) notifeePtr).cgocheck;
    }

    void close() {
        if (!disposed) {
            // writeln("!!NODE!! DESTROY MDNS");
            lib.stopMdnsApi(cast(void*) service).cgocheck;
            lib.destroyApi(cast(void*) service).cgocheck;
            disposed = true;
        }
    }

    ~this() {
        close();
    }
}

@trusted class MdnsNotifee : MdnsNotifeeI {
    protected shared const void* notifee;
    protected const MdnsService mdns;
    protected shared bool disposed = false;

    @disable this();
    this(const void* ptr, const MdnsService mdns) {
        notifee = cast(shared) ptr;
        this.mdns = mdns;
    }

    void close() {
        if (!disposed) {
            // writeln("!!NODE!! DESTROY MDNS HANDLER");
            (cast(MdnsService) mdns).unregisterNotifee(cast(void*) notifee);
            lib.destroyApi(cast(void*) notifee).cgocheck;
            disposed = true;
        }
    }

    ~this() {
        close();
    }
}

@trusted class AutoNAT {
    protected shared const void* natPtr;
    protected shared bool disposed = false;

    this(const void* ptr) {
        natPtr = cast(shared) ptr;
    }

    string address() {
        CopyCallback cb;
        lib.getPublicAddress(cast(void*) natPtr, &(CopyCallback.callbackFunc), &cb).cgocheck;
        return cast(string)(cb.buffer);
    }

    NATStatus status() {
        return lib.getNATStatus(cast(void*) natPtr).cgocheck;
    }

    void close() {
        if (!disposed) {
            disposed = true;
        }
    }

    ~this() {
        close();
    }
}
