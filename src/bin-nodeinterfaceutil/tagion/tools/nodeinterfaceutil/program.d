module tagion.tools.nodeinterfaceutil.program;

import core.time;
import core.thread;

import std.stdio;
import std.getopt;
import std.format;
import std.array;
import std.range;
import std.algorithm;
import m = std.math;
import std.conv;
import std.traits;

import tagion.std.container.rbtree;
import tagion.basic.Types;
import tagion.crypto.Types;
import tagion.tools.Basic;
import tagion.tools.revision;
import tagion.tools.toolsexception;
import tagion.logger;
import tagion.logger.subscription;
import tagion.services.nodeinterface;
import tagion.services.messages;
import tagion.utils.pretend_safe_concurrency;
import tagion.utils.LRUT;
import tagion.utils.Random;
import tagion.communication.HiRPC;
import tagion.hibon.Document;

import nngd;

import tagion.tools.nodeinterfaceutil.raylib;

void DrawText(const(char)[] text, int posX, int posY, int fontSize, Color color) {
    import rl = tagion.tools.nodeinterfaceutil.raylib;
    rl.DrawText(&(text ~ '\0')[0], posX, posY, fontSize, color);
}

enum Colors
{
    LIGHTGRAY = Color(200, 200, 200, 255), // Light Gray
    GRAY = Color(130, 130, 130, 255), // Gray
    DARKGRAY = Color(80, 80, 80, 255), // Dark Gray
    YELLOW = Color(253, 249, 0, 255), // Yellow
    GOLD = Color(255, 203, 0, 255), // Gold
    ORANGE = Color(255, 161, 0, 255), // Orange
    PINK = Color(255, 109, 194, 255), // Pink
    RED = Color(230, 41, 55, 255), // Red
    MAROON = Color(190, 33, 55, 255), // Maroon
    GREEN = Color(0, 228, 48, 255), // Green
    LIME = Color(0, 158, 47, 255), // Lime
    DARKGREEN = Color(0, 117, 44, 255), // Dark Green
    SKYBLUE = Color(102, 191, 255, 255), // Sky Blue
    BLUE = Color(0, 121, 241, 255), // Blue
    DARKBLUE = Color(0, 82, 172, 255), // Dark Blue
    PURPLE = Color(200, 122, 255, 255), // Purple
    VIOLET = Color(135, 60, 190, 255), // Violet
    DARKPURPLE = Color(112, 31, 126, 255), // Dark Purple
    BEIGE = Color(211, 176, 131, 255), // Beige
    BROWN = Color(127, 106, 79, 255), // Brown
    DARKBROWN = Color(76, 63, 47, 255), // Dark Brown

    WHITE = Color(255, 255, 255, 255), // White
    BLACK = Color(0, 0, 0, 255), // Black
    BLANK = Color(0, 0, 0, 0), // Blank (Transparent)
    MAGENTA = Color(255, 0, 255, 255), // Magenta
    RAYWHITE = Color(245, 245, 245, 255), // My own White (raylib logo)
}

Color ColorLerp(Color c1, Color c2, float alpha)
{
    ubyte r = cast(ubyte)((1 - alpha) * c1.r + alpha * c2.r);
    ubyte g = cast(ubyte)((1 - alpha) * c1.g + alpha * c2.g);
    ubyte b = cast(ubyte)((1 - alpha) * c1.b + alpha * c2.b);
    ubyte a = cast(ubyte)((1 - alpha) * c1.a + alpha * c2.a);

    return Color(r, g, b, a);
}

Color pubkey_to_color(Pubkey pubkey) @safe {
    if(pubkey.length < 4) {
        return Colors.BLACK;
    }
    /* assert(pubkey.length >= 4, format("Invalid pubkey %s", pubkey.encodeBase64)); */

    ubyte r = pubkey[1];
    ubyte g = pubkey[2];
    ubyte b = pubkey[3];
    ubyte a = 255;
    return Color(r, g, b, a);
}

