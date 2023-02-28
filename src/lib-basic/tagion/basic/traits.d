module tagion.basic.traits;

template getMemberUDA(alias member) {
    import std.traits : fullyQualifiedName, QualifierOf, FunctionTypeOf;
    pragma(msg, __traits(parent, member));
alias Parent=__traits(parent, member);
    pragma(msg, QualifierOf!(FunctionTypeOf!member));
    pragma(msg, __traits(getOverloads, Parent, fullyQualifiedName!member));
    enum getMemberUDA=true;
}

static unittest {
    enum test;
    struct S {
        @test
        int func() {
            return 0;
        }

        int func(int x) {
            return x;
        }
    }


    pragma(msg, "############ traits ", __traits(getOverloads, S, "func"));
    pragma(msg, "############ traits ", __traits(parent, S.func));
    pragma(msg, "############ traits ", getMemberUDA!(S.func));

}
