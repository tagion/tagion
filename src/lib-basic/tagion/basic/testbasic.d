module tagion.basic.testbasic;
import std.conv : to;

enum unitdata = "unitdata";

/**
* Used in unitttest local the path package/unitdata/filename 
* Params:
*   filename = name of the unitdata file
*   file = default location of the module
* Returns:
*   unittest data filename
 */
string unitfile(string filename, string file = __FILE__) @safe {
    import std.path;

    return buildPath(file.dirName, unitdata, filename);
}

/++
 Generate a temporary file name
+/
@trusted
string tempfile() {
    import std.file;
    import std.path;
    import std.random;
    import std.range;

    auto rnd = Random(unpredictableSeed);
    return buildPath(tempDir, generate!(() => uniform('A', 'Z', rnd)).takeExactly(20).array);
}

@safe
void forceRemove(const(string) filename) {
    import std.file : exists, remove;

    if (filename.exists) {
        filename.remove;
    }
}


import std.typecons : Tuple;

alias FileNames = Tuple!(string, "tempdir", string, "filename", string, "fullpath");
const(FileNames) fileId(T)(string ext, string prefix = null) @safe {
    import std.array : join;
    import std.file;
    import std.path;
    import std.process : environment, thisProcessID;

    //import std.traits;
    FileNames names;
    names.tempdir = tempDir.buildPath(environment.get("USER"));
    names.filename = setExtension([prefix, thisProcessID.to!string, T.stringof].join("_"), ext);
    names.fullpath = buildPath(names.tempdir, names.filename);
    names.tempdir.exists || names.tempdir.mkdir;
    return names;
}

