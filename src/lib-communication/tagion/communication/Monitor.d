module tagion.communication.Monitor;

import tagion.hashgraph.Event : Event, EventCallbacks;
import tagion.hashgraph.ConsensusExceptions : ConsensusException;

import tagion.bson.BSONType : EventCreateMessage, EventUpdateMessage, EventProperty, generateHoleThroughBsonMsg;
import tagion.Base : ThreadState;

import core.thread : dur, msecs, seconds;
import std.concurrency : Tid, spawn, send, ownerTid, receiveTimeout, receiveOnly, thisTid, receive;
import std.stdio : writeln, writefln;
import std.format : format;
import std.bitmanip : write;
import std.socket;
import core.thread;


@safe
class SocketMaxDataSize : Exception {
    this( immutable(char)[] msg, string file = __FILE__, size_t line = __LINE__ ) {
        super( msg, file, line );
    }
}

class Lock {
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

    void consensus_failure(const(ConsensusException) e) {
        writefln("Impl. needed. %s  msg=%s ",  __FUNCTION__, e.msg);
    }

    this(Tid socket_thread_id) {
        this._socket_thread_id = socket_thread_id;
    }

    @trusted
    void sendMessage(string msg) {
        _socket_thread_id.send(msg);
    }
}

struct ListenerSocket {

    const ushort port;
    string address;
    shared(bool) * run_listener;
    Tid ownerTid;

    void run () {

        try {
            auto listener = new TcpSocket();
            auto add = new InternetAddress(address, port);
            listener.bind(add);
            listener.listen(10);

            scope(exit) {
                writeln("In scope exit listener socket.");
                if(listener !is null) {
                    writeln("Close listener socket");
                    listener.close;
                }
            }

            writefln("Listening for backend connection on %s:%s", address, port);

            auto socketSet = new SocketSet(1);

            while ( *run_listener ) {
                socketSet.add(listener);
                Socket.select(socketSet, null, null, 2.seconds);
                if ( socketSet.isSet(listener) ) {
                    try {
                        auto client = listener.accept;
                        writefln("Client connection to %s established, is blocking: %s.", client.remoteAddress.toString, client.blocking);
                        assert(client.isAlive);
                        assert(listener.isAlive);
                        ownerTid.send(cast(immutable)client);
                    }
                    catch (SocketAcceptException ex) {
                        writeln(ex);
                    }
                }

                socketSet.reset;
            }

        } catch(Throwable t) {
            writeln(t.toString);
            t.msg ~= " - From listener thread";
            ownerTid.send(cast(immutable)t);
        }
    }
}


//Create flat webserver start class function - create Backend class.
void createSocketThread(ThreadState thread_state, const ushort port, string address, bool exit_flag=false) {

    try{
    //enum max_connections = 3;
    Socket[uint] clients;
    Thread listener_socket_t;
    shared(bool) run_listener = true;

    scope(failure) {
        writefln("In failure of soc. th., flag %s:", exit_flag);
        ownerTid.send(exit_flag);
        // if(exit_flag) {
        //     ownerTid.send(false);
        // }
    }

    scope(success) {
        writefln("In success of soc. th., flag %s:", exit_flag);
        ownerTid.send(exit_flag);
        // if ( exit_flag ) {
        //     ownerTid.send(true);
        // }
    }

    uint client_counter;
    void handleClient (immutable Socket client) {
        client_counter++;
        clients[client_counter] = cast(Socket)client;
    }

    scope(exit) {
        if ( listener_socket_t !is null ) {
            writeln("Kill listener socket.");
            //BUG: Needs to ping the socket to wake-up the timeout again for making the loop run to exit.
            new TcpSocket(new InternetAddress(address, port));
            receive( &handleClient);
            Thread.sleep(500.msecs);
            run_listener = false;
            listener_socket_t.join();
        }

        if ( clients ) {
            writeln("Close clients.");
            foreach ( c; clients) {
                c.close;
            }
        }
    }

    bool runBackend = false;
    void handleState (ThreadState ts) {
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



    enum socket_buffer_size = 0x1000;
    enum socket_max_data_size = 0x10000;


    //Start backend socket, send BSON through the socket
    if(runBackend) {

        auto lso = ListenerSocket(port, address, &run_listener, thisTid);
        void delegate() ls;
        ls.funcptr = &ListenerSocket.run;
        ls.ptr = &lso;

        listener_socket_t = new Thread( ls ).start();

        void sendBytes(immutable(ubyte)[] data) {
            foreach ( key, client; clients) {
                if ( client.isAlive) {
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
                    clients.remove(key);
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
                },
                (immutable(Throwable) t) {
                    writeln(t);
                }
            );
        }
    }
    }catch(Throwable t) {
        writeln(t);
    }
}
