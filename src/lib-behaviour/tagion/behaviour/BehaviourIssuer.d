module tagion.behaviour.BehaviourIssue;

import tagion.behaviour.BehaviourFeature;
import std.traits;
import std.algorithm : each, map;
import std.range : tee, chain;
import std.array : join, array;
import std.format;

MarkdownT!(Stream) Markdown(Stream)(Stream bout) {
    alias MasterT = MarkdownT!Stream;
    MasterT.master = masterMarkdown;
    return MasterT(bout);
}

DlangT!(Stream) Dlang(Stream)(Stream bout) {
    alias MasterT = DlangT!Stream;
    auto result = MasterT(bout);
    return result;
}

struct MarkdownFMT {
    string indent;
    string name;
    string scenario;
    string feature;
    string property;
}

static MarkdownFMT masterMarkdown = {
    indent: "  ",
    name: "`%2$s`",
    scenario: "### %2$s: %3$s",
    feature: "## %2$s: %3$s",
    property: "%s*%s* %s",
};

enum EXT {
    Markdown = "md",
    Dlang = "d",
}

@safe
struct MarkdownT(Stream) {
    Stream bout;
    //  enum property_fmt="%s*%s* %s"; //=function(string indent, string propery, string description);
    static MarkdownFMT master;

    void issue(Descriptor)(const(Descriptor) descriptor, string indent, string fmt) if (isDescriptor!Descriptor) {
        bout.writefln(fmt, indent, Descriptor.stringof, descriptor.description);
    }

    void issue(I)(const(I) info, string indent, string fmt) if (isInfo!I) {
        issue(info.property, indent, fmt);
        bout.write("\n");
        bout.writefln(master.name, indent ~ master.indent, info.name); //
    }

    void issue(Group)(const(Group) group, string indent, string fmt) if (isActionGroup!Group) {
        if (group !is group.init) {
            group.infos.each!(info =>issue(info, indent, master.property));
            // group.ands
            //     .each!(a => issue(a, indent ~ master.indent, fmt));
        }
    }

    void issue(const(ScenarioGroup) scenario_group, string indent = null) {
        issue(scenario_group.info, indent, master.scenario);
        issue(scenario_group.given, indent ~ master.indent, master.property);
        issue(scenario_group.when, indent ~ master.indent, master.property);
        issue(scenario_group.then, indent ~ master.indent, master.property);
        issue(scenario_group.but, indent ~ master.indent, master.property);
    }

    void issue(const(FeatureGroup) feature_group, string indent = null) {
        issue(feature_group.info, indent, master.feature);
        feature_group.scenarios
            .tee!(a => bout.write("\n"))
            .each!(a => issue(a, indent ~ master.indent));
    }
}

@safe
unittest { // Markdown scenario test
    auto bout = new OutBuffer;
    auto markdown = Markdown(bout);
    alias unit_mangle = mangleFunc!(MarkdownU);
    auto awesome = new Some_awesome_feature;
    const scenario_result = run(awesome);
    //const scenario_result = runner_awesome();
    {
        scope (exit) {
            bout.clear;
        }
        immutable filename = unit_mangle("descriptor")
            .unitfile
            .setExtension(EXT.Markdown);
        immutable expected = filename.freadText;
        io.writefln("scenario_result.given.infos %s", scenario_result.given.infos);
        markdown.issue(scenario_result.given.infos[0], null, markdown.master.property);
        filename.setExtension("mdtest").fwrite(bout.toString);
        assert(bout.toString == expected);
    }
    {
        scope (exit) {
            bout.clear;
        }
        immutable filename = unit_mangle("scenario")
            .unitfile
            .setExtension(EXT.Markdown);
        markdown.issue(scenario_result);
        filename.setExtension("mdtest").fwrite(bout.toString);
        immutable expected = filename.freadText;
//        filename.setExtension("mdtest").fwrite(bout.toString);
        assert(bout.toString == expected);
        //io.writefln("bout=%s", bout);
        //        filename.fwrite(bout.toString);
        //        im
    }
    //    assert(bout.toString == "Not code");
}

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
        immutable filename = unit_mangle("feature")
            .unitfile
            .setExtension(EXT.Markdown);
        markdown.issue(feature_group);
        io.writefln("mdtest = %s", filename.setExtension("mdtest"));
        filename.setExtension("mdtest").fwrite(bout.toString);

        immutable expected = filename.freadText;
        assert(bout.toString == expected);
    }

}

@safe
struct DlangT(Stream) {
    Stream bout;
    static string[] preparations;
    static this() {
        preparations ~=
            q{
            // Auto generated imports
            import tagion.behaviour.BehaviourBase;
            import tagion.behaviour.BehaviourException;
        };
    }

    string issue(I)(const(I) info) if (isInfo!I) {
        alias Property = TemplateArgsOf!(I)[0];
        return format(q{
                @%2$s("%3$s")
                Document %1$s() {
                    check(false, "Check for '%1$s' not implemented");
                    return Document();
                }
            },
                info.name,
                Property.stringof,
                info.property.description
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
                "\"%s\",\n[%-(\"%3$s\",\n%)]",
                scenario_group.info.property.description,
                scenario_group.info.property.comments
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

    void issue(const(FeatureGroup) feature_group, string indent = null) {
        immutable comments = format("[%-(\"%s\", %)]", feature_group.info.property.comments);
        bout.writefln(q{
                module %1$s;
                %4$s
                enum feature = Feature(
                    "%2$s",
                    %3$s);

            },
                feature_group.info.name,
                feature_group.info.property.description,
                comments,
                preparations.join
        );
        feature_group.scenarios
            .map!(s => issue(s))
            .each!(a => bout.write(a));
    }
}

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
        immutable filename = unit_mangle("feature")
            .unitfile
            .setExtension(EXT.Dlang);
        dlang.issue(feature_group);
        immutable result = bout.toString;
        filename.setExtension("dtest").fwrite(result);
        io.writefln("dtest =%s", filename.setExtension("dtest"));

        immutable expected = filename.freadText;
        assert(equal(
                result
                .splitLines
                .map!(a => a.strip)
                .filter!(a => a.length !is 0),
                expected
                .splitLines
                .map!(a => a.strip)
                .filter!(a => a.length !is 0)));
    }
}

version (unittest) {
    import tagion.basic.Basic : mangleFunc, unitfile;
    import tagion.behaviour.BehaviourUnittest;
    import tagion.behaviour.Behaviour;
    import tagion.hibon.Document;
    import std.algorithm.comparison : equal;
    import std.algorithm.iteration : filter;
    import std.string : strip, splitLines;
    import std.range : zip, enumerate;

    alias MarkdownU = Markdown!OutBuffer;
    alias DlangU = Dlang!OutBuffer;

    import std.file : fwrite = write, freadText = readText;

    //    import std.stdio;
    import std.path;
    import std.outbuffer;
    import io = std.stdio;
}
