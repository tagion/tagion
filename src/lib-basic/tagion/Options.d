module tagion.Options;


struct Options {
    uint node_number;
    uint seed;
    uint delay;
    uint timeout;
    uint nodes;
    uint loops;
    uint port;
    string url;
}

__gshared static Options options;
