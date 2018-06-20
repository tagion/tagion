module tagion.communication.Monitor;

import tagion.hashgraph.Event : Event;
import tagion.hashgraph.HashGraph : HashGraph;
import tagion.hashgraph.Net : StdGossipNet, NetCallbacks;;
import tagion.hashgraph.ConsensusExceptions : ConsensusException;

import tagion.bson.BSONType : EventCreateMessage, EventUpdateMessage, EventProperty, generateHoleThroughBsonMsg;
import tagion.Base : Control;

import core.thread : dur, msecs, seconds;
import std.concurrency;
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

// class Lock {
// }




@safe
class MonitorCallBacks : NetCallbacks {
    private Tid _socket_thread_id;
    private Tid _network_socket_tread_id;
    private const uint _local_node_id;
    private const uint _global_node_id;

    //Implementations of callbacks
    @trusted
    void create(const(Event) e) {
        // writefln("Event created, id: %s", e.id);
        if(e.mother !is null) {
            // writeln("Mother id", e.mother.id);
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
        // writefln("The event %s has been created and send to the socket: %s", newEvent.id, _socket_thread_id);
        auto bson = newEvent.serialize;

        _socket_thread_id.send(bson);
    }

    @trusted
    void witness(const(Event) e) {
        // writefln("Event witness, id: %s", e.id);
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
        // writefln("Event strongly seeing, id: %s", e.id);
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
        // writefln("Event famous, id: %s", e.id);
        immutable updateEvent = EventUpdateMessage(
            e.id,
            EventProperty.IS_FAMOUS,
            e.famous
            );
        auto bson = updateEvent.serialize;
        _socket_thread_id.send(bson);
    }

    void round(const(Event) e) {
        // writeln("Impl. needed");
    }

    void forked(const(Event) e) {
        // writefln("Impl. needed. Event %d forked %s ", e.id, e.forked);
    }

    void famous_votes(const(Event) e) {
        // writefln("Impl. needed. Event %d famous votes %d ", e.id, e.famous_votes);
    }

    void strong_vote(const(Event) e, immutable uint vote) {
        // writefln("Impl. needed. Event %d strong vote %d ", e.id, vote);
    }

    void consensus_failure(const(ConsensusException) e) {
        // writefln("Impl. needed. %s  msg=%s ",  __FUNCTION__, e.msg);
    }

    void wavefront_state_receive(const(HashGraph.Node) n) {
        import tagion.Base : cutHex;
        // writefln("Impl. needed. %s  node=%s ",  __FUNCTION__, n.pubkey.cutHex);
    }

    // void wavefront_state_send(const(HashGraph.Node) n) {
    //     import tagion.Base : cutHex;
    //     writefln("Impl. needed. %s  node=%s ",  __FUNCTION__, n.pubkey.cutHex);
    // }

    void sent_tidewave(immutable(ubyte[]) receiving_channel, const(StdGossipNet.Tides) tides) {
        // writefln("Impl. needed. %s  tides=%d ",  __FUNCTION__, tides.length);
    }

    void received_tidewave(immutable(ubyte[]) sending_channel, const(StdGossipNet.Tides) tides) {
        // writefln("Impl. needed. %s  tides=%d ",  __FUNCTION__, tides.length);
    }

    void receive(immutable(ubyte[]) data) {
        // writefln("Impl. needed. %s  ",  __FUNCTION__);
    }

    void send(immutable(ubyte[]) channel, immutable(ubyte[]) data) {
        import tagion.Base : cutHex;
        // writefln("Impl. needed. %s  channel=%s",  __FUNCTION__, channel.cutHex);
    }

    void exiting(const(HashGraph.Node) n) {
        import tagion.Base : cutHex;
        // writefln("Impl. needed. %s  node=%s ",  __FUNCTION__, n.pubkey.cutHex);
    }

    @trusted
    this(Tid socket_thread_id,
        const uint local_node_id,
        const uint global_node_id) {
        this._socket_thread_id = socket_thread_id;
        this._network_socket_tread_id = locate("network_socket_thread");
        this._local_node_id = local_node_id;
        this._global_node_id = global_node_id;
        // writefln("Created monitor socket with local node id: %s and global node id: %s. Has network socket %s", this._local_node_id, this._global_node_id, this._network_socket_tread_id != Tid.init);
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
            writefln("Open Net %s:%s", address, port);
            auto add = new InternetAddress(address, port);
            listener.bind(add);
            listener.listen(10);

            scope(exit) {
                writeln("In scope exit listener socket.");
                if ( listener !is null ) {
                    writeln("Close listener socket");
                    listener.close;
                }
            }

            // writefln("Listening for backend connection on %s:%s", address, port);

            auto socketSet = new SocketSet(1);

            while ( *run_listener ) {
                socketSet.add(listener);
                Socket.select(socketSet, null, null, 2000.msecs);
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
                writefln("Socket timeout %d", port);
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
void createSocketThread(Control thread_state, const ushort port, string address, bool exit_flag=false) {

    try{
        //enum max_connections = 3;
        Socket[uint] clients;
        Thread listener_socket_thread;
        shared(bool) run_listener = true;
        uint client_counter;
        void handleClient (immutable Socket client) {
            client_counter++;
            clients[client_counter] = cast(Socket)client;
        }

        scope(failure) {
            // writefln("In failure of soc. th., flag %s:", exit_flag);
            if(exit_flag) {
                ownerTid.send(Control.FAIL);
            }
        }

        scope(success) {
            // writefln("In success of soc. th., flag %s:", exit_flag);
            if ( exit_flag ) {
                ownerTid.send(Control.END);
            }
        }

        scope(exit) {
            if ( listener_socket_thread !is null ) {
                writeln("Kill listener socket.");
                //BUG: Needs to ping the socket to wake-up the timeout again for making the loop run to exit.
                //               new TcpSocket(new InternetAddress(address, port));
//                receive( &handleClient);
//                Thread.sleep(500.msecs);
                run_listener = false;
                writefln("run_listerner %s", run_listener);
                listener_socket_thread.join();
                writeln("Thread joined");
            }

            if ( clients ) {
                writeln("Close clients.");
                foreach ( c; clients) {
                    c.close;
                }
            }
        }


        bool runBackend = false;
        void handleState (Control ts) {
            with(Control) final switch(ts) {
                case KILL:
                    // writeln("Kill socket thread.");
                    runBackend = false;

                    break;

                case LIVE:
                    runBackend = true;
                    break;
                case STOP:
                case FAIL:
                case ACK:
                case REQUEST:
                case END:
                    writefln("Bad Control command %s", ts);
                    runBackend = false;
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

            listener_socket_thread = new Thread( ls ).start();

            void sendBytes(immutable(ubyte)[] data) {
                foreach ( key, client; clients) {
                    if ( client.isAlive) {
                        if(data.length > socket_max_data_size) {
                            throw new SocketMaxDataSize(format("The maximum data size to send over a socket is %sbytes.", socket_max_data_size));
                        }
                        auto buffer_length = new ubyte[uint.sizeof];
                        immutable data_length = cast(uint)data.length;
                        // writeln("Bytes to send: ", data_length);
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
                        // writeln("The backend socket thread received the message and sends to client socket: " , msg);
                        sendBytes(generateHoleThroughBsonMsg(msg));
                    },

                    (immutable(ubyte)[] bson_bytes) {
                        sendBytes(bson_bytes);
                    },
                    (immutable(Throwable) t) {
                        writeln(t);
                        runBackend=false;
                    }
                    );
            }
        }
    }
    catch(Throwable t) {
        writeln(t);
    }
}
