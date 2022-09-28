/// \file BehaviourFeature.d
module tagion.behaviour.BehaviourFeature;

/**
 * Handels all BDD information concerning the Feature
 * Comments, description, function-names, scenarios and actions
 */

import std.traits;
import std.meta : AliasSeq, Filter, aliasSeqOf, ApplyLeft, ApplyRight,
    allSatisfy, anySatisfy, Alias, Erase, aliasSeqOf;
import std.format;
import std.algorithm.searching : any;

import tagion.basic.Basic : isOneOf;
import tagion.hibon.HiBONRecord;
import tagion.hibon.Document : Document;

/* 
 * Set the common propery for
 * Feature, Scenario and the Actions (Given,When,Then and But)
 */
@safe mixin template Property()
{
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
struct Feature
{
    mixin Property;
}

struct Scenario
{
    mixin Property;
}

struct Given
{
    mixin Property;
}

struct When
{
    mixin Property;
}

struct Then
{
    mixin Property;
}

struct But
{
    mixin Property;
}
/** For check description */
enum isDescriptor(T) = hasMember!(T, "description");

/**
 * \struct Info
 * Contains the information of for the Protorty including the name id of the property
 */
struct Info(alias Property)
{
    /** Feature property */
    Property property;
    /** Name of the function member, scenario call or feature module */
    string name;
    /** Result in document*/
    Document result;
    mixin HiBONRecord!();
}

/** Returns true if I is a Info template */
enum isInfo(alias I) = __traits(isSame, TemplateOf!I, Info);

/**
 * \struct ActionGroup
 * The Action group contains a list of acrion with the property defined which is a part of the 
 * behaviour property
 */
struct ActionGroup(Property) if (isOneOf!(Property, BehaviourProperties))
{
    /** Feature properties */
    Info!Property[] infos;
    mixin HiBONRecord!();
}

/// Returns: true if I is a ActionGroup
enum isActionGroup(alias I) = __traits(isSame, TemplateOf!I, ActionGroup);

/**
 * \struct ScenarioGroup
 * Contains all infomation of a scenario
 * the class name of the scenario and the description
 * it also contains all the action groups of the scenario
 */
@safe struct ScenarioGroup
{
    @("Scenario") Info!Scenario info;
    /** Given actions */
    ActionGroup!(Given) given;
    /** When actions */
    @Label(VOID, true) ActionGroup!(When) when;
    /** Then actions */
    ActionGroup!(Then) then;
    /** But actions */
    @Label(VOID, true) ActionGroup!(But) but;
    mixin HiBONRecord!();
}

/**
 * \struct FeatureGroup
 * Conatins add the information of a Feature
 */
@safe struct FeatureGroup
{
    /** Info feature */
    Info!Feature info;
    /** Array of scenarios */
    ScenarioGroup[] scenarios;
    mixin HiBONRecord!();
}

/** All behaviour-properties of a Scenario */
alias BehaviourProperties = AliasSeq!(Given, When, Then, But);
/** The behaviour-properties which only occurrences once in a Scenario */
alias MandatoryBehaviourProperties = Erase!(When, Erase!(But, BehaviourProperties));

/** 
 * Used to get method in a scenario class
 * @param T - file to get method
 * @param name - module name
 * @return method in a scenario class
 */
template getMethod(alias T, string name)
{
    alias method = __traits(getOverloads, T, name);
    static if (method.length > 0)
    {
        alias getMethod = method[0];
    }
    else
    {
        alias getMethod = void;
    }
}

/** 
 * Used to get members of an object
 * @param T - feature name
 * @return an alias-sequency of all the callable members of an object
 */
template getAllCallables(T) if (is(T == class) || is(T == struct))
{
    alias all_members = aliasSeqOf!([__traits(allMembers, T)]);
    alias all_members_as_aliases = staticMap!(ApplyLeft!(getMethod, T), all_members);
    alias getAllCallables = Filter!(isCallable, all_members_as_aliases);
}

/** 
 * Used to check Action
 * @param T - Action to check
 * @return true if the alias T is an Action
 */
template hasActions(alias T) if (isCallable!T)
{
    alias hasProperty = ApplyLeft!(hasUDA, T);
    enum hasActions = anySatisfy!(hasProperty, BehaviourProperties);
}

/** 
 * Used to get all the actions in a scenario
 * @param T - scenario to get actions
 * @return all the actions in a scenario
 */
template getAllActions(T) if (is(T == class) || is(T == struct))
{
    alias get_all_callable = getAllCallables!T;
    alias getAllActions = Filter!(hasActions, get_all_callable);
}

/** 
 * Template get the action with the behaviour-Property from a Behaviour object
 * The function fails if there is more than one behaviour with this behaviour
 * and returns void if no behaviour-Property has been found
 * @param T - Behaviour object
 * @return The function with the behaviour-Property
 */
template getActions(T, Property) if (is(T == class) || is(T == struct))
{
    alias behaviours = getAllActions!T;
    alias behaviour_with_property = Filter!(ApplyRight!(hasUDA, Property), behaviours);
    static if (behaviour_with_property.length > 0)
    {
        alias getActions = behaviour_with_property;
    }
    else
    {
        alias getActions = void;
    }

}

/** Returns true if T has the Property */
enum hasProperty(alias T, Property) = !is(getActions!(T, Property) == void);

/**
 * Get the action propery of the alias T
 * @param T - alias to get property
 * @return the behaviour property of T and void if T does not have a behaviour property
 */
template getProperty(alias T)
{
    alias getUDAsProperty = ApplyLeft!(getUDAs, T);
    alias all_behaviour_properties = staticMap!(getUDAsProperty, BehaviourProperties);
    static assert(all_behaviour_properties.length <= 1,
            format!"The behaviour %s has more than one property %s"(T.strinof,
                all_behaviour_properties.stringof));
    static if (all_behaviour_properties.length is 1)
    {
        alias getProperty = all_behaviour_properties[0];
    }
    else
    {
        alias getProperty = void;
    }
}

/** Returns true of T is a Scenario */
enum isScenario(T) = hasUDA!(T, Scenario);

/** Default enum name of an Feature module */
enum feature_name = "feature";

/** 
 * Used to check module for fetute
 * @param M - the module
 * @return true if M is a feature module
 */
template isFeature(alias M) if (__traits(isModule, M))
{
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

/**
 * Used to get the Feature of a Module
 * @param M - the module
 * @return the Feature of a Module
 * If the Modules does not contain a feature then a false is returned
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

/** Helper template for Scenarios */
protected template _Scenarios(alias M, string[] names) if (isFeature!M)
{
    static if (names.length is 0)
    {
        alias _Scenarios = AliasSeq!();
    }
    else
    {
        alias member = __traits(getMember, M, names[0]);
        enum is_object = is(member == class) || is(member == struct);
        static if (is_object)
        {
            enum is_scenario = hasUDA!(member, Scenario);
        }
        else
        {
            enum is_scenario = false;
        }
        static if (is_scenario)
        {
            alias _Scenarios = AliasSeq!(member, _Scenarios!(M, names[1 .. $]));
        }
        else
        {
            alias _Scenarios = _Scenarios!(M, names[1 .. $]);
        }
    }
}

/**
 * Used to get all scenarios in the feature module M
 * @param M - the module
 * @return all scenarios in the feature module M
 */
template Scenarios(alias M) if (isFeature!M)
{
    alias Scenarios = _Scenarios!(M, [__traits(allMembers, M)]);
}

/**
 * Used to get the Scenario
 * @returns the Scenario UDA of T and if T is not a Scenario then result is false 
*/
template getScenario(T) if (is(T == class) || is(T == struct))
{
    enum scenario_attr = getUDAs!(T, Scenario);
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
}

@safe unittest
{
    import BehaviourUnittest = tagion.behaviour.BehaviourUnittest;

    /// getActions_function_good_bad_case
    {
        alias behaviour_with_given = getActions!(BehaviourUnittest.Some_awesome_feature, Given);
        static assert(allSatisfy!(isCallable, behaviour_with_given));

        static assert(allSatisfy!(ApplyRight!(hasUDA, Given), behaviour_with_given));
        static assert(is(getActions!(BehaviourUnittest.Some_awesome_feature_bad_format_missing_given,
                Given) == void));

        alias behaviour_with_when = getActions!(BehaviourUnittest.Some_awesome_feature, When);
        static assert(isCallable!(behaviour_with_when));
        static assert(hasUDA!(behaviour_with_when, When));

    }

    /// hasProperty_good_bad_case
    {
        static assert(hasProperty!(BehaviourUnittest.Some_awesome_feature, Then));
        static assert(!hasProperty!(
                BehaviourUnittest.Some_awesome_feature_bad_format_missing_given, Given));
    }

    /// getProperty_function_good_bad_case
    {
        alias properties = getProperty!(BehaviourUnittest.Some_awesome_feature.request_cash);
        static assert(is(typeof(properties) == When));
        static assert(is(getProperty!(
                BehaviourUnittest.Some_awesome_feature.helper_function) == void));
    }

    /// getProperty_function_good_bad_case
    {
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
        static assert(getProperty!(behaviour_of_but[0]) == But(
                "if the Customer does not take his card, then the card must be swollowed"));
    }

    /// isScenario_function_good_bad_case
    {
        static assert(isScenario!(BehaviourUnittest.Some_awesome_feature));
        static assert(!isScenario!(BehaviourUnittest.This_is_not_a_scenario));
    }

    /// isFeature_function_good_bad_case
    {
        static assert(isFeature!(tagion.behaviour.BehaviourUnittest));
        static assert(!isFeature!(tagion.behaviour.BehaviourFeature));
    }

    /// obtainFeature_function_good_bad_case
    {

        static assert(obtainFeature!(tagion.behaviour.BehaviourUnittest) == Feature(
                "Some awesome feature should print some cash out of the blue", null));
        static assert(!obtainFeature!(tagion.behaviour.BehaviourFeature));
    }

    /// AliasSeq_good_bad_case
    {
        alias scenarios = Scenarios!(tagion.behaviour.BehaviourUnittest);
        alias expected_scenarios = AliasSeq!(BehaviourUnittest.Some_awesome_feature,
                BehaviourUnittest.Some_awesome_feature_bad_format_double_property,
                BehaviourUnittest.Some_awesome_feature_bad_format_missing_given,
                BehaviourUnittest.Some_awesome_feature_bad_format_missing_then);

        static assert(scenarios.length == expected_scenarios.length);
        static assert(__traits(isSame, scenarios, expected_scenarios));
    }

    /// getMethod_function_good_case
    {
        static assert(isCallable!(getMethod!(BehaviourUnittest.Some_awesome_feature,
                "is_debited")));
        static assert(!isCallable!(getMethod!(BehaviourUnittest.Some_awesome_feature, "count")));
    }

    /// getAllCallable_good_bad_case
    {
        alias all_callables = getAllCallables!(BehaviourUnittest.Some_awesome_feature);
        static assert(all_callables.length == 13);
        static assert(allSatisfy!(isCallable, all_callables));
    }

    /// hasActions_good_bad_case
    {
        static assert(hasActions!(BehaviourUnittest.Some_awesome_feature.is_valid));
        static assert(!hasActions!(BehaviourUnittest.Some_awesome_feature.helper_function));
    }

    /// getAllActions_good_case
    {
        alias actions = getAllActions!(BehaviourUnittest.Some_awesome_feature);
        static assert(actions.length == 7);
        static assert(allSatisfy!(isCallable, actions));
        static assert(allSatisfy!(hasActions, actions));
    }

    // getScenario_good_bad_case
    {
        enum scenario = getScenario!(BehaviourUnittest.Some_awesome_feature);
        static assert(is(typeof(scenario) == Scenario));
        static assert(scenario is Scenario("Some awesome money printer", null));
        enum not_a_scenario = getScenario!(BehaviourUnittest.This_is_not_a_scenario);
        static assert(!not_a_scenario);
    }
}
