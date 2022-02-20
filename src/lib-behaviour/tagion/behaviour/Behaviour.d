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
    // writefln("%-( %s \n%)", expected);
    // writefln("%-( %s \n%)", result.map!(a => a.toPretty));
    assert(awesome.count == 6);
    assert(equal(result, expected));
    // auto awesome_implemeted = new Some_awesome_feature_all_implemented;
    // const run_awesome_implemeted=scenario(awesome_implemeted);
    // assert(run_awesome_implemeted());
    // assert(awesome_implemeted.count == 6);
}
