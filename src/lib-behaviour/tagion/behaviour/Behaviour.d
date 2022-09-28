/// \file Behaviour.d
module tagion.behaviour.Behaviour;

import tagion.hibon.Document;
import std.typecons;
import std.traits;
import std.format;
import std.range : only;
import std.array : join;
import std.algorithm.searching : any;
import std.exception : assumeWontThrow;
import std.uni : toLower;

public import tagion.behaviour.BehaviourFeature;
import tagion.behaviour.BehaviourException;
import tagion.basic.Types : FileExtension;
import tagion.hibon.HiBONRecord;
import tagion.basic.Basic : isOneOf;
import tagion.behaviour.BehaviourException : BehaviourError;

/**
 * \struct ScenarioResult
 * Store result of the scenario
 */
@safe struct ScenarioResult
{
    bool end;
    mixin HiBONRecord!(q{
            this(bool flag) {
                end=flag;
            }
        });
}

private static Document scenario_ends = result(ScenarioResult(true)).toDoc;

/**
 * Used to run the scenario in Given, When, Then, But order
 * @param scenario - scenario from file
 * @return the ScenarioGroup including the result of each action
 */
@safe ScenarioGroup run(T)(T scenario) if (isScenario!T)
{
    ScenarioGroup scenario_group = getScenarioGroup!T;
    try
    {
        alias memberCode = format!(q{
            // Scenario group      %1$s
            // Unique propery info %2$s
            // Info index          %3$d
            // Test scenario       %4$s
            // Test member         %5$s
            %1$s.%2$s.infos[%3$d].result = %4$s.%5$s;
        }, string, string, size_t, string, string);

        .check(scenario !is null,
                format("The constructor must be called for %s before it's runned", T.stringof));
        static foreach (_Property; BehaviourProperties)
        {
            {
                alias all_behaviours = getActions!(T, _Property);
                static if (is(all_behaviours == void))
                {
                    static assert(!isOneOf!(_Property, MandatoryBehaviourProperties),
                            format("%s is missing a @%s action", T.stringof, _Property.stringof));
                }
                else
                {
                    static foreach (i, behaviour; all_behaviours)
                    {
                        {
                            enum group_name = __traits(identifier, typeof(getProperty!(behaviour)))
                                    .toLower;
                            enum code = memberCode(scenario_group.stringof, group_name, i,
                                        scenario.stringof, __traits(identifier, behaviour));
                            mixin(code);
                        }
                    }
                }
            }
        }
        scenario_group.info.result = result(ScenarioResult(true)).toDoc;
    }
    catch (Exception e)
    {
        scenario_group.info.result = BehaviourError(e).toDoc;
    }
    return scenario_group;
}

/**
 * Used to get ScenarioGroup from scenario from file
 * @param T - scenario from file
 * @return the ScenarioGroup
 */
