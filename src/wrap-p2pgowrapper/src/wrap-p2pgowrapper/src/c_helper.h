#include <stdio.h>
#include <stdlib.h>
#include <stddef.h>
#include <stdbool.h>


typedef enum ControlCode{
	Control_Connected = 1,
	Control_RequestHandled = 2,
	Control_Disconnected = 3,
	Control_PeerDiscovered = 4
} ControlCode;

typedef struct
{
	void *callback;
	void *context;
} DCallback;

typedef struct
{
	bool isNull;
	void* pointer;
	int length;
} DBuffer;

static DBuffer emptyDBuffer(){
	DBuffer obj;
	obj.isNull = true;
	return obj;
}
static DBuffer getDBuffer(void *pointer, int len)
{
	DBuffer obj;
	obj.isNull = false;
	obj.pointer = pointer;
	obj.length = len;
	return obj;
}

typedef void (*handlerCallback)(DBuffer, DBuffer, void*, unsigned long, ControlCode);
static void bridgeHandlerCallback(handlerCallback cb, DBuffer data, DBuffer tid, void *stream, unsigned long id, ControlCode code)
{
	cb(data, tid, stream, id, code);
}

typedef void (*callback)(void *, int, void *);
static void bridgeCallback(callback cb, void *data, int len, void *context)
{
	cb(data, len, context);
}

typedef void (*asyncCallback)(DBuffer, DBuffer);
static void bridgeCallbackAsync(asyncCallback cb, DBuffer data, DBuffer tid)
{
	cb(data, tid);
}

static void myprint(char *s)
{
	printf("%s\n", s);
}

typedef enum ErrorCode
{
	Ok = 1,
	InternalError = 2,
	BadConnection = 3,
} ErrorCode;

typedef enum NATStatus
{
	NATStatusUnknown = 0,
    NATStatusPublic = 1,
    NATStatusPrivate = 2
} NATStatus;