module tagion.behaviour.BehaviourFeature;

import std.traits;
import std.meta : AliasSeq, Filter, aliasSeqOf, ApplyLeft, ApplyRight, allSatisfy, anySatisfy, Alias, Erase, aliasSeqOf;
import std.format;
import std.typecons;
import tagion.basic.Basic : isOneOf, staticSearchIndexOf;

import tagion.hibon.HiBONRecord;
import tagion.hibon.Document;

@safe:

mixin template Property() {
    string description;
    @Label(VOID, true) string[] comments;
    mixin HiBONRecord!(q{
            this(string description, string[] comments=null ) pure nothrow {
                this.description = description;
                this.comments = comments;
            }
            this(T)(T prop) pure nothrow {
                description = prop.description;
                comments = prop.comments;
            }
        });
}

@RecordType("Feature")
struct Feature {
    mixin Property;
}

struct Scenario {
    mixin Property;
}

struct Given {
    mixin Property;
}

struct When {
    mixin Property;
}

struct Then {
    mixin Property;
}

struct But {
    mixin Property;
}

enum isDescriptor(T) = hasMember!(T, "description");

struct Info(alias Property) {
    Property property;
    string name; /// Name of the function member
    Document result;
    mixin HiBONRecord!();
}

enum isInfo(alias I) = __traits(isSame, TemplateOf!I, Info);

struct ActionGroup(Property) if (isOneOf!(Property, BehaviourProperties)) {
    Info!Property[] infos;
//    @Label(VOID, true) Info!And[] ands;
    mixin HiBONRecord!();
}

enum isActionGroup(alias I) = __traits(isSame, TemplateOf!I, ActionGroup);

@safe
struct ScenarioGroup {
    @("Scenario") Info!Scenario info;
    ActionGroup!(Given) given; /// Given actions
    @Label(VOID, true) ActionGroup!(When) when; /// When actions
    ActionGroup!(Then) then; /// Then actions
    @Label(VOID, true) ActionGroup!(But) but; /// But actions
    mixin HiBONRecord!();
}

@safe
struct FeatureGroup {
    Info!Feature info;
    ScenarioGroup[] scenarios;
    mixin HiBONRecord!();
}

// version (unittest) {
//     private import tagion.behaviour.BehaviourUnittest;
// }

/// All behaviour-properties of a Scenario
alias BehaviourProperties = AliasSeq!(Given, When, Then, But);
/// The behaviour-properties which only occurrences once in a Scenario
alias MandatoryBehaviourProperties = Erase!(When, Erase!(But, BehaviourProperties));

// alias MemberProperty=Tuple!(string, "member", string, "goal");
// alias PropertyFormat(T)=format!(T.stringof~".%s", string);

// const(MemberProperty[]) memberSequency(T)() if (is(T==class) || is(T==struct)) {
//     MemberProperty[] result;
//     static foreach(name; __traits(allMembers, T)) {{
//             enum code=format!q{alias member=%s.%s;}(T.stringof, name);
//             mixin(code);
//             static if (__traits(compiles, typeof(member))) {
//                 alias hasProperty(Property) =hasUDA!(member, Property);
//                 alias filterProperty=Filter!(hasProperty, BehaviourProperties);
//                 static if (filterProperty.length == 1) {
//                     result~=MemberProperty(
//                         PropertyFormat!T(name),
//                         filterProperty[0].stringof);
//                 }
//             }
//         }}
//     return result;
// }

// unittest { // Test of memberSequency
//     alias SomeFormat=format!(Some_awesome_feature.stringof~".%s", string);

//     const expected=
//         zip(
//             ["is_valid", "in_credit", "contains_cash", "request_cash", "is_debited", "is_dispensed"],
//             ["Given", "And", "And", "When", "Then", "And"]
//         )
//         .map!(a => tuple(SomeFormat(a[0]), a[1]))
//         .array;

//     assert(equal(memberSequency!Some_awesome_feature,
//             expected));
// }

template getMemberAlias(string main, string name) {
    enum code = format!q{alias getMemberAlias=%s.%s;}(main, name);
    pragma(msg, "code ", code);
    mixin(code);
}

