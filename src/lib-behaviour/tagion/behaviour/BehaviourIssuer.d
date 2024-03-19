/// \file BehaviourIssue.d
module tagion.behaviour.BehaviourIssue;

import std.algorithm : each, map;
import std.array : array, join;
import std.format;
import std.range : chain, tee;
import std.traits;
import tagion.behaviour.BehaviourFeature;
import tagion.utils.Escaper : escaper;

@safe
MarkdownT!(Stream) Markdown(Stream)(Stream bout) {
    alias MasterT = MarkdownT!Stream;
    MasterT.master = masterMarkdown;
    return MasterT(bout);
}

@safe
DlangT!(Stream) Dlang(Stream)(Stream bout) {
    alias MasterT = DlangT!Stream;
    auto result = MasterT(bout);
    return result;
}

/**
 * \struct MarkdownFMT
 * Formator of the issuer
 */

@safe
struct MarkdownFMT {
    string name;
    string scenario;
    string feature;
    string property;
    string comments;
}

/** 
 * Default formatter for Markdown 
 */
@safe
static MarkdownFMT masterMarkdown = {
    name: "`%1$s`",
    scenario: "### %1$s: %2$s",
    feature: "## %1$s: %2$s",
    property: "*%s* %s",
    comments: "%-(%s\n%)",
};

@safe
struct MarkdownT(Stream) {
    Stream bout;
    static MarkdownFMT master;

    void issue(Descriptor)(const(Descriptor) descriptor, string fmt,
            string comment_fmt = null) if (isDescriptor!Descriptor) {
        bout.writefln(fmt, Descriptor.stringof, descriptor.description);
        if (descriptor.comments) {
            comment_fmt = (comment_fmt is null) ? master.comments : comment_fmt;
            bout.writefln(comment_fmt, descriptor.comments);
        }
    }

    void issue(I)(const(I) info, string fmt) if (isInfo!I) {
        issue(info.property, fmt);
        bout.write("\n");
        bout.writefln(master.name, info.name);
        bout.write("\n");
    }

    void issue(Group)(const(Group) group, string fmt) if (isActionGroup!Group) {
        if (group !is group.init) {
            group.infos.each!(info => issue(info, master.property));
        }
    }

    void issue(const(ScenarioGroup) scenario_group) {
        issue(scenario_group.info, master.scenario);
        issue(scenario_group.given, master.property);
        issue(scenario_group.when, master.property);
        issue(scenario_group.then, master.property);
        issue(scenario_group.but, master.property);
    }

    void issue(const(FeatureGroup) feature_group) {
        issue(feature_group.info, master.feature);
        feature_group.scenarios
            .tee!(a => bout.write("\n"))
            .each!(a => issue(a));
    }
}

/// Examples: Converting a Scenario to Markdown 
@safe
unittest { // Markdown scenario test
    auto bout = new OutBuffer;
    auto markdown = Markdown(bout);
    alias unit_mangle = mangleFunc!(MarkdownU);
    auto awesome = new Some_awesome_feature;
    const scenario_result = run(awesome);
    {
        scope (exit) {
            bout.clear;
        }
        enum filename = unit_mangle("descriptor")
                .setExtension(FileExtension.markdown);
        enum expected = import(filename);
        //io.writefln("scenario_result.given.infos %s", scenario_result.given.infos);
        markdown.issue(scenario_result.given.infos[0], markdown.master.property);
        version (behaviour_unitdata)
            filename.unitfile.setExtension("mdtest").fwrite(bout.toString);
        assert(bout.toString == expected);
    }
    {
        scope (exit) {
            bout.clear;
        }
        enum filename = unit_mangle("scenario")
                .setExtension(FileExtension.markdown);
        markdown.issue(scenario_result);
        version (behaviour_unitdata)
            filename.unitfile.setExtension("mdtest").fwrite(bout.toString);

        enum expected = import(filename);
        assert(bout.toString == expected);
    }
}

/// Examples: Converting a FeatureGroup to Markdown
@safe
unittest {
    auto bout = new OutBuffer;
    auto markdown = Markdown(bout);
    alias unit_mangle = mangleFunc!(MarkdownU);
    const feature_group = getFeature!(tagion.behaviour.BehaviourUnittest);
    {
        scope (exit) {
            bout.clear;
        }
        enum filename = unit_mangle("feature")
                .setExtension(FileExtension.markdown);
        markdown.issue(feature_group);
        version (behaviour_unitdata)
            filename.unitfile.setExtension("mdtest").fwrite(bout.toString);

        immutable expected = import(filename);
        assert(bout.toString == expected);
    }

}

