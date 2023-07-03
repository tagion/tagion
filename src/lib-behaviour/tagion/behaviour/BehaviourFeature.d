/**
 * Handels all BDD information concerning the Feature
 *    Comments, description, function-names, scenarios and actions
 */
module tagion.behaviour.BehaviourFeature;

import std.traits;
import std.meta : AliasSeq, Filter, aliasSeqOf, ApplyLeft, ApplyRight, allSatisfy, anySatisfy, Alias, Erase, aliasSeqOf;
import std.format;
import std.typecons;
import tagion.basic.traits : hasOneMemberUDA;
import tagion.basic.basic : isOneOf, staticSearchIndexOf;

import tagion.hibon.HiBONRecord;
import tagion.hibon.Document;

/* 
 * Set the common property for
 * Feature, Scenario and the Actions (Given,When,Then and But)
 */
@safe:
mixin template Property() {
    string description;
    @label(VOID, true) string[] comments;
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

@recordType("Feature")
struct Feature {
    mixin Property;
}

struct Scenario {
    mixin Property;
}

/// Action property for Given
struct Given {
    mixin Property;
}

/// Action property for When
struct When {
    mixin Property;
}

/// Action property for Then 
struct Then {
    mixin Property;
}

/// Action property for But 
struct But {
    mixin Property;
}

enum isDescriptor(T) = hasMember!(T, "description");

/* 
 * Contains the information for the Protorty including the name id and the result of the Property
* The Property is as a general container for the Feature, Scenario and Actions
 */
struct Info(alias Property) {
    Property property; /// The property is a Feature, Scenario or an Action
    string name; /// Name of the function member, scenario call or feature module
    Document result; /// The result after execution of the property (See BehaviourResult)
    mixin HiBONRecord!();
}

/// Returns: true if I is a Info template
enum isInfo(alias I) = __traits(isSame, TemplateOf!I, Info);

/**
 * The Action group contains a list of acrion with the property defined which is a part of the 
 * behaviour property
 */
struct ActionGroup(Property) if (isOneOf!(Property, ActionProperties)) {
    Info!Property[] infos;
    mixin HiBONRecord!();
}

/// Returns: true if I is a ActionGroup
enum isActionGroup(alias I) = __traits(isSame, TemplateOf!I, ActionGroup);

/** 
 * Contains all information of a scenario
 * the class name of the scenario and the description
 * it also contains all the action groups of the scenario
 */
@safe
struct ScenarioGroup {
    @("Scenario") Info!Scenario info;
    ActionGroup!(Given) given; /// Given actions
    @label(VOID, true) ActionGroup!(When) when; /// When actions
    ActionGroup!(Then) then; /// Then actions
    @label(VOID, true) ActionGroup!(But) but; /// But actions
    mixin HiBONRecord!();
}

/** 
 * Contains all the sceanrio groups and information of the Feature
 */
@safe
struct FeatureGroup {
    @label(VOID, true) string alternative;
    Info!Feature info; /// Information of the Feature
    ScenarioGroup[] scenarios; /// This all the information of each Sceanrio
    mixin HiBONRecord!();
}

/// All action-properties of a Scenario
alias ActionProperties = AliasSeq!(Given, When, Then, But);
/// All mandatory actions of a Scenario (Given, Then)
alias MandatoryActionProperties = Erase!(When, Erase!(But, ActionProperties));

/**
 * Params:
* T = Scenario class
* name = the action member function
 * Returns: method in a scenario class
 *          void if no member has been found
 */
template getMethod(alias T, string name) {
    alias method = __traits(getOverloads, T, name);
    static if (method.length > 0) {
        alias getMethod = method[0];
    }
    else {
        alias getMethod = void;
    }
}

// Check of the getMethod 
static unittest {
    static assert(isCallable!(getMethod!(BehaviourUnittest.Some_awesome_feature, "is_debited")));
    static assert(!isCallable!(getMethod!(BehaviourUnittest.Some_awesome_feature, "count")));
}

/**
 * Returns: an alias-sequency of all the callable members of an object/Scenario
 */
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

/**
 * Returns: true if the alias T is an Action
 */
template hasActions(alias T) if (isCallable!T) {
    alias hasProperty = ApplyLeft!(hasOneMemberUDA, T);
    enum hasActions = anySatisfy!(hasProperty, ActionProperties);
}

// Check if a function is an action or not
static unittest {
    static assert(hasActions!(BehaviourUnittest.Some_awesome_feature.is_valid));
    static assert(!hasActions!(BehaviourUnittest.Some_awesome_feature.helper_function));
}

/**
Returns:
all the actions in a scenario
*/
template getAllActions(T) if (is(T == class) || is(T == struct)) {
    alias get_all_callable = getAllCallables!T;
    alias getAllActions = Filter!(hasActions, get_all_callable);
}

///
static unittest { // Test of getAllActions
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
template getActions(T, Property) if (is(T == class) || is(T == struct)) {
    alias behaviours = getAllActions!T;
    alias behaviour_with_property = Filter!(ApplyRight!(hasOneMemberUDA, Property), behaviours);
    static if (behaviour_with_property.length > 0) {
        alias getActions = behaviour_with_property;
    }
    else {
        alias getActions = void;
    }

}

///
unittest {
    alias behaviour_with_given = getActions!(BehaviourUnittest.Some_awesome_feature, Given);
    static assert(allSatisfy!(isCallable, behaviour_with_given));

    static assert(allSatisfy!(ApplyRight!(hasOneMemberUDA, Given), behaviour_with_given));
    static assert(is(getActions!(BehaviourUnittest.Some_awesome_feature_bad_format_missing_given, Given) == void));

    alias behaviour_with_when = getActions!(BehaviourUnittest.Some_awesome_feature, When);
    static assert(isCallable!(behaviour_with_when));
    static assert(hasOneMemberUDA!(behaviour_with_when, When));

}

/// Returns: true if T has the Property
enum hasProperty(alias T, Property) = !is(getActions!(T, Property) == void);

///
unittest {
    static assert(hasProperty!(BehaviourUnittest.Some_awesome_feature, Then));
    static assert(!hasProperty!(BehaviourUnittest.Some_awesome_feature_bad_format_missing_given, Given));
}

/**
* Get the action propery of the alias T
* Returns: The behaviour property of T and void if T does not have a behaviour property
*/
template getProperty(alias T) {
    import tagion.basic.traits : getMemberUDAs;

    alias getUDAsProperty = ApplyLeft!(getMemberUDAs, T);
    alias all_behaviour_properties = staticMap!(getUDAsProperty, ActionProperties);
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

// Test of the getActions and check that the action-property is correct
@safe
unittest {
    alias behaviour_of_given = getActions!(BehaviourUnittest.Some_awesome_feature, Given);
    static assert(behaviour_of_given.length is 3);
    static assert(getProperty!(behaviour_of_given[0]) == Given("the card is valid"));
    static assert(getProperty!(behaviour_of_given[1]) == Given("the account is in credit"));
    static assert(getProperty!(behaviour_of_given[2]) == Given("the dispenser contains cash"));

    alias behaviour_of_when = getActions!(BehaviourUnittest.Some_awesome_feature, When);
    static assert(behaviour_of_when.length is 1);
    static assert(getProperty!(behaviour_of_when[0]) == When("the Customer request cash"));

    alias behaviour_of_then = getActions!(BehaviourUnittest.Some_awesome_feature, Then);
    static assert(behaviour_of_then.length is 2);
    static assert(getProperty!(behaviour_of_then[0]) == Then("the account is debited"));
    static assert(getProperty!(behaviour_of_then[1]) == Then("the cash is dispensed"));

    alias behaviour_of_but = getActions!(BehaviourUnittest.Some_awesome_feature, But);
    static assert(behaviour_of_but.length is 1);
    static assert(getProperty!(behaviour_of_but[0]) ==
        But("if the Customer does not take his card, then the card must be swollowed"));
}

///Returns: true of T is a Scenario
enum isScenario(T) = (is(T == struct) || is(T == class)) && hasUDA!(T, Scenario);

///
static unittest {
    static assert(isScenario!(BehaviourUnittest.Some_awesome_feature));
    static assert(!isScenario!(BehaviourUnittest.This_is_not_a_scenario));
}

enum feature_name = "feature"; /// Default enum name of an Feature module

/** 
 * Params:
 *   M = the module
*	Returns: true if M is a feature module
*/
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

/// Helper template for Scenarios
protected template _Scenarios(alias M, string[] names) if (isFeature!M) {
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

/**
* Returns: An alias-sequency of all scenarios in the feature module M
*/
template Scenarios(alias M) if (isFeature!M) {
    alias Scenarios = _Scenarios!(M, [__traits(allMembers, M)]);
}

///
static unittest { //
    import tagion.behaviour.BehaviourUnittest;

    alias scenarios = Scenarios!(tagion.behaviour.BehaviourUnittest);
    alias expected_scenarios = AliasSeq!(
            Some_awesome_feature,
            Some_awesome_feature_bad_format_double_property,
            Some_awesome_feature_bad_format_missing_given,
            Some_awesome_feature_bad_format_missing_then);

    static assert(scenarios.length == expected_scenarios.length);
    static assert(__traits(isSame, scenarios, expected_scenarios));
}

/**
* Returns: The Scenario UDA of T and if T is not a Scenario then result is false 
*/
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

// Checks the getScenario
static unittest {
    import tagion.behaviour.BehaviourUnittest;

    enum scenario = getScenario!(Some_awesome_feature);
    static assert(is(typeof(scenario) == Scenario));
    static assert(scenario is Scenario("Some awesome money printer", null));
    enum not_a_scenario = getScenario!(This_is_not_a_scenario);
    static assert(!not_a_scenario);
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
