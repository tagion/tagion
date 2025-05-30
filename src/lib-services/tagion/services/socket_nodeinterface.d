module tagion.services.socket_nodeinterface;

@safe:

import core.time;
import core.sys.posix.poll;

import std.array;

// we use our own socket wrapper based on a struct so we can easily pass it to a different concurrency task
import tagion.network.socket;
import tagion.network.ReceiveBuffer;
import tagion.actor : ActorHandle, run, Msg, thisActor;
import tagion.crypto.Types;
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
void event_listener() {
    pollfd[int] poll_fds;
    Tid[int] listeners;

    void add_poll(AddPoll, Tid tid, pollfd poll_event) {
        poll_fds[poll_event.fd] = poll_event;
        listeners[poll_event.fd] = tid;
    }

    void rm_poll(RmPoll, int fd) {
        poll_fds.remove(fd);
        listeners.remove(fd);
    }

    while(!thisActor.stop) {
        bool received;
        do {
            receiveTimeout(Duration.zero, &add_poll, &rm_poll);
        } while(!received);

        pollfd[] poll_fds_arr = poll_fds.byValue.array;
        int ready = poll(&poll_fds_arr[0], poll_fds_arr.length, POLL_TIMEOUT_MS);
        if(ready == -1) continue;

        foreach(fd; poll_fds_arr) {
            if(fd.revents == 0) {
                continue;
            }
            poll_fds[fd.fd].events = 0;
            Tid listener_tid = listeners[fd.fd];
            send(listener_tid, PollEvent(), fd);
        }
    }
}

struct NodeInterface { 
    shared(AddressBook) address_book;
    string listen_address;
    Tid event_listener_tid;
    Socket listener_sock;
    immutable(TaskNames) tn;

    this(string address, shared(AddressBook) address_book, immutable(TaskNames) task_names) {
        this.listen_address = address;
        this.address_book = address_book;
        this.tn = task_names;
    }

    void accept_conn(PollEvent, pollfd fd) {
        // check poll event is POLLIN
        if(!(fd.revents & POLLIN)) {
            return;
        }
        Socket new_sock = listener_sock.accept;
        pollfd listener_poll = pollfd(listener_sock.handle, POLLIN, 0);
        event_listener_tid.send(AddPoll(), thisTid, listener_poll);
        Tid conn_tid = spawn(&connection, event_listener_tid, new_sock, CONNECTION_STATE.receive);
    }

    // Initial send before a connection has been established with a peer
    void node_send(NodeSend req, Pubkey channel, Document doc) {
        Socket sock = Socket(AddressFamily.UNIX, SocketType.STREAM);
        string address = address_book[channel].get().address;
        sock.connect(address);

        Tid conn_tid = spawn(&connection, event_listener_tid, sock, CONNECTION_STATE.send);

        conn_tid.send(req, channel, doc);
    }

    void task() @trusted {
        import std.concurrency : FiberScheduler;
        auto scheduler = new FiberScheduler;
        event_listener_tid = spawn(&event_listener);
        scheduler.start({
                listener_sock = Socket(AddressFamily.UNIX, SocketType.STREAM);
                listener_sock.bind(listen_address);
                listener_sock.listen(2);
                listener_sock.blocking = false;
                pollfd listener_poll = pollfd(listener_sock.handle, POLLIN, 0);
                event_listener_tid.send(AddPoll(), thisTid, listener_poll);
                run(&node_send, &accept_conn);
            }
        );
    }
}

enum CONNECTION_STATE {
    send,
    receive,
}


void connection(Tid event_listener_tid, Socket sock, CONNECTION_STATE state) {
    scope(exit) event_listener_tid.send(RmPoll(), sock.handle);
    scope ubyte[0x8000] recv_frame; // 32kb
    enum MAX_RECEIVE_SIZE = 1_000_000; // 1MB

    final switch (state) {
        case state.send:
            immutable(ubyte)[] send_buffer;
            receive((NodeSend _, Pubkey channel, Document doc) { send_buffer = doc.serialize; });
            // 1. try to send
            size_t rc = sock.send(send_buffer);
            // 2. if eagain add event listener
            if(rc == -1 && wouldHaveBlocked()) {
                pollfd pfd = pollfd(sock.handle, POLLOUT);
                event_listener_tid.send(AddPoll(), thisTid(), pfd);
            }
            // 3. send again
            pollfd poll_event;
            receive((PollEvent _, pollfd fd) { poll_event = fd; });
            if(poll_event.revents & POLLOUT) {
                rc = sock.send(send_buffer);
            }
            // 4. if not everything is sent repeat

            // 5. Set to send state
            state = CONNECTION_STATE.receive;
            break;
        case state.receive:

            ReceiveBuffer receive_buffer;
            while(true) {
                if(socket.wouldHaveBlocked) {
                    pollfd pfd = pollfd(sock.handle, pollout);
                    event_listener_tid.send(addpoll(), thistid(), pfd);
                    receive((PollEvent _, pollfd fd) { poll_event = fd; });
                    if(!(poll_event.revents & POLLIN)) {
                        // err;
                        return;
                    }
                }
                auto result = receive_buffer.next(&sock.receive);
                if(result == ReceiveBuffer.State.done) {
                    break;
                }
            }

            // 1. try to receive
            size_t len = sock.receive(recv_frame);
            // 2. if eagain add event listener
            if(len == -1 && socket.wouldHaveBlocked) {
                pollfd pfd = pollfd(sock.handle, POLLIN);
                event_listener_tid.send(addpoll(), thistid(), pfd);
                // 3. receive again
                pollfd poll_event;
                receive((PollEvent _, pollfd fd) { poll_event = fd; });
                if(poll_event.revents & POLLIN) {
                    len = sock.receive(recv_frame);
                }
            }
            long expected_msg_size = doc_full_size(recv_frame[0..len]);
            if(expected_msg_size > MAX_RECEIVE_SIZE) {
                // TODO err
            }
            // immutable(ubyte[]) recv_buffer = new immutable(ubyte)[](expected_msg_size); // allocate the total expected buffer
            immutable(ubyte)[] recv_buffer;
            recv_buffer ~= recv_frame[0..len];

            // 4. if not everything is received repeat

            // 5. Set to send state
            state = CONNECTION_STATE.send;

            // 6. Check data and send to relevant service
            Document doc;
            break;
    }

    // cleanup
}

// Same as Document.full_size.
// Created such that we don't have to cast data to immutable and create Document object in order to get pre received data;
private
size_t doc_full_size(scope const(ubyte)[] data) @nogc {
    import LEB128 = tagion.utils.LEB128;
    if (data) {
        const len = LEB128.decode!uint(data);
        return len.size + len.value;
    }
    return 0;
}
