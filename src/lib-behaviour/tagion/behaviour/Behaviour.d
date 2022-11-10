module tagion.behaviour.Behaviour;

public import tagion.behaviour.BehaviourFeature;
import tagion.hibon.Document;

import std.traits;
import std.format;
import std.meta : AliasSeq;
import std.range : only;
import std.array : join;
import std.algorithm.searching : any, all;
import std.exception : assumeWontThrow;

import tagion.behaviour.BehaviourException;
import tagion.behaviour.BehaviourResult;
import tagion.basic.Types : FileExtension;
import tagion.hibon.HiBONRecord;
import tagion.basic.Basic : isOneOf;

/**
   Runs the scenario in Given, When, Then, But order
   Returns:
   The ScenarioGroup including the result of each action
*/
@safe
ScenarioGroup run(T)(T scenario) if (isScenario!T) {
    ScenarioGroup scenario_group = getScenarioGroup!T;
    try {
        // Mixin code to produce the action Given, When, Then, But
        alias memberCode = format!(q{
            // Scenario group      %1$s
            // Action propery info %2$s
            // Info index (i)      %3$d
            // Test scenario       %4$s
            // Test member         %5$s
            try {
                // Example.
                // scenario_group.when.info[i].result = scenario.member_function;
                %1$s.%2$s.infos[%3$d].result = %4$s.%5$s;
            }
            catch (Exception e) {
                // In case of an exception error the result is set to a BehaviourError
                // Example.
                // scemario_group.when.info[i].result = BehaviourError(e).toDoc;
                %1$s.%2$s.infos[%3$d].result= BehaviourError(e).toDoc;
            }
        }, string, string, size_t, string, string);
        import std.uni : toLower;

        

        .check(scenario !is null,
                format("The constructor must be called for %s before it's runned", T.stringof));
        static foreach (_Property; ActionProperties) {
            {
                alias all_actions = getActions!(T, _Property);
                static if (is(all_actions == void)) {
                    static assert(!isOneOf!(_Property, MandatoryActionProperties),
                            format("%s is missing a @%s action", T.stringof, _Property.stringof));
                }
                else {
                    // Traverse all the actions the scenario
                    static foreach (i, behaviour; all_actions) {
                        {
                            // This action_name is the action of the scenario
                            // The action is the lower case of Action type (ex. Given is given)
                            // See the definition of ScenarioGroup
                            enum action_name = __traits(identifier,
                                        typeof(getProperty!(behaviour))).toLower;
                            enum code = memberCode(
                                        scenario_group.stringof, action_name, i,
                                        scenario.stringof, __traits(identifier, behaviour));
                            // The memberCode is used here
                            mixin(code);
                        }
                    }
                }
            }
        }
        scenario_group.info.result = result_ok;
    }
    catch (Exception e) {
        scenario_group.info.result = BehaviourError(e).toDoc;
    }
    return scenario_group;
}

///Examples: How use the rub fuction on a feature
@safe
unittest {
    import std.algorithm.iteration : map;
    import std.algorithm.comparison : equal;
    import std.array;
    import tagion.behaviour.BehaviourUnittest;

    auto awesome = new Some_awesome_feature;
    const runner_result = run(awesome);
    auto expected = only(
            "tagion.behaviour.BehaviourUnittest.Some_awesome_feature.is_valid",
            "tagion.behaviour.BehaviourUnittest.Some_awesome_feature.in_credit",
            "tagion.behaviour.BehaviourUnittest.Some_awesome_feature.contains_cash",
            "tagion.behaviour.BehaviourUnittest.Some_awesome_feature.request_cash",
            "tagion.behaviour.BehaviourUnittest.Some_awesome_feature.is_debited",
            "tagion.behaviour.BehaviourUnittest.Some_awesome_feature.is_dispensed",
            "tagion.behaviour.BehaviourUnittest.Some_awesome_feature.swollow_the_card",
    )
        .map!(a => result(a));
    assert(awesome.count == 7);
    Document[] results;
    results ~= runner_result.given.infos
        .map!(info => info.result)
        .array;
    results ~= runner_result.when.infos
        .map!(info => info.result)
        .array;
    results ~= runner_result.then.infos
        .map!(info => info.result)
        .array;
    results ~= runner_result.but.infos
        .map!(info => info.result)
        .array;
    assert(equal(results, expected));
}

@safe
ScenarioGroup getScenarioGroup(T)() if (isScenario!T) {
    ScenarioGroup scenario_group;
    scenario_group.info.property = getScenario!T;
    scenario_group.info.name = T.stringof;
    static foreach (_Property; ActionProperties) {
        {
            alias behaviours = getActions!(T, _Property);
            static if (!is(behaviours == void)) {
                import std.uni : toLower;

                enum group_name = _Property.stringof.toLower;
                auto group = &__traits(getMember, scenario_group, group_name);
                group.infos.length = behaviours.length;
                static foreach (i, behaviour; behaviours) {
                    {
                        Info!_Property info;
                        info.property = getProperty!behaviour;
                        info.name = __traits(identifier, behaviour);
                        group.infos[i] = info;
                    }
                }
            }
        }
    }
    return scenario_group;
}

