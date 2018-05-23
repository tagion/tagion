module tagion.communication.Monitor;

import tagion.hashgraph.Event : Event, EventCallbacks;
import tagion.bson.BSONType : EventCreateMessage, EventUpdateMessage, EventProperty, generateHoleThroughBsonMsg;
import tagion.Base : ThreadState;

import core.thread : dur, msecs;
import std.concurrency : Tid, spawn, send, ownerTid, receiveTimeout, LinkTerminated;
import std.stdio : writeln, writefln;
import std.format : format;
import std.bitmanip : write;
import std.socket;


@safe
class SocketMaxDataSize : Exception {
    this( immutable(char)[] msg, string file = __FILE__, size_t line = __LINE__ ) {
        super( msg, file, line );
    }
}

@safe
class MonitorCallBacks : EventCallbacks {
    private Tid _socket_thread_id;
    private Event _currentEvent;

    //Implementations of callbacks
    @trusted
    void create(const(Event) e) {
        writefln("Event created, id: %s", e.id);
        if(e.mother !is null) {
            writeln("Mother id", e.mother.id);
        }

        auto newEvent = immutable(EventCreateMessage) (
            e.id,
            e.payload,
            e.node_id,
            e.mother !is null ? e.mother.id : 0,
            e.father !is null ? e.father.id : 0,
            e.witness,
            e.signature,
            e.pubkey,
            e.event_body.serialize
        );
        writefln("The event %s has been created and send to the socket: %s", newEvent.id, _socket_thread_id);
        auto bson = newEvent.serialize;

        _socket_thread_id.send(bson);
    }

    @trusted
    void witness(const(Event) e) {
        writefln("Event witness, id: %s", e.id);
        immutable updateEvent = EventUpdateMessage(
            e.id,
            EventProperty.IS_WITNESS,
            e.witness
        );
        auto bson = updateEvent.serialize;
        _socket_thread_id.send(bson);
    }

    @trusted
    void strongly_seeing(const(Event) e) {
        writefln("Event strongly seeing, id: %s", e.id);
        immutable updateEvent = EventUpdateMessage(
            e.id,
            EventProperty.IS_STRONGLY_SEEING,
            e.strongly_seeing
        );
        auto bson = updateEvent.serialize;
        _socket_thread_id.send(bson);
    }

    @trusted
    void famous(const(Event) e) {
        writefln("Event famous, id: %s", e.id);
        immutable updateEvent = EventUpdateMessage(
            e.id,
            EventProperty.IS_FAMOUS,
            e.famous
        );
        auto bson = updateEvent.serialize;
        _socket_thread_id.send(bson);
    }

    void round(const(Event) e) {
        writeln("Impl. needed");
    }

    void forked(const(Event) e) {
        writefln("Impl. needed. Event %d forked %s ", e.id, e.forked);
    }

    void famous_votes(const(Event) e) {
        writefln("Impl. needed. Event %d famous votes %d ", e.id, e.famous_votes);
    }

    void strong_vote(const(Event) e, immutable uint vote) {
        writefln("Impl. needed. Event %d strong vote %d ", e.id, vote);
    }

    this(Tid socket_thread_id) {
        this._socket_thread_id = socket_thread_id;
    }

    @trusted
    void sendMessage(string msg) {
        _socket_thread_id.send(msg);
    }
}


void createListenerSocket (const ushort port, string address ) {
    auto listener = new TcpSocket();
    auto add = new InternetAddress(address, port);
    listener.bind(add);
    listener.listen(10);

    writefln("Listening for backend connection on %s:%s", address, port);

    Socket client;
    auto socketSet = new SocketSet(1);
    socketSet.add(listener);

    bool run = true;
    while ( run ) {
        Socket.select(socketSet, null, null);
        if ( socketSet.isSet(listener) ) {
            try {
                client = listener.accept;
                assert(client.isAlive);
                assert(listener.isAlive);
            }
            catch (SocketAcceptException ex) {
                writeln(ex);
            }
        }

        if ( client ) {
            writefln("Client connection to %s established, is blocking: %s.", client.remoteAddress.toString, client.blocking);
            ownerTid.send(cast(immutable)client);
        }

        if ( client  && !client.isAlive) {
            writeln("Backend client connection disrupted.");
            client.close;
            client.destroy;
        }
    }

    scope(exit) {
        if(listener !is null) {
            writeln("Close listener socket");
            listener.close;
            listener.destroy;
        }
    }
}

//Create flat webserver start class function - create Backend class.
void createSocketThread(immutable(ThreadState) thread_state, const ushort port, string address, bool test_flag=false) {
    enum socket_buffer_size = 0x1000;
    enum socket_max_data_size = 0x10000;
    //TO-DO no max connection limit impl.
    enum max_connections = 3;

    Socket[] clients;

    bool runBackend = false;
    shared static bool run_listener_socket = true;

    scope(failure) {
        if(test_flag) {
            ownerTid.send(false);
        }
    }

    scope(success) {
        if ( test_flag ) {
            ownerTid.send(true);
        }
    }

    scope(exit) {
        if ( clients ) {
            writeln("Close clients.");
            foreach ( c; clients) {
                c.close;
                c.destroy;
            }
        }
        run_listener_socket = false;
    }

    void handleState (immutable ThreadState ts) {
        with(ThreadState) final switch(ts) {
            case KILL:
                writeln("Kill socket thread.");
                runBackend = false;
            break;

            case LIVE:
                runBackend = true;
            break;
        }
    }

    handleState(thread_state);


    void handleClient (immutable Socket client) {
        writeln("received client");
        clients ~= cast(Socket)client;
    }
    //Start backend socket, send BSON through the socket
    if(runBackend) {
        spawn(&createListenerSocket, port, address);

        void sendBytes(immutable(ubyte)[] data) {
            writeln("In send bytes");
            foreach ( i, client; clients) {
                if( client ) {
                    if ( client.isAlive) {
                        writeln("after client check");
                        if(data.length > socket_max_data_size) {
                            throw new SocketMaxDataSize(format("The maximum data size to send over a socket is %sbytes.", socket_max_data_size));
                        }
                        auto buffer_length = new ubyte[uint.sizeof];
                        immutable data_length = cast(uint)data.length;
                        writeln("Bytes to send: ", data_length);
                        buffer_length.write(data_length, 0);

                        client.send(buffer_length);

                        for (uint start_pos = 0; start_pos < data_length; start_pos += socket_buffer_size) {
                            immutable end_pos = (start_pos+socket_buffer_size < data_length) ? start_pos+socket_buffer_size : data_length;
                            client.send(data[start_pos..end_pos]);
                        }
                    }
                    else {
                        client.close;
                        client.destroy;
                        clients[i] = null;
                    }
                }
            }
        }

        while(runBackend) {
            receiveTimeout(500.msecs,
                //Control the thread
                &handleState,

                &handleClient,

                (string msg) {
                    writeln("The backend socket thread received the message and sends to client socket: " , msg);
                    sendBytes(generateHoleThroughBsonMsg(msg));
                },

                (immutable(ubyte)[] bson_bytes) {
                    sendBytes(bson_bytes);
                }
            );

        }
    }
}