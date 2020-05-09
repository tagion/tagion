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
import hibon.HiBON;
import hibon.Document;

import core.stdc.stdio;

version(none)
void callUnittest(alias Members)() {
    // static foreach(m; members) {
    //     pragma(msg, typeof(m));
    // }
//    static foreach(u; __traits(getUnittests, Members)) {
//    static foreach(u; __traits(getUnittests, Members)) {
//     static foreach(u; Members) {
//         pragma(
// //        u();
//     }
//    pragma(msg, Members);
    // static foreach(u; Members) {
    //     pragma(msg, u, " ", typeof(u));
    // }
}

void callUnittest(string parent, Members...)() {
    pragma(msg, "CALLED:",__FUNCTION__);
    pragma(msg, Members);
    static foreach(i, x; Members) {
        {
            pragma(msg, Members[i]);
//                    enum code1="alias T1=hibon.HiBON."~X[i]~";";

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

void callUnittest(alias Module)() {
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
            Document doc;
//            auto hibon=HiBON();
            pragma(msg, __traits(getUnitTests, hibon.HiBONBase));
            pragma(msg, __traits(getUnitTests, hibon.HiBON.HiBON));
            pragma(msg, __traits(allMembers, hibon.Document));
            pragma(msg, "---- ---- ----");
            pragma(msg, __traits(allMembers, test));
            alias X=__traits(allMembers, hibon.HiBON);
            pragma(msg, typeof(X));
            pragma(msg, X);
            pragma(msg, X[0]);
            pragma(msg, typeof(X[0]));
            pragma(msg, X[3]);
            enum code="alias T=hibon.HiBON."~X[3]~";";
            mixin(code);
            pragma(msg, T);
            pragma(msg, is(T==struct));
//            callUnittest!(null, X)();
            callUnittest!(hibon.utils.RBTree)();
//            callUnittest!(hibon.HiBON)();
            version(none)
            static foreach(i, x; X) {
                {
                    printf("x=%s\n", x.ptr);
//                    enum code1="alias T1=hibon.HiBON."~X[i]~";";
                    enum code1="alias T1="~X[i]~";";
                    mixin(code1);
                    pragma(msg, X[i], " : ", is(T1 == struct));
                    // static if (__traits(compiles, T1 x)) {
                    //     pragma(msg, "T1=", T1);
                    // }
                    // static if (__traits(compiles, mixin(code1))) {
                    //     pragma(msg, "Compiles ", code1);
                    //     mixin(code1);
                    //     //enum _X=x;
                    // }
                }
            }
//            callUnittest!(X)();
//            hibon.HiBON.HiBON.__unittest_L574_C5();
//            allMembers
//            pragma(msg, __traits(parent, main));
            // static foreach(u; __traits(getUnitTests, __traits(parent, main))) {
            //     {
            //         enum name=u.stringof;
            //         printf("%s\n", name);
            //     }
            //     u();
            // }
            return 0;
        }
    }
}
