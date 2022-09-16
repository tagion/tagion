module tagion.behaviour.Emendation;

import tagion.behaviour.BehaviourFeature;
import std.traits : Fields;
import std.meta : Filter;
import std.algorithm.iteration : map, cache, joiner;
import std.string : join;
import std.algorithm;
import std.algorithm.sorting : sort;
import std.typecons : Flag, No, Yes;
import std.ascii : toUpper, toLower, isAlphaNum, isWhite;
import std.array : split, array;

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
    static void emendation(ref ScenarioGroup scenario_group) {
        size_t countActionInfos() { //nothrow {
            size_t result;
            static foreach (i, Type; Fields!ScenarioGroup) {
                static if (isActionGroup!Type) {
                    result += scenario_group.tupleof[i].infos.length;
                }
            }
            return result;
        }

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
                            name_index++;
                        }
                    }
                }
            }
        }

        void setCollectNames() {
            uint name_index;
            static foreach (i, Type; Fields!ScenarioGroup) {
                static if (isActionGroup!Type) {
                    with (scenario_group.tupleof[i]) {
                        foreach (ref info; infos) {
                            if (!info.name.length) {
                                info.name = names[name_index].camelName;
                            }
                            name_index++;
                        }
                    }
                }
            }
        }

        scenario_group.info.name = scenario_group.info.property.description.camelName(Yes.BigCamel);
        collectNames;
        int bail_out = 6;
        while (!names.isUnique && bail_out > 0) {

            collectNames;
            bail_out--;
        }
        setCollectNames;
    }

    foreach (ref scenario_group; feature_group.scenarios) {
        emendation(scenario_group);
    }
}

// Test emendation on a BDD with none function names
unittest {
    enum bddfile_proto = "ProtoBDD_nofunc_name".unitfile;
    immutable bdd_filename = bddfile_proto.setExtension(FileExtension.markdown);

    auto feature_byline = (() @trusted => File(bdd_filename).byLine)();

    string[] errors;
    auto feature = parser(feature_byline, errors);
    //"/tmp/feature_no_emendation".setExtension("hibon").fwrite(feature);
    feature.emendation("test.emendation");

    //"/tmp/feature_with_emendation".setExtension("hibon").fwrite(feature);

    //bdd_filename.setExtension(FileExtension.hibon).fwrite(feature);
    const expected_feature = bdd_filename.setExtension(FileExtension.hibon).fread!FeatureGroup;
    assert(feature.toDoc == expected_feature.toDoc);
}

/++ 
+ This function add a word in reverse order from the description
+ Params:
+   action_name = names which alreay was take
+   description = description of the action or scenario
+/
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

/++
+ 
+ Params:
+   names_with_space = list of name separated with white-space
+   flag = No means function camel case and Yes means object camel case
+ Returns: the a camel case name 
+/
@safe
string camelName(string names_with_space, const Flag!"BigCamel" flag = No.BigCamel) {
    string camelCase(string name, ref bool not_first) {
        if (name.length) {
            if (not_first) {
                return toUpper(name[0]) ~ name[1 .. $];
            }
            not_first = true;
            return (flag is Yes.BigCamel ? toUpper(name[0]) : toLower(name[0])) ~ name[1 .. $];
        }
        return null;
    }

    bool not_first = false;
    return names_with_space
        .splitter!isWhite
        .map!(a => camelCase(a, not_first))
        .join
        .filter!isAlphaNum
        .map!(c => cast(immutable(char)) c)

        .array;

}

/// Examples: takeName and camelName
@safe
unittest {
    string name;
    auto some_description = "This is some description.";
    takeName(name, some_description);
    assert(name == "description.");
    assert(name.camelName == "description");
    assert(name.camelName(Yes.BigCamel) == "Description");
    takeName(name, some_description);
    assert(name == "some description.");
    assert(name.camelName == "someDescription");
    assert(name.camelName(Yes.BigCamel) == "SomeDescription");
    takeName(name, some_description);
    assert(name == "is some description.");
    assert(name.camelName == "isSomeDescription");
    assert(name.camelName(Yes.BigCamel) == "IsSomeDescription");
    takeName(name, some_description);
    assert(name == "This is some description.");
    assert(name.camelName == "thisIsSomeDescription");
    assert(name.camelName(Yes.BigCamel) == "ThisIsSomeDescription");
    takeName(name, some_description);
    assert(name == "This is some description.");
    assert(name.camelName == "thisIsSomeDescription");
    assert(name.camelName(Yes.BigCamel) == "ThisIsSomeDescription");
}

/++ 
 + 
 + Params:
 +   list_of_names = list of names which is goint to be checked
 + Returns: true if all the names in the list is unique and not empty
 +/
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

/** 
 * Suggest a module name from the paths and the filename
 * Params:
 *   paths = list of search paths
 *   filename = name of the file to be mapped to module name
 * Returns: return a suggestion of a module name
 */
@safe
string suggestModuleName(string filename, const(string)[] paths) {
    import std.path : stripExtension, absolutePath, pathSplitter;

    import std.range.primitives : walkLength;
    import std.range : take, drop;

    auto filename_path = filename.stripExtension.absolutePath.pathSplitter;
    foreach (path; paths) {
        auto path_split = path.absolutePath.pathSplitter;
        if (equal(path_split, filename_path.take(path_split.walkLength))) {
            return filename_path.drop(path_split.walkLength).join(".");
        }
    }
    return null;
}

@safe
unittest {
    auto paths = [
        buildPath(["some", "path", "to", "modules"]),
        buildPath(["another", "path", "to"])
    ];
    const filename = buildPath(["another", "path", "to", "some", "module", "path", "ModuleName"])
        .setExtension(FileExtension.dsrc);

    io.writefln("suggestModuleName %s", filename.suggestModuleName(paths));
    assert(filename.suggestModuleName(paths) == "some.module.path.ModuleName");
}

version (unittest) {
    import io = std.stdio;
    import std.exception;
    import tagion.basic.Types : FileExtension;
    import std.stdio : File;
    import std.path;
    import std.file : fwrite = write;
    import tagion.hibon.HiBONJSON;
    import tagion.hibon.HiBONRecord : fwrite, fread;
    import tagion.basic.Basic : unitfile;
    import tagion.behaviour.BehaviourParser;
}
