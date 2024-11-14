module nngd.testsuite;

import std.stdio;
import std.conv;
import std.string;
import std.algorithm;
import std.array;
import std.concurrency;
import core.thread;
import core.thread.osthread;
import core.stdc.errno;
import std.datetime.systime;
import std.exception;
import std.traits;
import std.process: environment;
import std.parallelism;

import nngd;
import nngd.nngtests;

static string dump_exception_recursive(Throwable ex, string tag = "") {
    string[] res; 
    res ~= format("\r\nException caught %s : %s\r\n", Clock.currTime().toSimpleString(), tag);
    foreach (t; ex) {
        res ~= format("%s [%d]: %s \r\n%s\r\n", t.file, t.line, t.message(), t.info);
    }
    return join(res, "\r\n");
}    

static double timestamp() {
    auto ts = Clock.currTime().toTimeSpec();
    return ts.tv_sec + ts.tv_nsec/1e9;
}

static string nngtest_socket_properties(ref NNGSocket s, string tag) {
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

static uint rot3 ( uint data ) { return ( data << 3 )&( data >> 29 ); }
static uint mkrot3 ( uint data ) { return data ^ rot3(data); }
static bool chkrot3 ( uint data, uint chk ) { return (chk ^ rot3(data)) == data; }

static string[] __errors;

static void nngtest_error(A...)(string fmt, A a) @trusted {
    __errors ~= format(fmt, a);
}

enum nngtestflag : uint {
    DEBUG   = 1,
    SETENV  = 2
}

alias runtest = string[] delegate () @trusted; 

@trusted class NNGTest {
        void log(A...)(string fmt, A a) @trusted {
            if(!(flags & nngtestflag.DEBUG) || logfile is null) return;
            logfile.writefln("%.6f "~fmt,timestamp,a);
            logfile.flush();
        }

        void error(A...)(string fmt, A a) @trusted {
            _errors ~= format(fmt, a);
            if(!(flags & nngtestflag.DEBUG) || logfile is null) return;
            logfile.writefln("%.6f "~fmt,timestamp,a);
            logfile.flush();
        }
        
        this(File* ilog = null, uint iflags = 0 ){
            this.logfile = ilog;
            this.flags = iflags;
            if( flags & nngtestflag.SETENV ){
                auto envdbg = environment.get("NNG_DEBUG");
                if(envdbg !is null && envdbg == "TRUE"){
                    flags |= nngtestflag.DEBUG;
                }
            }
        }
        
        auto self(){
            return this;
        }
        
        string[] run() @trusted { return []; }
        
        string errors() @trusted {
            return this._errors.empty() ? null :  "ERRORS: " ~  this._errors.join("\n");
        }

        string[] geterrors() @trusted { return _errors; }

        void seterrors ( string[] e ) @trusted { _errors ~= e; }

        File* getlogfile() { return this.logfile; } 

    protected:
        
        File* logfile;                
        uint flags;
        string[] _errors;
}

@trusted class NNGTestSuite : NNGTest {
    
    this(Args...)(auto ref Args args) { this.todo = -1; super(args); }
    
    string[] runonce( int testno ) {
        this.todo = testno;
        auto res = this.run();
        this.todo = -1;
        return res;
    }

    override string[] run() @trusted {
        string[] res = []; 
        mixin("auto pool = new TaskPool(4);");
        static foreach(i,t; nngd.nngtests.testlist){
           mixin(
           "if( this.todo < 0 || this.todo == "~to!string(i)~" ) { \n" ~
           "auto t"~to!string(i)~" = new "~t~"(this.logfile, this.flags); \n" ~
           "this.tests[\""~to!string(i)~"\"] = cast(NNGTest*)&(t"~to!string(i)~"); \n" ~
           "auto task"~to!string(i)~" = task(&(t"~to!string(i)~".run)); \n" ~
           "pool.put(task"~to!string(i)~"); \n" ~
           "} \n"
           );
        }
        mixin("pool.finish(true);");
        mixin("pool.stop;");
        static foreach(i,t; nngd.nngtests.testlist){
            mixin(
            "if( this.todo < 0 || this.todo == "~to!string(i)~" ) { \n" ~
            "this.seterrors(this.tests[\""~to!string(i)~"\"].geterrors()); \n" ~
            "} \n"
            );
        }
        
        if(!__errors.empty){
            this.seterrors(__errors);
        }

        return res;       
    }

    private:
        int todo;
        NNGTest*[string] tests;
}

