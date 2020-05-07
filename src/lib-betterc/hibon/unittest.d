
import hibon.HiBONBase;
import hibon.HiBONRecord;
import hibon.BigNumber;
import hibon.utils.utc;
import hibon.utils.Queue;
import hibon.utils.RBTree;
import hibon.utils.BinBuffer;
import hibon.utils.Memory;
import hibon.utils.Bailout;
import hibon.utils.Text;
import hibon.HiBON;
import hibon.Document;

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
