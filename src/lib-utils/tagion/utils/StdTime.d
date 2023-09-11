module tagion.utils.StdTime;

import std.datetime;
import std.typecons : Typedef;

enum SDT = "SDT";

alias sdt_t = Typedef!(long, long.init, SDT);

@safe
sdt_t currentTime() {
    return sdt_t(Clock.currStdTime);
}
