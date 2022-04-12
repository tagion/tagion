module tagion.gossip.DartSynchInterfase;
import core.time;

import std.stdio;


static struct Defaults {
    Duration timeout = 100.seconds;
    int maxSize = 1024 * 10;
}

@safe synchronized interface TestTest {

    void print();

    // void closeListener(string pid);

    // void listen(
    //       //  HandlerCallback handler,
    //         string tid,
    //         Duration timeout = Defaults.timeout,
    //         int maxSize = Defaults.maxSize);

    // shared(RequestStreamI) connect(
    //         string addr,
    //         bool addrInfo,
    //         string[] pids...);
    
}


synchronized class Test : TestTest{
    protected shared char[] a;
    this(shared char[] a) {
        this.a=a;
    }

    void print() {
        writeln(a);
    }
}