/**
 * \struct DlangT
 * D-source generator
 */
@safe
struct DlangT(Stream) {
    Stream bout;
    static string[] preparations;
    static this() {
        preparations ~=
            q{
            // Auto generated imports
            import tagion.behaviour.BehaviourException;
            import tagion.behaviour.BehaviourFeature;
            import tagion.behaviour.BehaviourResult;
        };
    }

    string issue(I)(const(I) info) if (isInfo!I) {
        alias Property = TemplateArgsOf!(I)[0];
        return format(q{
                @%2$s("%3$s")
                Document %1$s() {
                        return Document();
                    }
                },
                info.name,
                Property.stringof,
                info.property.description.escaper
        );
    }

    string[] issue(Group)(const(Group) group) if (isActionGroup!Group) {
        if (group !is group.init) {
            return group.infos
                .map!(info => issue(info))
                .array;
        }
        return null;
    }

    string issue(const(ScenarioGroup) scenario_group) {
        immutable scenario_param = format(
                "\"%s\",\n[%(%3$s,\n%)]",
                scenario_group.info.property.description,
                scenario_group.info.property.comments
                .map!(comment => comment.escaper.array)
        );
        auto behaviour_groups = chain(
                issue(scenario_group.given),
                issue(scenario_group.when),
                issue(scenario_group.then),
                issue(scenario_group.but),
        );
        return format(q{
                @safe @Scenario(%1$s)
                    class %2$s {
                        %3$s
                    }
                },
                scenario_param,
                scenario_group.info.name,
                behaviour_groups
                .join
        );
    }

    void issue(const(FeatureGroup) feature_group) {
        immutable comments = format("[%(%s,\n%)]",
                feature_group.info.property.comments
                .map!(comment => comment.escaper.array)
        );
        auto feature_tuple = chain(
                feature_group.scenarios
                .map!(scenario => [scenario.info.name, scenario.info.name]),
        [["FeatureGroup*", "result"]])
            .map!(ctx_type => format(`%s, "%s"`, ctx_type[0], ctx_type[1]))
            .join(",\n");

        bout.writefln(q{
                module %1$s;
                %5$s
                enum feature = Feature(
                    "%2$s",
                    %3$s);
                
                alias FeatureContext = Tuple!(
                    %4$s
                );
            },
                feature_group.info.name,
                feature_group.info.property.description,
                comments,
                feature_tuple,
                preparations.join("\n")
        );
        if (feature_group.scenarios.length) {
            feature_group.scenarios
                .map!(s => issue(s))
                .each!(a => bout.write(a));
        }
    }
}

/// Examples: Converting a FeatureGroup to a D-source skeleten
@safe
unittest {
    auto bout = new OutBuffer;
    auto dlang = Dlang(bout);
    alias unit_mangle = mangleFunc!(DlangU);
    const feature_group = getFeature!(tagion.behaviour.BehaviourUnittest);
    {
        scope (exit) {
            bout.clear;
        }
        enum filename = unit_mangle("feature")
                .setExtension(FileExtension.dsrc);
        dlang.issue(feature_group);
        immutable result = bout.toString;
        version (behaviour_unitdata)
            filename.unitfile.setExtension("dtest").fwrite(result.trim_source.join("\n"));
        enum expected = import(filename);
        assert(equal(
                result
                .trim_source,
                expected
                .trim_source
        ));
    }
}

version (unittest) {
    import std.algorithm.comparison : equal;
    import std.algorithm.iteration : filter;
    import std.file : freadText = readText, fwrite = write;
    import std.outbuffer;
    import std.path;
    import std.range : enumerate, zip;
    import std.string : splitLines, strip;
    import tagion.basic.Types : FileExtension;
    import tagion.basic.basic : mangleFunc, unitfile;
    import tagion.behaviour.Behaviour;
    import tagion.behaviour.BehaviourUnittest;
    import tagion.hibon.Document;

    alias MarkdownU = Markdown!OutBuffer;
    alias DlangU = Dlang!OutBuffer;
    ///Returns: a stripped version of a d-source text
    auto trim_source(S)(S source) {
        return source
            .splitLines
            .map!(a => a.strip)
            .filter!(a => a.length !is 0);

    }
}