@safe
FeatureGroup getFeature(alias M)() if (isFeature!M) {
    FeatureGroup result;
    result.info.property = obtainFeature!M;
    result.info.name = moduleName!M;
    alias ScenariosSeq = Scenarios!M;
    result.scenarios.length = ScenariosSeq.length;
    static foreach (i, _Scenario; ScenariosSeq) {
        result.scenarios[i] = getScenarioGroup!_Scenario;
    }
    return result;
}

///Examples: How to use getFeature on a feature
@safe
unittest { //
    import tagion.hibon.HiBONRecord;
    import tagion.basic.Basic : unitfile;
    import core.demangle : mangle;

    import Module = tagion.behaviour.BehaviourUnittest;
    import std.path;

    enum filename = mangle!(FunctionTypeOf!(getFeature!Module))("unittest")
            .unitfile
            .setExtension(FileExtension.hibon);
    const feature = getFeature!(Module);
    const expected = filename.fread!FeatureGroup;
    assert(feature.toDoc == expected.toDoc);
}

protected string _scenarioTupleCode(alias M, string tuple_name)() if (isFeature!M) {
    string[] result;
    {
        result ~= format("alias %s = Tuple!(", tuple_name);
        scope (exit) {
            result ~= ");";
        }
        static foreach (_Scenario; Scenarios!M) {
            result ~= format(q{%1$s, "%1$s",}, _Scenario.stringof);
        }
    }
    return result.join("\n");
}

mixin template ScenarioTuple(alias M, string tuple_name) {
    import std.array : join;
    import std.format;

    enum code = _scenarioTupleCode!(M, tuple_name);
    mixin(code);
}

@safe
auto automation(alias M)() if (isFeature!M) {
    import std.typecons;

    mixin(format(q{import %s;}, moduleName!M));

    static struct FeatureFactory {
        Feature feature;
        // Defines the tuple of the Feature scenarios
        mixin ScenarioTuple!(M, "ScenariosT");
        ScenariosT scenarios;
        FeatureContext context;
        void opDispatch(string scenario_name, Args...)(Args args) {
            /*
        enum tuple_index = FeatureContext.fieldNames.countUntil(scenario_name);
            static assert(tuple_index < 0, 
            format("Scenarion '%s' does not exists. Possible scenarions is \n%(%s,\n%)", 
        scenario_name, FeatureContext.fieldNames[0..$-1]));
            context[tuple_index] = new FeatureContext.Types[tuple_index](args);  
        // enum code = format(q{scenarios.%1$s = new typeof(ScenariosT.%1$s)(args);}, scenario_name);
*/
            enum code = format(q{scenarios.%1$s = new typeof(ScenariosT.%1$s)(args);}, scenario_name);
            mixin(code);
        }

        FeatureGroup run() nothrow {
            uint error_count;

            FeatureGroup result;
            //FeatureContext context;
            //    auto result=new FeatureGroup;
            //           context.result = result;
            result.info.property = obtainFeature!M;
            result.info.name = moduleName!M;
            alias ScenariosSeq = Scenarios!M;
            result.scenarios.length = ScenariosSeq.length;
            static foreach (i, _Scenario; ScenariosSeq) {
                try {
                    static if (__traits(compiles, new _Scenario())) {
                        if (scenarios[i] is null) {
                            scenarios[i] = new _Scenario();
                        }
                    }
                    result.scenarios[i] = .run(scenarios[i]);
                }
                catch (Exception e) {
                    error_count++;
                    import std.exception : assumeWontThrow;

                    result.scenarios[i].info.result = assumeWontThrow(BehaviourError(e).toDoc);
                }
            }
            if (error_count == 0) {
                result.info.result = result_ok;

            }
            return result;
        }
    }

    FeatureFactory result;
    return result;
}

/**
   Returns:
   true if one of more scenarios in the Feature has failed
 */
@safe
bool hasErrors(ref const FeatureGroup feature_group) nothrow {
    if (feature_group.info.result.isRecordType!BehaviourError) {
        return true;
    }
    return feature_group.scenarios.any!(scenario => scenario.hasErrors);
}

/**
   Returns:
   true if one of more actions in the Scenario has failed
 */
@safe
bool hasErrors(ref const ScenarioGroup scenario_group) nothrow {
    static foreach (i, Type; Fields!ScenarioGroup) {
        static if (isActionGroup!Type) {
            if (scenario_group.tupleof[i].infos.any!(info => info.result.isRecordType!BehaviourError)) {
                return true;
            }
        }
        else static if (isInfo!Type) {
            if (scenario_group.tupleof[i].result.isRecordType!BehaviourError) {
                return true;
            }
        }
    }
    return false;
}

