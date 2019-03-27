module tagion.Debug;


@safe
void D(alias var)() pure const {
    debug {
        import std.stdio;
        writefln("%s=%s", var.stringof, var);
    }
}
