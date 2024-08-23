module tagion.tools.graphview;
import std.array : join;
import std.range;
import std.conv : to;
import std.typecons;
import std.file : exists, fwrite = write;
import std.format;
import std.functional : toDelegate;
import std.getopt;
import std.outbuffer;
import std.path : extension;
import std.traits : EnumMembers;
import std.traits : isIntegral;
import tagion.basic.basic : EnumText;
import tagion.basic.Types : Buffer, hasExtension, FileExtension;
import tagion.hashgraphview.EventView;
import tagion.hibon.Document : Document;
import tagion.hibon.HiBONJSON;
import tagion.hibon.HiBONRecord : HiBONRecord, isRecord;
import tagion.hibon.HiBONValid : error_callback;
import tagion.hibon.HiBONFile : fread, HiBONRange;
import std.algorithm;
import tools = tagion.tools.toolsexception;
import tagion.tools.revision;
import tagion.utils.BitMask;
import tagion.basic.Debug;
import stdio = std.stdio;

@safe:
static immutable pastel19 = [
    "#fbb4ae", // Light pink
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
    "#ffccff" // Light lavender pink
];
static immutable nonPastel19 = [
    "#f06292", // Pink
    "#4caf50", // Green
    "#9c27b0", // Lavender
    "#ff9800", // Peach
    "#ffeb3b", // Yellow
    "#795548", // Brown
    "#e91e63", // Lavender pink
    "#9e9e9e", // Gray
    "#f44336", // Coral pink
    "#00e676", // Mint
    "#ff5722", // Apricot
    "#616161", // Grayish
    "#4caf50", // Pastel green
    "#ff9800", // Peachy
    "#e91e63", // Pinkish lavender
    "#8bc34a", // Pale green
    "#9c27b0" // Lavender pink
];

struct Segment {
    int from, to;
    Flag!"order" mode;
    this(string s, Flag!"order" mode) const pure {
        this.mode=mode;
        auto r = s.split("..");
        from = r.front.to!int;
        r.popFront;
        to = r.front.to!int;
    }

    bool inRange(ref const EventView event) {
        const x=mode?event.order:event.round;
        return (from == to) || ((x >= from) || from == -1) && ((x < to) || (to == -1));
    }
}

Segment segment;

const(string) color(T)(const(string[]) colors, T index) pure nothrow @nogc if (isIntegral!T) {
    import std.math : abs;

    const i = abs(index) % colors.length;
    return colors[i];
}

static string escapeHtml(string input) pure nothrow {
    string result;
    foreach (char c; input) {
        switch (c) {
        case '&':
            result ~= "&amp;";
            break;
        case '<':
            result ~= "&lt;";
            break;
        case '>':
            result ~= "&gt;";
            break;
        case '"':
            result ~= "&quot;";
            break;
        default:
            result ~= c;
            break;
        }
    }
    return result;
}

struct SVGDot(Range) if (isInputRange!Range && is(ElementType!Range : Document)) {
    import std.format;
    import std.algorithm.comparison : max;
    import std.typecons;

    Range doc_range;
    size_t node_size = 5;
    EventView[uint] events;
    int NODE_INDENT = 120;
    const NODE_CIRCLE_SIZE = 40;

    this(Range doc_range) {
        this.doc_range = doc_range;
    }

    int max_height = int.min;
    int min_height = int.max;
    int max_width = int.min;

    alias Pos = Tuple!(int, "x", int, "y");

    struct SVGCircle {
        bool raw_svg;
        Pos pos;
        int radius;
        string fill;
        string stroke;
        int stroke_width;

        // for html
        string classes;
        string data_info;

        string toString() const pure @safe {
            string options = format(`cx="%s" cy="%s" r="%s" fill="%s" stroke="%s" stroke-width="%s" `, pos.x, pos.y, radius, fill, stroke, stroke_width);
            if (!raw_svg) {
                options ~= format(`class="%s" data-info="%s"`, classes, data_info);
            }
            return format(`<circle %s />`, options);
        }
    }

    struct SVGBox {
        bool raw_svg;
        Pos pos;
        int width;
        int height;
        string fill;
        float fill_opacity=1.0;
        string stroke;
        int stroke_width;

        // for html
        string classes;
        string data_info;

