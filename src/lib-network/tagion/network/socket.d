/// Simple c socket wrapper using struct instead of a class
module tagion.network.socket;

import tagion.network.address;

@safe:

import std.exception;

class SocketOSException : Exception {
    int errno;
    @nogc @safe pure nothrow this(string msg, int errno, string file = __FILE__, size_t line = __LINE__)
    {
        this.errno = errno;
        super(msg, file, line);
    }
}

void socket_check(bool check, string msg = "") {
    import core.stdc.errno;
    import core.stdc.string;
    import std.string;

    if(!check) {
        throw new SocketOSException((() @trusted => fromStringz(strerror(errno)))().idup ~ msg, errno);
    }
}

public import std.socket :
    AddressFamily,
    SocketType,
    ProtocolType,
    SocketFlags;

import sys = core.sys.posix.sys.socket;
import core.stdc.errno;
import unistd = core.sys.posix.unistd;

struct Socket {
    protected int fd;
    int last_error;

    NNGAddress address;

    /* 
     * 
     * Params:
     *   address = nng style address
     */
    this(string address) {
        this.address = NNGAddress(address);
        int protocol = 0; // use default for domain
        fd = sys.socket(this.address.domain, SocketType.STREAM, protocol);
        last_error = errno;
        socket_check(fd != -1);
    }

    void blocking(bool byes) @trusted {
        import core.sys.posix.fcntl;
        int x = fcntl(fd, F_GETFL, 0);
        socket_check(-x != -1);
        if (byes)
            x &= ~O_NONBLOCK;
        else
            x |= O_NONBLOCK;
        last_error = errno;
        socket_check((fcntl(fd, F_SETFL, x) != -1));
    }

    @trusted 
    bool blocking() {
        import core.sys.posix.fcntl;
        int x = fcntl(fd, F_GETFL, 0);
        socket_check(-x != -1);
        return (x & O_NONBLOCK) == 0;
    }

    @trusted
    void bind() {
        scope sock_addr = address.toSockAddr();
        int rc = sys.bind(fd, sock_addr.name, sock_addr.nameLen);
        last_error = errno;
        socket_check(rc != -1, address.address);
    }

    @trusted
    void connect() {
        scope sock_addr = address.toSockAddr();
        int rc = sys.connect(fd, sock_addr.name, sock_addr.nameLen);
        last_error = errno;
        socket_check(rc != -1, address.address);
    }


    void listen(int backlog) {
        int rc = sys.listen(fd, backlog);
        last_error = errno;
        socket_check(rc != -1);
    }

    int handle() => fd;

    @trusted
    Socket accept() {
         int new_fd = sys.accept(fd, null, null);
         last_error = errno;
         socket_check(new_fd != -1);
         Socket new_sock;
         new_sock.fd = new_fd;
         return new_sock;
    }

    // Does not check the return code;
    @trusted nothrow
    ptrdiff_t receive(scope void[] buf) {
        SocketFlags flags;
        size_t rc = sys.recv(fd, &buf[0], buf.length, flags);
        last_error = errno;
        return rc;
    }

    // Does not check the return code;
   @trusted nothrow
   ptrdiff_t send(const void[] buf) {
       SocketFlags flags;
       size_t rc =  sys.send(fd, &buf[0], buf.length, flags);
       last_error = errno;
       return rc;
   }

    void close() {
        unistd.close(fd);
        // todo unlink UNIX file address
        last_error = errno;
    }

    bool wouldHaveBlocked() {
        return last_error == EAGAIN || last_error == EWOULDBLOCK;
    }

    int shutdown(int how = sys.SHUT_RDWR) {
        // Shutdown read/write
        int rc = sys.shutdown(fd, how);
        last_error = errno;
        return rc;
    }
}
