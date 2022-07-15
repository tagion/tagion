module tagion.behaviour.BehaviourBase;

import std.traits;
import std.meta : AliasSeq, Filter, aliasSeqOf, ApplyLeft, ApplyRight, allSatisfy, anySatisfy, Alias, Erase, aliasSeqOf;
import std.format;
import std.typecons;
import tagion.basic.Basic : isOneOf, staticSearchIndexOf;

import tagion.hibon.HiBONRecord;
import tagion.hibon.Document;

@safe:

@RecordType("Feature")
struct Feature
{
    string description;
    @Label(VOID, true) string[] comments;
    string name;
    mixin HiBONRecord!(q{
            this(string description, string[] comments=null ) {
                this.description = description;
                this.comments = comments;
            }
        });
}

@RecordType("Scenario")
struct Scenario
{
    string description;
    @Label(VOID, true) string[] comments;
    mixin HiBONRecord!(q{
            this(string description, string[] comments=null ) {
                this.description = description;
                this.comments = comments;
            }
        });
}

@RecordType("Give")
struct Given
{
    string description;
    mixin HiBONRecord!(q{
            this(string description) {
                this.description = description;
            }
        });
}

@RecordType("And")
struct And
{
    string description;
    mixin HiBONRecord!(q{
            this(string description) {
                this.description = description;
            }
        });
}

@RecordType("When")
struct When
{
    string description;
    mixin HiBONRecord!(q{
            this(string description) {
                this.description = description;
            }
        });
}

@RecordType("Then")
struct Then
{
    string description;
    mixin HiBONRecord!(q{
            this(string description) {
                this.description = description;
            }
        });
}

enum isDescriptor(T) = hasMember!(T, "description");

struct Info(alias Property)
{
    Property property;
    string name; /// Name of the function member
    Document result;
    mixin HiBONRecord!();
}

enum isInfo(alias I) = __traits(isSame, TemplateOf!I, Info);

struct BehaviourGroup(Property) if (isOneOf!(Property, UniqueBehaviourProperties))
{
    Info!Property info;
    @Label(VOID, true) Info!And[] ands;
    mixin HiBONRecord!();
}

enum isBehaviourGroup(alias I) = __traits(isSame, TemplateOf!I, BehaviourGroup);

struct ScenarioGroup
{
    Info!Scenario info;
    BehaviourGroup!(Given) given;
    @Label(VOID, true) BehaviourGroup!(Then) then;
    BehaviourGroup!(When) when;
    mixin HiBONRecord!();
}

struct FeatureGroup
{
    Info!Feature info;
    ScenarioGroup[] scenarios;
    mixin HiBONRecord!();
}

version (unittest)
{
    private import tagion.behaviour.BehaviourUnittest;
}
/// All behaviour-properties of a Scenario
alias BehaviourProperties = AliasSeq!(Given, And, When, Then);
/// The behaviour-properties which only occurrences once in a Scenario
alias UniqueBehaviourProperties = Erase!(And, BehaviourProperties);

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

template getMemberAlias(string main, string name)
{
    enum code = format!q{alias getMemberAlias=%s.%s;}(main, name);
    mixin(code);
}

static unittest
{
    static assert(isCallable!(getMemberAlias!(Some_awesome_feature.stringof, "is_debited")));
}

template getAllCallables(T) if (is(T == class) || is(T == struct))
{
    alias all_members = aliasSeqOf!([__traits(allMembers, T)]);
    alias all_members_as_aliases = staticMap!(ApplyLeft!(getMemberAlias, T.stringof), all_members);
    alias getAllCallables = Filter!(isCallable, all_members_as_aliases);
}

static unittest
{ // Test of getAllCallable
    alias all_callables = getAllCallables!Some_awesome_feature;
    static assert(all_callables.length == 13);
    static assert(allSatisfy!(isCallable, all_callables));
}

template hasBehaviours(alias T) if (isCallable!T)
{
    alias hasProperty = ApplyLeft!(hasUDA, T);
    enum hasBehaviours = anySatisfy!(hasProperty, BehaviourProperties);
}

///
static unittest
{
    static assert(hasBehaviours!(Some_awesome_feature.is_valid));
    static assert(!hasBehaviours!(Some_awesome_feature.helper_function));
}

template getBehaviours(T) if (is(T == class) || is(T == struct))
{
    alias get_all_callable = getAllCallables!T;
    alias getBehaviours = Filter!(hasBehaviours, get_all_callable);
}

