module tagion.services.socket_nodeinterface;

@safe:

import core.time;
import core.sys.posix.poll;
import core.stdc.errno;

import std.array;
import std.exception;
import std.format;

import tagion.crypto.Types;
import tagion.crypto.SecureNet;
import tagion.communication.HiRPC;
import tagion.communication.Envelope;
import tagion.script.methods;
// we use our own socket wrapper based on a struct so we can easily pass it to a different concurrency task
import tagion.network.socket;
import tagion.logger;
import tagion.network.ReceiveBuffer;
import actor = tagion.actor;
import tagion.gossip.AddressBook;
import tagion.services.messages;
import tagion.services.tasknames;
import tagion.services.exception;
import tagion.services.nodeinterface;
import tagion.utils.pretend_safe_concurrency;
import tagion.hibon.Document;

alias PollEvent = actor.Msg!"poll_event";
alias RmPoll = actor.Msg!"rm_poll";
alias AddPoll = actor.Msg!"add_poll";

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

    actor.thisActor.task_name = task_name;

    actor.setState(actor.Ctrl.ALIVE);
    scope(exit) actor.setState(actor.Ctrl.END);
    while(!actor.thisActor.stop) {
        try {
            bool received;
            do {
                received = receiveTimeout(Duration.zero, &add_poll, &rm_poll);
            } while(received);

            if(poll_fds.empty) continue;

            pollfd[] poll_fds_arr = poll_fds.byValue.array;
            assert(poll_fds_arr.length <= uint.max);
            int ready = poll(&poll_fds_arr[0], cast(uint)poll_fds_arr.length, POLL_TIMEOUT_MS);
            if(ready == -1) continue;

            foreach(fd; poll_fds_arr) {
                if(fd.revents == 0) {
                    continue;
                }
                debug(nodeinterface) log("Event %s", fd);
                poll_fds[fd.fd].events = 0;
                Tid listener_tid = listeners[fd.fd];
                send(listener_tid, PollEvent(), fd);
            }
        }
        catch(PriorityMessageException) {
            log("stopping priority message");
            return;
        }
        catch(OwnerTerminated e) {
            log("Stopping");
            return;
        }
        catch(Throwable e) {
            log.fatal(e);
            return;
        }
    }
}

struct NodeInterface { 
    shared(AddressBook) address_book;
    immutable(NodeInterfaceOptions) opts;
    Tid event_listener_tid;
    Socket listener_sock;
    TaskNames tn;
    shared(SecureNet) shared_net;

    this(immutable(NodeInterfaceOptions) opts, shared(SecureNet) shared_net, shared(AddressBook) address_book, TaskNames task_names) {
        this.opts = opts;
        this.shared_net = shared_net;
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
        Tid conn_tid = spawn(&connection, event_listener_tid, opts, tn, new_sock, CONNECTION_STATE.receive);
    }

    // Initial send before a connection has been established with a peer
    void node_send(NodeSend req, Pubkey channel, Document doc) {
        string address = address_book[channel].get().address;
        Socket sock = Socket(address);
        sock.connect();

        Tid conn_tid = spawn(&connection, event_listener_tid, opts, tn, sock, CONNECTION_STATE.send);

        conn_tid.send(req, channel, doc);
    }

    void wave_send(WavefrontReq req, Pubkey channel, Document doc) {
        try {
            string address = address_book[channel].get().address;
            Socket sock = Socket(address);
            log("opening connection to %s", address);
            sock.connect();

            Tid conn_tid = spawn(&connection, event_listener_tid, opts, tn, sock, CONNECTION_STATE.send);

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
                listener_sock = Socket(opts.node_address);
                listener_sock.bind();
                listener_sock.listen(10);
                log("listening on %s", opts.node_address);
                listener_sock.blocking = false;
                pollfd listener_poll = pollfd(listener_sock.handle, POLLIN, 0);
                event_listener_tid.send(AddPoll(), thisTid, listener_poll);
                actor.waitforChildren(actor.Ctrl.ALIVE);
                actor.run(&node_send, &wave_send, &accept_conn);

                listener_sock.shutdown();
                listener_sock.close();
        });
    }
}

enum CONNECTION_STATE {
    send,
    receive,
}

@trusted
void connection(Tid event_listener_tid, immutable(NodeInterfaceOptions) opts, TaskNames tn , Socket sock, CONNECTION_STATE state) {
    try {
        connection_impl(event_listener_tid, opts, tn , sock, state);
    }
    catch(OwnerTerminated e) {
        return;
    }
    // We catch the throwable here because it's inside a seperate thread.
    catch(Throwable e) {
        log.fatal(e);
        return;
    }
}

