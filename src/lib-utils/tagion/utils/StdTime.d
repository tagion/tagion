module tagion.utils.StdTime;

import std.datetime;
import std.typecons: Typedef;
import tagion.basic.Basic: nameOf;

enum SDT = "SDT";

alias sdt_t = Typedef!(long, long.init, SDT);

sdt_t currentTime() {
    return sdt_t(Clock.currStdTime);
}