template getMemberAlias_(alias main, string name) {
//     pragma(msg, "modulename ", moduleName!main);
//     mixin(format(q{import %s;}, moduleName!main));
// //    mixin Import!main;
//     enum code = format!q{alias getMemberAlias=%s.%s;}(main.stringof, name);
//     pragma(msg, "code ", code);
//     mixin(code);
    alias getMemberAlias_= __traits(getMember, main, name);
}

template getMethod(alias T, string name) {
    alias method = __traits(getOverloads, T, name);
    static if (method.length > 0) {
        alias getMethod = method[0];
    }
    else {
        alias getMethod = void;
    }
}

static unittest {
    pragma(msg, "BehaviourUnittest.Some_awesome_feature.stringof ", BehaviourUnittest.Some_awesome_feature.stringof);
    // pragma(msg, getMemberAlias_!(BehaviourUnittest.Some_awesome_feature, "is_debited"));
    // pragma(msg, getMemberAlias_!(BehaviourUnittest.Some_awesome_feature, "count"));
    // static assert(isMethod!(BehaviourUnittest.Some_awesome_feature, "is_debited"));
    // static assert(!isMethod!(BehaviourUnittest.Some_awesome_feature, "count"));
    static assert(isCallable!(getMethod!(BehaviourUnittest.Some_awesome_feature, "is_debited")));
    static assert(!isCallable!(getMethod!(BehaviourUnittest.Some_awesome_feature, "count")));
    // static assert(isCallable!(getMemberAlias__!(BehaviourUnittest.Some_awesome_feature.stringof, "is_debited")));
    // static assert(!isCallable!(getMemberAlias__!(BehaviourUnittest.Some_awesome_feature.stringof, "count")));
}

template getAllCallables(T) if (is(T == class) || is(T == struct)) {
    alias all_members = aliasSeqOf!([__traits(allMembers, T)]);
    pragma(msg, "all_members ", all_members);
    pragma(msg, "T.stringof ", T.stringof);
    alias all_members_as_aliases = staticMap!(ApplyLeft!(getMethod, T), all_members);
    pragma(msg, "all_members_as_aliases ", all_members_as_aliases);
    alias getAllCallables = Filter!(isCallable, all_members_as_aliases);
    pragma(msg, "getAllCallables  ", getAllCallables); //all_members_as_aliases);
}

static unittest { // Test of getAllCallable
    import tagion.behaviour.BehaviourUnittest;
    alias all_callables = getAllCallables!(Some_awesome_feature);
    static assert(all_callables.length == 13);
    static assert(allSatisfy!(isCallable, all_callables));
}

template hasBehaviours(alias T) if (isCallable!T) {
    alias hasProperty = ApplyLeft!(hasUDA, T);
    enum hasBehaviours = anySatisfy!(hasProperty, BehaviourProperties);
}

///
static unittest {
    static assert(hasBehaviours!(BehaviourUnittest.Some_awesome_feature.is_valid));
    static assert(!hasBehaviours!(BehaviourUnittest.Some_awesome_feature.helper_function));
}

template getBehaviours_(T) if (is(T == class) || is(T == struct)) {
    pragma(msg, "get_all_callable ", T);
    alias get_all_callable = getAllCallables!T;
    alias getBehaviours_ = Filter!(hasBehaviours, get_all_callable);
}

static unittest { // Test of getBehaviours
    alias behaviours = getBehaviours_!(BehaviourUnittest.Some_awesome_feature);
    pragma(msg, "!!!! behaviours ", behaviours);
    static assert(behaviours.length == 7);
    static assert(allSatisfy!(isCallable, behaviours));
    static assert(allSatisfy!(hasBehaviours, behaviours));
}

/**
   This template get the behaviour with the behaviour-Property from a Behaviour object
   Returns: The function with the behaviour-Property
   The function fails if there is more than one behaviour with this behaviour
   and returns void if no behaviour-Property has been found
 */
template getBehaviour(T, Property) if (is(T == class) || is(T == struct)) {
    alias behaviours = getBehaviours_!T;
    pragma(msg, "behaviours ", behaviours);
    alias behaviour_with_property = Filter!(ApplyRight!(hasUDA, Property), behaviours);
    // static assert(behaviour_with_property.length <= 1,
    //         format!"More than 1 behaviour %s has been declared in %s"(Property.stringof, T.stringof));
    static if (behaviour_with_property.length > 0) {
        alias getBehaviour = behaviour_with_property;
    }
    else {
        alias getBehaviour = void;
    }

}

