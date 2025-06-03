module tagion.network.address;

@safe:

import core.sys.posix.sys.socket;
import core.sys.posix.sys.un;

import std.traits;
import std.conv;
import std.format;
import std.algorithm;
import tagion.errors.tagionexceptions;
import std.socket : AddressFamily, InternetAddress;

class AddressException : TagionException {
    @safe pure nothrow this(string msg, string file = __FILE__, size_t line = __LINE__)
    {
        super(msg, file, line);
    }
}

private alias check = Check!AddressException;

enum Schemes {
    unknown = "",
    ipc = "ipc", // nng format for ipc socket address
    abstract_ = "abstract", // nng linux abstract socket
    tcp = "tcp", // nng ip4 address
    tcp6 = "tcp6", // nng ip6 address
}

struct Sockaddr {
    const socklen_t length;
    const sockaddr* addr;
}

struct Address {
    string address;

    Schemes scheme() const {
        size_t idx = address.countUntil(':');
        if(idx <= 0) {
            return Schemes.unknown;
        }
        string scheme_str = address[0..idx];
        switch(scheme_str) {
            static foreach(S; EnumMembers!Schemes) {
                case S:
                    return S;
            }
            default:
                return Schemes.unknown;
        }
    }

    AddressFamily domain() {
        final switch(scheme) {
            case Schemes.ipc:
            case Schemes.abstract_:
                return AddressFamily.UNIX;
            case Schemes.tcp:
                return AddressFamily.INET;
            case Schemes.tcp6:
                return AddressFamily.INET6;
            case Schemes.unknown:
                return AddressFamily.UNSPEC;
        }
    }

    string host() const {
        size_t idx = address.countUntil(':');
        if(idx <= 0) {
            return Schemes.unknown;
        }
        string host;
        idx += 3; // skip '//'
        if(address.length > idx) {
            host = address[idx..$];
            switch(scheme) {
                case Schemes.tcp:
                case Schemes.tcp6:
                    size_t port_sep;
                    foreach_reverse(i, c; host) {
                        if(c == ':') {
                            port_sep = i;
                            break;
                        }
                    }
                    check(port_sep != 0, format("address missing port %s", address));
                    host = host[0..port_sep];
                break;
                default:
                    break;
            }
        }
        return host;
    }

    ushort port() const {
        size_t port_sep;
        foreach_reverse(i, c; address) {
            if(c == ':') {
                port_sep = i;
                break;
            }
        }
        if(port_sep == 0) {
            return 0;
        }
        return address[port_sep + 1..$].to!ushort;
    }

    @trusted
    socklen_t toSockAddr(scope sockaddr* sockaddr_) const {
        assert(sockaddr_ !is null);
        switch(scheme) {
            case Schemes.abstract_:
                sockaddr_un* sun = cast(sockaddr_un*)sockaddr_;
                sun.sun_family = AddressFamily.UNIX;
                // check if the abstract address can fit in in a un addr pluss and extra '\0' byte
                check(host.length < sockaddr_un.sun_path.length, "address to big for sun addr");
                sun.sun_path[1..host.length+1] = (cast(byte[])host)[];
                assert(&sun.sun_path[1] !is cast(void*)&host[0]);
                return cast(socklen_t)(sockaddr_un.sun_path.offsetof + host.length + 1);
            case Schemes.ipc:
                sockaddr_un* sun = cast(sockaddr_un*)sockaddr_;
                check(host.length <= sockaddr_un.sun_path.length, "address to big for sun addr");
                sun.sun_path = '\0';
                sun.sun_path.ptr[0..host.length] = (cast(byte[])host)[];
                assert(&sun.sun_path[0] !is cast(void*)&host[0]);
                return cast(socklen_t)(sockaddr_un.sun_path.offsetof + host.length);
            default:
                assert(0, format("No impl for converting type %s to sockaddr", scheme));
        }
        assert(0, "TODO!");
    }
}

unittest {
    import std.exception;
    {
    const abs_addr = Address("abstract://mysocket:local");
    assert(abs_addr.scheme == Schemes.abstract_);
    assert(abs_addr.host == "mysocket:local", abs_addr.host);
    assertThrown(abs_addr.port);
    scope sockaddr addr;
    assertNotThrown(abs_addr.toSockAddr(&addr));
    }
    {
    Address ipc_addr = Address("ipc:///mysocket.local");
    assert(ipc_addr.scheme == Schemes.ipc);
    assert(ipc_addr.host == "/mysocket.local", ipc_addr.host);
    assertThrown(ipc_addr.port);
    scope sockaddr addr;
    assertNotThrown(ipc_addr.toSockAddr(&addr));
    }
    {
    const ip4_addr = Address("tcp://localhost:9000");
    assert(ip4_addr.scheme == Schemes.tcp);
    assert(ip4_addr.host == "localhost", ip4_addr.host);
    assert(ip4_addr.port == 9000);
    }
    {
    const ip6_addr = Address("tcp6://[::1]:9000");
    assert(ip6_addr.scheme == Schemes.tcp6);
    assert(ip6_addr.host == "[::1]", ip6_addr.host);
    assert(ip6_addr.port == 9000);
    }
}
