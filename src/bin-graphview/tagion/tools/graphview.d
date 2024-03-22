module tagion.tools.graphview;
import std.algorithm : min, map;
import std.array : join;
import std.range;
import std.conv : to;
import std.file : exists, fwrite = write;
import std.format;
import std.functional : toDelegate;
import std.getopt;
import std.outbuffer;
import std.path : extension;
import std.traits : EnumMembers;
import std.traits : isIntegral;
import tagion.basic.basic : EnumText;
import tagion.hashgraphview.EventView;
import tagion.hibon.Document : Document;
import tagion.hibon.HiBONJSON;
import tagion.hibon.HiBONRecord;
import tagion.hibon.HiBONValid : error_callback;
import tagion.hibon.HiBONFile : fread, HiBONRange;
import tagion.tools.revision;
import tagion.utils.BitMask;

protected static immutable _params = [
    "events",
    "size",
];

mixin(EnumText!("Params", _params));

static immutable pastel19 = [
    "#fbb4ae", // Light pink
    "#b3cde3", // Light blue
    "#ccebc5", // Light green
    "#decde4", // Light lavender
    "#fed9a6", // Light peach
    "#ffffcc", // Light yellow
    "#e5d8bd", // Light beige
    "#fddaec", // Light lavender pink
    "#f2f2f2", // Light gray
    "#ffcccc", // Light coral pink
    "#b9f6ca", // Light mint
    "#ffd8b1", // Light apricot
    "#d9d9d9", // Light grayish
    "#c2f0c2", // Light pastel green
    "#ffcc99", // Light peachy
    "#ffd1dc", // Light pinkish lavender
    "#d9f2d9", // Light pale green
    "#b2ebf2", // Light pale blue
    "#ffccff"  // Light lavender pink
];

@safe
const(string) color(T)(const(string[]) colors, T index) pure nothrow @nogc if (isIntegral!T) {
    import std.math : abs;

    const i = abs(index) % colors.length;
    return colors[i];
}

@safe
struct SVGDot(Range) if(isInputRange!Range && is (ElementType!Range : Document)) {
    import std.format;
    import std.algorithm.comparison : max;

    Range doc_range;
    size_t node_size = 5;
    EventView[uint] events;
    long NODE_INDENT = 100;

    this(Range doc_range) {
        this.doc_range = doc_range;
    }

    long max_height = long.min;
    long max_width = long.min;

    private void node(ref OutBuffer obuf, ref const EventView e) {
        const cx = long(e.node_id)*100 + NODE_INDENT;
        const cy = long(e.order*100) + NODE_INDENT;
        max_width = max(cx, max_width);
        max_height = max(cy, max_height);

        obuf.writefln(`<circle cx=%s cy=%s r="25" stroke="red" stroke-width="4" fill="yellow"/>`,cx, cy);

       // <circle cx="50" cy="50" r="40" stroke="green" stroke-width="4" fill="yellow" />
    }
    

    void draw(ref OutBuffer obuf, ref OutBuffer start, ref OutBuffer end) {
        const nodes_doc = doc_range.front;
        if (nodes_doc.isRecord!NodeAmount) {
            node_size = NodeAmount(nodes_doc).nodes;
            doc_range.popFront;
        }

        foreach (e; doc_range) {
            if(e.isRecord!EventView) {
                auto event = EventView(e);
                events[event.id] = event;
            }
            else {
                throw new Exception("Unknown element in graphview doc_range %s", e.toPretty);
            }
        }
        foreach(e; events) {
            node(obuf, e);
        }

        // obuf.write("<!DOCTYPE html>\n<html>\n<body>\n");
        scope(success) {
            start.writefln("<!DOCTYPE html>\n<html>\n<body>");
            start.writefln(`<svg width="%s" height="%s" xmlns="http://www.w3.org/2000/svg">`, max_width + NODE_INDENT, max_height + NODE_INDENT);
            start.writefln(`<g transform="scale(1,-1) translate(0,%s)">`, -max_height);

            end.writefln("</g>");
            end.writefln("</body>\n</html>");
        }

    }


}

