module test;

import hibon.HiBONBase;
//import hibon.HiBONRecord;
import hibon.BigNumber;
import hibon.utils.utc;
import hibon.utils.Stack;
import hibon.utils.RBTree;
import hibon.utils.BinBuffer;
import hibon.utils.Memory;
import Bailout=hibon.utils.Bailout;
import hibon.utils.Text;
import hibon.HiBON;
import hibon.Document;

import core.stdc.stdio;

static void callUnittest(string parent, Members...)() {
    static foreach(i, x; Members) {
        {
            enum parentDot=(parent is null)?"":parent~".";
            enum dotMember=parentDot~Members[i];
            static if(is(mixin(dotMember))) {
                enum code1="alias T1="~parentDot~Members[i]~";";
                mixin(code1);
                static if (is(T1 == struct)) {
                printf("x=%s\n", x.ptr);
                alias SubMembers=__traits(allMembers, T1);
                printf("Sub module %s\n", T1.stringof.ptr);
                static foreach(u; __traits(getUnitTests, T1)) {
                    Bailout.clear;
                    u();
                    Bailout.dump;
                }
                enum SubName=parentDot~T1.stringof;
                callUnittest!(SubName, SubMembers)();
            }
            }
        }
    }
}

static void callUnittest(alias Module)() {
    alias Members=__traits(allMembers, Module);
    static foreach(u; __traits(getUnitTests, Module)) {
        u();
    }
    callUnittest!(null, Members)();

}

version(unittest) {
    static if (!__traits(compiles, main())) {
        extern(C) int main()
        {
            printf("Main\n");
            import core.stdc.stdlib;
            callUnittest!(hibon.utils.Memory)();
            callUnittest!(hibon.utils.BinBuffer)();
            callUnittest!(hibon.utils.Text)();
            callUnittest!(hibon.utils.Stack)();

            callUnittest!(hibon.utils.RBTree)();
            callUnittest!(hibon.HiBONBase)();

            callUnittest!(hibon.Document)();
            callUnittest!(hibon.HiBON);
            printf("After\n");
            return 0;
        }
    }
}
