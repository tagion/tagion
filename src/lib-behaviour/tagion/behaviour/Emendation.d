module tagion.behaviour.Emendation;

import tagion.behaviour.BehaviourFeature;
import std.traits : Fields;
import std.meta : Filter;
import std.algorithm.iteration : map, cache;
import std.string : join;
import std.ascii : isWhite;
import std.algorithm;
import std.algorithm.sorting : sort;
import std.typecons : Flag, No, Yes;
import std.ascii : toUpper;
import std.array : split;

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
    alias ScenarioActionGroups = Filter!(isActionGroup, Fields!ScenarioGroup);
    pragma(msg, "ScenarioActionGroups ", ScenarioActionGroups);
    static void emendation(ref ScenarioGroup scenario_group) {
        size_t countActionInfos() { //nothrow {
            size_t result;
            static foreach (i, Type; Fields!ScenarioGroup) {
                static if (isActionGroup!Type) {
                    //		io.writefln("-count=%d", scenario_group.tupleof[i].infos.length);
                    pragma(msg, i, " Type ", Type, " isActionGroup ", isActionGroup!Type);
                    result += scenario_group.tupleof[i].infos.length;
                }
            }
            return result;
        }

        pragma(msg, "Scenario ", ScenarioActionGroups.length);
        auto names = new string[countActionInfos];

        // Collects all the action function name and if name hasn't been defined, a name will be suggested
        void collectNames() {
            uint name_index;
            static foreach (i, Type; Fields!ScenarioGroup) {
                static if (isActionGroup!Type) {
                    with (scenario_group.tupleof[i]) {
                        foreach (ref info; infos) {
                            if (info.name.length) {
                                names[name_index] = info.name;
                            }
                            else {
                                takeName(names[name_index], info.property.description);
                            }
                            io.writefln("names[%d]=%s", name_index, names[name_index]);
                            info.name = names[name_index];
                            name_index++;
                        }
                    }
                }
            }
        }

        collectNames;
        while (!names.isUnique) {

            collectNames;
        }
    }

    foreach (ref scenario_group; feature_group.scenarios) {
        emendation(scenario_group);
    }
}

// Test emendation on a BDD with none function names
version (none) unittest {
    enum bddfile_proto = "ProtoBDD_nofunc_name".unitfile;
    immutable bdd_filename = bddfile_proto.setExtension(FileExtension.markdown);

    auto feature_byline = (() @trusted => File(bdd_filename).byLine)();

    string[] errors;
    auto feature = parser(feature_byline, errors);
    "/tmp/feature_no_emendation".setExtension("hibon").fwrite(feature);
    feature.emendation("test.emendation");

    "/tmp/feature_with_emendation".setExtension("hibon").fwrite(feature);

    /* immutable markdown_filename = bddfile_proto_test */
    /*     .unitfile.setExtension(FileExtension.markdown); */

}

@safe
void takeName(ref string action_name, string description) {
    import std.algorithm.iteration : splitter;
    import std.range.primitives : walkLength;
    import std.ascii : isWhite;
    import std.range : retro, take;

    const action_subwords = action_name
        .split!isWhite.walkLength;
    // .splitter(function_word_separator).walkLength;
    action_name = description
        .split!isWhite
        .retro
        .take(action_subwords + 1)
        .retro
        .join(" ");
}

/// Examples: takeName
@safe
unittest {
    string name;
    auto some_description = "This is some description";
    takeName(name, some_description);
    assert(name == "description");
    io.writefln("takeName %s", name);
    io.writefln("camelName %s", camelName(name));
    io.writefln("camelName %s", camelName(name, Yes.BigCamel));
    takeName(name, some_description);
    io.writefln("takeName %s", name);
    io.writefln("camelName %s", camelName(name));
    io.writefln("camelName %s", camelName(name, Yes.BigCamel));
    assert(name == "some description");
    takeName(name, some_description);
    io.writefln("takeName %s", name);
    io.writefln("camelName %s", camelName(name));
    io.writefln("camelName %s", camelName(name, Yes.BigCamel));
    assert(name == "is some description");
    takeName(name, some_description);
    io.writefln("takeName %s", name);
    io.writefln("camelName %s", camelName(name));
    io.writefln("camelName %s", camelName(name, Yes.BigCamel));
    takeName(name, some_description);
    assert(name == "This is some description");
    io.writefln("camelName %s", camelName(name));
    io.writefln("camelName %s", camelName(name, Yes.BigCamel));
}

@safe
string camelName(string names_with_space, const Flag!"BigCamel" flag = No.BigCamel) {
    bool not_first;
    string camelCase(string name) {
        if (!not_first || flag is Yes.BigCamel) {
            return toUpper(name[0]) ~ name[1 .. $];
        }
        not_first = true;
        return name;
    }

    return names_with_space
        .split!isWhite
        .map!camelCase
        .join;
    //	return "";
}

/// Returns: true if all the functions names in the scenario are unique
@safe
bool isUnique(string[] list_of_names) nothrow {
    import std.algorithm.sorting : isStrictlyMonotonic;
    import std.algorithm.iteration : cache;
    import std.array : array;
    import std.algorithm.searching : all;

    return (list_of_names.length == 0) ||
        list_of_names
        .all!(name => name.length != 0)
        &&
        list_of_names
        .array
        .sort
        .isStrictlyMonotonic;
}

///Examples:  Test of the isUnique
@safe
unittest {
    string[] names;
    assert(names.isUnique);
    names = [null, "test"];
    assert(!names.isUnique);
    names = ["test", "test"];

    assert(!names.isUnique);

    names = ["test", "test1"];
    assert(names.isUnique);
}

import io = std.stdio;

version (unittest) {
    //import io=std.stdio;
    import std.exception;
    import tagion.basic.Types : FileExtension;
    import std.stdio : File;
    import std.path;
    import std.file : fwrite = write;
    import tagion.hibon.HiBONJSON;
    import tagion.hibon.HiBONRecord : fwrite;
    import tagion.basic.Basic : unitfile;
    import tagion.behaviour.BehaviourParser;
}
