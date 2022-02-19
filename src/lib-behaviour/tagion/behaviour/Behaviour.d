module tagion.behaviour.Behaviour;

import std.traits;
import std.meta : AliasSeq, Filter, aliasSeqOf, ApplyLeft, ApplyRight, allSatisfy, anySatisfy, Alias, Erase;
import std.format;
import std.typecons;
import tagion.basic.Basic : isOneOf, staticSearchIndexOf;

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

/// All behaviour-properties of a Feature
alias BehaviourProperties = AliasSeq!(Given, And, When, Then);
/// The behaviour-properties which only occurrences once in a Feature
alias UniqueBehaviourProperties = Erase!(And, BehaviourProperties);

alias MemberProperty=Tuple!(string, "member", string, "goal");
alias PropertyFormat(T)=format!(T.stringof~".%s", string);

const(MemberProperty[]) memberSequency(T)() if (is(T==class) || is(T==struct)) {
    MemberProperty[] result;
    static foreach(name; __traits(allMembers, T)) {{
            enum code=format!q{alias member=%s.%s;}(T.stringof, name);
            mixin(code);
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

template hasBehaviours(alias T) if (isCallable!T) {
    alias hasProperty=ApplyLeft!(hasUDA, T);
    enum hasBehaviours=anySatisfy!(hasProperty, BehaviourProperties);
}

///
static unittest {
    static assert(hasBehaviours!(Some_awesome_feature.is_valid));
    static assert(!hasBehaviours!(Some_awesome_feature.helper_function));
}

template getBehaviours(T) if (is(T==class) || is(T==struct)) {
    alias get_all_callable = getAllCallable!T;
    alias getBehaviours = Filter!(hasBehaviours, get_all_callable);
}

static unittest { // Test of getBehaviours
    alias get_behaviour=getBehaviours!Some_awesome_feature;
    static assert(allSatisfy!(isCallable, get_behaviour));
    static assert(allSatisfy!(hasBehaviours, get_behaviour));
}

/**
   This template get the behaviour with the behaviour-Property from a Behaviour object
   Returns: The function with the behaviour-Property
   The function fails if there is more than one behaviour with this behaviour
   and returns void if no behaviour-Property has been found
 */
template getBehaviour(T, Property) if (is(T==class) || is(T==struct)) {
    alias behaviours=getBehaviours!T;
    alias get_property_behaviour=Filter!(ApplyRight!(hasUDA, Property), behaviours);
    static assert(get_property_behaviour.length <= 1,
        format!"More than 1 behaviour %s has been declared in %s"(Property.stringof, T.stringof));
    static if (get_property_behaviour.length is 1) {
        alias getBehaviour=get_property_behaviour[0];
    }
    else {
        alias getBehaviour= void;
    }
}

unittest {
    alias behaviour_with_given = getBehaviour!(Some_awesome_feature, Given);
    static assert(isCallable!(behaviour_with_given));
    static assert(hasUDA!(behaviour_with_given, Given));
    static assert(is(getBehaviour!(Some_awesome_feature_bad_format_missing_given, Given) == void));
}

enum hasBehaviour(T, Property) = !is(getBehaviour!(T, Property) == void);

unittest {
    static assert(hasBehaviour!(Some_awesome_feature, Then));
    static assert(!hasBehaviour!(Some_awesome_feature_bad_format_missing_given, Given));
}

template getBehaviour(alias T) {
    alias getProperty = ApplyLeft!(getUDAs, T);
    alias all_behaviour_properties=staticMap!(getProperty, BehaviourProperties);
    static assert(all_behaviour_properties.length <= 1,
        format!"The behaviour %s has more than one property %s"(T.strinof, all_behaviour_properties.stringof));
    static if (all_behaviour_properties.length is 1) {
        alias getBehaviour=all_behaviour_properties[0];
    }
    else {
        alias getBehaviour=void;
    }
}

unittest {
    alias behaviour=getBehaviour!(Some_awesome_feature.request_cash);
    static assert(is(typeof(behaviour) == When));
    static assert(is(getBehaviour!(Some_awesome_feature.helper_function) == void));
}

version(none)
protected template _getUnderBehaviour(bool property_found, Property, L...) {
    static if (L.length is 0) {
        alias _getUnderBehaviour=AliasSeq!();
    }
    else static if(property_found) {
//        alias
        alias other_unique_propeties = Erase!(Property, UniqueBehaviourProperties);
//        enum is_other=anySatisfy!(;
    }
    // else static if(hasBehavior!(L[0], Property)) {
    //     alias _getUnderBehaviour = _getUnderBehaviour(true, Property, L[1..$]);
    // }
    // else {
    //     alias _getUnderBehaviour = _getUnderBehaviour(false, Property, L[1..$]);
    // }
}

template getUnderBehaviour(T, Property) if (is(T==class) || is(T==struct)) {
    alias hasProperty =ApplyRight!(hasBehaviour,Property);

//    static assert(hasProperty!(T[0]));
    alias behaviours=getBehaviours!T;
    static assert(hasProperty!(behaviours[0]));
    alias get_property_behaviour=Filter!(hasProperty, behaviours);
    pragma(msg, " getUnderBehaviour get_property_behaviour ", get_property_behaviour);
    enum property_index_1=staticSearchIndexOf!(Given, behaviours); //BehaviourProperties);
    pragma(msg, "index_1 ", property_index_1);
    enum property_index=staticSearchIndexOf!(hasProperty, behaviours); //BehaviourProperties);
    pragma(msg, "index ", property_index);
    static if (property_index < 0) {
        alias getUnderBehaviour=AliasSeq!();
    }
    else {
        alias other_unique_propeties = Erase!(Property, UniqueBehaviourProperties);
        pragma(msg, " other_unique_propeties ", other_unique_propeties);
        static assert(isOneOf!(Then, other_unique_propeties));

        alias isOther=ApplyRight!(isOneOf, other_unique_propeties);
        pragma(msg, "isOther!Then " ,isOther!Then);
        // static assert(isOther!Then);
//         alias rest = get_behaviour[property_index+1..$];
//         pragma(msg, "rest ", rest);
//         pragma(msg, "isOther!(rest[0]) ", isOther!(rest[0]));
//         enum end_index = staticSearchIndexOf!(isOther, rest);
//         pragma(msg, "end_index ", end_index);
//         // static if (end_index < 0) {
//         //     alias getUnderBehaviour = get_behaviour[property_index+1..$];
//         // }
//         // else {
//         //     alias getUnderBehaviour = get_behaviour[property_index+1..end_index];
//         // }
// //    static assert(isOther!Property);
//     // pragma(msg, "T ", T, " Property ", Property);
//     // pragma(msg, "get_behaviour ", get_behaviour);
        alias getUnderBehaviour=AliasSeq!(void);
        pragma(msg, "getUnderBehaviour ", getUnderBehaviour);
    }
}

unittest {
    alias under_behaviour_of_given = getUnderBehaviour!(Some_awesome_feature, Given);
    static assert(under_behaviour_of_given.length is 2);
}

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