@safe ScenarioGroup getScenarioGroup(T)() if (isScenario!T)
{
    ScenarioGroup scenario_group;
    scenario_group.info.property = getScenario!T;
    scenario_group.info.name = T.stringof;
    static foreach (_Property; BehaviourProperties)
    {
        {
            alias behaviours = getActions!(T, _Property);
            static if (!is(behaviours == void))
            {
                enum group_name = _Property.stringof.toLower;
                auto group = &__traits(getMember, scenario_group, group_name);
                group.infos.length = behaviours.length;
                static foreach (i, behaviour; behaviours)
                {
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

/**
 * Used to get FeatureGroup from the module
 * @param M - module
 * @return the FeatureGroup
 */
@safe FeatureGroup getFeature(alias M)() if (isFeature!M)
{
    FeatureGroup result;
    result.info.property = obtainFeature!M;
    result.info.name = moduleName!M;
    alias ScenariosSeq = Scenarios!M;
    result.scenarios.length = ScenariosSeq.length;
    static foreach (i, _Scenario; ScenariosSeq)
    {
        result.scenarios[i] = getScenarioGroup!_Scenario;
    }
    return result;
}

/**
 * Used to get tuple with scanario code
 * @param M - module to check valid Feature
 * @param tuple_name - name of tuple
 * @return tuple with scanario code
 */
protected string _scenarioTupleCode(alias M, string tuple_name)() if (isFeature!M)
{
    string[] result;
    {
        result ~= format("alias %s = Tuple!(", tuple_name);
        scope (exit)
        {
            result ~= ");";
        }
        static foreach (_Scenario; Scenarios!M)
        {
            result ~= format(q{%1$s, "%1$s",}, _Scenario.stringof);
        }
    }
    return result.join("\n");
}

/* 
 * Set scenario tuple code
 */
mixin template ScenarioTuple(alias M, string tuple_name)
{
    enum code = _scenarioTupleCode!(M, tuple_name);
    mixin(code);
}

/**
 * Used to get Feature from module
 * @param M - module
 * @return Feature
 */
@safe auto automation(alias M)() if (isFeature!M)
{
    mixin(format(q{import %s;}, moduleName!M));
    /**
     * \struct FeatureFactory
     * Factory for featurs
     */
    static struct FeatureFactory
    {
        Feature feature;
        // Defines the tuple of the Feature scenarios
        mixin ScenarioTuple!(M, "ScenariosT");
        ScenariosT scenarios;
        void opDispatch(string scenario_name, Args...)(Args args)
        {
            enum code_1 = format(q{alias Scenario=typeof(ScenariosT.%1$s);}, scenario_name);
            mixin(code_1);
            alias PickCtorParams = ParameterTypeTuple!(__traits(getOverloads,
                    Scenario, "__ctor")[0]);
            enum code = format(q{scenarios.%1$s = new typeof(ScenariosT.%1$s)(args);},
                        scenario_name);
            mixin(code);
        }
        /**
         * Used to add scenario into the feature
         */
        FeatureGroup run()
        {
            FeatureGroup result;
            result.info.property = obtainFeature!M;
            result.info.name = moduleName!M;
            alias ScenariosSeq = Scenarios!M;
            result.scenarios.length = ScenariosSeq.length;

            static foreach (i, _Scenario; ScenariosSeq)
            {
                try
                {
                    static if (__traits(compiles, new _Scenario()))
                    {
                        if (!result.scenarios[i].info.property.description)
                        {
                            auto scenario = new _Scenario();
                            result.scenarios[i] = .run(scenario);
                        }
                        else
                        {
                            result.scenarios[i] = .run(scenarios[i]);

                        }
                    }
                }
                catch (Exception e)
                {
                    result.scenarios[i].info.result = assumeWontThrow(BehaviourError(e).toDoc);
                }
            }
            return result;
        }
    }

    FeatureFactory result;
    return result;
}

/**
 * Used to check FeatureGroup
 * @param feature_group - FeatureGroup to check
 * @return true, if error
 */
@safe bool hasErrors(ref const FeatureGroup feature_group) nothrow
{
    if (feature_group.info.result.isRecordType!BehaviourError)
    {
        return true;
    }
    return feature_group.scenarios.any!(scenario => scenario.hasErrors);
}

/**
 * Used to check ScenarioGroup
 * @param scenario_group - ScenarioGroup to check
 * @return true, if error
 */
@safe bool hasErrors(ref const ScenarioGroup scenario_group) nothrow
{
    static foreach (i, Type; Fields!ScenarioGroup)
    {
        static if (isActionGroup!Type)
        {
            if (scenario_group.tupleof[i].infos.any!(
                    info => info.result.isRecordType!BehaviourError))
            {
                return true;
            }
        }
        else static if (isInfo!Type)
        {
            if (scenario_group.tupleof[i].result.isRecordType!BehaviourError)
            {
                return true;
            }
        }
    }
    return false;
}

/**
 * Used to checks if a feature has passed all tests
 * @param feature_group - FeatureGroup to check
 * @return true if one of more actions in the Feature has failed
 */
@safe bool hasPassed(ref const FeatureGroup feature_group) nothrow
{
    if (feature_group.info.result.isRecordType!Result)
    {
        return true;
    }
    return feature_group.scenarios.any!(scenario => scenario.hasPassed);
}

/**
 * Used to checks if a scenario has passed all tests
 * @param scenario_group - ScenarioGroup to check
 * @return true if one of more actions in the Scenario has failed
 */
@safe bool hasPassed(ref const ScenarioGroup scenario_group) nothrow
{
    static foreach (i, Type; Fields!ScenarioGroup)
    {
        static if (isActionGroup!Type)
        {
            if (scenario_group.tupleof[i].infos.any!(info => !info.result.isRecordType!Result))
            {
                return false;
            }
        }
        else static if (isInfo!Type)
        {
            if (!scenario_group.tupleof[i].result.isRecordType!Result)
            {
                return false;
            }
        }
    }
    return true;
}

@safe unittest
{
    /// run_fuction_on_a_feature
    {
        import std.algorithm.iteration : map;
        import std.algorithm.comparison : equal;
        import std.array;
        import tagion.behaviour.BehaviourUnittest;

        auto awesome = new Some_awesome_feature;
        const runner_result = run(awesome);
        auto expected = only("tagion.behaviour.BehaviourUnittest.Some_awesome_feature.is_valid",
                "tagion.behaviour.BehaviourUnittest.Some_awesome_feature.in_credit",
                "tagion.behaviour.BehaviourUnittest.Some_awesome_feature.contains_cash",
                "tagion.behaviour.BehaviourUnittest.Some_awesome_feature.request_cash",
                "tagion.behaviour.BehaviourUnittest.Some_awesome_feature.is_debited",
                "tagion.behaviour.BehaviourUnittest.Some_awesome_feature.is_dispensed",
                "tagion.behaviour.BehaviourUnittest.Some_awesome_feature.swollow_the_card",).map!(
                a => result(a));

        assert(awesome.count == 7);
        Document[] results;
        results ~= runner_result.given.infos.map!(info => info.result).array;
        results ~= runner_result.when.infos.map!(info => info.result).array;
        results ~= runner_result.then.infos.map!(info => info.result).array;
        results ~= runner_result.but.infos.map!(info => info.result).array;
        assert(equal(results, expected));
    }

    /// getFeature_fuction_on_a_feature
    {
        import tagion.basic.Basic : unitfile;
        import core.demangle : mangle;

        import Module = tagion.behaviour.BehaviourUnittest;
        import std.path;

        enum filename = mangle!(FunctionTypeOf!(getFeature!Module))("unittest").unitfile.setExtension(
                    FileExtension.hibon);
        const feature = getFeature!(Module);
        /+ test file printout
         + (filename.stripExtension~"_test")
         + .setExtension(FileExtension.hibon)
         + .fwrite(feature);
         +/
        const expected = filename.fread!FeatureGroup;
        assert(feature.toDoc == expected.toDoc);
    }

    /// automation_function_hasError_fuction_on_a_feature
    {
        import WithCtor = tagion.behaviour.BehaviourUnittestWithCtor;

        auto feature_with_ctor = automation!(WithCtor)();

        { // No constructor has been called for the scenarios, this means that scenarios and the feature will have errors
            const feature_result = feature_with_ctor.run;
            assert(feature_result.scenarios[0].hasErrors);
            assert(feature_result.scenarios[1].hasErrors);
            assert(feature_result.hasErrors);
        }

        { // Fails in second scenario because the constructor has not been called
            // Calls the construction for the Some_awesome_feature scenario
            feature_with_ctor.Some_awesome_feature(42, "with_ctor");
            const feature_result = feature_with_ctor.run;
            assert(!feature_result.scenarios[0].hasErrors);
            assert(feature_result.scenarios[1].hasErrors);
            assert(feature_result.hasErrors);
        }

        { // The constructor of both scenarios has been called, this means that no errors is reported
            // Calls the construction for the Some_awesome_feature scenario
            feature_with_ctor.Some_awesome_feature(42, "with_ctor");
            feature_with_ctor.Some_awesome_feature_bad_format_double_property(17);
            const feature_result = feature_with_ctor.run;
            assert(!feature_result.scenarios[0].hasErrors);
            assert(!feature_result.scenarios[1].hasErrors);
            assert(!feature_result.hasErrors);
        }
    }

    /// automation_function_on_scenarios_with_constructor_hasParssed_function
    {
        // Test of hasPassed function on Scenarios and Feature
        import WithCtor = tagion.behaviour.BehaviourUnittestWithCtor;

        auto feature_with_ctor = automation!(WithCtor)();
        feature_with_ctor.Some_awesome_feature(42, "with_ctor");
        feature_with_ctor.Some_awesome_feature_bad_format_double_property(17);

        { // None of the scenario passes
            const feature_result = feature_with_ctor.run;
            assert(!feature_result.scenarios[0].hasPassed);
            assert(!feature_result.scenarios[1].hasPassed);
            assert(!feature_result.hasPassed);
        }

        { // None of the scenario passes
            WithCtor.pass = true; /// Pass all tests!
            const feature_result = feature_with_ctor.run;
            assert(feature_result.scenarios[0].hasPassed);
            assert(feature_result.scenarios[1].hasPassed);
        }
    }
}