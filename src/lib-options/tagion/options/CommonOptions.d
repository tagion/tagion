module tagion.options.CommonOptions;

import tagion.utils.JSONCommon;

struct CommonOptions
{
    string nodeprefix; /// Node name prefix used in emulator mode to set the node name and generate keypairs
    string separator; /// Name separator
    string url; /// URL to be used for the sockets

    mixin JSONCommon;
}

protected static shared
{
    CommonOptions _common_options;
    bool _common_options_set;
}

/++
+  Sets the thread global options opt
+/
@safe @nogc
static void setCommonOptions(const(CommonOptions) opt)
in
{
    assert(!_common_options_set, "Common options already set");
}
do
{
    _common_options_set = true;
    _common_options = opt;
}

@safe @nogc
immutable(CommonOptions) commonOptions() nothrow
in
{
    assert(_common_options_set, "Common options has not been set");
}
do
{
    return (() @trusted { return cast(immutable) _common_options; })();
}
