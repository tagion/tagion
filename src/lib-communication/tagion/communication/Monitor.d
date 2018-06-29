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

    private immutable ushort port;
    private string address;
    private shared(bool) stop_listener;
    private Tid ownerTid;
    private Socket[uint] clients;

    // struct ClientChain {
    //     Socket socket;
    //     immutable uint id;
    //     ClientChain* next;
    // }



//    private Socket[uint] clients;
    //private uint client_counter;
//    private ClientStack stack;
//    synchronized
    // struct ClientStack {
    //     private uint client_counter;
    //     private Socket[uint] clients;
    //     void push(ref Socket client) {
    //         clients[client_counter] = client;
    //         client_counter++;
    //     }
    //     void remove(uint socket_id) {
    //         clients.remove(socket_id);
    //     }
    //     Socket client(uint socket_id) {
    //         return clients[socket_id];
    //     }
    // }

//    private shared(ClientStack)* stack;

    this(immutable ushort port, string address, Tid ownerTid) {
        this.port=port;
        this.address=address;
        this.ownerTid=ownerTid;
//        run_listener=true;
    }

    void stop() {
        writeln("STOP!!!!!!!");
        stop_listener=true;
    }

    enum socket_buffer_size = 0x1000;
    enum socket_max_data_size = 0x10000;


    // This function is only call by one thread

    synchronized
    class SharedClients {
        private shared(Socket[uint])* locate_clients;
        private shared(uint) client_counter;
//        ( locate_clients ) {
        this(ref Socket[uint] _clients)
            in {
                assert(locate_clients is null);
                assert(_clients !is null);
            }
        out {
            assert(locate_clients !is null);
            client_counter=cast(uint)_clients.length;
        }
        body {
            locate_clients=cast(typeof(locate_clients))&_clients;
        }
        void add(ref Socket client) {
            auto clients=cast(Socket[uint]) *locate_clients;
            clients[client_counter] = client;
            client_counter=client_counter + 1;
        }
        bool active() const pure {
            return (locate_clients !is null);
        }
        void sendBytes(immutable(ubyte)[] data) {
            auto clients=cast(Socket[uint]) *locate_clients;
            //auto clients=stack.clients.dup;
            writefln("number of clients=%s data=%d", clients.length, data.length);
            foreach ( key, client; clients) {
                // writefln("key=%s client.isAlive=%s", key, client.isAlive);
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
        void close() {
            if ( locate_clients !is null ) {
                auto clients=cast(Socket[uint]) *locate_clients;
                foreach ( key, client; clients) {
                    client.close;
//                clients.remove(key);
                }
                locate_clients=null;
            }
        }
    }


    void sendBytes(immutable(ubyte)[] data) {
        if ( active ) {
            shared_clients.sendBytes(data);
        }
    }

    bool active() pure const {
        return (shared_clients !is null) && shared_clients.active;
    }

    void add(ref Socket client) {
        if ( shared_clients is null) {
            clients[0]=client;
            shared_clients=new shared(SharedClients)(clients);
        }
        else {
            shared_clients.add(client);
        }
    }

    void close() {
        if ( active ) {
            shared_clients.close;
        }
    }

    private shared(SharedClients) shared_clients;
    void run () {
        writefln("!!!!!!!!!!!!!! Start %s", clients is null);
        try {
            auto listener = new TcpSocket;
            writefln("Open Net %s:%s", address, port);
            auto add = new InternetAddress(address, port);
            listener.bind(add);
            listener.listen(10);

            scope(exit) {
                writeln("In scope exit listener socket.");
                if ( listener !is null ) {
                    writefln("Close listener socket %d", port);
                    listener.close;
                }
                writefln("listerner closed %d", port);
            }

            writefln("Listening for backend connection on %s:%s", address, port);

            auto socketSet = new SocketSet(1);

            while ( !stop_listener ) {
                socketSet.add(listener);
                Socket.select(socketSet, null, null, 500.msecs);
                if ( socketSet.isSet(listener) ) {
                    try {
                        auto client = listener.accept;
                        writefln("Client connection to %s established, is blocking: %s.", client.remoteAddress.toString, client.blocking);
                        assert(client.isAlive);
                        assert(listener.isAlive);
                        this.add(client);
                        // client_counter++;
                        // clients[client_counter] = client;

                        //ownerTid.send(cast(immutable)client);
                    }
                    catch (SocketAcceptException ex) {
                        writeln(ex);
                    }
                }
                writefln("Socket timeout %d", port);
                socketSet.reset;
            }

        }
        catch(Throwable t) {
            writeln(t.toString);
            t.msg ~= " - From listener thread";
            ownerTid.send(cast(immutable)t);
        }
    }
}


//Create flat webserver start class function - create Backend class.
void createSocketThread(const ushort port, string address, bool exit_flag=false) {
    scope(failure) {
        writefln("In failure of soc. th., flag %s:", exit_flag);
//            if(exit_flag) {
        ownerTid.prioritySend(Control.FAIL);
//            }
    }

    scope(success) {
        writefln("In success of soc. th., flag %s:", exit_flag);
//            if ( exit_flag ) {
        ownerTid.prioritySend(Control.END);
//            }
    }

    auto lso = ListenerSocket(port, address, thisTid);
    void delegate() ls;
    ls.funcptr = &ListenerSocket.run;
    ls.ptr = &lso;
    auto listener_socket_thread = new Thread( ls ).start();

    scope(exit) {
        if ( listener_socket_thread !is null ) {
            lso.close;
            writefln("Kill listener socket. %d", port);
            //BUG: Needs to ping the socket to wake-up the timeout again for making the loop run to exit.
//            if ( ldo.active ) {
            auto ping=new TcpSocket(new InternetAddress(address, port));
//                receive( &handleClient);
//                Thread.sleep(500.msecs);
            // run_listener = false;
            writeln("After tcpsocket");
            writefln("run_listerner %s", lso.active);
//            }
            lso.stop;


            listener_socket_thread.join();
            ping.close;
//            Thread.sleep(2.seconds);
            writefln("Thread joined %d", port);
        }

    }




    try{
        //enum max_connections = 3;
        // Socket[uint] clients;
        // auto lso = ListenerSocket(port, address, thisTid);

//        shared(bool) run_listener = true;
        // uint client_counter;
        // void handleClient (immutable Socket client) {
        //     client_counter++;
        //     clients[client_counter] = cast(Socket)client;
        // }

        bool runBackend = true;
        void handleState (Control ts) {
            with(Control) switch(ts) {
                case STOP:
                    writefln("Kill socket thread. %d", port);
                    runBackend = false;
                    break;
                case LIVE:
                    runBackend = true;
                    break;
                default:
                    writefln("Bad Control command %s", ts);
                    runBackend = false;
                }
        }

//        handleState(thread_state);



        // enum socket_buffer_size = 0x1000;
        // enum socket_max_data_size = 0x10000;


        //Start backend socket, send BSON through the socket
        // if(runBackend) {




        // version(none)
        //     void sendBytes(immutable(ubyte)[] data) {
        //     foreach ( key, client; clients) {
        //         if ( client.isAlive) {
        //             if(data.length > socket_max_data_size) {
        //                 throw new SocketMaxDataSize(format("The maximum data size to send over a socket is %sbytes.", socket_max_data_size));
        //             }
        //             auto buffer_length = new ubyte[uint.sizeof];
        //             immutable data_length = cast(uint)data.length;
        //             // writeln("Bytes to send: ", data_length);
        //             buffer_length.write(data_length, 0);

        //             client.send(buffer_length);

        //             for (uint start_pos = 0; start_pos < data_length; start_pos += socket_buffer_size) {
        //                 immutable end_pos = (start_pos+socket_buffer_size < data_length) ? start_pos+socket_buffer_size : data_length;
        //                 client.send(data[start_pos..end_pos]);
        //             }
        //         }
        //         else {
        //             client.close;
        //             clients.remove(key);
        //         }
        //     }
        // }


        while(runBackend) {
            receiveTimeout(500.msecs,
                //Control the thread
                &handleState,

                // &handleClient,

                // (string msg) {
                //     writeln("The backend socket thread received the message and sends to client socket: " , msg);
                //     if ( lso.active ) {
                //         lso.sendBytes(generateHoleThroughBsonMsg(msg));
                //     }
                // },

                (immutable(ubyte)[] bson_bytes) {
                    lso.sendBytes(bson_bytes);
                },
                (immutable(Throwable) t) {
                    writefln("Throwable -------------------- %d", port);
                    writeln(t);
                    runBackend=false;
                }
                );
        }
    }
    catch(Throwable t) {
        writefln(":::::::::: Throwable %d",port);
        writeln(t);
    }
}
