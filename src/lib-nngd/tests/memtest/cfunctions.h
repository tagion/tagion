
#define NNI_ARG_UNUSED(x) ((void) x)
#define NNI_ALLOC_STRUCT(s) nni_zalloc(sizeof(*s))
#define NNI_FREE_STRUCT(s) nni_free((s), sizeof(*s))

enum nng_errno_enum {
        NNG_EINTR        = 1,
        NNG_ENOMEM       = 2,
        NNG_EINVAL       = 3,
        NNG_EBUSY        = 4,
        NNG_ETIMEDOUT    = 5,
        NNG_ECONNREFUSED = 6,
        NNG_ECLOSED      = 7,
        NNG_EAGAIN       = 8,
        NNG_ENOTSUP      = 9,
        NNG_EADDRINUSE   = 10,
        NNG_ESTATE       = 11,
        NNG_ENOENT       = 12,
        NNG_EPROTO       = 13,
        NNG_EUNREACHABLE = 14,
        NNG_EADDRINVAL   = 15,
        NNG_EPERM        = 16,
        NNG_EMSGSIZE     = 17,
        NNG_ECONNABORTED = 18,
        NNG_ECONNRESET   = 19,
        NNG_ECANCELED    = 20,
        NNG_ENOFILES     = 21,
        NNG_ENOSPC       = 22,
        NNG_EEXIST       = 23,
        NNG_EREADONLY    = 24,
        NNG_EWRITEONLY   = 25,
        NNG_ECRYPTO      = 26,
        NNG_EPEERAUTH    = 27,
        NNG_ENOARG       = 28,
        NNG_EAMBIGUOUS   = 29,
        NNG_EBADTYPE     = 30,
        NNG_ECONNSHUT    = 31,
        NNG_EINTERNAL    = 1000,
        NNG_ESYSERR      = 0x10000000,
        NNG_ETRANERR     = 0x20000000
};


typedef struct nng_url {
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
} nng_url;

typedef nng_url      nni_url;

int nng_url_parse(nng_url **, const char *);

void nng_url_free(nng_url*);


