module p2p.callback;

import std.concurrency;
import std.stdio;
import p2p.cgo.libp2pgowrapper;
import p2p.cgo.c_helper;
import p2p.node;
import p2p.interfaces;

struct CopyCallback {
    immutable(ubyte)[] buffer;
    extern (C) {
        static void callbackFunc(const void* data, int len, void* context) {
            auto cb = cast(CopyCallback*) context;
            cb.buffer = (cast(ubyte*) data)[0 .. len].idup;
        }
    }
}

shared struct Response(ControlCode code) {
    ulong key;
    Stream stream;
    Buffer data;
    this(const ulong id, const void* stream = null, Buffer data = null) {
        this.key = id;
        if (stream !is null) {
            this.stream = new shared(Stream)(stream, id);
        }
        this.data = data;
    }
}

alias HandlerCallback = extern (C) void function(DBuffer, DBuffer, void*, ulong, ControlCode);

import std.stdio;
import std.traits;

extern (C) {
    static void StdHandlerCallback(DBuffer data, DBuffer taskId, void* stream,
            ulong id, ControlCode code) {
        string taskName = cast(string)((taskId.pointer)[0 .. taskId.length].idup);
        auto tid = locate(taskName);
        // writeln(taskName);
        if (tid != Tid.init) {
        switchCode:
            switch (code) {
                static foreach (control; EnumMembers!ControlCode) {
            case control: {
                        if (!data.isNull) {
                            auto dataBuff = ((cast(ubyte*) data.pointer)[0 .. data.length]).idup;
                            auto response = Response!(control)(id, stream, dataBuff);
                            send(tid, response);
                        }
                        else {
                            auto response = Response!(control)(id, stream);
                            send(tid, response);
                        }
                        break switchCode;
                    }
                }
            default: {
                    writeln(code);
                    assert(0);
                }
            }
        }
        else {
            writefln("Task %s is not found", taskName);
        }
    }
}

extern (C) {
    static void AsyncCopyCallback(DBuffer data, DBuffer taskId) {
        string taskName = cast(string)((taskId.pointer)[0 .. taskId.length].idup);
        auto tid = locate(taskName);
        // writeln(taskName);
        if (tid != Tid.init) {
            writeln("async copy: data len: ", data.length);
            if (!data.isNull) {
                auto dataBuff = ((cast(ubyte*) data.pointer)[0 .. data.length]).idup;
                send(tid, dataBuff);
            }
            else {
                send(tid, cast(immutable(ubyte)[])[]);
            }
        }
        else {
            writefln("Task %s is not found", taskName);
        }
    }
}
