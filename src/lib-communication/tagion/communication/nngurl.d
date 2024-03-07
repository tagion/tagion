module tagion.communication.nngurl;

import std.string;
import std.conv;

import libnng;

private extern(C) {
int nng_url_parse(nng_url **urlp, const char *str) pure;
void nng_url_free(nng_url *url) pure;
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
    int port;
    string path;
    string query;
    string fragment;
    string requri;

    this(const(char)[] url_str) @trusted {
        auto _nng_url = new nng_url;

        int rc = nng_url_parse(&_nng_url, toStringz(url_str));
        if(rc != nng_errno.NNG_OK) {
            throw new Exception(nng_errstr(rc));
        }
        scope(exit) {
            nng_url_free(_nng_url);
        }

        rawurl = fromStringz(_nng_url.u_rawurl).idup;
        scheme = fromStringz(_nng_url.u_scheme).idup;
        userinfo = fromStringz(_nng_url.u_userinfo).idup;
        host = fromStringz(_nng_url.u_host).idup;
        hostname = fromStringz(_nng_url.u_hostname).idup;
        const _port = fromStringz(_nng_url.u_port);
        port = _port.empty ? -1 : _port.to!int;
        path = fromStringz(_nng_url.u_path).idup;
        query = fromStringz(_nng_url.u_query).idup;
        fragment = fromStringz(_nng_url.u_fragment).idup;
        requri = fromStringz(_nng_url.u_requri).idup;
    }
}

unittest {
    import std.exception;
    NNGURL("abstract://EPOCURL");
    assertThrown(NNGURL("blbalablbadurl"));
}
