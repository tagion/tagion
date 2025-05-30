/// Simple c socket wrapper using struct instead of a class
module tagion.network.socket;

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

void socket_check(bool check) {
    import core.stdc.errno;
    import core.stdc.string;
    import std.string;

    if(!check) {
        throw new SocketOSException((() @trusted => fromStringz(strerror(errno)))().idup, errno);
    }
}

public import std.socket :
    AddressFamily,
    SocketType,
    ProtocolType,
    SocketFlags,
    wouldHaveBlocked;

import sys = core.sys.posix.sys.socket;
import unistd = core.sys.posix.unistd;

struct Socket {
    protected int fd;
    int last_error;

    AddressFamily domain;

    this(AddressFamily domain, SocketType type) {
        this.domain = domain;
        int protocol = 0;
        fd = sys.socket(domain, type, protocol);
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
    void bind(string address) {
        import core.sys.posix.sys.un;
        assert(domain == AddressFamily.UNIX, "Only unix socket supported currently");
        sockaddr_un sun;
        enforce(address.length < sockaddr_un.sun_path.length);
        // Socket paths can be 0 terminated, however linux abstract addresses require the proper length to be set
        sun.sun_path = '0';
        sun.sun_family = AddressFamily.UNIX;
        sun.sun_path.ptr[0..address.length] = (cast(byte[])address)[];
        assert(sun.sun_path.ptr !is cast(void*)&address[0]);
        int rc = sys.bind(fd, cast(sys.sockaddr*)&sun, cast(sys.socklen_t)(sockaddr_un.sun_path.offsetof + address.length));
        last_error = errno;
        socket_check(rc != -1);
    }

    @trusted 
    void connect(string address) {
        import core.sys.posix.sys.un;
        assert(domain == AddressFamily.UNIX, "Only unix socket supported currently");
        sockaddr_un sun;
        enforce(address.length < sockaddr_un.sun_path.length);
        // Socket paths can be 0 terminated, however linux abstract addresses require the proper length to be set
        sun.sun_path = '0';
        sun.sun_family = AddressFamily.UNIX;
        sun.sun_path.ptr[0..address.length] = (cast(byte[])address)[];
        assert(sun.sun_path.ptr !is cast(void*)&address[0]);
        int rc = sys.connect(fd, cast(sys.sockaddr*)&sun, cast(sys.socklen_t)(sockaddr_un.sun_path.offsetof + address.length));
        last_error = errno;
        socket_check(rc != -1);
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
         new_sock.domain = domain;
         return new_sock;
    }

    // Does not check the return code;
    @trusted nothrow
    ptrdiff_t receive(scope void[] buf) {
        SocketFlags flags;
        int rc = sys.recv(fd, &buf[0], buf.length, flags);
        last_error = errno;
        return rc;
    }

    // Does not check the return code;
   @trusted nothrow
   ptrdiff_t send(const void[] buf) {
       SocketFlags flags;
       int rc =  sys.send(fd, &buf[0], buf.length, flags);
       last_error = errno;
       return rc;
   }

    void close() {
        unistd.close(fd);
        last_error = errno;
    }

    bool wouldHaveBlocked() {
        return last_error == EAGAIN;
    }

    void shutdown(int how = sys.SHUT_RDWR) {
        // Shutdown read/write
        sys.shutdown(fd, how);
        last_error = errno;
    }
}
