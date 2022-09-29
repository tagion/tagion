/// \file BehaviourIssue.d
module tagion.behaviour.BehaviourIssue;

import std.traits;
import std.algorithm : each, map;
import std.range : tee, chain;
import std.array : join, array;
import std.format;

import tagion.behaviour.BehaviourFeature;

@safe MarkdownT!(Stream) Markdown(Stream)(Stream bout)
{
    alias MasterT = MarkdownT!Stream;
    MasterT.master = masterMarkdown;
    return MasterT(bout);
}

@safe DlangT!(Stream) Dlang(Stream)(Stream bout)
{
    alias MasterT = DlangT!Stream;
    auto result = MasterT(bout);
    return result;
}

/**
 * \struct MarkdownFMT
 * Storage for bdd components
 */
@safe struct MarkdownFMT
{
    string indent;
    string name;
    string scenario;
    string feature;
    string property;
    string comments;
}

@safe static MarkdownFMT masterMarkdown = 
{
    indent: "  ", 
    name : "`%2$s`", 
    scenario : "### %2$s: %3$s", 
    feature : "## %2$s: %3$s",
    property : "%s*%s* %s", 
    comments : "%-(%s\n%)",
};

/**
 * \struct MarkdownT
 */
@safe struct MarkdownT(Stream)
{
    Stream bout;

    static MarkdownFMT master;

    void issue(Descriptor)(const(Descriptor) descriptor, string indent,
            string fmt, string comment_fmt = null) if (isDescriptor!Descriptor)
    {
        bout.writefln(fmt, indent, Descriptor.stringof, descriptor.description);
        if (descriptor.comments)
        {
            comment_fmt = (comment_fmt is null) ? master.comments : comment_fmt;
            bout.writefln(comment_fmt, descriptor.comments);
        }
    }

    void issue(I)(const(I) info, string indent, string fmt) if (isInfo!I)
    {
        issue(info.property, indent, fmt);
        bout.writefln(master.name, indent ~ master.indent, info.name);
        bout.write("\n");
    }

    void issue(Group)(const(Group) group, string indent, string fmt)
            if (isActionGroup!Group)
    {
        if (group !is group.init)
        {
            group.infos.each!(info => issue(info, indent, master.property));
        }
    }

    void issue(const(ScenarioGroup) scenario_group, string indent = null)
    {
        issue(scenario_group.info, indent, master.scenario);
        issue(scenario_group.given, indent ~ master.indent, master.property);
        issue(scenario_group.when, indent ~ master.indent, master.property);
        issue(scenario_group.then, indent ~ master.indent, master.property);
        issue(scenario_group.but, indent ~ master.indent, master.property);
    }

    void issue(const(FeatureGroup) feature_group, string indent = null)
    {
        issue(feature_group.info, indent, master.feature);
        feature_group.scenarios
            .tee!(a => bout.write("\n"))
            .each!(a => issue(a, indent ~ master.indent));
    }
}

/**
 * \struct DlangT
 * For generate D files
 */
@safe struct DlangT(Stream)
{
    Stream bout;
    static string[] preparations;
    static this()
    {
        preparations ~= q{
            // Auto generated imports
            import tagion.behaviour.BehaviourFeature;
            import tagion.behaviour.BehaviourException;
            import tagion.hibon.Document : Document;
        };
    }

    string issue(I)(const(I) info) if (isInfo!I)
    {
        alias Property = TemplateArgsOf!(I)[0];
        return format(q{
                @%2$s("%3$s")
                Document %1$s() {
                    check(false, "Check for '%1$s' not implemented");
                    return Document();
                }
            }, info.name, Property.stringof, info.property.description);
    }

    string[] issue(Group)(const(Group) group) if (isActionGroup!Group)
    {
        if (group !is group.init)
        {
            return group.infos.map!(info => issue(info)).array;
        }
        return null;
    }

