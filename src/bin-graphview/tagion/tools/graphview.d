module tagion.tools.graphview;
import std.getopt;
import std.file : fread = read, fwrite = write, exists;
import std.format;
import std.path : extension;
import std.exception : assumeUnique;
import std.traits : EnumMembers;
import std.array : join;
import std.outbuffer;
import std.algorithm : min;
import std.conv : to;

import tagion.hibon.Document : Document;
import tagion.hibon.HiBONJSON;
import tagion.hibon.HiBONValid : error_callback;
import tagion.hashgraphview.EventView : EventView;
import tagion.tools.revision;
import tagion.utils.BitMask;
import std.traits : isIntegral;
import std.functional : toDelegate;

import tagion.basic.basic : EnumText;

protected enum _params = [
        "events",
        "size",
    ];

mixin(EnumText!("Params", _params));

//

enum pastel19 = [
        "#fbb4ae",
        "#b3cde3",
        "#ccebc5",
        "#decde4",
        "#fed9a6",
        "#ffffcc",
        "#e5d8bd",
        "#fddaec",
        "#f2f2f2"
    ];

string color(T)(string[] colors, T index) if (isIntegral!T) {
    import std.math : abs;

    const i = abs(index) % colors.length;
    return colors[i];
}

enum fileextensions {
    HIBON = ".hibon" //    JSON  = ".json"
}

enum dot_fileextension {
    CMAPX = "cmapx", /// Produces HTML map files for client-side image maps.
    PDF = "pdf", /++ Adobe PDF via the Cairo library. We have seen problems when embedding
                       into, other documents. Instead, use -Tps2 as described below. +/
    PLAIN = "txt", /++ Simple, line-based ASCII format. Appendix E describes this output. An
                     alternate format is plain-ext, which provides port names on the head and
                     tail nodes of edges. +/
    PNG = "png", /// PNG (Portable Network Graphics) output.
    PS = "ps", /// PostScript (EPSF) output.
    PS2 = "ps2", /++
                   PostScript (EPSF) output with PDF annotations.
                   This output should be distilled into PDF,
                   such as for pdflatex, before being included in a document.
                   (Use ps2pdf; epstopdf doesn’t handle %%BoundingBox: (atend).)
                   +/
    SVG = "svg", /// SVG output. The alternate form svgz produces compressed SVG.
    VRML = "vrml", /// VRML output.
    WBMP = "wbmp", ///Wireless BitMap (WBMP) format.
}

// dot -Tsvg test.dot -o test1.svg

struct Dot {
    import std.format;

    static string INDENT;
    static this() {
        INDENT = "  ";
    }
    // OutputBuf obuf;
    string name;
    const size_t node_size;
    //    string indet;
    EventView[uint] events;
    // this(string name, string indent="  ") {
    //     this.obuf = obuf;
    //     this.name = name;
    //     this.indent=indent;
    // }

    this(const Document doc, string name) {
        node_size = doc[Params.size].get!ulong;
        const events_doc = doc[Params.events].get!Document;
        foreach (e; events_doc[]) {
            auto event = EventView(e.get!Document);
            events[event.id] = event;
        }
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
            const mask_text = format("%s", BitMask(mask));
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

                // const strongly_seening_mask = mask2text(
                //     // mother_event.strongly_seeing_mask);
                // if (strongly_seening_mask) {
                //     texts ~= format("%s:s", strongly_seening_mask);
                // }
                // const round_seen_mask = mask2text(mother_event.round_seen_mask);
                // if (round_seen_mask) {
                    // texts ~= format("%s:r", round_seen_mask); //mask2text(mother_event.round_seen_mask));
                // }
            }
            // texts ~= format("%s:w", witness_mask_text);

