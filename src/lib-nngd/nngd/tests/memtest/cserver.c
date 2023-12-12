
#include <stdlib.h>
#include <string.h>

#include "cfunctions.h"
#include "cserver.h"

void
cserver_init(csrv **s, const char* name, void(*cb)(cdata*) )
{
    *s = (csrv*)calloc(sizeof(csrv),1);
    (*s)->name = (char*)calloc(strlen(name)+1,1);
    memcpy((*s)->name, name, strlen(name)+1);
    (*s)->cb = cb;
}



void 
cserver_start( csrv *s )
{   
    const char* _uri = "http://localhost/a/b/c/d/e/f";

    cdata* d;

    while(1){
        
        d = (cdata*)calloc(sizeof(cdata),1);
        
        d->uri = (char*)calloc(strlen(_uri)+1,1); 
        memcpy(d->uri, _uri, strlen(_uri)+1);

        s->cb(d);

        free(d->uri);
        free(d);

    }
}




