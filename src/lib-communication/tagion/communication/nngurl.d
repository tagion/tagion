module tagion.communication.nngurl;

import std.string;

import libnng;

private extern(C) {
int nng_url_parse(nng_url **urlp, const char *str);
void nng_url_free(nng_url *url);
struct nng_url {
    char *u_rawurl;
    char *u_scheme;
    char *u_userinfo;
    char *u_host;
    char *u_hostname;
    char *u_port;
    char *u_path;
    char *u_query;
    char *u_fragment;
    char *u_requri;
}
}

struct NNGURL {
    string rawurl;
    string scheme;
    string userinfo;
    string host;
    string hostname;
    string port;
    string path;
    string query;
    string fragment;
    string requri;

    @disable this(this);

    protected nng_url* _nng_url;
    this(const(char)[] url_str) @trusted {
        _nng_url = new nng_url;

        int rc = nng_url_parse(&_nng_url, toStringz(url_str));
        if(rc != nng_errno.NNG_OK) {
            throw new Exception(nng_errstr(rc));
        }

        rawurl = cast(immutable)fromStringz(_nng_url.u_rawurl);
        scheme = cast(immutable)fromStringz(_nng_url.u_scheme).idup;
        userinfo = cast(immutable)fromStringz(_nng_url.u_userinfo);
        host = cast(immutable)fromStringz(_nng_url.u_host);
        hostname = cast(immutable)fromStringz(_nng_url.u_hostname);
        port = cast(immutable)fromStringz(_nng_url.u_port);
        path = cast(immutable)fromStringz(_nng_url.u_path);
        query = cast(immutable)fromStringz(_nng_url.u_query);
        fragment = cast(immutable)fromStringz(_nng_url.u_fragment);
        requri = cast(immutable)fromStringz(_nng_url.u_requri);
    }

    ~this() {
        if(_nng_url !is null) {
            nng_url_free(_nng_url);
        }
    }
}

unittest {
    import std.exception;
    auto nn = NNGURL("tcp://0.0.0.0:473");
    assert(nn.scheme == "tcp");
    assert(nn.hostname == "0.0.0.0", nn.hostname);
    assert(nn.port == "473");
    assertThrown(NNGURL("blbalablbadurl"));
}
