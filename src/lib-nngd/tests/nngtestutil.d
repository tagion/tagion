import std.stdio;
import std.format;
import std.array;
import std.datetime.systime;
import std.process: environment;
import nngd;


string nngtest_socket_properties(ref NNGSocket s, string tag){
    string res;
    res ~= format("\n----------------------- <PROPERTIES %s>\n", tag);
    res ~= format("\tversion    :\t %s\n", s.versionstring);
        if(s.errno != 0) res ~= format("\t\t== state: %d errno: %d errstr: %s\n",s.state,s.errno,s.errno);
    res ~= format("\tname       :\t %s\n ", s.name);
        if(s.errno != 0) res ~= format("\t\t== state: %d errno: %d errstr: %s\n",s.state,s.errno,s.errno);
    res ~= format("\traw        :\t %s\n ", s.raw);
        if(s.errno != 0) res ~= format("\t\t== state: %d errno: %d errstr: %s\n",s.state,s.errno,s.errno);
    res ~= format("\tproto      :\t %s\n ", s.proto);
        if(s.errno != 0) res ~= format("\t\t== state: %d errno: %d errstr: %s\n",s.state,s.errno,s.errno);
    res ~= format("\tprotoname  :\t %s\n ", s.protoname);
        if(s.errno != 0) res ~= format("\t\t== state: %d errno: %d errstr: %s\n",s.state,s.errno,s.errno);
    res ~= format("\tpeer       :\t %s\n ", s.peer);
        if(s.errno != 0) res ~= format("\t\t== state: %d errno: %d errstr: %s\n",s.state,s.errno,s.errno);
    res ~= format("\tpeername   :\t %s\n ", s.peername);
        if(s.errno != 0) res ~= format("\t\t== state: %d errno: %d errstr: %s\n",s.state,s.errno,s.errno);
    res ~= format("\trecvbuf    :\t %s\n ", s.recvbuf);
        if(s.errno != 0) res ~= format("\t\t== state: %d errno: %d errstr: %s\n",s.state,s.errno,s.errno);
    res ~= format("\tsendbuf    :\t %s\n ", s.sendbuf);
        if(s.errno != 0) res ~= format("\t\t== state: %d errno: %d errstr: %s\n",s.state,s.errno,s.errno);
    res ~= format("\trecvfd     :\t %s\n ", s.recvfd);
        if(s.errno != 0) res ~= format("\t\t== state: %d errno: %d errstr: %s\n",s.state,s.errno,s.errno);
    res ~= format("\tsendfd     :\t %s\n ", s.sendfd);
        if(s.errno != 0) res ~= format("\t\t== state: %d errno: %d errstr: %s\n",s.state,s.errno,s.errno);
    res ~= format("\trecvtimeout:\t %s\n ", s.recvtimeout);
        if(s.errno != 0) res ~= format("\t\t== state: %d errno: %d errstr: %s\n",s.state,s.errno,s.errno);
    res ~= format("\tsendtimeout:\t %s\n ", s.sendtimeout);
        if(s.errno != 0) res ~= format("\t\t== state: %d errno: %d errstr: %s\n",s.state,s.errno,s.errno);
    res ~= format("\tlocaddr    :\t %s\n ", toString(s.locaddr));
        if(s.errno != 0) res ~= format("\t\t== state: %d errno: %d errstr: %s\n",s.state,s.errno,s.errno);
    res ~= format("\tremaddr    :\t %s\n ", toString(s.remaddr));
        if(s.errno != 0) res ~= format("\t\t== state: %d errno: %d errstr: %s\n",s.state,s.errno,s.errno);
    res ~= format("\turl        :\t %s\n ", s.url);
        if(s.errno != 0) res ~= format("\t\t== state: %d errno: %d errstr: %s\n",s.state,s.errno,s.errno);
    res ~= format("\tmaxttl     :\t %s\n ", s.maxttl);
        if(s.errno != 0) res ~= format("\t\t== state: %d errno: %d errstr: %s\n",s.state,s.errno,s.errno);
    res ~= format("\trecvmaxsz  :\t %s\n ", s.recvmaxsz);
        if(s.errno != 0) res ~= format("\t\t== state: %d errno: %d errstr: %s\n",s.state,s.errno,s.errno);
    res ~= format("\treconnmint :\t %s\n ", s.reconnmint);
        if(s.errno != 0) res ~= format("\t\t== state: %d errno: %d errstr: %s\n",s.state,s.errno,s.errno);
    res ~= format("\treconnmaxt :\t %s\n ", s.reconnmaxt);
        if(s.errno != 0) res ~= format("\t\t== state: %d errno: %d errstr: %s\n",s.state,s.errno,s.errno);
    res ~= format("\n----------------------- </PROPERTIES %s>\n", tag);
    return res;
}

static double timestamp()
{
    auto ts = Clock.currTime().toTimeSpec();
    return ts.tv_sec + ts.tv_nsec/1e9;
}

static void log(A...)(string fmt, A a){
    auto _debug = environment.get("NNG_DEBUG");
    if(_debug is null || _debug != "TRUE") return;
    writefln("%.6f "~fmt,timestamp,a);
    stdout.flush();
}

shared string[] _errors;

static void error(A...)(string fmt, A a){
    _errors ~= format(fmt, a);
    auto _debug = environment.get("NNG_DEBUG");
    if(_debug is null || _debug != "TRUE") return;
    writefln("%.6f "~fmt,timestamp,a);
    stdout.flush();
}

static int populate_state( int testno, string tag ){
    auto _res = format("\n#TEST%02d - %s - ",testno,tag);
    auto _err = 0;
    if(_errors.empty()){
        _res ~= "PASSED\n";
    }else{
        _res ~= "ERROR\n" ~ _errors.join("\n");
        _err = 1;
    }
    writefln(_res);
    writefln("\n");
    return _err;
}

static string dump_exception_recursive(Throwable ex, string tag = "") {
    string[] res; 
    res ~= format("\r\nException caught %s : %s\r\n", Clock.currTime().toSimpleString(), tag);
    foreach (t; ex) {
        res ~= format("%s [%d]: %s \r\n%s\r\n", t.file, t.line, t.message(), t.info);
    }
    return join(res, "\r\n");
}    
