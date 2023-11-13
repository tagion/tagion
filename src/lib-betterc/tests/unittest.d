module tests;

import tagion.betterC.hibon.HiBONBase;

//import tagion.betterC.hibon.HiBONRecord;
import tagion.betterC.hibon.BigNumber;
import tagion.betterC.utils.BinBuffer;
import tagion.betterC.utils.Memory;
import tagion.betterC.utils.RBTree;
import tagion.betterC.utils.Stack;
import tagion.betterC.utils.sdt;
import tagion.betterC.utils.LEB128;
import core.stdc.stdio;
import tagion.betterC.hibon.Document;
import tagion.betterC.hibon.HiBON;
import tagion.betterC.mobile.Recycle;
import tagion.betterC.mobile.WalletWrapperApi;
import Bailout = tagion.betterC.utils.Bailout;
import tagion.betterC.utils.Text;
import tagion.betterC.wallet.KeyRecover;

static void callUnittest(string parent, Members...)() {
    static foreach (i, x; Members) {
        {
            enum parentDot = (parent is null) ? "" : parent ~ ".";
            enum dotMember = parentDot ~ Members[i];
            static if (is(mixin(dotMember))) {
                enum code1 = "alias T1=" ~ parentDot ~ Members[i] ~ ";";
                mixin(code1);
                static if (is(T1 == struct)) {
                    alias SubMembers = __traits(allMembers, T1);
                    printf("\tSub %s\n", T1.stringof.ptr);
                    static foreach (u; __traits(getUnitTests, T1)) {
                        Bailout.clear;
                        printf("\t\t%s\n", u.stringof.ptr);
                        u();
                        printf("\t\t");
                        Bailout.dump;
                    }
                    enum SubName = parentDot ~ T1.stringof;
                    callUnittest!(SubName, SubMembers)();
                }
            }
        }
    }
}

static void callUnittest(alias Module)() {
    alias Members = __traits(allMembers, Module);
    printf("%s\n", Module.stringof.ptr);
    static foreach (u; __traits(getUnitTests, Module)) {
        import Bailout = tagion.betterC.utils.Bailout;

        Bailout.clear;
        printf("\t%s\n", u.stringof.ptr);
        u();
        printf("\t");
        Bailout.dump;
    }
    callUnittest!(null, Members)();

}

//version (unittest) {
static if (!__traits(compiles, main())) {
    extern (C) int main() {
        printf("Unittest\n");
        import core.stdc.stdlib;

        // callUnittest!(tagion.betterC.utils.Memory)();
        // callUnittest!(tagion.betterC.utils.BinBuffer)();
        // callUnittest!(tagion.betterC.utils.Text)();
        // callUnittest!(tagion.betterC.utils.Stack)();

        // callUnittest!(tagion.betterC.utils.RBTree)();
        // callUnittest!(tagion.betterC.hibon.HiBONBase)();

        // callUnittest!(tagion.betterC.hibon.Document)();
        // callUnittest!(tagion.betterC.hibon.HiBON);
        // callUnittest!(tagion.betterC.utils.LEB128);

        callUnittest!(tagion.betterC.wallet.KeyRecover);
        callUnittest!(tagion.betterC.mobile.Recycle);
        callUnittest!(tagion.betterC.mobile.WalletWrapperApi);
        printf("Passed\n");
        return 0;
    }
}
//}
