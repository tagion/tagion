module tagion.tools.revision;

import std.string : splitLines;
import std.format;
import std.array : join;
import std.algorithm.iteration : map;
import std.range : zip;

enum revision_info = import("revision.mixin").splitLines;

// enum REVNO=5428;
// enum HASH="ce2a1ead7b778bee54c1a1d7e7fbe621b413c88b";
// enum INFO="git@github.com:tagion/tagion.git";
// enum DATE="2022-06-14 16:07";

// import std.format;
// import std.array : join;
enum revision_text = zip(
            [
        "git: %s", "branch: %s", "hash: %s", "revno: %s", "build_date: %s", "builder_name: %s", "builder_email: %s", "CC: %s",
        "DC: %s"
    ],
    revision_info)
        .map!(a => format(a[0], a[1]))
        .join("\n");
//     INFO, HASH, REVNO, DATE, USER, EMAIL, CC, DC);