    string issue(const(ScenarioGroup) scenario_group)
    {
        immutable scenario_param = format("\"%s\",\n[\"%-( %3$s ,\n%)\"]",
                scenario_group.info.property.description, scenario_group.info.property.comments);
        auto behaviour_groups = chain(issue(scenario_group.given), issue(scenario_group.when),
                issue(scenario_group.then), issue(scenario_group.but),);
        return format(q{
                @safe @Scenario(%1$s)
                    class %2$s {
                    %3$s
                        }
            }, scenario_param, scenario_group.info.name,
                behaviour_groups.join);
    }

    void issue(const(FeatureGroup) feature_group, string indent = null)
    {
        string comments;
        if (feature_group.info.property.comments.length > 0)
        {
            comments = format("[\"%-(%s, %)\"]", feature_group.info.property.comments); //add to scen
        }

        bout.writefln(q{
                module %1$s;
                %4$s
                enum feature = Feature(
                    "%2$s",
                    %3$s);

            }, feature_group.info.name,
                feature_group.info.property.description, comments, preparations.join);
        if (feature_group.scenarios.length)
        {
            feature_group.scenarios
                .map!(s => issue(s))
                .each!(a => bout.write(a));
        }
    }
}

@safe unittest
{
    import std.algorithm.comparison : equal;
    import std.algorithm.iteration : filter;
    import std.string : strip, splitLines;
    import std.file : fwrite = write, freadText = readText;
    import std.path;
    import std.outbuffer;

    import tagion.basic.Basic : mangleFunc, unitfile;
    import tagion.basic.Types : FileExtension;
    import tagion.behaviour.BehaviourUnittest;
    import tagion.behaviour.Behaviour;
    import tagion.hibon.Document;
    alias MarkdownU = Markdown!OutBuffer;
    alias DlangU = Dlang!OutBuffer;

    /// Markdown_scenario_test
    {
        auto bout = new OutBuffer;
        auto markdown = Markdown(bout);
        alias unit_mangle = mangleFunc!(MarkdownU);
        auto awesome = new Some_awesome_feature;
        const scenario_result = run(awesome);
        {
            scope (exit)
            {
                bout.clear;
            }
            immutable filename = unit_mangle("descriptor").unitfile.setExtension(
                    FileExtension.markdown);
            immutable expected = filename.freadText;
            markdown.issue(scenario_result.given.infos[0], null, markdown.master.property);
            assert(bout.toString == expected);
        }
        {
            scope (exit)
            {
                bout.clear;
            }
            immutable filename = unit_mangle("scenario").unitfile.setExtension(
                    FileExtension.markdown);
            markdown.issue(scenario_result);
            immutable expected = filename.freadText;
            assert(bout.toString == expected);
        }
    }

    /// Markdown_feature_test
    {
        auto bout = new OutBuffer;
        auto markdown = Markdown(bout);
        alias unit_mangle = mangleFunc!(MarkdownU);
        const feature_group = getFeature!(tagion.behaviour.BehaviourUnittest);
        {
            scope (exit)
            {
                bout.clear;
            }
            immutable filename = unit_mangle("feature").unitfile.setExtension(
                    FileExtension.markdown);
            markdown.issue(feature_group);

            immutable expected = filename.freadText;
            assert(bout.toString == expected);
        }

    }

    /// Dlang_feature_test
    {
        auto bout = new OutBuffer;
        auto dlang = Dlang(bout);
        alias unit_mangle = mangleFunc!(DlangU);
        const feature_group = getFeature!(tagion.behaviour.BehaviourUnittest);
        {
            scope (exit)
            {
                bout.clear;
            }
            immutable filename = unit_mangle("feature").unitfile.setExtension(FileExtension.dsrc);
            dlang.issue(feature_group);
            immutable result = bout.toString;
            immutable expected = filename.freadText;
            assert(equal(result.splitLines
                    .map!(a => a.strip)
                    .filter!(a => a.length !is 0), expected.splitLines
                    .map!(a => a.strip)
                    .filter!(a => a.length !is 0)));
        }
    }
}