@safe
struct Dot(Range) if(isInputRange!Range && is(ElementType!Range : Document)){
    @safe:
    import std.format;

    enum INDENT = "  ";

    string name;
    Range doc_range;
    // default node_size 
    // if the eventview range does not begin with a NodeAmount record 
    size_t node_size = 5;
    EventView[uint] events;

    this(Range doc_range, string name) {
        this.doc_range = doc_range;
        this.name = name;
    }

    private void edge(ref OutBuffer obuf, const(string) indent, const bool father_flag, ref const EventView e) const {
        string witness_text;
        void local_edge(string[] texts, const uint end_id, string[] options = null) {
            string[] edge_params;
            edge_params ~= format(`label="%s"`, texts.join("\n"));
            edge_params ~= options;
            obuf.writefln(`%s%s -> %s [%s];`, indent, e.id, end_id,
                    edge_params.join(", "));
        }

        string mask2text(const(uint[]) mask) {
            const mask_text = (()@trusted => format("%s", BitMask(mask)))();
            return mask_text[0 .. min(node_size, mask_text.length)];
        }

        if (father_flag && e.father !is e.father.init && e.father in events) {
            const father_event = events[e.father];
            string[] texts;
            // texts ~= mask2text(father_event.witness_mask);
            local_edge(texts, e.father);
        }
        else if (e.mother !is e.mother.init && e.mother in events) {
            const mother_event = events[e.mother];
            string[] texts;
            string[] options;
            // const witness_mask_text=mask2text(mother_event.witness_mask);
            //texts~=mask2text(mother_event.witness_mask);
            const round_received_mask = mask2text(mother_event.round_received_mask);
            if (round_received_mask) {
                texts ~= format("%s:e", round_received_mask);
            }
            if (mother_event.witness) {
                options ~= format(`color="%s"`, "red");
                options ~= format(`fontcolor="%s"`, "blue");
                options ~= format(`shape="%s"`, "plane");
            }
            local_edge(texts, e.mother, options);
        }
    }

    private void node(ref OutBuffer obuf, const(string) indent, ref const EventView e) const {
        if (e.father !is e.father.init) {
            //obuf.writefln("%s%s -> %s;", indent~INDENT, e.id, e.father);
            edge(obuf, indent ~ INDENT, true, e);

        }
        obuf.writefln(`%s%s [pos="%s, %s!"];`, indent ~ INDENT, e.id, e.node_id * 2, e.order);

        if (e.witness) {
            const color = (e.famous) ? "red" : "lightgreen";
            obuf.writefln(`%s%s [fillcolor="%s"];`, indent ~ INDENT, e.id, color);
        }
        else {
            obuf.writefln(`%s%s [fillcolor="%s"];`, indent ~ INDENT, e.id, pastel19.color(e.round_received));
        }
        if (e.error) {
            obuf.writefln(`%s%s [shape="%s"];`, indent ~ INDENT, e.id, "star");
        }
        else if (e.father_less) {
            obuf.writefln(`%s%s [shape="%s"];`, indent ~ INDENT, e.id, "egg");
        }
        string round_text = (e.round is long.min) ? "\u2693" : e.round.to!string;
        if (e.round_received !is long.min) {
            round_text ~= format(":%s", e.round_received);
        }
        // if (e.erased) {
        //     obuf.writefln(`%s%s [fontcolor="%s"];`, indent~INDENT, e.id, "yellow");
        // }
        obuf.writefln(`%s%s [xlabel="%s"];`, indent ~ INDENT, e.id, round_text);
    }