static unittest
{ // Test of getBehaviours
    alias behaviours = getBehaviours!Some_awesome_feature;
    static assert(behaviours.length == 6);
    static assert(allSatisfy!(isCallable, behaviours));
    static assert(allSatisfy!(hasBehaviours, behaviours));
}

/**
   This template get the behaviour with the behaviour-Property from a Behaviour object
   Returns: The function with the behaviour-Property
   The function fails if there is more than one behaviour with this behaviour
   and returns void if no behaviour-Property has been found
 */
template getBehaviour(T, Property) if (is(T == class) || is(T == struct))
{
    alias behaviours = getBehaviours!T;
    alias behaviour_with_property = Filter!(ApplyRight!(hasUDA, Property), behaviours);
    static assert(behaviour_with_property.length <= 1,
        format!"More than 1 behaviour %s has been declared in %s"(Property.stringof, T.stringof));
    static if (behaviour_with_property.length is 1)
    {
        alias getBehaviour = behaviour_with_property[0];
    }
    else
    {
        alias getBehaviour = void;
    }

}

unittest
{
    alias behaviour_with_given = getBehaviour!(Some_awesome_feature, Given);
    static assert(isCallable!(behaviour_with_given));
    static assert(hasUDA!(behaviour_with_given, Given));
    static assert(is(getBehaviour!(Some_awesome_feature_bad_format_missing_given, Given) == void));

    alias behaviour_with_when = getBehaviour!(Some_awesome_feature, When);
    static assert(isCallable!(behaviour_with_when));
    static assert(hasUDA!(behaviour_with_when, When));

}

enum hasProperty(alias T, Property) = !is(getBehaviour!(T, Property) == void);

unittest
{
    static assert(hasProperty!(Some_awesome_feature, Then));
    static assert(!hasProperty!(Some_awesome_feature_bad_format_missing_given, Given));
}

template getProperty(alias T)
{
    alias getUDAsProperty = ApplyLeft!(getUDAs, T);
    alias all_behaviour_properties = staticMap!(getUDAsProperty, BehaviourProperties);
    static assert(all_behaviour_properties.length <= 1,
        format!"The behaviour %s has more than one property %s"(T.strinof, all_behaviour_properties
            .stringof));
    static if (all_behaviour_properties.length is 1)
    {
        alias getProperty = all_behaviour_properties[0];
    }
    else
    {
        alias getProperty = void;
    }
}

unittest
{
    alias properties = getProperty!(Some_awesome_feature.request_cash);
    static assert(is(typeof(properties) == When));
    static assert(is(getProperty!(Some_awesome_feature.helper_function) == void));
}

enum hasProperty(alias T) = !is(getProperty!(T) == void);

unittest
{
    static assert(hasProperty!(Some_awesome_feature.request_cash));
    static assert(!(hasProperty!(Some_awesome_feature.helper_function)));
}

protected template _getUnderBehaviour(bool property_found, Property, L...)
{
    static if (L.length == 0)
    {
        alias _getUnderBehaviour = AliasSeq!();
    }
    else static if (property_found)
    {
        alias behavior_property = getProperty!(L[0]);
        alias other_unique_propeties = Erase!(Property, UniqueBehaviourProperties);
        alias behavior_property_type = typeof(behavior_property);
        static if (isOneOf!(behavior_property_type, other_unique_propeties))
        {
            alias _getUnderBehaviour = AliasSeq!();
        }
        else
        {
            alias _getUnderBehaviour = AliasSeq!(
                L[0],
                _getUnderBehaviour!(property_found, Property, L[1 .. $])
            );
        }
    }
    else static if (is(typeof(getProperty!(L[0])) == Property))
    {
        alias _getUnderBehaviour = _getUnderBehaviour!(true, Property, L[1 .. $]);
    }
    else
    {
        alias _getUnderBehaviour = _getUnderBehaviour!(property_found, Property, L[1 .. $]);
    }
}

template getUnderBehaviour(T, Property) if (is(T == class) || is(T == struct))
{
    alias behaviours = getBehaviours!T;

    alias getUnderBehaviour = _getUnderBehaviour!(false, Property, behaviours);
}

