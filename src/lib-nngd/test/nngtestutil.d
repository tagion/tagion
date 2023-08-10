import std.stdio;
import std.format;

import nngd;


string nngtest_socket_properties(ref NNGSocket s, string tag){
    string res = "";
    res ~= format("\n----------------------- <PROPERTIES %s>\n", tag);
    res ~= format("\tversion    :\t %s\n", s.versionstring);
        if(s.errno != 0) res ~= format("\t\t== state: %d errno: %d errstr: %s\n",s.state,s.errno,nng_strerror(s.errno));
    res ~= format("\tname       :\t %s\n ", s.name);
        if(s.errno != 0) res ~= format("\t\t== state: %d errno: %d errstr: %s\n",s.state,s.errno,nng_strerror(s.errno));
    res ~= format("\traw        :\t %s\n ", s.raw);
        if(s.errno != 0) res ~= format("\t\t== state: %d errno: %d errstr: %s\n",s.state,s.errno,nng_strerror(s.errno));
    res ~= format("\tproto      :\t %s\n ", s.proto);
        if(s.errno != 0) res ~= format("\t\t== state: %d errno: %d errstr: %s\n",s.state,s.errno,nng_strerror(s.errno));
    res ~= format("\tprotoname  :\t %s\n ", s.protoname);
        if(s.errno != 0) res ~= format("\t\t== state: %d errno: %d errstr: %s\n",s.state,s.errno,nng_strerror(s.errno));
    res ~= format("\tpeer       :\t %s\n ", s.peer);
        if(s.errno != 0) res ~= format("\t\t== state: %d errno: %d errstr: %s\n",s.state,s.errno,nng_strerror(s.errno));
    res ~= format("\tpeername   :\t %s\n ", s.peername);
        if(s.errno != 0) res ~= format("\t\t== state: %d errno: %d errstr: %s\n",s.state,s.errno,nng_strerror(s.errno));
    res ~= format("\trecvbuf    :\t %s\n ", s.recvbuf);
        if(s.errno != 0) res ~= format("\t\t== state: %d errno: %d errstr: %s\n",s.state,s.errno,nng_strerror(s.errno));
    res ~= format("\tsendbuf    :\t %s\n ", s.sendbuf);
        if(s.errno != 0) res ~= format("\t\t== state: %d errno: %d errstr: %s\n",s.state,s.errno,nng_strerror(s.errno));
    res ~= format("\trecvfd     :\t %s\n ", s.recvfd);
        if(s.errno != 0) res ~= format("\t\t== state: %d errno: %d errstr: %s\n",s.state,s.errno,nng_strerror(s.errno));
    res ~= format("\tsendfd     :\t %s\n ", s.sendfd);
        if(s.errno != 0) res ~= format("\t\t== state: %d errno: %d errstr: %s\n",s.state,s.errno,nng_strerror(s.errno));
    res ~= format("\trecvtimeout:\t %s\n ", s.recvtimeout);
        if(s.errno != 0) res ~= format("\t\t== state: %d errno: %d errstr: %s\n",s.state,s.errno,nng_strerror(s.errno));
    res ~= format("\tsendtimeout:\t %s\n ", s.sendtimeout);
        if(s.errno != 0) res ~= format("\t\t== state: %d errno: %d errstr: %s\n",s.state,s.errno,nng_strerror(s.errno));
    res ~= format("\tlocaddr    :\t %s\n ", toString(s.locaddr));
        if(s.errno != 0) res ~= format("\t\t== state: %d errno: %d errstr: %s\n",s.state,s.errno,nng_strerror(s.errno));
    res ~= format("\tremaddr    :\t %s\n ", toString(s.remaddr));
        if(s.errno != 0) res ~= format("\t\t== state: %d errno: %d errstr: %s\n",s.state,s.errno,nng_strerror(s.errno));
    res ~= format("\turl        :\t %s\n ", s.url);
        if(s.errno != 0) res ~= format("\t\t== state: %d errno: %d errstr: %s\n",s.state,s.errno,nng_strerror(s.errno));
    res ~= format("\tmaxttl     :\t %s\n ", s.maxttl);
        if(s.errno != 0) res ~= format("\t\t== state: %d errno: %d errstr: %s\n",s.state,s.errno,nng_strerror(s.errno));
    res ~= format("\trecvmaxsz  :\t %s\n ", s.recvmaxsz);
        if(s.errno != 0) res ~= format("\t\t== state: %d errno: %d errstr: %s\n",s.state,s.errno,nng_strerror(s.errno));
    res ~= format("\treconnmint :\t %s\n ", s.reconnmint);
        if(s.errno != 0) res ~= format("\t\t== state: %d errno: %d errstr: %s\n",s.state,s.errno,nng_strerror(s.errno));
    res ~= format("\treconnmaxt :\t %s\n ", s.reconnmaxt);
        if(s.errno != 0) res ~= format("\t\t== state: %d errno: %d errstr: %s\n",s.state,s.errno,nng_strerror(s.errno));
    res ~= format("\n----------------------- </PROPERTIES %s>\n", tag);
    return res;
}
