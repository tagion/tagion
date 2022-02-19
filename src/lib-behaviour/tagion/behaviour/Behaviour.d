module tagion.behaviour.Behaviour;

import std.traits;
import std.meta : AliasSeq, Filter, aliasSeqOf, ApplyLeft, allSatisfy, anySatisfy, Alias;
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
    alias all_members = aliasSeqOf!([__traits(allMembers, T)]);
    alias all_members_as_aliases=staticMap!(ApplyLeft!(getMemberAlias, T), all_members);
    pragma(msg, "all_members_as_aliases ", all_members_as_aliases);
    alias getAllCallable=Filter!(isCallable, all_members_as_aliases);
    pragma(msg, "only_callable_members ", getAllCallable);
}

static unittest { // Test of getAllCallable
    static assert(allSatisfy!(isCallable, getAllCallable!Some_awesome_feature));
}

template hasBehaviour(alias T) if (isCallable!T) {
    alias hasProperty=ApplyLeft!(hasUDA, T);
    pragma(msg, "hasProperty ", hasUDA!(T, Given));
//    pragma(msg, "hasProperty ", hasUDA!(T, Given));
    pragma(msg, "hasProperty ", hasProperty!(Given));
    enum hasBehaviour=anySatisfy!(hasProperty, BehaviourProperties);
    pragma(msg, "_has ", hasBehaviour);
//    enum hasBehaviour=false;
}

unittest {
//    alias is_valid=FunctionTypeOf!(Some_awesome_feature.is_valid);
//    pragma(msg, "is_valid ", is_valid);
    pragma(msg, "is_valid attr ", hasUDA!(Some_awesome_feature.is_valid, Given));
    static assert(hasBehaviour!(Some_awesome_feature.is_valid));
    static assert(!hasBehaviour!(Some_awesome_feature.helper_function));
    //Some_awesome_feature.is_valid);
}

template getBehaviour(T) if (is(T==class) || is(T==struct)) {
    alias get_all_callable = getAllCallable!T;
    alias hasProperty=ApplyLeft!(hasUDA, T);
//    alias one=get_all_callable[0]);
    pragma(msg, "get_all_callable ", get_all_callable);
//    pragma(msg, one);
    pragma(msg, hasUDA!(get_all_callable[0], Given));

    alias getBehaviour=Filter!(hasProperty, BehaviourProperties);
    pragma(msg, "getBehaviour ", getBehaviour);
}

static unittest { // Test of getBehaviour
    alias get_behaviour=getBehaviour!Some_awesome_feature;
    pragma(msg, "get_behaviour ", get_behaviour);
    pragma(msg, "get_behaviour.length ", get_behaviour.length);

    static assert(allSatisfy!(isCallable, get_behaviour));
    static assert(allSatisfy!(ApplyLeft!(hasUDA, Some_awesome_feature), get_behaviour));
}

//alias hasProperty(Property) =hasUDA!(member, Property);

template Should(T, Property) if (is(T==class) || is(T==struct)) {
    alias get_behaviour=getBehaviour!T;
    pragma(msg, "T ", T, " Property ", Property);
    pragma(msg, "get_behaviour ", get_behaviour);
    alias get_property_behaviour=Filter!(ApplyLeft!(hasUDA, Property), get_behaviour);
    pragma(msg, "get_property_behaviour ", get_property_behaviour);
//    "T ", T, "Property ", Property);

//    alias allMemberNames = aliasSeqOf!([__traits(allMembers, S)]);

    //  alias filterProperty=Filter!(hasProperty, BehaviourProperties);
//    pragma(msg, "T ", T, "Property ", Property);
    // static if (hasUDA!(T, Property)) {
    //     alias Should = int;
    // }
    // else {
    //     alias Should = void;
    // }
    alias Should = void;
}

unittest {
    alias behaviour_with_given = Should!(Some_awesome_feature, Given);
    static assert(isCallable!(behaviour_with_given));
    static assert(hasUDA!(behaviour_with_given, Given));
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
            void helper_function() {
            }
        }

    @Feature("Some awesome feature should print some cash out of the blue")
        class Some_awesome_feature_bad_format_double_propery {
            @Given("the card is valid")
            bool is_valid() {
                return false;
            }
            @Given("the card is valid (should not have two Given)")
            bool is_valid_bad_one() {
                return false;
            }
            @When("the Customer request cash")
            bool request_cash() {
                return false;
            }
            @When("the Customer request cash (Should not have two When)")
            bool request_cash_bad_one() {
                return false;
            }
            @Then("the account is debited")
            bool is_debited() {
                return false;
            }
            @Then("the account is debited (Should not have two Then)")
            bool is_debited_bad_one() {
                return false;
            }
            @And("the cash is dispensed")
            bool is_dispensed() {
                return false;
            }
        }

    @Feature("Some awesome feature should print some cash out of the blue")
        class Some_awesome_feature_bad_format_missing_given {
            @Then("the account is debited (Should not have two Then)")
            bool is_debited_bad_one() {
                return false;
            }
            @And("the cash is dispensed")
            bool is_dispensed() {
                return false;
            }
        }

    @Feature("Some awesome feature should print some cash out of the blue")
        class Some_awesome_feature_bad_format_missing_then {
            @Given("the card is valid")
            bool is_valid() {
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
