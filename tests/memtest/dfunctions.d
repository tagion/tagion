@nogc nothrow extern (C)
{

    struct nng_url {
        char *u_rawurl;   // never NULL
        char *u_scheme;   // never NULL
        char *u_userinfo; // will be NULL if not specified
        char *u_host;     // including colon and port
        char *u_hostname; // name only, will be "" if not specified
        char *u_port;     // port, will be "" if not specified
        char *u_path;     // path, will be "" if not specified
        char *u_query;    // without '?', will be NULL if not specified
        char *u_fragment; // without '#', will be NULL if not specified
        char *u_requri;   // includes query and fragment, "" if not specified
    };
    
    int nng_url_parse(nng_url **, const char *);
    void nng_url_free(nng_url *);
    
    struct cdata {
        char* uri;
    };

    alias void function (cdata *) ccallback;

    struct csrv {
        char* name;
        ccallback cb;
    };        

    void cserver_init( csrv **, const char*, void function (cdata *) );
    void cserver_start( csrv * );

}
