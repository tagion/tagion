module tagion.Debug;


@safe
void D(alias var, string form="%s")() pure const {
    debug {
        import std.stdio;
        writefln("%s="~form, var.stringof, var);
    }
}
