module tagion.behaviour.Behaviour;

import std.traits;
import std.meta : AliasSeq, Filter;
import std.format;
import std.typecons;

struct Feature {
    string description;
    string[] comments;
}

struct Given {
    string description;
}

struct And {
    string description;
}

struct When {
    string description;
}

struct Then {
    string description;
}

alias BehaviourProperties = AliasSeq!(Given, And, When, Then);

alias MemberProperty=Tuple!(string, "member", string, "goal");
alias PropertyFormat(T)=format!(T.stringof~".%s", string);

const(MemberProperty[]) memberSequency(T)() if (is(T==class) || is(T==struct)) {
    MemberProperty[] result;
    static foreach(name; __traits(allMembers, T)) {{
            enum code=format!q{alias member=%s.%s;}(T.stringof, name);
            //pragma(msg,code);
            mixin(code);
            //T elem;
            static if (__traits(compiles, typeof(member))) {
                alias hasProperty(Property) =hasUDA!(member, Property);
                alias filterProperty=Filter!(hasProperty, BehaviourProperties);
                static if (filterProperty.length == 1) {
                    result~=MemberProperty(
                        PropertyFormat!T(name),
                        filterProperty[0].stringof);
                }
            }
        }}
    return result;
}


unittest { // Test of memberSequency
    alias SomeFormat=format!(Some_awesome_feature.stringof~".%s", string);

    const expected=
        zip(
            ["is_valid", "in_credit", "contains_cash", "request_cash", "is_debited", "is_dispensed"],
            ["Given", "And", "And", "When", "Then", "And"]
        )
        .map!(a => tuple(SomeFormat(a[0]), a[1]))
        .array;

    assert(equal(memberSequency!Some_awesome_feature,
            expected));
}

template getMemberAlias(T, string name) if (is(T==class) || is(T==struct)) {
    enum code=format!q{alias getMemberAlias=%s.%s;}(T.stringof, name);
    mixin(code);
}

static unittest {
    static assert(isCallable!(getMemberAlias!(Some_awesome_feature, "is_debited")));
}

template getAllCallable(T) if (is(T==class) || is(T==struct)) {
    alias getAllCallable=void;
}

unittest {
    static assert(isCallable!(getAllCallable!Some_awesome_feature));
}
//alias hasProperty(Property) =hasUDA!(member, Property);

template Should(T, alias Property) if (is(T==class) || is(T==struct)) {
    pragma(msg, "T ", T, "Property ", Property);
    alias allMemberNames = aliasSeqOf!([__traits(allMembers, S)]);

    //  alias filterProperty=Filter!(hasProperty, BehaviourProperties);
//    pragma(msg, "T ", T, "Property ", Property);
    static if (hasUDA!(T, Property)) {
        alias Should = int;
    }
    else {
        alias Should = void;
    }
}

unittest {
    static assert(isCallable!(Should!(Some_awesome_feature, Given)));
}
// template memberPropertyToAlias(MemberProperty M) {
//     pragma(msg, "MemberProperty.member ", M.member);
//     enum code=format!q{alias memberPropertyToAlias=%s;}(M.member);
//     pragma(msg, memberPropertyToAlias);
//     mixin(code);
// }

// static unittest {
//     // enum members=memberSequency!Some_awesome_feature;
//     // pragma(msg, members);
//     alias propertyFunc=memberPropertyToAlias!(MemberProperty("Some_awesome_feature.request_cash", "When"));
//     static assert(isCallable!propertyFunc);
// }

// template executionList(alias T) {
//     enum member_sequency=memberSequency!T;
// //    alias executionList=staticMap!(memberPropertyToAlias, member_sequency);

// }

// unittest { // Test of ExecutionSequency
//     pragma(msg, executionList!Some_awesome_feature);
//     static assert(isCallable!(executionList[0]));
// }

version(unittest) {
    // Behavioral examples
    @Feature("Some awesome feature should print some cash out of the blue")
        class Some_awesome_feature {
            @Given("the card is valid")
            bool is_valid() {
                return false;
            }
            @And("the account is in credit")
            bool in_credit() {
                return false;
            }
            @And("the dispenser contains cash")
            bool contains_cash() {
                return false;
            }
            @When("the Customer request cash")
            bool request_cash() {
                return false;
            }
            @Then("the account is debited")
            bool is_debited() {
                return false;
            }
            @And("the cash is dispensed")
            bool is_dispensed() {
                return false;
            }
        }

    @Feature("Some awesome feature should print some cash out of the blue")
        class Some_awesome_feature_not_ordered {
            @Then("the account is debited")
            bool is_debited() {
                return false;
            }
            @And("the cash is dispensed")
            bool is_dispensed() {
                return false;
            }
            @When("the Constumer request cash")
            bool request_cash() {
                return false;
            }
            @Given("that the card is valid")
            bool is_valid() {
                return false;
            }
            @And("the account is in credit")
            bool in_credit() {
                return false;
            }
            @And("the dispenser contains cash")
            bool contains_cash() {
                return false;
            }
        }
}

version(unittest) {
    import std.stdio;
    import std.algorithm.iteration : map, joiner;
    import std.algorithm.comparison : equal;
    import std.range : zip, only;
    import std.typecons;
    import std.array;
}
