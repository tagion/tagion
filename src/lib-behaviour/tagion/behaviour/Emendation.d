module tagion.behaviour.Emenedation;

import tagion.behaviour.BehaviourFeature;

enum function_word_separator = "_";

/**
This function try to add functions name to a feature group for the action description
Params:
feature_group = Is the feature which have an emendation with function name
module_name = Will add the module name to the feature group if it's not already given
*/
@safe
void emendation(ref FeatureGroup feature_group, string module_name = null) {
    if (module_name && feature_group.info.name.length is 0) {
        feature_group.info.name = module_name;
    }
    static void emendation(ref ScenaionGroup scenario_group) {
        size_t countActionInfos() nothrow {
            size_t result;
            static foreach (i, Type; Field!ScenarionGroup) {
                static if (isActionGroup!Type) {
                    result += scenario_group.typeleof[i].infos.length;
                }
            }
            return result;
        }

        auto names = new string[countActionInfos];

        static void suggestName(ref string action_name, string description) nothrow {
            import std.algorithm.iteration : splitter;
            import std.range.primitives : walkLength;
            import std.ascii : isWhite;

            const action_subwords = action_name
                .splitter(function_word_separator).walkLength;
            action_name = description
                .splitter!isWhite
                .retro
                .take(action_subwords + 1)
                .retro
                .join(function_word_separator);
        }

        // Collects all the action function name and if name hasn't been defined, a name will be suggested
        void collectName() {
            static foreach (i, Type; Field!ScenarionGroup) {
                static if (isActionGroup!Type) {
                    with (scenario_group.tupleof[i]) {
                        foreach (ref info; infos) {
                            if (info.name.length) {
                                names[i].name = info.name;
                            }
                            else {
                                suggestName(names[i].name, info.description);
                            }
                        }
                    }
                }
            }
        }

        collectNames;
        while (!names.map!q{a.name}.isUnique) {

        }
    }

    foreach (ref scenario_group; feature_group.scenarios) {
        emendation(scenario_group);
    }
}

// Returns: true if all the functions names in the scenario are unique
@safe
bool isUnique(scope const(string[]) list_of_names) nothrow {
    import std.algorithm.sorting : sort, isStrictlyMonotonic;
    import std.algorithm.iteration : cache;

    return list_of_names
        .any!(name => name.length !is 0)
        &&
        list_of_names
        .cashe
        .sort
        .isStrictlyMonotonic;
}

@safe
unittest {
    string[] names;
    assert(names.isUnique);
    names = [null, "test"];
    assert(!names.isUnique);
    names = ["test", "test"];

    assert(!names.isUnique);

    names = ["test", "test1"];
    assert(!names.isUnique);
}
