module test;

import hibon.HiBONBase;
//import hibon.HiBONRecord;
import hibon.BigNumber;
import hibon.utils.utc;
import hibon.utils.Stack;
import hibon.utils.RBTree;
import hibon.utils.BinBuffer;
import hibon.utils.Memory;
import hibon.utils.Bailout;
import hibon.utils.Text;
//import hibon.HiBON;
//import hibon.Document;

import core.stdc.stdio;

static void callUnittest(string parent, Members...)() {
    pragma(msg, "CALLED:",__FUNCTION__);
    pragma(msg, Members);
    static foreach(i, x; Members) {
        {
            pragma(msg, Members[i]);
            enum parentDot=(parent is null)?"":parent~".";
            pragma(msg, "parentDot=", parentDot);
            enum dotMember=parentDot~Members[i];
            pragma(msg , dotMember, " is type ", is(mixin(dotMember)));
            static if(is(mixin(dotMember))) {
                enum code1="alias T1="~parentDot~Members[i]~";";
                pragma(msg, "code1=", code1);
                mixin(code1);
                pragma(msg, Members[i], " : ", is(T1 == struct));
                static if (is(T1 == struct)) {
                printf("x=%s\n", x.ptr);
                alias SubMembers=__traits(allMembers, T1);
                printf("Sub module %s\n", T1.stringof.ptr);
                //    pragma(msg, T1, " members ", __traits(allMembers, T1));
                pragma(msg, T1, " unttests ", __traits(getUnitTests, T1));
                static foreach(u; __traits(getUnitTests, T1)) {
                    {
                        enum name=u.stringof;
                        printf("%s\n", name.ptr);
                    }
                    u();
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
    pragma(msg, "Members=", Members);
    pragma(msg, __FUNCTION__, " unttests ", __traits(getUnitTests, Module));
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
            printf("After\n");

            // callUnittest!(hibon.utils.Stack)();
            // callUnittest!(hibon.utils.RBTree)();
            return 0;
        }
    }
}
