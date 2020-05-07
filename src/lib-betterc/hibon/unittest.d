
import hibon.Queue;
import hibon.RBTree;
import hibon.HiBON;


import core.stdc.stdio;

version(unittest) {
    static if (!__traits(compiles, main())) {
        extern(C) void main()
        {
            static foreach(u; __traits(getUnitTests, __traits(parent, main)))
                u();
        }
    }
}