        string toString() const pure @safe {
            string options = format(`x="%s" y="%s" width="%s" height="%s" fill="%s" fill-opacity="%f" stroke="%s" stroke-width="%s" `, pos
                    .x - width, pos.y - height, width * 2, height * 2, fill, fill_opacity, stroke, stroke_width);
            if (!raw_svg) {
                options ~= format(`class="%s" data-info="%s"`, classes, data_info);
            }
            return format(`<rect %s />`, options);
        }
    }

    struct SVGLine {
        Pos pos1;
        Pos pos2;
        string stroke;
        int stroke_width;

        string toString() const pure @safe {
            return format(`<line x1="%s" y1="%s" x2="%s" y2="%s" style="stroke: %s; stroke-width: %s"/>`,
                    pos1.x, pos1.y, pos2.x, pos2.y, stroke, stroke_width);
        }
    }

    struct SVGText {
        Pos pos;
        string fill;
        string text_anchor;
        string dominant_baseline;
        string text;

        string toString() const pure @safe {
            return format(`<text x="%d" y="%d" text-anchor="%s" dominant-baseline="%s" fill="%s"> %s </text>`,
                    pos.x, pos.y, text_anchor, dominant_baseline, fill, text);

        }
    }

    private const(Pos) getPos(ref const EventView e) pure nothrow {
        return Pos(int(e.node_id) * NODE_INDENT + NODE_INDENT, -(int(e.order * NODE_INDENT) + NODE_INDENT));
    }

    private void drawEdge(ref HeightBuffer obuf, const Pos event_pos, ref const EventView ref_event, bool isMother) {

        // const father_event = events[e.father];
        const ref_pos = getPos(ref_event);

        SVGLine line;
        line.pos1 = event_pos;
        line.pos2 = ref_pos;
        line.stroke_width = 10;
        // colors
        if (isMother) {
            line.stroke = ref_event.witness ? "red" : nonPastel19.color(ref_event.node_id);
        }
        else {
            line.stroke = nonPastel19.color(ref_event.node_id);
        }
        obuf[0].writefln("%s", line.toString);
    }

    private void node(ref HeightBuffer obuf, ref const EventView e, const bool raw_svg) {
        const vote_fmt = "%" ~ node_size.to!string ~ ".8s";
        const pos = getPos(e);
        max_width = max(pos.x, max_width);
        max_height = max(-pos.y, max_height);
        min_height = min(-pos.y, min_height);

        if (e.father !is e.father.init && e.father in events) {
            drawEdge(obuf, pos, events[e.father], isMother:
            false);
        }
        if (e.mother !is e.mother.init && e.mother in events) {
            drawEdge(obuf, pos, events[e.mother], isMother:
            true);
        }

        SVGCircle node_circle;
        SVGBox node_box;
        node_circle.raw_svg = raw_svg;
        node_circle.pos = pos;
        node_circle.radius = NODE_CIRCLE_SIZE;
        node_circle.stroke = "black";
        node_circle.stroke_width = 4;

        node_box.raw_svg = raw_svg;
        node_box.pos = pos;
        node_box.width = node_box.height = NODE_CIRCLE_SIZE * 5 / 4;
        node_box.fill_opacity=0;
        // colors
        if (e.witness) {
            //  if (e.famous || e.decided) {
            node_circle.fill = nonPastel19.color(e.round);
            import tagion.hashgraph.Event;

            node_circle.stroke = "red";
            if (e.decided) {
                node_circle.stroke = "green";
            }
            if (e.weak) {
                node_circle.stroke = "yellow";

            }
            node_circle.stroke_width = 10;
            node_circle.radius += NODE_CIRCLE_SIZE / 4;
        }
        else {
            node_circle.fill = pastel19.color(e.round_received);
        }
        if (e.intermediate) {
           // node_box.fill = "lightblue";
            if (e.round_received != int.min) {
                node_box.stroke = pastel19.color(e.round_received);
                node_box.stroke_width = 6;
            }
            obuf[5].writefln("%s", node_box.toString);
        }
        if (e.collector) {
            node_circle.stroke = nonPastel19.color(e.round);
            node_circle.stroke_width += 6;
        }
        if (!raw_svg) {
            node_circle.classes = "myCircle";
            node_circle.data_info = escapeHtml(e.toPretty);
        }

        obuf[10].writefln("%s", node_circle.toString);

        SVGText text;
        text.pos = pos;
        text.text_anchor = "middle";
        text.dominant_baseline = "middle";
        text.fill = "black";
        text.text = format("%s:%s", e.round == int.min ? "X" : format("%s", e.round), e.round_received == int.min ? "X" : format(
                "%s", e.round_received));
        obuf[20].writefln("%s", text.toString);

        text.text = format("%d", e.id);
        text.pos.y += NODE_CIRCLE_SIZE / 2;
        obuf[20].writefln("%s", text.toString);

        text.pos.y += NODE_CIRCLE_SIZE / 2;
        BitMask seen_mask;
        seen_mask = e.seen;
        text.text = (() @trusted => format(vote_fmt ~ ":%d", seen_mask, seen_mask.count))();
        text.fill = "orange";
        text.pos.y += NODE_CIRCLE_SIZE / 2;
        obuf[20].writefln("%s", text.toString);
        BitMask vote_intermediate;
        vote_intermediate = e.intermediate_seen;
        if (vote_intermediate.count > 0) {
            text.text = (() @trusted => format(vote_fmt ~ ":%d", vote_intermediate, vote_intermediate.count))();
            text.fill = "green";
            text.pos.y += NODE_CIRCLE_SIZE / 2;
            obuf[20].writefln("%s", text.toString);
        }
        if (e.witness) {
            BitMask seen_strongly;
            seen_strongly = e.strongly_seen;
            text.text = (() @trusted => format(vote_fmt ~ ":%d", seen_strongly, seen_strongly.count))();
            text.pos.y += NODE_CIRCLE_SIZE / 2;
            text.fill = "red";
            obuf[20].writefln("%s", text.toString);

            BitMask voted_mask;
            voted_mask = e.voted;
            text.text = (() @trusted => format(vote_fmt ~ ":%d", voted_mask, voted_mask.count))();
            text.pos.y += NODE_CIRCLE_SIZE / 2;
            text.fill = "blue";
            obuf[20].writefln("%s", text.toString);

            text.pos = pos;
            text.pos.x -= NODE_CIRCLE_SIZE * 2;
            text.fill = "blue";
            text.text = format("yes %d", e.yes_votes); //, e.no_votes);
            obuf[20].writefln("%s", text.toString);
            text.pos.y += NODE_CIRCLE_SIZE / 2;
        }
    }

