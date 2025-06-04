module tagion.network.address;

@safe:

import core.sys.posix.sys.socket;
import core.sys.posix.sys.un;

import std.traits;
import std.conv;
import std.format;
import std.algorithm;
import tagion.errors.tagionexceptions;
import std.socket : AddressFamily, Address;
static import std.socket;

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

struct NNGAddress {
    string address;

    Schemes scheme() const pure {
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

    AddressFamily domain() pure {
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

    string host() const pure {
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

    ushort port() const pure {
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

    Address toSockAddr() const {
        switch(scheme) {
            case Schemes.abstract_:
                string host_str = '\0' ~ host;
                auto un = new std.socket.UnixAddress(host_str);
                return un;
            case Schemes.ipc:
                auto un = new std.socket.UnixAddress(host);
                return un;
            case Schemes.tcp:
                auto in4 = new std.socket.InternetAddress(host, port);
                return in4;
            case Schemes.tcp6:
                auto in6 = new std.socket.Internet6Address(host, port);
                return in6;
            default:
                check(false, format("No impl for converting type %s to sockaddr", scheme));
        }
        assert(0, "Unreachable!");
    }
}

unittest {
    import std.exception;
    {
    const abs_addr = NNGAddress("abstract://interface_addr12345");
    assert(abs_addr.scheme == Schemes.abstract_);
    assert(abs_addr.host == "interface_addr12345", abs_addr.host);
    assertThrown(abs_addr.port);
    Address addr = abs_addr.toSockAddr();
    assert(addr.nameLen > 0);
    assert(addr.name.sa_family == AddressFamily.UNIX);
    }
    {
    const ipc_addr = NNGAddress("ipc:///mysocket.local");
    assert(ipc_addr.scheme == Schemes.ipc);
    assert(ipc_addr.host == "/mysocket.local", ipc_addr.host);
    assertThrown(ipc_addr.port);
    Address addr = ipc_addr.toSockAddr();
    assert(addr.nameLen > 0);
    assert(addr.name.sa_family == AddressFamily.UNIX);
    }
    {
    const ip4_addr = NNGAddress("tcp://localhost:9000");
    assert(ip4_addr.scheme == Schemes.tcp);
    assert(ip4_addr.host == "localhost", ip4_addr.host);
    assert(ip4_addr.port == 9000);
    Address addr = ip4_addr.toSockAddr();
    assert(addr.nameLen > 0);
    assert(addr.name.sa_family == AddressFamily.INET);
    }
    {
    const ip6_addr = NNGAddress("tcp6://[::1]:9000");
    assert(ip6_addr.scheme == Schemes.tcp6);
    // Fix parse ip6 addr
    assert(ip6_addr.host == "[::1]", ip6_addr.host);
    assert(ip6_addr.port == 9000);
    // Address addr = ip6_addr.toSockAddr();
    // assert(addr.nameLen > 0);
    // assert(addr.name.sa_family == AddressFamily.INET6);
    }
}
