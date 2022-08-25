module tagion.behaviour.Behaviour;

public import tagion.behaviour.BehaviourFeature;

import std.traits;
import std.format;
import std.meta : AliasSeq;

version (unittest)
{
    //    import std.stdio;
    public import tagion.behaviour.BehaviourUnittest;
    import tagion.hibon.Document;
}

/**
   Returns:
   true if all the behaviours has been runned
*/
@safe
ScenarioGroup run(T)(T scenario) if (isScenario!T)
{
    alias memberCode = format!(q{
            // Scenario group      %1$s
            // Unique propery info %2$s
            // Info index          %3$d
            // Test scenario       %4$s
            // Test member         %5$s
            %1$s.%2$s.infos[%3$d].result = %4$s.%5$s;
        }, string, string, size_t,string, string);
    // alias underMemberCode = format!(q{
    //         // Scenario group      %1$s
    //         // Unique propery info %2$s
    //         // Test scenario       %3$s
    //         // Test member         %4$s
    //         // Under index         %5$d
    //         auto and = %3$s.%4$s;
    //         %1$s.%2$s.ands[%5$d].result = and;
    //     }, string, string, string, string, size_t);
    pragma(msg, "Dav do", T);
    ScenarioGroup scenario_group = getScenarioGroup!T;
    // alias all_behaviours = getBehaviours_!(T);
    // pragma(msg, "- - - all_behaviours ", all_behaviours);

    static foreach(_Property; BehaviourProperties) {
        //pragma(msg, "FieldTupleNames!T ", FieldNameTuple!T);
        {
            alias all_behaviours = getBehaviour!(T, _Property);
            pragma(msg, "all_behaviour ", all_behaviours, " ", _Property);
            static foreach(i, behaviour; all_behaviours) {
                pragma(msg, "i ", i, " behaviour ", typeof(behaviour));
            }
        // static foreach(name; [ __traits(allMembers, T) ]) {
        //     static if (__traits(compiles, typeof(__traits(getMember, scenario, name)))) {{
        //         pragma(msg, "--- Name ", name);
        //         const m = __traits(getMember, scenario, name);
        //         static if (hasUDA!(m, _BehaviourProperty))  {
        //             pragma(msg, "Member ", name, " has ", _BehaviourProperty);
        //             }

        //         }}
        // }
            }
    }
    version(none)
    ScenarioGroup run(S...)()
    {
        static if (S.length is 0)
        {
            return scenario_group;
        }
        else
        {
            alias behaviours = getBehaviour!(T, S[0]);
            static foreach (Property; AliasSeq!(Given, Then))
            {
                static if (is(S[0] == Property))
                {
                    static assert(!is(behaviour),
                        format!"%s of the Scenario %s is missing"(Property.stringof, T.stringof));
                }
            }
            static if (!is(behaviour == void))
            {
                import std.uni : toLower;

                enum group_name = __traits(identifier, typeof(getProperty!(behaviour))).toLower;
                enum code = memberCode(
                        scenario_group.stringof, group_name,
                        test.stringof, __traits(identifier, behaviour));
                mixin(code);
                static foreach (i, under_behaviour; getUnderBehaviour!(T, S[0]))
                {
                    {
                        enum under_code = underMemberCode(
                                scenario_group.stringof, group_name,
                                test.stringof, __traits(identifier, under_behaviour), i);
                        mixin(under_code);
                    }
                }
            }
            return run!(S[1 .. $])();
        }
    }

    return ScenarioGroup.init;
}

@safe
unittest {
    pragma(msg, "UNITTEST ", Some_awesome_feature);
    auto awesome = new Some_awesome_feature;
    const result = run(awesome);
}