Color action_color(NodeInterfaceSub.EventState action) {
    final switch(action) with(NodeInterfaceSub) {
        case EventState.receive:
            return Colors.DARKBLUE;
        case EventState.received:
            return Colors.SKYBLUE;
        case EventState.dial:
            return Colors.BEIGE;
        case EventState.dialed:
            return Colors.BROWN;
        case EventState.accept:
            return Colors.GREEN;
        case EventState.accepted:
            return Colors.LIME;
        case EventState.sent:
            return Colors.RED;
        case EventState.send:
            return Colors.DARKPURPLE;
        case EventState.send_from_queue:
            return Colors.PINK;
        case EventState.send_queued:
            return Colors.ORANGE;
    }
}

Vector2 Vector2Subtract(Vector2 v1, Vector2 v2)
{
    Vector2 result = { v1.x - v2.x, v1.y - v2.y };

    return result;
}

float Vector2Length(Vector2 v)
{
    float result = m.sqrt((v.x*v.x) + (v.y*v.y));

    return result;
}



void draw_gradient_line(const Vector2 pos1, const Vector2 pos2, const Color colorStart, const Color colorEnd, int steps)
{
    // Calculate direction vector
    Vector2 dir = Vector2Subtract(pos2, pos1);
    float len = Vector2Length(dir);
    dir.x /= len;
    dir.y /= len;

    // Calculate step size
    float stepSize = len / cast(float)steps;

    // Loop through each step
    for (int i = 0; i < steps; i++)
    {
        // Calculate current position
        Vector2 currPos = {pos1.x + dir.x * stepSize * i, pos1.y + dir.y * stepSize * i};

        // Calculate next position
        Vector2 nextPos = {currPos.x + dir.x * stepSize, currPos.y + dir.y * stepSize};

        // Interpolate color
        Color currColor = ColorLerp(colorStart, colorEnd, cast(float)i / cast(float)(steps - 1));

        // Draw line segment
        DrawLineEx(currPos, nextPos, 5, currColor);
    }
}

void draw_color_map() {
    int x = 15;
    int y = 15;
    static immutable event_members = [EnumMembers!(NodeInterfaceSub.EventState)];
    foreach(state; event_members) {
            DrawRectangle(x, y, 20, 20, action_color(state));
            DrawText(text(state), x + 25, y, 20, Colors.BLACK);
            y += 20;
    }
}

int _main(string[] args) {
    try {
        return __main(args);
    }
    catch(Exception e) {
        error(e);
        return 1;
    }
}

