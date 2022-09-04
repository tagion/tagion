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

/// All behaviour-properties of a Scenario
alias BehaviourProperties = AliasSeq!(Given, When, Then, But);
/// The behaviour-properties which only occurrences once in a Scenario
alias MandatoryBehaviourProperties = Erase!(When, Erase!(But, BehaviourProperties));

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
    static assert(isCallable!(getMethod!(BehaviourUnittest.Some_awesome_feature, "is_debited")));
    static assert(!isCallable!(getMethod!(BehaviourUnittest.Some_awesome_feature, "count")));
}

template getAllCallables(T) if (is(T == class) || is(T == struct)) {
    alias all_members = aliasSeqOf!([__traits(allMembers, T)]);
    alias all_members_as_aliases = staticMap!(ApplyLeft!(getMethod, T), all_members);
    alias getAllCallables = Filter!(isCallable, all_members_as_aliases);
}

static unittest { // Test of getAllCallable
    import tagion.behaviour.BehaviourUnittest;

    alias all_callables = getAllCallables!(Some_awesome_feature);
    static assert(all_callables.length == 13);
    static assert(allSatisfy!(isCallable, all_callables));
}

template hasActions(alias T) if (isCallable!T) {
    alias hasProperty = ApplyLeft!(hasUDA, T);
    enum hasActions = anySatisfy!(hasProperty, BehaviourProperties);
}

// Check if a function is an action or not
static unittest {
    static assert(hasActions!(BehaviourUnittest.Some_awesome_feature.is_valid));
    static assert(!hasActions!(BehaviourUnittest.Some_awesome_feature.helper_function));
}


// Collects all the actions in a scenario
template getAllActions(T) if (is(T == class) || is(T == struct)) {
    alias get_all_callable = getAllCallables!T;
    alias getAllActions = Filter!(hasActions, get_all_callable);
}

///
static unittest { // Test of getActionss
    alias actions = getAllActions!(BehaviourUnittest.Some_awesome_feature);
    static assert(actions.length == 7);
    static assert(allSatisfy!(isCallable, actions));
    static assert(allSatisfy!(hasActions, actions));
}

/**
   This template get the action with the behaviour-Property from a Behaviour object
   Returns: The function with the behaviour-Property
   The function fails if there is more than one behaviour with this behaviour
   and returns void if no behaviour-Property has been found
 */
template getAction(T, Property) if (is(T == class) || is(T == struct)) {
    alias behaviours = getAllActions!T;
    alias behaviour_with_property = Filter!(ApplyRight!(hasUDA, Property), behaviours);
    static if (behaviour_with_property.length > 0) {
        alias getAction = behaviour_with_property;
    }
    else {
        alias getAction = void;
    }

}

///
unittest {
    alias behaviour_with_given = getAction!(BehaviourUnittest.Some_awesome_feature, Given);
    static assert(allSatisfy!(isCallable, behaviour_with_given));

    static assert(allSatisfy!(ApplyRight!(hasUDA, Given), behaviour_with_given));
    static assert(is(getAction!(BehaviourUnittest.Some_awesome_feature_bad_format_missing_given, Given) == void));

    alias behaviour_with_when = getAction!(BehaviourUnittest.Some_awesome_feature, When);
    static assert(isCallable!(behaviour_with_when));
    static assert(hasUDA!(behaviour_with_when, When));

}

/// Returns: true if T has the Property
enum hasProperty(alias T, Property) = !is(getAction!(T, Property) == void);

///
unittest {
    static assert(hasProperty!(BehaviourUnittest.Some_awesome_feature, Then));
    static assert(!hasProperty!(BehaviourUnittest.Some_awesome_feature_bad_format_missing_given, Given));
}

	/**
	  Get the action propery of the alias T
	 Returns: The behaviour property of T and void if T does not have a behaviour property
	 */
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

/// Examples: How get the behaviour property
unittest {
    alias properties = getProperty!(BehaviourUnittest.Some_awesome_feature.request_cash);
    static assert(is(typeof(properties) == When));
    static assert(is(getProperty!(BehaviourUnittest.Some_awesome_feature.helper_function) == void));
}

	// Test of the getAction of a specific behaviour property
@safe
unittest {
    alias behaviour_of_given = getAction!(BehaviourUnittest.Some_awesome_feature, Given);
    static assert(behaviour_of_given.length is 3);
    static assert(getProperty!(behaviour_of_given[0]) == Given("the card is valid"));
    static assert(getProperty!(behaviour_of_given[1]) == Given("the account is in credit"));
    static assert(getProperty!(behaviour_of_given[2]) == Given("the dispenser contains cash"));

    alias behaviour_of_when = getAction!(BehaviourUnittest.Some_awesome_feature, When);
    static assert(behaviour_of_when.length is 1);
    static assert(getProperty!(behaviour_of_when[0]) == When("the Customer request cash"));

    alias behaviour_of_then = getAction!(BehaviourUnittest.Some_awesome_feature, Then);
    static assert(behaviour_of_then.length is 2);
    static assert(getProperty!(behaviour_of_then[0]) == Then("the account is debited"));
    static assert(getProperty!(behaviour_of_then[1]) == Then("the cash is dispensed"));

    alias behaviour_of_but = getAction!(BehaviourUnittest.Some_awesome_feature, But);
    static assert(behaviour_of_but.length is 1);
    static assert(getProperty!(behaviour_of_but[0]) ==
            But("if the Customer does not take his card, then the card must be swollowed"));
}

enum isScenario(T) = hasUDA!(T, Scenario);

///
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
        alias member = __traits(getMember, M, names[0]);
        enum is_object = is(member == class) || is(member == struct);
        static if (is_object) {
            enum is_scenario = hasUDA!(member, Scenario);
        }
        else {
            enum is_scenario = false;
        }
        static if (is_scenario) {
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
    static assert(scenario_attr.length <= 1,
            format!"%s is not a %s"(T.stringof, Scenario.stringof));
    static if (scenario_attr.length is 1) {
        enum getScenario = scenario_attr[0];
    }
    else {
        enum getScenario = false;
    }
}

static unittest {
    import tagion.behaviour.BehaviourUnittest;

    enum scenario = getScenario!(Some_awesome_feature);
    static assert(is(typeof(scenario) == Scenario));
    static assert(scenario is Scenario("Some awesome money printer", null));
}

version (unittest) {
    import BehaviourUnittest = tagion.behaviour.BehaviourUnittest;
    import std.stdio;
    import std.algorithm.iteration : map, joiner;
    import std.algorithm.comparison : equal;
    import std.range : zip, only;
    import std.typecons;
    import std.array;
}
