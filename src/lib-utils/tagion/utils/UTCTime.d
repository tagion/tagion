module tagion.utils.UTCTime;

import std.datetime;
import std.typecons : Typedef;
import tagion.Base: nameOf;

enum UTC = "UTC";

alias utc_t = Typedef!(ulong, ulong.init, UTC);

utc_t currentTime() nothrow{
    return utc_t(Clock.currStdTime);
}