///Examples: Show how to use the automation function and the hasError on a feature group
@safe
unittest {
    import WithCtor = tagion.behaviour.BehaviourUnittestWithCtor;

    auto feature_with_ctor = automation!(WithCtor)();

    { // No constructor has been called for the scenarios, this means that scenarios and the feature will have errors
        const feature_result = feature_with_ctor.run;
        assert(feature_result.scenarios[0].hasErrors);
        assert(feature_result.scenarios[1].hasErrors);
        assert(feature_result.hasErrors);
        version (behaviour_unitdata)
            "/tmp/bdd_which_has_feature_errors.hibon".fwrite(feature_result);
    }

    { // Fails in second scenario because the constructor has not been called
        // Calls the construction for the Some_awesome_feature scenario
        feature_with_ctor.Some_awesome_feature(42, "with_ctor");
        const feature_result = feature_with_ctor.run;
        assert(!feature_result.scenarios[0].hasErrors);
        assert(feature_result.scenarios[1].hasErrors);
        assert(feature_result.hasErrors);
        version (behaviour_unitdata)
            "/tmp/bdd_which_has_scenario_errors.hibon".fwrite(feature_result);
    }

    { // The constructor of both scenarios has been called, this means that no errors is reported
        // Calls the construction for the Some_awesome_feature scenario
        feature_with_ctor.Some_awesome_feature(42, "with_ctor");
        feature_with_ctor.Some_awesome_feature_bad_format_double_property(17);
        const feature_result = feature_with_ctor.run;
        assert(!feature_result.scenarios[0].hasErrors);
        assert(!feature_result.scenarios[1].hasErrors);
        assert(!feature_result.hasErrors);
        version (behaviour_unitdata)
            "/tmp/bdd_which_has_no_errors.hibon".fwrite(feature_result);
    }
}

/**
Checks if a feature has passed all tests
   Returns:
   true if all scenarios in a Feature has passed all tests
 */
@safe
bool hasPassed(ref const FeatureGroup feature_group) nothrow {
    return feature_group.info.result.isRecordType!Result &&
        feature_group.scenarios.all!(scenario => scenario.hasPassed);
}

/**
Used to checks if a scenario has passed all tests
Params:
scenario_group = The scenario which been runned
Returns: true if the scenario has passed all tests
*/
@safe
bool hasPassed(ref const ScenarioGroup scenario_group) nothrow {
    static foreach (i, Type; Fields!ScenarioGroup) {
        static if (isActionGroup!Type) {
            if (scenario_group.tupleof[i].infos.any!(info => !info.result.isRecordType!Result)) {
                return false;
            }
        }
        else static if (isInfo!Type) {
            if (!scenario_group.tupleof[i].result.isRecordType!Result) {
                return false;
            }
        }
    }
    return true;
}

@safe
unittest {

    import WithoutCtor = tagion.behaviour.BehaviourUnittestWithoutCtor;

    auto feature_without_ctor = automation!(WithoutCtor)();

    { // None of the scenario passes
        const feature_result = feature_without_ctor.run;
        assert(!feature_result.scenarios[0].hasPassed);
        assert(!feature_result.scenarios[1].hasPassed);
        assert(!feature_result.hasPassed);
    }
}

///Examples: Shows how to use a automation on scenarios with constructor and the hasParssed
@safe
unittest {
    // Test of hasPassed function on Scenarios and Feature
    import WithCtor = tagion.behaviour.BehaviourUnittestWithCtor;

    auto feature_with_ctor = automation!(WithCtor)();
    feature_with_ctor.Some_awesome_feature(42, "with_ctor");
    feature_with_ctor.Some_awesome_feature_bad_format_double_property(17);

    { // None of the scenario passes
        const feature_result = feature_with_ctor.run;
        version (behaviour_unitdata)
            "/tmp/bdd_sample_has_failed.hibon".fwrite(feature_result);
        assert(!feature_result.scenarios[0].hasPassed);
        assert(!feature_result.scenarios[1].hasPassed);
        assert(!feature_result.hasPassed);
    }

    { // One of the scenario passed
        WithCtor.pass_one = true;
        const feature_result = feature_with_ctor.run;
        version (behaviour_unitdata)
            "/tmp/bdd_sample_one_has_passed.hibon".fwrite(feature_result);
        assert(!feature_result.scenarios[0].hasPassed);
        assert(feature_result.scenarios[1].hasPassed);
        assert(!feature_result.hasPassed);
    }

    { // Some actions passed passes
        WithCtor.pass_some = true;
        WithCtor.pass_one = false;
        const feature_result = feature_with_ctor.run;
        version (behaviour_unitdata)
            "/tmp/bdd_sample_some_actions_has_passed.hibon".fwrite(feature_result);
        assert(!feature_result.scenarios[0].hasPassed);
        assert(!feature_result.scenarios[1].hasPassed);
        assert(!feature_result.hasPassed);
    }

    { // All of the scenario passes
        WithCtor.pass = true; /// Pass all tests!
        WithCtor.pass_some = false;

        const feature_result = feature_with_ctor.run;
        version (behaviour_unitdata)
            "/tmp/bdd_sample_has_passed.hibon".fwrite(feature_result);
        assert(feature_result.scenarios[0].hasPassed);
        assert(feature_result.scenarios[1].hasPassed);
    }
}

version (unittest) {
    import tagion.hibon.Document;
    import tagion.hibon.HiBONRecord;
    import tagion.hibon.HiBONJSON;
}
