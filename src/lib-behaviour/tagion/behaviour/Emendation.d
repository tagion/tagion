/// \file Emendation.d
module tagion.behaviour.Emendation;

import std.traits : Fields;
import std.meta : Filter;
import std.algorithm.iteration : map;
import std.string : join;
import std.algorithm;
import std.algorithm.sorting : sort, isStrictlyMonotonic;
import std.typecons : Flag, No, Yes;
import std.ascii : toUpper, toLower, isAlphaNum, isWhite;
import std.array : split, array;
import std.algorithm.iteration : splitter;
import std.range.primitives : walkLength;
import std.range : retro, take, drop;
import std.path : stripExtension, absolutePath, pathSplitter;

import tagion.behaviour.BehaviourFeature;

/** 
 * Used to add functions name to a feature group for the action description
 * @param feature_group - the feature which have an emendation with function name
 * @param module_name - Will add the module name to the feature group if it's not already given
 */
@safe void emendation(ref FeatureGroup feature_group, string module_name = null)
{
    if (module_name && feature_group.info.name.length is 0)
    {
        feature_group.info.name = module_name;
    }
    alias ScenarioActionGroups = Filter!(isActionGroup, Fields!ScenarioGroup);
    static void emendation(ref ScenarioGroup scenario_group)
    {
        size_t countActionInfos()
        {
            size_t result;
            static foreach (i, Type; Fields!ScenarioGroup)
            {
                static if (isActionGroup!Type)
                {
                    result += scenario_group.tupleof[i].infos.length;
                }
            }
            return result;
        }

        auto names = new string[countActionInfos];

        void collectNames()
        {
            uint name_index;
            static foreach (i, Type; Fields!ScenarioGroup)
            {
                static if (isActionGroup!Type)
                {
                    with (scenario_group.tupleof[i])
                    {
                        foreach (ref info; infos)
                        {
                            if (info.name.length)
                            {
                                names[name_index] = info.name;
                            }
                            else
                            {
                                takeName(names[name_index], info.property.description);
                            }
                            name_index++;
                        }
                    }
                }
            }
        }

        void setCollectNames()
        {
            uint name_index;
            static foreach (i, Type; Fields!ScenarioGroup)
            {
                static if (isActionGroup!Type)
                {
                    with (scenario_group.tupleof[i])
                    {
                        foreach (ref info; infos)
                        {
                            if (!info.name.length)
                            {
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
        while (!names.isUnique && bail_out > 0)
        {

            collectNames;
            bail_out--;
        }
        setCollectNames;
    }

    foreach (ref scenario_group; feature_group.scenarios)
    {
        emendation(scenario_group);
    }
}

/** 
 * Used to add a word in reverse order from the description
 * @param action_name - names which alreay was take
 * @param description - description of the action or scenario
 */
@safe void takeName(ref string action_name, string description)
{
    const action_subwords = action_name.split!isWhite.walkLength;
    action_name = description.split!isWhite.retro.take(action_subwords + 1).retro.join(" ");
}

/** 
 * Used to get the camel case name 
 * @param names_with_space - list of name separated with white-space
 * @param flag - No means function camel case and Yes means object camel case
 * @return the camel case name
 */
@safe string camelName(string names_with_space, const Flag!"BigCamel" flag = No.BigCamel)
{
    string camelCase(string name, ref bool not_first)
    {
        if (name.length)
        {
            if (not_first)
            {
                return toUpper(name[0]) ~ name[1 .. $];
            }
            not_first = true;
            return (flag is Yes.BigCamel ? toUpper(name[0]) : toLower(name[0])) ~ name[1 .. $];
        }
        return null;
    }

    bool not_first = false;
    return names_with_space.splitter!isWhite
        .map!(a => camelCase(a, not_first))
        .join
        .filter!isAlphaNum
        .map!(c => cast(immutable(char)) c)
        .array;
}

/** 
 * Used check names in list
 * @param list_of_names - list of names which is goint to be checked
 * @return true if all the names in the list is unique and not empty
 */
@safe bool isUnique(string[] list_of_names) nothrow
{
    return (list_of_names.length == 0) || list_of_names.all!(name => name.length != 0)
        && list_of_names.array.sort.isStrictlyMonotonic;
}

/** 
 * Used to suggest a module name from the paths and the filename
 * @param paths - list of search paths
 * @param filename - name of the file to be mapped to module name
 * @return true a suggestion of a module name
 */
@safe string suggestModuleName(string filename, const(string)[] paths)
{
    auto filename_path = filename.stripExtension.absolutePath.pathSplitter;
    foreach (path; paths)
    {
        auto path_split = path.absolutePath.pathSplitter;
        if (equal(path_split, filename_path.take(path_split.walkLength)))
        {
            return filename_path.drop(path_split.walkLength).join(".");
        }
    }
    return null;
}

unittest
{
    import tagion.basic.Basic : unitfile;
    import std.stdio : File;
    import std.path;
    import tagion.basic.Types : FileExtension;
    import tagion.hibon.HiBONRecord : fread;
    import tagion.behaviour.BehaviourParser;

    /// emendation_none_function_names
    enum bddfile_proto = "ProtoBDD_nofunc_name".unitfile;
    immutable bdd_filename = bddfile_proto.setExtension(FileExtension.markdown);

    auto feature_byline = (() @trusted => File(bdd_filename).byLine)();

    string[] errors;
    auto feature = parser(feature_byline, errors);
    feature.emendation("test.emendation");

    const expected_feature = bdd_filename.setExtension(FileExtension.hibon).fread!FeatureGroup;
    assert(feature.toDoc == expected_feature.toDoc);
}

@safe unittest
{
    import tagion.basic.Types : FileExtension;
    import std.path;

    /// takeName_camelName
    {
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

    /// isUnique
    {
        string[] names;
        assert(names.isUnique);
        names = [null, "test"];
        assert(!names.isUnique);
        names = ["test", "test"];
        assert(!names.isUnique);
        names = ["test", "test1"];
        assert(names.isUnique);
    }

    /// suggestModuleName
    {
        auto paths = [
            buildPath(["some", "path", "to", "modules"]),
            buildPath(["another", "path", "to"])
        ];
        const filename = buildPath([
                "another", "path", "to", "some", "module", "path", "ModuleName"
                ]).setExtension(FileExtension.dsrc);
        assert(filename.suggestModuleName(paths) == "some.module.path.ModuleName");
    }
}
