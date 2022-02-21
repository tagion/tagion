module tagion.behaviour.Behaviour;

public import tagion.behaviour.BehaviourBase;

import std.traits;
import std.format;
import std.meta : AliasSeq;

version(unittest) {
//    import std.stdio;
    public import tagion.behaviour.BehaviourUnittest;
    import tagion.hibon.Document;
}

/**
   Returns:
   true if all the behavios has been runned
 */
@safe
auto scenario(T)(T test) if (isScenario!T) {
    alias memberCode = format!(q{results ~= %s.%s;},string, string);
    Document[] results;
    Document[] run(S...)() {
        static if (S.length is 0) {
            return results;
        }
        else {
            alias behaviour = getBehaviour!(T, S[0]);
            static foreach(Property; AliasSeq!(Given, Then)) {
                static if (is(S[0] == Property)) {
                static assert(!is(behaviour),
                    format!"%s of the Scenario %s is missing"
                    (Property.stringof, T.stringof));
                }
            }
            static if (!is(behaviour == void)) {
                enum code = memberCode(
                    test.stringof, __traits(identifier, behaviour));
                mixin(code);
                static foreach(under_behaviour; getUnderBehaviour!(T, S[0])) {{
                        enum under_code = memberCode(
                            test.stringof, __traits(identifier, under_behaviour));
                        mixin(under_code);
                    }}
                run!(S[1..$])();
            }
            return results;
        }
    }
    return &run!UniqueBehaviourProperties;
}

unittest {
    import tagion.hibon.HiBONJSON;
    import std.algorithm.iteration : map;
    import std.algorithm.comparison : equal;
    import std.stdio;
    auto awesome = new Some_awesome_feature;
    const run_awesome=scenario(awesome);
    const result = run_awesome();
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
    assert(equal(result, expected));
}

//@safe
FeatureGroup getFeature(alias M)() if (isFeature!M) {
    import std.stdio;
    FeatureGroup result;
    result.feature.property = obtainFeature!M;
    result.feature.name = moduleName!M;
    static foreach(_Scenario; Scenarios!M) {{
        ScenarioGroup scenario;
        scope(exit) {
            result.scenarios~=scenario;
        }
        scenario.info.property = getScenario!(_Scenario);
        scenario.info.name = _Scenario.stringof;
//        ScenarioGroup scenario;
//        scenario.info.
        pragma(msg, "_Scenario ", _Scenario);

//        writefln("%J", scenario);
        static foreach(_Property; UniqueBehaviourProperties) {{
                alias behaviour=getBehaviour!(_Scenario, _Property);
                static if (!is(behaviour == void)) {
                    import std.uni : toLower;
                    pragma(msg, "Property ", _Property);
                    pragma(msg, "Property ", getProperty!behaviour);
                    pragma(msg, "_Property.stringof.toLower ", _Property.stringof.toLower);
                    auto group = &__traits(getMember, scenario, _Property.stringof.toLower);

                    group.info.property = getProperty!behaviour;
                    group.info.name = __traits(identifier, behaviour);
                    static foreach(under_behaviour; getUnderBehaviour!(_Scenario, _Property)) {{
                            Info!And and;
                            scope(exit) {
                                group.ands~=and;
                            }
                            and.property = getProperty!(under_behaviour);
                            and.name = __traits(identifier, under_behaviour);
//                        foreach(
                            }}
//                    enum code = format!q{alias call=%}
//                    pragma
                    //BehaviourGroup behaviour = getBehaviour!Property;
//                 behaviour = getBehaviour!Property;
                }
            }}
        }}
    return result;
}

unittest { //
    import tagion.hibon.HiBONRecord;
    import tagion.basic.Basic : unitfile;
    import core.demangle : mangle;
//    import std.array : replace;
    alias Module=tagion.behaviour.BehaviourUnittest;
    import std.path;
    enum filename=mangle!(FunctionTypeOf!(getFeature!Module))("unittest")
        .unitfile
        .setExtension("hibon");
    pragma(msg, "filename ", filename);
    import std.stdio;
    // FeatureGroup expected;
    // expected.feature.name= "tagion.behaviour.BehaviourUnittest";
    // expected.feature.property = Feature("Some awesome feature should print some cash out of the blue");

    const feature = getFeature!(Module);
//    const doc = filename.fread;
    const expected = filename.fread!FeatureGroup;
    writefln("expected=%J", expected);
    writefln("feature=%J", feature);
    writefln("filename %s", filename);

//    const
//    filename.fwrite(feature);
    assert(feature == expected);
}

@safe
void genBehaviourCode(alias M, Stream)(Stream bout) if(isFeature!M) {

}

unittest {
    import std.outbuffer;
    auto bout=new OutBuffer;
    genBehaviourCode!(tagion.behaviour.BehaviourUnittest)(bout);

    assert(bout.toString == "Not code");
}
