import std.stdio;
import std.array;
import std.range;

import nngd;

version (unittest) {
}
else {
    int main(string[] args) {

        auto log = stderr;
        NNGTestSuite nt = new NNGTestSuite(&log, nngtestflag.DEBUG);

        auto rc = nt.run();
        auto er = nt.errors();

        if (er !is null) {
            writeln(er);
            return -1;
        }
        return 0;

    }
}