void connection_impl(Tid event_listener_tid, immutable(NodeInterfaceOptions) opts, TaskNames tn, Socket sock, CONNECTION_STATE state) {
    // count how many times this connection has sent or received some data
    uint statistic_state_change;

    scope(exit) {
        event_listener_tid.send(RmPoll(), sock.handle);
        sock.shutdown();
        sock.close();
        log("connection closed %s", statistic_state_change);
    }

    HiRPC hirpc = HiRPC(null);

    log.task_name = format("%s(%s,%s)", tn.node_interface, thisTid, sock.handle);

    string method;

    while(true) {
        statistic_state_change++;
        final switch (state) {
        case state.send:
            log("state sending");
            state = CONNECTION_STATE.receive;
            Document send_doc;
            receive(
                (NodeSend _, Pubkey channel, Document doc) { send_doc = doc; },
                (WavefrontReq _, Pubkey channel, Document doc) { send_doc = doc; },
                (dartHiRPCRR.Response _, Document doc) { send_doc = doc;  },
                (readRecorderRR.Response _, Document doc) { send_doc = doc; },
                (dartHiRPCRR.Error _, string msg) { log(msg); },
                (readRecorderRR.Error _, string msg) { log(msg); },
                // (Variant v) @trusted { throw new Exception(format("Unknown message %s", v)); },
            );
            if(send_doc.empty) {
                debug(nodeinterface) log("empty doc");
                return;
            }

            pollfd pfd = pollfd(sock.handle, POLLOUT | POLLHUP);
            event_listener_tid.send(AddPoll(), thisTid(), pfd);
            pollfd poll_event;
            receive((PollEvent _, pollfd fd) { poll_event = fd; });
            check(cast(bool)(poll_event.revents & POLLOUT), format("event should be ready to send %s", poll_event));

            ptrdiff_t total_sent;
            ptrdiff_t sent;
            immutable(ubyte)[] serialized_doc = send_doc.serialize;
            do {
                sent = sock.send(serialized_doc[(sent == 0)? sent : sent+1 .. $]);
                // todo if the op would have blocked wait for it to be ready 
                socket_check(sent != -1, "Failed to send");
                total_sent += sent;
            } while(total_sent < serialized_doc.length);

            debug(nodeinterface) log("sent %s bytes", total_sent);
            const hirpcmsg = hirpc.receive(send_doc);

            if(hirpcmsg.isMethod) {
                method = hirpcmsg.method.name;
            }
            else {
                return; // close connection
            }

            break;
        case state.receive:
            debug(nodeinterface) log("state recv");
            state = CONNECTION_STATE.send;
            ReceiveBuffer receive_buffer;
            receive_buffer.max_size = opts.bufsize;
            // receive_buffer will keep calling the callback until the entire document has been received
            auto result_buffer = receive_buffer(
                (scope void[] buf) {
                    ptrdiff_t rc = sock.receive(buf);
                    if(sock.wouldHaveBlocked) {
                        debug(nodeinterface) log("send wouldHaveBlocked");
                        pollfd pfd = pollfd(sock.handle, POLLIN | POLLHUP);
                        event_listener_tid.send(AddPoll(), thisTid(), pfd);
                        pollfd poll_event;
                        receive((PollEvent _, pollfd fd) { poll_event = fd; });
                        check(cast(bool)(poll_event.revents & POLLIN), format("event should be ready to recv %s", poll_event));
                        rc = sock.receive(buf);
                    }
                    return rc;
                }
            );

            debug(nodeinterface) log("recv %s bytes", result_buffer.size);

            if(result_buffer.size <= 0) {
                    // err
                    return;
            }

            Document doc = Document((() @trusted => receive_buffer.buffer.assumeUnique)());

            if (!doc.empty && !doc.isInorder(Document.Reserved.no)) {
                check(false, "doc not in order");
            }
            const hirpcmsg = hirpc.receive(doc);
            // if (hirpcmsg.pubkey == this.net.pubkey) {
            //     // err
            //     return;
            // }
            // if (!hirpcmsg.isSigned) {
            //     // err
            //     return;
            // }

            if(hirpcmsg.isMethod) {
                method = hirpcmsg.method.name;
            }

            switch(method) {
                case RPCMethods.dartRead:
                case RPCMethods.dartCheckRead:
                case RPCMethods.dartBullseye:
                case RPCMethods.dartRim:
                    locate(tn.dart).send(dartHiRPCRR(), doc);
                    break;
                case RPCMethods.readRecorder:
                    locate(tn.replicator).send(readRecorderRR(), doc);
                    break;
                case RPCMethods.wavefront:
                    locate(tn.epoch_creator).send(WavefrontReq(), doc);
                    break;
                default:
                    check(false, format("Unsupported method %s", hirpcmsg.method.name));
            }

            if(hirpcmsg.isResponse || hirpcmsg.isError) {
                return; // close connection;
            }
        }
    }
}
