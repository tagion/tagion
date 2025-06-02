module tagion.services.socket_nodeinterface;

@safe:

import core.time;
import core.sys.posix.poll;

import std.array;
import std.exception;
import std.format;

import tagion.crypto.Types;
import tagion.communication.HiRPC;
import tagion.communication.Envelope;
import tagion.script.methods;
// we use our own socket wrapper based on a struct so we can easily pass it to a different concurrency task
import tagion.network.socket;
import tagion.logger;
import tagion.network.ReceiveBuffer;
import tagion.actor : ActorHandle, run, Msg, thisActor;
import tagion.gossip.AddressBook;
import tagion.services.messages;
import tagion.services.tasknames;
import tagion.utils.pretend_safe_concurrency;
import tagion.hibon.Document;

alias PollEvent = Msg!"poll_event";
alias RmPoll = Msg!"rm_poll";
alias AddPoll = Msg!"add_poll";

enum POLL_TIMEOUT_MS = 100;

@trusted
void event_listener(string task_name) {
    pollfd[int] poll_fds;
    Tid[int] listeners;

    void add_poll(AddPoll, Tid tid, pollfd poll_event) {
        log("Add poll object %s", poll_event);
        poll_fds[poll_event.fd] = poll_event;
        listeners[poll_event.fd] = tid;
    }

    void rm_poll(RmPoll, int fd) {
        log("Rm poll object %s", fd);
        poll_fds.remove(fd);
        listeners.remove(fd);
    }

    thisActor.task_name = task_name;

    while(!thisActor.stop) {
        try {
            bool received;
            do {
                received = receiveTimeout(Duration.zero, &add_poll, &rm_poll);
            } while(received);

            pollfd[] poll_fds_arr = poll_fds.byValue.array;
            int ready = poll(&poll_fds_arr[0], poll_fds_arr.length, POLL_TIMEOUT_MS);
            if(ready == -1) continue;

            foreach(fd; poll_fds_arr) {
                if(fd.revents == 0) {
                    continue;
                }
                log("Event %s", fd);
                poll_fds[fd.fd].events = 0;
                Tid listener_tid = listeners[fd.fd];
                send(listener_tid, PollEvent(), fd);
            }
        } catch(Exception e) {
            log.fatal(e);
        }
    }
}

struct NodeInterface { 
    shared(AddressBook) address_book;
    string listen_address;
    Tid event_listener_tid;
    Socket listener_sock;
    TaskNames tn;

    this(string address, shared(AddressBook) address_book, TaskNames task_names) {
        this.listen_address = address;
        this.address_book = address_book;
        this.tn = task_names;
    }

    void accept_conn(PollEvent, pollfd fd) {
        // check poll event is POLLIN
        if(!(fd.revents & POLLIN)) {
            return;
        }
        log("new incoming connection");
        Socket new_sock = listener_sock.accept;
        pollfd listener_poll = pollfd(listener_sock.handle, POLLIN, 0);
        event_listener_tid.send(AddPoll(), thisTid, listener_poll);
        Tid conn_tid = spawn(&connection, event_listener_tid, tn, new_sock, CONNECTION_STATE.receive);
    }

    // Initial send before a connection has been established with a peer
    void node_send(NodeSend req, Pubkey channel, Document doc) {
        Socket sock = Socket(AddressFamily.UNIX, SocketType.STREAM);
        string address = address_book[channel].get().address;
        sock.connect(address);

        Tid conn_tid = spawn(&connection, event_listener_tid, tn, sock, CONNECTION_STATE.send);

        conn_tid.send(req, channel, doc);
    }

    void wave_send(WavefrontReq req, Pubkey channel, Document doc) {
        try {
            Socket sock = Socket(AddressFamily.UNIX, SocketType.STREAM);
            string address = address_book[channel].get().address;
            log("opening connection to %s", address);
            sock.connect(address);

            Tid conn_tid = spawn(&connection, event_listener_tid, tn, sock, CONNECTION_STATE.send);

            conn_tid.send(req, channel, doc);
        }
        catch (Exception e) {
            log.error(e.msg);
        }

    }

    void task() @trusted {
        import std.concurrency : FiberScheduler;
        auto scheduler = new FiberScheduler;
        event_listener_tid = spawn(&event_listener, tn.event_listener);
        scheduler.start({
                listener_sock = Socket(AddressFamily.UNIX, SocketType.STREAM);
                listener_sock.bind(listen_address);
                listener_sock.listen(2);
                log("listening on %s", listen_address);
                listener_sock.blocking = false;
                pollfd listener_poll = pollfd(listener_sock.handle, POLLIN, 0);
                event_listener_tid.send(AddPoll(), thisTid, listener_poll);
                run(&node_send, &wave_send, &accept_conn);
            }
        );
    }
}

