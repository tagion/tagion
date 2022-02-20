module tagion.behaviour.BehaviourBase;

import std.traits;
import std.meta : AliasSeq, Filter, aliasSeqOf, ApplyLeft, ApplyRight, allSatisfy, anySatisfy, Alias, Erase, aliasSeqOf;
import std.format;
import std.typecons;
import tagion.basic.Basic : isOneOf, staticSearchIndexOf;

struct Feature {
    string description;
    string[] comments;
}

struct Scenario {
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

version(unittest) {
    private import tagion.behaviour.BehaviourUnittest;
}
/// All behaviour-properties of a Scenario
alias BehaviourProperties = AliasSeq!(Given, And, When, Then);
/// The behaviour-properties which only occurrences once in a Scenario
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
    alias getAllCallable=Filter!(isCallable, all_members_as_aliases);
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

    alias behaviour_with_when = getBehaviour!(Some_awesome_feature, When);
    static assert(isCallable!(behaviour_with_when));
    static assert(hasUDA!(behaviour_with_when, When));

}

enum hasProperty(alias T, Property) = !is(getBehaviour!(T, Property) == void);

unittest {
    static assert(hasProperty!(Some_awesome_feature, Then));
    static assert(!hasProperty!(Some_awesome_feature_bad_format_missing_given, Given));
}

template getProperty(alias T) {
    alias getUDAsProperty = ApplyLeft!(getUDAs, T);
    alias all_behaviour_properties=staticMap!(getUDAsProperty, BehaviourProperties);
    static assert(all_behaviour_properties.length <= 1,
        format!"The behaviour %s has more than one property %s"(T.strinof, all_behaviour_properties.stringof));
    static if (all_behaviour_properties.length is 1) {
        alias getProperty=all_behaviour_properties[0];
    }
    else {
        alias getProperty=void;
    }
}

unittest {
    alias properties=getProperty!(Some_awesome_feature.request_cash);
    static assert(is(typeof(properties) == When));
    static assert(is(getProperty!(Some_awesome_feature.helper_function) == void));
}

enum hasProperty(alias T) = !is(getProperty!(T) == void);

unittest {
    static assert(hasProperty!(Some_awesome_feature.request_cash));
    static assert(!(hasProperty!(Some_awesome_feature.helper_function)));
}

protected template _getUnderBehaviour(bool property_found, Property, L...) {
    static if (L.length == 0) {
        alias _getUnderBehaviour=AliasSeq!();
    }
    else static if(property_found) {
        alias behavior_property = getProperty!(L[0]);
        alias other_unique_propeties = Erase!(Property, UniqueBehaviourProperties);
        alias behavior_property_type = typeof(behavior_property);
        static if (isOneOf!(behavior_property_type, other_unique_propeties)) {
            alias _getUnderBehaviour=AliasSeq!();
        }
        else {
            alias _getUnderBehaviour=AliasSeq!(
                L[0],
                _getUnderBehaviour!(property_found, Property, L[1..$])
                );
        }
    }
    else static if(is(typeof(getProperty!(L[0])) == Property)) {
        alias _getUnderBehaviour = _getUnderBehaviour!(true, Property, L[1..$]);
    }
    else {
        alias _getUnderBehaviour = _getUnderBehaviour!(property_found, Property, L[1..$]);
    }
}

template getUnderBehaviour(T, Property) if (is(T==class) || is(T==struct)) {
    alias behaviours=getBehaviours!T;

    alias getUnderBehaviour = _getUnderBehaviour!(false, Property, behaviours);
}

unittest {
    alias under_behaviour_of_given = getUnderBehaviour!(Some_awesome_feature, Given);
    pragma(msg, under_behaviour_of_given);
    pragma(msg, "under_behaviour_of_given ", under_behaviour_of_given);
    static assert(under_behaviour_of_given.length is 2);
    static assert(getProperty!(under_behaviour_of_given[0]) == And("the account is in credit"));
    static assert(getProperty!(under_behaviour_of_given[1]) == And("the dispenser contains cash"));

    alias under_behaviour_of_when = getUnderBehaviour!(Some_awesome_feature, When);
    pragma(msg, "under_behaviour_of_when ", under_behaviour_of_when);
    static assert(under_behaviour_of_when.length is 0);

    alias under_behaviour_of_then = getUnderBehaviour!(Some_awesome_feature, Then);
    pragma(msg, "under_behaviour_of_then ", under_behaviour_of_then);
    pragma(msg, "under_behaviour_of_then ", getProperty!(under_behaviour_of_then[0]));
    assert(getProperty!(under_behaviour_of_then[0]) == And("the cash is dispensed"));
    static assert(under_behaviour_of_then.length is 1);

}

enum isScenario(T) = hasUDA!(T, Scenario);

static unittest {
    static assert(isScenario!Some_awesome_feature);
}

enum feature_name="feature";

template hasFeature(alias M)  if (__traits(isModule, M)) {
    import std.algorithm.searching : any;
    enum feature_found = [__traits(allMembers, M)].any!(a => a == feature_name);
    pragma(msg, "feature_found ", feature_found);
    static if (feature_found) {
        enum obtainFeature = __traits(getMember, M, feature_name);
        pragma(msg, "obtainFeature ", obtainFeature);
        pragma(msg, "obtainFeature ", typeof(obtainFeature));
        enum hasFeature = is(typeof(obtainFeature) == Feature);
    }
    else {
        enum hasFeature=false;
    }
}

unittest {
    static assert(hasFeature!(tagion.behaviour.BehaviourUnittest));
    static assert(!hasFeature!(tagion.behaviour.BehaviourBase));
}

template obtainFeature(alias M) if (__traits(isModule, M)) {
    pragma(msg, `__traits(getMember, M, "feature") `, __traits(getMember, M, "feature"));
//    enum feature="feature";
    enum obtainFeature = __traits(getMember, M, "feature");
}

///
unittest { // Obtain the
    static assert(obtainFeature!(tagion.behaviour.BehaviourUnittest) ==
            Feature("Some awesome feature should print some cash out of the blue", null));
    pragma(msg, "allMembers ", __traits(allMembers, tagion.behaviour.BehaviourBase));

    pragma(msg, "obtainFeature!(tagion.behaviour.BehaviourBase) ", obtainFeature!(tagion.behaviour.BehaviourBase));
}


template Senarious(alias M) if (__traits(isModule, M)) {
    pragma(msg, __traits(allMembers, M));
    alias Senarious = void;
}


static unittest { //
    static assert(is(Senarious!(tagion.behaviour.BehaviourUnittest) == int));
}

version(unittest) {
    import std.stdio;
    import std.algorithm.iteration : map, joiner;
    import std.algorithm.comparison : equal;
    import std.range : zip, only;
    import std.typecons;
    import std.array;
}