unittest
{
    alias under_behaviour_of_given = getUnderBehaviour!(Some_awesome_feature, Given);
    static assert(under_behaviour_of_given.length is 2);
    static assert(getProperty!(under_behaviour_of_given[0]) == And("the account is in credit"));
    static assert(getProperty!(under_behaviour_of_given[1]) == And("the dispenser contains cash"));

    alias under_behaviour_of_when = getUnderBehaviour!(Some_awesome_feature, When);
    static assert(under_behaviour_of_when.length is 0);

    alias under_behaviour_of_then = getUnderBehaviour!(Some_awesome_feature, Then);
    assert(getProperty!(under_behaviour_of_then[0]) == And("the cash is dispensed"));
    static assert(under_behaviour_of_then.length is 1);

}

enum isScenario(T) = hasUDA!(T, Scenario);

static unittest
{
    static assert(isScenario!Some_awesome_feature);
}

enum feature_name = "feature";

template isFeature(alias M) if (__traits(isModule, M))
{
    import std.algorithm.searching : any;

    enum feature_found = [__traits(allMembers, M)].any!(a => a == feature_name);
    static if (feature_found)
    {
        enum obtainFeature = __traits(getMember, M, feature_name);
        enum isFeature = is(typeof(obtainFeature) == Feature);
    }
    else
    {
        enum isFeature = false;
    }
}

//
unittest
{
    static assert(isFeature!(tagion.behaviour.BehaviourUnittest));
    static assert(!isFeature!(tagion.behaviour.BehaviourBase));
}

/**
   Returns:
   The Feature of a Module
   If the Modules does not contain a feature then a false is returned
 */
template obtainFeature(alias M) if (__traits(isModule, M))
{
    static if (isFeature!M)
    {
        enum obtainFeature = __traits(getMember, M, feature_name);
    }
    else
    {
        enum obtainFeature = false;
    }
}

///
unittest
{ // The obtainFeature of a module
    static assert(obtainFeature!(tagion.behaviour.BehaviourUnittest) ==
            Feature(
                "Some awesome feature should print some cash out of the blue", null));
    static assert(!obtainFeature!(tagion.behaviour.BehaviourBase));

}

protected template _Scenarios(alias M, string[] names)
{
    static if (names.length is 0)
    {
        alias _Scenarios = AliasSeq!();
    }
    else
    {
        enum compiles = __traits(compiles, getMemberAlias!(moduleName!M, names[0]));
        static if (compiles)
        {
            enum is_scenario = hasUDA!(member, Scenario);

            alias member = getMemberAlias!(moduleName!M, names[0]);
        }
        else
        {
            enum is_scenario = false;
            alias member = void;
        }
        static if (is_scenario && (is(member == class) || is(member == struct)))
        {
            alias _Scenarios =
                AliasSeq!(
                    member,
                    _Scenarios!(M, names[1 .. $])
                );
        }
        else
        {
            alias _Scenarios = _Scenarios!(M, names[1 .. $]);
        }
    }
}

template Scenarios(alias M) if (__traits(isModule, M))
{
    alias Scenarios = _Scenarios!(M, [__traits(allMembers, M)]);
}

///
static unittest
{ //
    alias scenarios = Scenarios!(tagion.behaviour.BehaviourUnittest);
    alias expected_scenarios = AliasSeq!(
        Some_awesome_feature,
        Some_awesome_feature_bad_format_double_property,
        Some_awesome_feature_bad_format_missing_given,
        Some_awesome_feature_bad_format_missing_then);

    static assert(scenarios.length == expected_scenarios.length);
    static assert(__traits(isSame, scenarios, expected_scenarios));
}

template getScenario(T) if (is(T == class) || is(T == struct))
{
    enum scenario_attr = getUDAs!(T, Scenario);
    pragma(msg, "scenario_attr ", scenario_attr);
    static assert(scenario_attr.length <= 1,
        format!"%s is not a %s"(T.stringof, Scenario.stringof));
    static if (scenario_attr.length is 1)
    {
        enum getScenario = scenario_attr[0];
    }
    else
    {
        enum getScenario = false;
    }
    pragma(msg, "getScenario ", getScenario);
}

static unittest
{
    enum scenario = getScenario!Some_awesome_feature;
    static assert(is(typeof(scenario) == Scenario));
    static assert(scenario is Scenario("Some awesome money printer", null));
}

version (unittest)
{
    import std.stdio;
    import std.algorithm.iteration : map, joiner;
    import std.algorithm.comparison : equal;
    import std.range : zip, only;
    import std.typecons;
    import std.array;
}