unittest {
    alias behaviour_with_given = getBehaviour!(BehaviourUnittest.Some_awesome_feature, Given);
    pragma(msg, "behaviour_with_given ", behaviour_with_given);
    static assert(allSatisfy!(isCallable, behaviour_with_given));

    static assert(allSatisfy!(ApplyRight!(hasUDA, Given), behaviour_with_given));
        //static assert(hasUDA!(behaviour_with_given, Given));
    static assert(is(getBehaviour!(BehaviourUnittest.Some_awesome_feature_bad_format_missing_given, Given) == void));

    alias behaviour_with_when = getBehaviour!(BehaviourUnittest.Some_awesome_feature, When);
    static assert(isCallable!(behaviour_with_when));
    static assert(hasUDA!(behaviour_with_when, When));

}

enum hasProperty(alias T, Property) = !is(getBehaviour!(T, Property) == void);

unittest {
    static assert(hasProperty!(BehaviourUnittest.Some_awesome_feature, Then));
    static assert(!hasProperty!(BehaviourUnittest.Some_awesome_feature_bad_format_missing_given, Given));
}

template getProperty(alias T) {
    alias getUDAsProperty = ApplyLeft!(getUDAs, T);
    alias all_behaviour_properties = staticMap!(getUDAsProperty, BehaviourProperties);
    static assert(all_behaviour_properties.length <= 1,
            format!"The behaviour %s has more than one property %s"(T.strinof, all_behaviour_properties.stringof));
    static if (all_behaviour_properties.length is 1) {
        alias getProperty = all_behaviour_properties[0];
    }
    else {
        alias getProperty = void;
    }
}

unittest {
    alias properties = getProperty!(BehaviourUnittest.Some_awesome_feature.request_cash);
    static assert(is(typeof(properties) == When));
    static assert(is(getProperty!(BehaviourUnittest.Some_awesome_feature.helper_function) == void));
}

// enum hasProperty(alias T) = !is(getProperty!(T) == void);

// @safe
// unittest {
//     static assert(hasProperty!(Some_awesome_feature.request_cash));
//     static assert(!(hasProperty!(Some_awesome_feature.helper_function)));
// }

@safe
unittest {
    alias behaviour_of_given = getBehaviour!(BehaviourUnittest.Some_awesome_feature, Given);
    static assert(behaviour_of_given.length is 3);
    static assert(getProperty!(behaviour_of_given[0]) == Given("the card is valid"));
    static assert(getProperty!(behaviour_of_given[1]) == Given("the account is in credit"));
    static assert(getProperty!(behaviour_of_given[2]) == Given("the dispenser contains cash"));

    alias behaviour_of_when = getBehaviour!(BehaviourUnittest.Some_awesome_feature, When);
    static assert(behaviour_of_when.length is 1);
    static assert(getProperty!(behaviour_of_when[0]) == When("the Customer request cash"));

    alias behaviour_of_then = getBehaviour!(BehaviourUnittest.Some_awesome_feature, Then);
    static assert(behaviour_of_then.length is 2);
    static assert(getProperty!(behaviour_of_then[0]) == Then("the account is debited"));
    static assert(getProperty!(behaviour_of_then[1]) == Then("the cash is dispensed"));

    alias behaviour_of_but = getBehaviour!(BehaviourUnittest.Some_awesome_feature, But);
    static assert(behaviour_of_but.length is 1);
    static assert(getProperty!(behaviour_of_but[0]) == But("if the Customer does not take his card, then the card must be swollowed"));
}


enum isScenario(T) = hasUDA!(T, Scenario);

static unittest {
    static assert(isScenario!(BehaviourUnittest.Some_awesome_feature));
}

enum feature_name = "feature";

template isFeature(alias M) if (__traits(isModule, M)) {
    import std.algorithm.searching : any;

    enum feature_found = [__traits(allMembers, M)].any!(a => a == feature_name);
    static if (feature_found) {
        enum obtainFeature = __traits(getMember, M, feature_name);
        enum isFeature = is(typeof(obtainFeature) == Feature);
    }
    else {
        enum isFeature = false;
    }
}