    void draw(ref HeightBuffer obuf, ref OutBuffer start, ref OutBuffer end, bool raw_svg) {
        // If the first document is a node amount record we set amount of nodes...
        // Maybe this should be always be possible to set.
        // Or even better it's a part of the EventView package
        const nodes_doc = doc_range.front;
        if (nodes_doc.isRecord!NodeAmount) {
            node_size = NodeAmount(nodes_doc).nodes;
            doc_range.popFront;
        }

        foreach (e; doc_range) {
            if (e.isRecord!EventView) {
                auto event = EventView(e);
                if (segment.inRange(event)) {
                    events[event.id] = event;
                }
            }
            else {
                throw new Exception("Unknown element in graphview doc_range %s", e.toPretty);
            }
        }
        foreach (e; events) {
            node(obuf, e, raw_svg);
        }

        scope (success) {
            start.writefln(`<svg id="hashgraph" width="%s" height="%s" xmlns="http://www.w3.org/2000/svg">`, max_width + NODE_INDENT, max_height - min_height + 4 * NODE_INDENT);
            start.writefln(`<g transform="translate(0,%s)">`, max_height + 2 * NODE_INDENT);
            end.writefln("</g>");
            end.writefln("</svg>");
        }
    }
}

struct HeightBuffer {
    OutBuffer[int] obufs;
    OutBuffer opIndex(const int height) {
        return obufs.require(height, new OutBuffer);
    }

    Range opSlice() pure nothrow {
        return Range(this);
    }

    struct Range {
        HeightBuffer owner;
        int[] height_order;
        this(ref HeightBuffer owner) pure nothrow {
            this.owner = owner;
            height_order = owner.obufs.keys;
            height_order.sort;
            __write("height_order %s", height_order);
        }

        OutBuffer front() pure nothrow {
            if (height_order.empty) {
                return null;
            }
            return owner.obufs[height_order[0]];
        }

        bool empty() const pure nothrow {
            return height_order.empty;
        }

        void popFront() pure nothrow {
            if (!empty) {
                height_order = height_order[1 .. $];
            }
        }
    }
}

import tagion.tools.Basic;

mixin Main!_main;

