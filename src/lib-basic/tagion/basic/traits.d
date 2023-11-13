/// Extension of std.traist used in the tagion project
module tagion.basic.traits;
import std.meta : ApplyRight, Filter, staticMap;
import std.range.primitives : isInputRange;
import std.traits : getUDAs, hasUDA;

/**
    Similar to .stringof but working on member functions
    Params: 
       member = symbol of module,struct or class
    Returns: the name of the symbol 
*/
template getName(alias member) {
    import std.algorithm.iteration : splitter;
    import std.range : tail;
    import std.traits : fullyQualifiedName;

    enum getName = fullyQualifiedName!(member).splitter('.').tail(1).front;
}

/**
    Params: 
        member = symbol of a member
    Returns: 
        all overloads of the member
*/
template getOverloads(alias member) {
    alias Parent = __traits(parent, member);
    alias getOverloads = __traits(getOverloads, Parent, getName!member);
}

/** 
 * Params:
 *     member = symbol of a member
 *     UDA = User defined attribute of the member
 * Returns:
 *     all the member symbols which has this UDA
 *     If no UDA was found a empty alias sequency will be returned 
 */
template hasMemberUDA(alias member, alias UDA) {
    alias Overloads = getOverloads!(member);
    alias hasTheUDA = ApplyRight!(hasUDA, UDA);
    alias hasMemberUDA = Filter!(hasTheUDA, Overloads);
}

enum hasOneMemberUDA(alias member, alias UDA) = hasMemberUDA!(member, UDA).length is 1;

/**
 * Params:
 *     member = symbol of a member
 *     UDA = User defined attribute of the member
 * Returns:
 *     
*/
template getMemberUDAs(alias member, alias UDA) {
    alias Overloads = getOverloads!(member);
    alias getTheUDAs = ApplyRight!(getUDAs, UDA);
    alias getMemberUDAs = staticMap!(getTheUDAs, hasMemberUDA!(member, UDA));
}

///
static unittest {
    import std.typecons : Tuple;

    enum test;
    struct special {
        string label;
    }

    struct S {
        @test
        int func() {
            return 0;
        }

        @special("text")
        int func(int x) {
            return x;
        }

        string func(string str) {
            return str;
        }
    }

    static assert(getName!(S.func) == "func");
    static assert(__traits(isSame, __traits(getOverloads, S, "func"), getOverloads!(S.func)));
    /// UDA @test
    static assert(hasMemberUDA!(S.func, test).length is 1);
    static assert(__traits(isSame, hasMemberUDA!(S.func, test)[0], getOverloads!(S.func)[0]));
    static assert(is(getMemberUDAs!(S.func, test)[0] == test));
    /// UDA special
    static assert(hasMemberUDA!(S.func, special).length is 1);
    static assert(__traits(isSame, hasMemberUDA!(S.func, special)[0], getOverloads!(S.func)[1]));
    enum s_special = getMemberUDAs!(S.func, special)[0];
    static assert(s_special == special("text"));
}