version(none)
unittest
{
    import tagion.hibon.HiBONJSON;
    import std.algorithm.iteration : map;
    import std.algorithm.comparison : equal;
    import std.array;

    auto awesome = new Some_awesome_feature;
    const runner_awesome = scenario(awesome);
    //    ScenarioGroup scenario=getScenarioGroup!Some_awesome_feature;
    const result = runner_awesome();
    auto expected = [
        "tagion.behaviour.BehaviourUnittest.Some_awesome_feature.is_valid",
        "tagion.behaviour.BehaviourUnittest.Some_awesome_feature.in_credit",
        "tagion.behaviour.BehaviourUnittest.Some_awesome_feature.contains_cash",
        "tagion.behaviour.BehaviourUnittest.Some_awesome_feature.request_cash",
        "tagion.behaviour.BehaviourUnittest.Some_awesome_feature.is_debited",
        "tagion.behaviour.BehaviourUnittest.Some_awesome_feature.is_dispensed"
    ]
        .map!(a => Some_awesome_feature.result(a));
    assert(awesome.count == 6);
    Document[] results;
    results ~= result.given.info.result;
    results ~= result.given.ands
        .map!(a => a.result)
        .array;
    results ~= result.when.info.result;
    results ~= result.when.ands
        .map!(a => a.result)
        .array;
    results ~= result.then.info.result;
    results ~= result.then.ands
        .map!(a => a.result)
        .array;
    assert(equal(results, expected));
}

@safe
ScenarioGroup getScenarioGroup(T)() if (isScenario!T)
{
    ScenarioGroup scenario_group;
    scenario_group.info.property = getScenario!T;
    scenario_group.info.name = T.stringof;
    static foreach (_Property; BehaviourProperties)
    {
        {
            alias behaviours = getBehaviour!(T, _Property);
            static if (!is(behaviours == void))
            {
                import std.uni : toLower;

                auto group = __traits(getMember, scenario_group, _Property.stringof.toLower);

                pragma(msg, "behaviour ", behaviours);
                static foreach (behaviour; behaviours)
                {{
                        //BehaviourGroup!_Property group;
                    pragma(msg, "behaviour, ", typeof(behaviour));
                    pragma(msg, "group, ", typeof(group));
                    Info!_Property info;
                    info.property = getProperty!behaviour;
                    info.name = __traits(identifier, behaviour);
                    group.infos~=info;
                    {
                        version(none_and) {
                        Info!And and;
                        scope (exit)
                        {
                            group.ands ~= and;
                        }
                        and.property = getProperty!(under_behaviour);
                        and.name = __traits(identifier, under_behaviour);
                        }
                    }
                    }}
            }
        }
    }
    return scenario_group;
}

@safe
FeatureGroup getFeature(alias M)() if (isFeature!M)
{
    //    import std.stdio;
    FeatureGroup result;
    result.info.property = obtainFeature!M;
    result.info.name = moduleName!M;
    static foreach (_Scenario; Scenarios!M)
    {
        {
            ScenarioGroup scenario_group = getScenarioGroup!_Scenario;
            scope (exit)
            {
                result.scenarios ~= scenario_group;
            }
            version (none)
            {
                scenario.info.property = getScenario!(_Scenario);
                scenario.info.name = _Scenario.stringof;
                static foreach (_Property; UniqueBehaviourProperties)
                {
                    {
                        alias behaviour = getBehaviour!(_Scenario, _Property);
                        static if (!is(behaviour == void))
                        {
                            import std.uni : toLower;

                            auto group = &__traits(getMember, scenario, _Property.stringof.toLower);

                            group.info.property = getProperty!behaviour;
                            group.info.name = __traits(identifier, behaviour);
                            static foreach (under_behaviour; getUnderBehaviour!(_Scenario, _Property))
                            {
                                {
                                    Info!And and;
                                    scope (exit)
                                    {
                                        group.ands ~= and;
                                    }
                                    and.property = getProperty!(under_behaviour);
                                    and.name = __traits(identifier, under_behaviour);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    return result;
}

version (CBR) @safe
unittest
{ //
    import tagion.hibon.HiBONRecord;
    import tagion.basic.Basic : unitfile;
    import core.demangle : mangle;

    alias Module = tagion.behaviour.BehaviourUnittest;
    import std.path;

    enum filename = mangle!(FunctionTypeOf!(getFeature!Module))("unittest")
            .unitfile
            .setExtension("hibon");
    const feature = getFeature!(Module);
    //    filename.fwrite(feature);
    const expected = filename.fread!FeatureGroup;
    assert(feature.toDoc == expected.toDoc);
}
