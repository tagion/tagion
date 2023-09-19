module tagion.network.ListenerSocket;

//import std.stdio;
import std.socket;
import std.concurrency;
import std.format;
import core.thread;
import std.array : join;
import std.conv : to;
import std.bitmanip : binwrite = write;

import tagion.basic.Types : Buffer;

//import tagion.services.Options: Options, setOptions, options;
import tagion.options.CommonOptions : commonOptions;
import tagion.hibon.Document;
import tagion.logger.Logger;
import tagion.network.NetworkExceptions;
import tagion.basic.tagionexceptions : TagionException;
import tagion.actor.exceptions : taskException;

struct ListenerSocket {
    immutable ushort port;
    immutable(string) address;
    immutable uint timeout;
    immutable(string) listen_task_name;
    //    immutable(Options) opts;
    protected {
        shared(bool) stop_listener;
        Tid masterTid;
        Socket[uint] clients;
    }

    this(string address, const ushort port, const uint timeout, string task_name) {
        log("Socker port %d", port);
        this.port = port;
        this.address = address;
        this.timeout = timeout;
        if (task_name) {
            masterTid = locate(task_name);
        }
        listen_task_name = [task_name, port.to!string].join("_");
    }

    void stop() {
        if (!stop_listener) {
            stop_listener = true;
            if (listerner_thread !is null) {
                //BUG: Needs to ping the socket to wake-up the timeout again for making the loop run to exit.
                auto ping = new TcpSocket(new InternetAddress(address, port));
                ping.close;
                listerner_thread.join();
            }
        }
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
        }
        do {
            locate_clients = cast(typeof(locate_clients))&_clients;
            client_counter = cast(uint)(_clients.length);
        }

        void add(ref Socket client) {
            //            writefln("locate_client is null %s", locate_clients is null);
            if (locate_clients !is null) {
                auto clients = cast(Socket[uint])*locate_clients;
                clients[client_counter] = client;
                client_counter = client_counter + 1;
            }
        }

        bool active() const pure {
            return (locate_clients !is null);
        }

        /++
         + This function send a Document directly, because the buffer length is included in the HIBON from
         + the length is not instead in front of the package
         +/
        protected void send(T)(ref Socket client, T arg) if (is(T : const(Buffer)) || is(T : const(Document)) || is(T : string)) {
            static if (is(T : const(Buffer)) || is(T : string)) {
                enum include_size = true;
                immutable data = cast(Buffer) arg;
            }
            else {
                enum include_size = false;
                immutable data = arg.data;
            }
            static if (include_size) {
                scope buffer_length = new ubyte[uint.sizeof];
                immutable data_length = cast(uint) data.length;
                buffer_length.binwrite(data_length, 0);
                client.send(buffer_length);
            }

            for (size_t start_pos = 0; start_pos < data.length; start_pos += socket_buffer_size) {
                immutable end_pos = (start_pos + socket_buffer_size < data.length) ? start_pos + socket_buffer_size : data
                    .length;
                client.send(data[start_pos .. end_pos]);
            }
        }

        void broadcast(T)(T arg) if (is(T : const(Buffer)) || is(T : const(Document)) || is(T : string)) {
            auto clients = cast(Socket[uint])*locate_clients;
            static if (is(T : const(Buffer)) || is(T : string)) {
                immutable size = arg.length;
            }
            else {
                immutable size = arg.size;
            }

            check(size <= socket_max_data_size, format("The maximum data size to send over a socket is %sbytes.", socket_max_data_size));
            foreach (socket_id, ref client; clients) {
                if (client.isAlive) {

                    send(client, arg);
                }
                else {
                    client.close;
                    clients.remove(socket_id);
                }
            }
        }

        void send(T)(const uint socket_id, T arg) if (is(T : const(Buffer)) || is(T : const(Document))) {
            auto clients = cast(Socket[uint])*locate_clients;
            auto client = clients.get(socket_id, null);
            check(clinet !is null, message("Socket with the id %d is not avaible", socket_id));
            if (client.active) {
                send(client, arg);
            }
        }

        void close(const uint socket_id) {
            if (active) {
                auto clients = cast(Socket[uint])*locate_clients;
                auto client = clients.get(socket_id, null);
                if (client) {
                    client.close;
                    clients.remove(socket_id);
                }
            }
        }

        void close() {
            if (active) {
                auto clients = cast(Socket[uint])*locate_clients;
                foreach (key, client; clients) {
                    client.close;
                }
                locate_clients = null;
            }
        }
    }

    void broadcast(T)(T arg) if (is(T : const(Buffer)) || is(T : const(Document)) || is(T : string)) {
        if (active) {
            shared_clients.broadcast(arg);
        }
    }

    void send(T)(const uint socket_id, T arg) if (is(T : const(Buffer)) || is(T : const(Document))) {
        if (active) {
            shared_clients.send(socket_id, arg);
        }
    }

    void close(const uint socket_id) {
        if (active) {
            shared_clients.close(socket_id);
        }
    }

    bool active() pure const {
        return (shared_clients !is null) && shared_clients.active;
    }

    void add(ref Socket client) {
        if (shared_clients is null) {
            clients[0] = client;
            shared_clients = new shared(SharedClients)(clients);
        }
        else {
            shared_clients.add(client);
        }
    }

    void close() {
        if (active) {
            shared_clients.close;
        }
    }

    ~this() {
        close;
    }

    protected Thread listerner_thread;
    Thread start()
    in {
        assert(listerner_thread is null, format("Listerner on port %d has already been started", port));
    }
    do {
        void delegate() listerner;
        listerner = &ListenerSocket.run;
        //        listerner.ptr = &listener_socket;
        listerner_thread = new Thread(listerner).start();
        return listerner_thread;
    }

    protected shared(SharedClients) shared_clients;

    void run() {
        log.register(listen_task_name);
        log("Listener opened");

        try {
            auto listener = new TcpSocket;
            log("Open Net %s:%s", address, port);
            auto add = new InternetAddress(address, port);
            log("before bind listener");
            listener.bind(add);
            pragma(msg, "FixMe(cbr): why is this value 10");
            log("before listener");
            listener.listen(10);
            log("before socketset");
            auto socketSet = new SocketSet(1);

            scope (exit) {
                if (listener !is null) {
                    log("Close listener socket %d", port);
                    socketSet.reset;
                    close;
                    listener.close;
                }
            }
            log("before start");
            while (!stop_listener) {
                log("inside while loop");
                socketSet.add(listener);
                pragma(msg, "FixMe(cbr): 500.msecs should be a options parameter");
                Socket.select(socketSet, null, null, timeout.msecs);
                if (socketSet.isSet(listener)) {
                    try {
                        auto client = listener.accept;
                        assert(client.isAlive);
                        assert(listener.isAlive);
                        this.add(client);
                    }
                    catch (SocketAcceptException ex) {
                        log.error("%s", ex);
                    }
                }
                socketSet.reset;
            }

        }
        catch (TagionException e) {
            log("%s", e);
            stop_listener = true;
            if (masterTid != masterTid.init) {
                masterTid.send(e.taskException);
            }
            else {
                log.warning("Exception caugth: %s", e.taskException);
            }
        }
        catch (Throwable t) {
            log("%s", t);

            stop_listener = true;
            if (masterTid != masterTid.init) {
                masterTid.send(t.taskException);
            }
            else {
                log.warning("Exception caugth: %s", t.taskException);
            }
        }
    }
}
