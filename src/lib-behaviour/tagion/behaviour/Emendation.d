module tagion.behaviour.Emendation;

import std.algorithm;
import std.algorithm.iteration : cache, joiner, map;
import std.algorithm.searching : any;
import std.algorithm.sorting : sort;
import std.array : array, split;
import std.ascii : isAlphaNum, isWhite, toLower, toUpper;
import std.meta : Filter;
import std.range : empty;
import std.string : join, strip;
import std.traits : Fields;
import std.typecons : Flag, No, Yes;
import std.uni : isNumber;
import tagion.behaviour.BehaviourFeature;

/**
This function tries to add functions name to a feature group for the action description
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
        while ((!names.isUnique && bail_out > 0) || names.any!(a => !a.isValidName)) {

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
    feature.emendation("test.emendation");
    version (behaviour_unitdata)
        "/tmp/feature_with_emendation".setExtension("hibon").fwrite(feature);

    const expected_feature = bdd_filename.setExtension(FileExtension.hibon).fread!FeatureGroup;
    assert(feature.toDoc == expected_feature.toDoc);
}

/** 
* This function add a word in reverse order from the description
* Params:
*   action_name = names which already was take
*   description = description of the action or scenario
* Returns: The camel case name
*/
@safe
void takeName(ref string action_name, string description) {
    import std.algorithm.iteration : splitter;
    import std.ascii : isWhite;
    import std.range : retro, take;
    import std.range.primitives : walkLength;

    const action_subwords = action_name
        .split!isWhite.walkLength;
    action_name = description
        .split!isWhite
        .retro
        .take(action_subwords + 1)
        .map!(name => name.filterName)
        .retro
        .join(" ");
}

@safe
bool isValidName(const string name) pure nothrow @nogc {
    return !name.empty && !name[0].isNumber;
}

@safe
unittest {
    assert(!isValidName(""));
    assert(!isValidName("1not_valid_name"));
    assert(!isValidName("1"));
    assert(isValidName("valid_name"));
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
        .strip
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
    assert(name == "description");
    assert(name.camelName == "description");
    assert(name.camelName(Yes.BigCamel) == "Description");
    takeName(name, some_description);
    assert(name == "some description");
    assert(name.camelName == "someDescription");
    assert(name.camelName(Yes.BigCamel) == "SomeDescription");
    takeName(name, some_description);
    assert(name == "is some description");
    assert(name.camelName == "isSomeDescription");
    assert(name.camelName(Yes.BigCamel) == "IsSomeDescription");
    takeName(name, some_description);
    assert(name == "This is some description");
    assert(name.camelName == "thisIsSomeDescription");
    assert(name.camelName(Yes.BigCamel) == "ThisIsSomeDescription");
}

/// Test of camelName with trailing white space
@safe
unittest {
    string name = "  This is some description ";
    assert(name.camelName == "thisIsSomeDescription");
    assert(name.camelName(Yes.BigCamel) == "ThisIsSomeDescription");

    name = "  This is some description . ";
    assert(name.camelName == "thisIsSomeDescription");
    assert(name.camelName(Yes.BigCamel) == "ThisIsSomeDescription");
    name = " the client is connected success fully ";
    assert(name.camelName == "theClientIsConnectedSuccessFully");
    assert(name.camelName(Yes.BigCamel) == "TheClientIsConnectedSuccessFully");

}

/** 
 * 
 * Params:
 *   list_of_names = list of names which is going to be checked
 * Returns: true if all the names in the list is unique and not empty
 */
@safe
bool isUnique(string[] list_of_names) nothrow {
    import std.algorithm.iteration : cache;
    import std.algorithm.searching : all;
    import std.algorithm.sorting : isStrictlyMonotonic;
    import std.array : array;

    return (list_of_names.length == 0) ||
        (list_of_names
                .all!(name => name.length != 0) &&
                list_of_names
                    .array
                    .sort
                    .isStrictlyMonotonic);
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
    names = ["test", "test1", "test"];
    assert(!names.isUnique);
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
    import std.path : absolutePath, pathSplitter, stripExtension;
    import std.range : drop, take;
    import std.range.primitives : walkLength;

    auto filename_path = filename.stripExtension.absolutePath.pathSplitter;
    foreach (path; paths) {
        auto path_split = path.absolutePath.pathSplitter;
        if (equal(path_split, filename_path.take(path_split.walkLength))) {
            return filename_path.drop(path_split.walkLength).join(".");
        }
    }
    return null;
}

/// Example: suggestModuleName
@safe
unittest {
    auto paths = [
        buildPath(["some", "path", "to", "modules"]),
        buildPath(["another", "path", "to"])
    ];
    const filename = buildPath(["another", "path", "to", "some", "module", "path", "ModuleName"])
        .setExtension(FileExtension.dsrc);
    assert(filename.suggestModuleName(paths) == "some.module.path.ModuleName");
}

@safe
string filterName(const(char[]) name) pure {
    return name
        .filter!(a => a.isWhite || a.isAlphaNum)
        .map!(a => cast(immutable char) a)
        .array;
}

@safe
unittest {
    assert("#label.".filterName == "label");
}

version (unittest) {
    //    import io = std.stdio;
    import std.exception;
    import std.file : fwrite = write;
    import std.path;
    import std.stdio : File;
    import tagion.basic.Types : FileExtension;
    import tagion.basic.basic : unitfile;
    import tagion.behaviour.BehaviourParser;
    import tagion.hibon.HiBONFile : fread, fwrite;
    import tagion.hibon.HiBONJSON;
}
