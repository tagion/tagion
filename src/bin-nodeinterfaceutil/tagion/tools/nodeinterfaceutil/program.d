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
import tagion.utils.Random : generateId;
import tagion.communication.HiRPC;
import tagion.hibon.Document;
import tagion.hibon.HiBONFile;

import nngd;

import tagion.tools.nodeinterfaceutil.raylib;

Color pubkey_to_color(Pubkey pubkey) @safe {
    if(pubkey.length < 4) {
        return Colors.BLACK;
    }
    ubyte r = pubkey[1];
    ubyte g = pubkey[2];
    ubyte b = pubkey[3];
    ubyte a = 255;
    return Color(r, g, b, a);
}

Color action_color(NodeAction action) {
    final switch(action) with(NodeInterfaceSub) {
        case NodeAction.received:
            return Colors.DARKBLUE;
        case NodeAction.dialed:
            return Colors.DARKGRAY;
        case NodeAction.accepted:
            return Colors.DARKGRAY;
        case NodeAction.sent:
            return Colors.MAROON;
    }
}

void draw_gradient_line(const Vector2 pos1, const Vector2 pos2, const Color colorStart, const Color colorEnd, int steps)
{
    // Calculate direction vector
    Vector2 dir = Vector2Subtract(pos2, pos1);
    float len = Vector2Length(dir);
    dir.x /= len;
    dir.y /= len;

    float stepSize = len / cast(float)steps;

    foreach(i; 0 .. steps) {
        Vector2 currPos = {pos1.x + dir.x * stepSize * i, pos1.y + dir.y * stepSize * i};
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
    static immutable event_members = [EnumMembers!(NodeAction)];
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

    version(none)
    if(addresses.empty) {
        throw new Exception("Missing subscription address");
    }

    Tid[] tids;
    if(args.length >= 2) {
        string event_filename = args[1];
        tids ~= spawn(&file_handle_worker, event_filename);
    }

    int screenWidth = 800;
    int screenHeight = 800;
    SetConfigFlags(FLAG_WINDOW_RESIZABLE);
    InitWindow(screenWidth, screenHeight, "Tagion Nodeinterface debugger");
    scope(exit) {
        CloseWindow();
    }
    SetTargetFPS(60);

    foreach(address; addresses) {
        tids ~= spawn(&subscription_handle_worker, address);
    }

    static struct Node {
        Vector2 pos;
    }

    auto all_nodes = new RedBlackTree!(Pubkey);

    Node[Pubkey] nodes_by;

    size_t last_node_length;
    auto event_queue = new shared(LRUT!(int, NodeInterfaceSub))(null, 8, 300);

    bool paused;

    while (!WindowShouldClose()) {
        BeginDrawing();
        scope(exit) EndDrawing();

        screenWidth = GetScreenWidth();
        screenHeight = GetScreenHeight();
        int cx = screenWidth/2;
        int cy = screenHeight/2;

        ClearBackground(Colors.RAYWHITE);

        if(IsKeyPressed(KEY_SPACE)) {
            paused = !paused;
        }

        if(!paused) {
            receiveTimeout(Duration.zero,
                    (NodeInterfaceSub sub) { 
                        all_nodes.stableInsert(sub.owner);

                        version(none)
                        if(!sub.channel.empty) {
                            event_queue[generateId] = sub;
                            all_nodes.stableInsert(sub.channel);
                        }
                    }
            );
        }

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

        version(none)
        foreach(event; event_queue[]) {
            const sender = nodes_by[event.value.owner];
            const receiver = nodes_by[event.value.channel];
            // DrawLineEx(sender.pos, receiver.pos, 5, action_color(event.value.event_state));
            const color_begin = action_color(event.value.event_state);
            Color color_end = color_begin;
            color_end.a = 0;
            draw_gradient_line(sender.pos, receiver.pos, color_begin, color_end, 30);
        }

        /* DrawCircle(200, 200, 35, node_color); */
        /* DrawText(display_text, 400, 400, 28, Colors.BLACK); */
    }

    foreach(tid; tids) {
        tid.send(Stop());
    }

    return 0;
}

enum Stop { _ }

void file_handle_worker(string file) {
    try {
        HiBONRange event_range = File(file);

        bool stop;
        while(!stop) {
            try {
                receiveTimeout(Duration.zero, (Stop _) { stop = true; } );
                Thread.sleep(50.msecs);

                if(event_range.empty) {
                    continue;
                }
                Document hirpc_doc = event_range.front;
                event_range.popFront();
                NodeInterfaceSub sub = hirpc_doc["$msg"]["params"]["data"].get!NodeInterfaceSub;
                ownerTid.send(sub);
            }
            catch(Exception e) {
                error(e);
            }
        }
    }
    catch(Throwable e) {
        error(e);
    }
    stderr.writeln("Stopping");
}

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
                NodeInterfaceSub sub = doc["$msg"]["params"]["data"].get!NodeInterfaceSub;
                ownerTid.send(sub);
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