int _main(string[] args) @trusted {
    import std.stdio;

    immutable program = args[0];

    bool version_switch;

    string[] inputfilenames;
    //string outputfilename;
    string segment_arg;
    bool by_order;
    bool svg;
    try {
        auto main_args = getopt(args,
                std.getopt.config.caseSensitive,
                std.getopt.config.bundling,
                "version", "display the version", &version_switch,
                "v|verbose", "Prints more debug information", &__verbose_switch,
                "svg", "Generate raw svg to stdout else html", &svg,
                "s|segment", "Segment of graph (from:to)", &segment_arg,
                "S|order", "Segment by order", &by_order,

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
                    "Usage:",
                    format("%s [<option>...] <in-file>", program),
                    "",
                    "Where:",
                    "<in-file>           Is an input file in .hibon format",
                    "",
                    "Example:",
                    "# SVG",
                    "graphview Alice.hibon index.svg",
                    "# HTML multi-graph",
                    "graphview *_graph.hibon index.html",
                    "<option>:",
                    ].join("\n"),
                    main_args.options);
            return 0;
        }

        if (segment_arg) {
            const mode=(by_order)?Yes.order:No.order;
            segment = Segment(segment_arg, mode);
        }
        import tagion.basic.Types : hasExtension, FileExtension;

        inputfilenames = args.filter!(arg => arg.hasExtension(FileExtension.hibon)).array;

        File[] inputfiles;
        if (inputfilenames.empty) {
            inputfiles ~= stdin;
            verbose("Reading graph data from stdin");
        }
        else {
            inputfilenames.each!(inputfilename => inputfiles ~= File(inputfilename, "r"));
        }

        File outfile = stdout();
        auto outputfilename = args.filter!(file => file.hasExtension(FileExtension.svg) || file.hasExtension(FileExtension
                .html));
        if (!outputfilename.empty) {
            tools.check(outputfilename.walkLength == 1, format("More then one output file %s", outputfilename));
            const filename = outputfilename.front;
            outfile = File(filename, "w");
            svg = filename.hasExtension(FileExtension.svg);
        }

        assert(inputfiles.length != 0);
        foreach (i, inputfile; inputfiles) {
            HiBONRange hibon_range = HiBONRange(inputfile);

            //auto obuf = new OutBuffer;
            //obuf.reserve(inputfile.size * 2);
            HeightBuffer obuf;
            verbose("inputfile size=%s", inputfile.size);
            auto startbuf = new OutBuffer;
            auto endbuf = new OutBuffer;
            if (i == 0 && !svg) {
                startbuf.writefln(HTML_BEGIN);
            }

            auto dot = SVGDot!HiBONRange(hibon_range);
            dot.draw(obuf, startbuf, endbuf, svg);
            if (inputfiles.length == i + 1 && !svg) {
                endbuf.writefln(EVENT_POPUP);
                endbuf.writefln(HTML_END);
            }

            outfile.write(startbuf);
            obuf[].each!(buf => outfile.write(buf));

            //outfile.write(obuf);
            outfile.write(endbuf);
            verbose("outfile size=%s", outfile.size);
        }
    }
    catch (Exception e) {
        error(e);
        return 1;
    }
    return 0;
}

static immutable HTML_BEGIN = q"EX
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Interactive SVG</title>
  <style>
    #popup {
      display: none;
      position: absolute;
      background-color: #ffffff;
      border: 1px solid #000000;
      padding: 10px;
      z-index: 1;
    }
  </style>
</head>
<body>
EX";

static immutable HTML_END = q"EX
</body>
</html>
EX";

static immutable EVENT_POPUP = q"EX
<!-- The pop-up box -->
<div id="popup"></div>
<script>
// Get the SVG element
const svg = document.querySelector('svg');

// Get all circle elements with the class 'myCircle'
const circles = document.querySelectorAll('.myCircle');

// Add click event listener to each circle
circles.forEach(circle => {
  circle.addEventListener('click', function() {
      console.log("circle pressed!");
    // Get the information from the circle's data-info attribute
    const information = circle.getAttribute('data-info');

    // Show the pop-up box with the information
    const popup = document.getElementById('popup');
    popup.innerHTML = information;
    popup.style.display = 'block';

    // Position the pop-up box near the circle
    const circleBounds = circle.getBoundingClientRect();
    popup.style.top = `${circleBounds.top}px`;
    popup.style.left = `${circleBounds.right}px`;
  });
});

// Close the pop-up box when clicking outside of it
svg.addEventListener('click', function(event) {
  const popup = document.getElementById('popup');
  if (!event.target.classList.contains('myCircle') && event.target !== popup) {
    popup.style.display = 'none';
  }
});
</script>            
EX";