    void draw(ref OutBuffer obuf, const(string) indent = null) {
        const nodes_doc = doc_range.front;
        if (nodes_doc.isRecord!NodeAmount) {
            node_size = NodeAmount(nodes_doc).nodes;
            doc_range.popFront;
        }

        foreach (e; doc_range) {
            if(e.isRecord!EventView) {
                auto event = EventView(e);
                events[event.id] = event;
            }
            else {
                throw new Exception("Unknown element in graphview doc_range %s", e.toPretty);
            }
        }

        import stdio = std.stdio;

        obuf.writefln("%sdigraph %s {", indent, name);
        //        obuf.writefln(`%snode [margin=0.1 fontcolor=blue fixedsize=true fontsize=32 width=1.2 shape=ellipse rankdir=TB style=filled splines="line"]`, indent);
        obuf.writefln(`%ssplines=line; pin=true;`, indent);
        //obuf.writefln(`%sgraph  [ranksep="1", nodesep="2"]`, indent);
        obuf.writefln(`%snode [margin=0.1 fontcolor=blue fixedsize=true fontsize=24 width=1.2 shape=ellipse rankdir=TB style=filled splines=true];`, indent);
        // edge [lblstyle="above, sloped"];
        //obuf.writefln(`%sedge [lblstyle="above, sloped"];`, indent);
        scope (exit) {
            obuf.writefln("%s}", indent);
        }
        void subgraphs(const(string) indent) {
            OutBuffer[size_t] subbuf;
            scope (exit) {
                foreach (buf; subbuf) {
                    buf.writefln("%s}", indent);
                    obuf.writefln("%s", buf);

                }
            }

            foreach (e; events) {
                OutBuffer subgraph_header(ref const EventView e) {
                    auto sbuf = new OutBuffer;
                    sbuf.writefln("%ssubgraph node_%d { peripheries=0", indent, e.node_id);
                    return sbuf;
                }
                //                stdio.writefln("%s %d", e.id, e.mother);
                auto sub_obuf = subbuf.require(e.node_id, subgraph_header(e));
                if (e.mother !is e.mother.init) {
                    //sub_obuf.writefln("%s%s -> %s;", sub_indent, e.id, e.mother);
                    edge(sub_obuf, indent ~ INDENT, false, e);
                }
            }
        }

        subgraphs(indent ~ INDENT);
        foreach (e; events) {
            node(obuf, indent ~ INDENT, e);
        }
    }
}

import tagion.tools.Basic;

mixin Main!_main;

int _main(string[] args) {
    import std.stdio;

    immutable program = args[0];

    bool version_switch;

    string inputfilename;
    string outputfilename;

    bool svg;

    auto main_args = getopt(args,
            std.getopt.config.caseSensitive,
            std.getopt.config.bundling,
            "version", "display the version", &version_switch,
            "o|output", "output graphviz file", &outputfilename,
            "s|svg", "Generate svg", &svg,
    );

    if (version_switch) {
        revision_text.writeln;
        return 0;
    }

    if (main_args.helpWanted) {
        defaultGetoptPrinter(
                [
            "Documentation: https://docs.tagion.org/",
            "",
            "",
            "Example:",
            "graphview Alice.hibon | neato -Tsvg -o outputfile.svg",
            "Usage:",
            format("%s [<option>...] <in-file>", program),
            "",
            "Where:",
            "<in-file>           Is an input file in .hibon format",
            "",

            "<option>:",
        ].join("\n"),
                main_args.options);
        return 0;
    }

    if (args.length > 1) {
        inputfilename = args[1];
    }

    File inputfile;
    if(inputfilename.empty) {
        inputfile = stdin;
        verbose("Reading graph data from stdin");
    }
    else {
        inputfile = File(inputfilename, "r");
    }

    HiBONRange hibon_range = HiBONRange(inputfile);

    auto obuf = new OutBuffer;
    auto startbuf = new OutBuffer;
    auto endbuf = new OutBuffer;

    if (svg) {
        auto dot = SVGDot!HiBONRange(hibon_range);
        dot.draw(obuf, startbuf, endbuf);
    } else {
        auto dot = Dot!HiBONRange(hibon_range, "G");
        dot.draw(obuf);
    }

    File outfile;
    if(outputfilename.empty) {
        outfile = stdout();
    }
    else {
        outfile = File(outputfilename, "w");
    }

    outfile.write(startbuf);
    outfile.write(obuf);
    outfile.write(endbuf);
    return 0;
}
