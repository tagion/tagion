module tagion.basic.Version;

import std.format;

/**
   This macro enables the use of version flags in static if
   Example:
   static if (ver.unittest && ver.linux ) {
     ...
   }
 */
struct ver {
    template opDispatch(string M) {
        enum code = format(q{
                version(%s) enum opDispatch = true;
                else         enum opDispatch = false;
            }, M);
        mixin(code);
    }
}

static if (ver.linux && !not_unittest) {
    pragma(msg, "This is a unittest in linux");
}

static if (ver.linux) {
    pragma(msg, "This is LINUX");
}

version (unittest) {
    // empty
    enum not_unittest = false;
}
else {
    enum not_unittest = true;
}