enum CONNECTION_STATE {
    send,
    receive,
}


void connection(Tid event_listener_tid, TaskNames tn , Socket sock, CONNECTION_STATE state) {
    scope(exit) event_listener_tid.send(RmPoll(), sock.handle);
    scope ubyte[0x8000] recv_frame; // 32kb
    enum MAX_RECEIVE_SIZE = 1_000_000; // 1MB

    log.task_name = format("%s(%s)", tn.node_interface, sock.handle);
    log("hello");

    ActorHandle task_handle;

    while(true) {
        final switch (state) {
            case state.send:
                state = CONNECTION_STATE.receive;
                immutable(ubyte)[] send_buffer;
                receive(
                    (NodeSend _, Pubkey channel, Document doc) { send_buffer = doc.serialize; },
                    (dartHiRPCRR.Response _, Document doc) { send_buffer = doc.serialize;  },
                    (readRecorderRR.Response _, Document doc) { send_buffer = doc.serialize; },
                    (dartHiRPCRR.Error _, string msg) { /* err */ },
                    (readRecorderRR.Error _, string msg) { /* err */ },
                    (Variant v) @trusted { throw new Exception(format("Unknown message %s", v)); },
                );
                if(send_buffer.empty) {
                    // err
                    return;
                }
                // 1. try to send
                size_t rc = sock.send(send_buffer);
                log("sent %s bytes", rc);
                // // 2. if eagain add event listener
                // if(sock.wouldHaveBlocked()) {
                //     pollfd pfd = pollfd(sock.handle, POLLOUT);
                //     event_listener_tid.send(AddPoll(), thisTid(), pfd);
                // }
                // // 3. send again
                // pollfd poll_event;
                // receive((PollEvent _, pollfd fd) { poll_event = fd; });
                // if(poll_event.revents & POLLOUT) {
                //     rc = sock.send(send_buffer);
                // }
                // 4. if not everything is sent repeat

                break;
            case state.receive:
                state = CONNECTION_STATE.send;
                ReceiveBuffer receive_buffer;
                auto result_buffer = receive_buffer(
                    (scope void[] buf) {
                        ptrdiff_t rc = sock.receive(buf);
                        if(sock.wouldHaveBlocked) {
                            pollfd pfd = pollfd(sock.handle, POLLIN);
                            event_listener_tid.send(AddPoll(), thisTid(), pfd);
                            pollfd poll_event;
                            receive((PollEvent _, pollfd fd) { poll_event = fd; });
                            if(!(poll_event.revents & POLLIN)) {
                                return -1;
                            }
                            rc = sock.receive(buf);
                        }
                        return rc;
                    }
                );

                if(result_buffer.size < 0) {
                    // err
                    return;
                }
                log("recv %s bytes", result_buffer.size);

                Document doc = Document((() @trusted => receive_buffer.buffer.assumeUnique)());

                if (!doc.empty && !doc.isInorder(Document.Reserved.no)) {
                    // err
                    return;
                }

                HiRPC hirpc = HiRPC(null);
                const hirpcmsg = hirpc.receive(doc);
                // if (hirpcmsg.pubkey == this.net.pubkey) {
                //     // err
                //     return;
                // }
                // if (!hirpcmsg.isSigned) {
                //     // err
                //     return;
                // }
                if(hirpcmsg.isResponse || hirpcmsg.isError) {
                    task_handle.send(WavefrontReq(), doc);
                }

                switch(hirpcmsg.method.name) {
                    case RPCMethods.dartRead:
                    case RPCMethods.dartCheckRead:
                    case RPCMethods.dartBullseye:
                    case RPCMethods.dartRim:
                        ActorHandle(tn.dart).send(dartHiRPCRR(), doc);
                        break;
                    case RPCMethods.readRecorder:
                        ActorHandle(tn.replicator).send(readRecorderRR(), doc);
                        break;
                    case RPCMethods.wavefront:
                        task_handle = ActorHandle(tn.epoch_creator);
                        task_handle.send(WavefrontReq(), doc);
                        break;
                    default:
                        // err
                }

            break;
        }
    }

    // cleanup
}
