
#include <stdlib.h>
#include <string.h>
#include <pthread.h>

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


void* cserver_worker ( void* ptr ){
    csrv *s = (csrv*)ptr;
    const char* _uri = "http://localhost/a/b/c/d/e/f";
    cdata* d;
    d = (cdata*)calloc(sizeof(cdata),1);
    d->uri = (char*)calloc(strlen(_uri)+1,1); 
    memcpy(d->uri, _uri, strlen(_uri)+1);
    s->cb(d);
    free(d->uri);
    free(d);
    return NULL;
} 

void* cserver_thread(void *ptr){
    csrv *s = (csrv*)ptr;
    pthread_t cs_theread_worker;
    while(1){
        pthread_create(&cs_theread_worker, NULL, *cserver_worker, (void *) s);
        pthread_join(cs_theread_worker,NULL);
    }
    return NULL;
}


void 
cserver_start( csrv *s )
{   
    pthread_t cs_thread_main;

    pthread_create(&cs_thread_main, NULL, *cserver_thread, (void *) s);

    pthread_join(cs_thread_main,NULL);

}