///
@safe
unittest {
    import tagion.behaviour.BehaviourUnittest;
    static assert(isFeature!(tagion.behaviour.BehaviourUnittest));
    static assert(!isFeature!(tagion.behaviour.BehaviourFeature));
}

/**
   Returns:
   The Feature of a Module
   If the Modules does not contain a feature then a false is returned
 */
template obtainFeature(alias M) if (__traits(isModule, M)) {
    static if (isFeature!M) {
        enum obtainFeature = __traits(getMember, M, feature_name);
    }
    else {
        enum obtainFeature = false;
    }
}

///
@safe
unittest { // The obtainFeature of a module
    import tagion.behaviour.BehaviourUnittest;
    static assert(obtainFeature!(tagion.behaviour.BehaviourUnittest) ==
            Feature(
                "Some awesome feature should print some cash out of the blue", null));
    static assert(!obtainFeature!(tagion.behaviour.BehaviourFeature));

}

protected template _Scenarios(alias M, string[] names) if (__traits(isModule, M)) {
    static if (names.length is 0) {
        alias _Scenarios = AliasSeq!();
    }
    else {
        //enum compiles = __traits(compiles, getMemberAlias!(moduleName!M, names[0]));
        pragma(msg, "names ", names[0]);
        alias member = __traits(getMember, M, names[0]);
        pragma(msg, "__traits(isModule, module_member) ", __traits(isModule, member));
        pragma(msg, "is(module_member == class) ", is(member == class), " ", moduleName!M);
//        pragma(msg, "module_member ", module_member.stringof);
        //      enum compiles =false;
        enum is_object = is(member == class) || is(member == struct);
        static if (is_object) {
            enum is_scenario  = hasUDA!(member, Scenario);

//            alias member = getMemberAlias!(moduleName!M, names[0]);
        }
        else {
            enum is_scenario = false;
//            alias member = void;
        }
        static if (is_scenario && (is(member == class) || is(member == struct))) {
            alias _Scenarios =
                AliasSeq!(
                        member,
                        _Scenarios!(M, names[1 .. $])
                );
        }
        else {
            alias _Scenarios = _Scenarios!(M, names[1 .. $]);
        }
    }
}

template Scenarios(alias M) if (__traits(isModule, M)) {
    alias Scenarios = _Scenarios!(M, [__traits(allMembers, M)]);
}

///
static unittest { //
    import tagion.behaviour.BehaviourUnittest;
    alias scenarios = Scenarios!(tagion.behaviour.BehaviourUnittest);
    pragma(msg, "scenarios ", scenarios);
    alias expected_scenarios = AliasSeq!(
            Some_awesome_feature,
            Some_awesome_feature_bad_format_double_property,
            Some_awesome_feature_bad_format_missing_given,
            Some_awesome_feature_bad_format_missing_then);

    static assert(scenarios.length == expected_scenarios.length);
    static assert(__traits(isSame, scenarios, expected_scenarios));
}

template getScenario(T) if (is(T == class) || is(T == struct)) {
    enum scenario_attr = getUDAs!(T, Scenario);
    pragma(msg, "scenario_attr ", scenario_attr);
    static assert(scenario_attr.length <= 1,
            format!"%s is not a %s"(T.stringof, Scenario.stringof));
    static if (scenario_attr.length is 1) {
        enum getScenario = scenario_attr[0];
    }
    else {
        enum getScenario = false;
    }
    pragma(msg, "getScenario ", getScenario);
}

static unittest {
    import tagion.behaviour.BehaviourUnittest;
    enum scenario = getScenario!(Some_awesome_feature);
    static assert(is(typeof(scenario) == Scenario));
    static assert(scenario is Scenario("Some awesome money printer", null));
}

version (unittest) {
    import BehaviourUnittest=tagion.behaviour.BehaviourUnittest;
    import std.stdio;
    import std.algorithm.iteration : map, joiner;
    import std.algorithm.comparison : equal;
    import std.range : zip, only;
    import std.typecons;
    import std.array;
}