            //     //       texts~=mask2text(mother_event.strongly_seeing_mask);
            // }
            // else {
            //     texts~=witness_mask_text;
            // }
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
            obuf.writefln(`%s%s [fillcolor="%s"];`, indent ~ INDENT, e.id, pastel19.color(e.round));
        }
        if (e.error) {
            obuf.writefln(`%s%s [shape="%s"];`, indent ~ INDENT, e.id, "star");
        }
        else if (e.father_less) {
            obuf.writefln(`%s%s [shape="%s"];`, indent ~ INDENT, e.id, "egg");
        }
        string round_text = (e.round is int.min) ? "\u2693" : e.round.to!string;
        if (e.round_received !is int.min) {
            round_text ~= format(":%s", e.round_received);
        }
        // if (e.erased) {
        //     obuf.writefln(`%s%s [fontcolor="%s"];`, indent~INDENT, e.id, "yellow");
        // }
        obuf.writefln(`%s%s [xlabel="%s"];`, indent ~ INDENT, e.id, round_text);
    }

    void draw(ref OutBuffer obuf, const(string) indent = null) {
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
            const sub_indent = indent ~ INDENT;
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
            // if (e.father !is e.father.init) {
            //     //obuf.writefln("%s%s -> %s;", indent~INDENT, e.id, e.father);
            //     edge(obuf, indent~INDENT, true, e);

            // }
            // obuf.writefln(`%s%s [pos="%s, %s!"];`, indent~INDENT, e.id, e.node_id*2, e.order);
            // if (e.witness) {
            //     obuf.writefln(`%s%s [fillcolor="%s"];`, indent~INDENT, e.id, "red");
            // }
            // if (e.father_less) {
            //     obuf.writefln(`%s%s [shape="%s"];`, indent~INDENT, e.id, "egg");
            // }
            // if (e.witness_mask.length) {
            //     BitArray witness_mask;
            //     obuf.writefln(`%s%s [fillcolor="%s"];`, indent~INDENT, e.id, "red");

            // }
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

    auto logo = import("logo.txt");
    auto main_args = getopt(args,
            std.getopt.config.caseSensitive,
            std.getopt.config.bundling,
            "version", "display the version", &version_switch,
            "inputfile|i", "Sets the HiBON input file name", &inputfilename, // "outputfile|o", "Sets the output file name",  &outputfilename,
            // "bin|b", "Use HiBON or else use JSON", &binary,
            // "value|V", format("Bill value : default: %d", value), &value,
            // "pretty|p", format("JSON Pretty print: Default: %s", pretty), &pretty,
            //        "passphrase|P", format("Passphrase of the keypair : default: %s", passphrase), &passphrase

            

    );

    if (version_switch) {
        revision_text.writeln;
        return 0;
    }

    if (main_args.helpWanted) {
        defaultGetoptPrinter(
                [
                "Documentation: https://tagion.org/",
                "",
                "",
                "Example:",
                "graphview Alice.hibon | neato -Tsvg -o outputfile.svg",
                "Usage:",
                // format("%s [<option>...] <in-file> <out-file>", program),
                format("%s [<option>...] <in-file>", program),
                "",
                "Where:",
                "<in-file>           Is an input file in .hibon format",
                // "<out-file>          Is an output file in .json or .hibon format",
                // "                    stdout is used of the output is not specifed the",
                "",

                "<option>:",
                ].join("\n"),
                main_args.options);
        return 0;
    }

    if (args.length > 1) {
        inputfilename = args[1];
    }
    else {
        stderr.writefln("Input file missing");
        return 1;
    }

    const input_extension = inputfilename.extension;
    switch (input_extension) {
    case fileextensions.HIBON:
        immutable data = assumeUnique(cast(ubyte[]) fread(inputfilename));
        const doc = Document(data);
        const error_code = doc.valid(toDelegate(&error_callback));
        if (error_code !is Document.Element.ErrorCode.NONE) {
            writeln("Document format error");
            writefln("For the file %s", inputfilename);
            return 1;
        }
        auto dot = Dot(doc, "G");
        auto obuf = new OutBuffer;
        dot.draw(obuf);
        writefln("%s", obuf);
        break;
    default:
        stderr.writefln("File extensions %s not valid (only %s)",
                input_extension, [EnumMembers!fileextensions]);
    }

    return 0;
}
