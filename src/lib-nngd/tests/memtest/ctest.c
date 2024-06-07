#include <stdio.h>
#include <stdlib.h>

#include "cserver.h"
#include "cfunctions.h"

void
handler(cdata* d)
{
    nng_url *u;
    
    int rc = nng_url_parse(&u, d->uri);

    if(rc != 0){
        perror("Error parsing\n");
        exit(-1);
    }

    printf("URI handled: %s Path found: %s\n", d->uri, u->u_path);

    nng_url_free(u);
}


int
main()
{
    printf("Begin...\n");

    csrv *s;
    
    cserver_init( &s, "myserver", &handler );
    
    printf("Start process...\n");

    cserver_start(s);

    printf("Bye!\n");
    return 0;
}

