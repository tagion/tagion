

typedef struct cdata {
    char* uri;
} cdata;

typedef void(*ccallback)(cdata*);

typedef struct csrv {
    char* name;
    ccallback cb;
} csrv;


void
cserver_init(csrv**, const char*, void(*cb)(cdata*) );

void 
cserver_start( csrv* );




