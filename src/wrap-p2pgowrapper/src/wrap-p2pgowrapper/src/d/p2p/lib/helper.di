module p2p.lib.helper;

import core.stdc.config;

extern (C):

enum ControlCode
{
    Control_Connected = 1,
    Control_RequestHandled = 2,
    Control_Disconnected = 3,
    Control_PeerDiscovered = 4
}

struct DCallback
{
    void* callback;
    void* context;
}

struct DBuffer
{
    bool isNull;
    void* pointer;
    int length;
}

DBuffer emptyDBuffer ();
DBuffer getDBuffer (void* pointer, int len);

alias handlerCallback = void function (DBuffer, DBuffer, void*, c_ulong, ControlCode);
void bridgeHandlerCallback (
    handlerCallback cb,
    DBuffer data,
    DBuffer tid,
    void* stream,
    c_ulong id,
    ControlCode code);

alias callback = void function (void*, int, void*);
void bridgeCallback (callback cb, void* data, int len, void* context);

alias asyncCallback = void function (DBuffer, DBuffer);
void bridgeCallbackAsync (asyncCallback cb, DBuffer data, DBuffer tid);

void myprint (char* s);

enum ErrorCode
{
    Ok = 1,
    InternalError = 2,
    BadConnection = 3
}

enum NATStatus
{
    NATStatusUnknown = 0,
    NATStatusPublic = 1,
    NATStatusPrivate = 2
}