int __main(string[] args) {
    immutable program = args[0];

    string[] addresses;
    bool version_switch;

    auto main_args = getopt(args,
            "version", "display the version", &version_switch,
            "v|verbose", "Prints more debug information", &__verbose_switch,
            "a|address", "Specify an address to listen on (multiple allowed)", &addresses,
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
            format("%s [<option>...] [<hibon-files>...]", program),
            "",
            "<option>:",

        ].join("\n"),
        main_args.options);
        return 0;
    }

    if(addresses.empty) {
        throw new Exception("Missing subscription address");
    }

    int screenWidth = 800;
    int screenHeight = 800;
    SetConfigFlags(FLAG_WINDOW_RESIZABLE);
    InitWindow(screenWidth, screenHeight, "Tagion Nodeinterface debugger");
    scope(exit) {
        CloseWindow();
    }
    SetTargetFPS(60);

    Tid[] tids;
    foreach(address; addresses) {
        tids ~= spawn(&subscription_handle_worker, address);
    }

    static struct Node {
        Vector2 pos;
        /* int posX; */
        /* int posY; */
    }

    auto all_nodes = new RedBlackTree!(Pubkey);

    Node[Pubkey] nodes_by;

    size_t last_node_length;
    NodeInterfaceSub last_event;
    auto event_queue = new shared(LRUT!(int, NodeInterfaceSub))(null, 8, 300);

    while (!WindowShouldClose()) {
        BeginDrawing();
        scope(exit) EndDrawing();

        screenWidth = GetScreenWidth(); screenHeight = GetScreenHeight();
        int cx = screenWidth/2; int cy = screenHeight/2;

        ClearBackground(Colors.RAYWHITE);

        receiveTimeout(Duration.zero,
                (NodeInterfaceSub sub) { 
                    /* display_text = sub.channel.encodeBase64; */
                    /* node_color = pubkey_to_color(sub.channel);  */
                    last_event = sub;
                    all_nodes.stableInsert(sub.owner);
                    if(!sub.channel.empty) {
                        event_queue[generateId] = sub;
                        all_nodes.stableInsert(sub.channel);
                    }
                }
        );

        int RADIUS = (screenWidth <= screenHeight)? cx - 50 : cy - 50;
        // DrawCircle(cx, cy, RADIUS, Colors.BLACK);
        // DrawCircle(cx, cy, RADIUS-10, Colors.RAYWHITE);

        DrawText("TAGION!", screenWidth/2 - 100, screenHeight/2, 28, Colors.BLACK);
        draw_color_map();

        if(last_node_length != all_nodes.length || IsWindowResized()) {
            last_node_length = all_nodes.length;
            foreach(i, pubkey; all_nodes[].enumerate) {
                float angle = m.PI*2 / all_nodes.length * (i + 1);
                Node node;
                node.pos.x = (cx + RADIUS * m.cos(angle));
                node.pos.y = (cy + RADIUS * m.sin(angle));
                nodes_by[pubkey] = node;
            }
        }

        foreach(pubkey; all_nodes[]) {
            Node node = nodes_by[pubkey];
            DrawCircle(node.pos.x.to!int, node.pos.y.to!int, 35, pubkey_to_color(pubkey));
        }

        foreach(event; event_queue[]) {
            const sender = nodes_by[event.value.owner];
            const receiver = nodes_by[event.value.channel];
            // DrawLineEx(sender.pos, receiver.pos, 5, action_color(event.value.event_state));
            const color_begin = action_color(event.value.event_state);
            Color color_end = color_begin;
            color_end.a = 0;
            draw_gradient_line(sender.pos, receiver.pos, color_begin, color_end, 30);
        }
        /* if(last_event !is NodeInterfaceSub.init && !last_event.channel.empty) { */
        /*         const sender = nodes_by[last_event.owner]; */
        /*         const receiver = nodes_by[last_event.channel]; */
        /*         DrawLine(sender.posX, receiver.posX, receiver.posX, receiver.posY, Colors.DARKPURPLE); */
        /*     } */
        /* } */

        /* DrawCircle(200, 200, 35, node_color); */
        /* DrawText(display_text, 400, 400, 28, Colors.BLACK); */
    }

    foreach(tid; tids) {
        tid.send(Stop());
    }

    return 0;
}

enum Stop { _ }

void subscription_handle_worker(string address) {
    try {
        string tag = NodeInterfaceService_().node_action_event.name;
        NNGSocket sock = NNGSocket(nng_socket_type.NNG_SOCKET_SUB);
        int rc;
        scope(exit) sock.close;
        sock.recvtimeout = 500.msecs;
        rc = sock.subscribe(tag);
        check(rc == 0, nng_errstr(rc));
        bool stop;

        while(!stop) {
            try {
                receiveTimeout(Duration.zero, (Stop _) { stop = true; } );

                if(sock.m_state !is nng_socket_state.NNG_STATE_CONNECTED) {
                    rc = sock.dial(address);
                    if(rc != nng_errno.NNG_OK) {
                        Thread.sleep(200.msecs);
                        continue;
                    }
                    stderr.writefln("Listening on %s", address);
                }

                const data = sock.receive!Buffer;
                if (sock.errno == nng_errno.NNG_ETIMEDOUT) {
                    continue;
                }
                check(sock.errno == nng_errno.NNG_OK, nng_errstr(sock.errno));

                long index = data.countUntil('\0');
                check(index > 0, "Message did not begin with a tag");

                Document doc = data[index + 1 .. $];
                SubscriptionPayload payload = HiRPC(null).receive(doc).params;
                ownerTid.send(NodeInterfaceSub(payload.data));
            }
            catch(Exception e) {
                sock.close();
                error(e);
            }
        }
    }
    catch(Throwable e) {
        error(e);
    }
    stderr.writeln("Stopping");
}
