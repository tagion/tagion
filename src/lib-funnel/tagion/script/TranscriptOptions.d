module tagion.script.TranscriptOptions;

import tagion.utils.JSONCommon;
import std.conv : to;

struct TranscriptOptions
{
    string task_name; /// Name of the transcript service
    // This maybe removed later used to make internal transaction test without TLS connection
    // bool enable;

    //    string prefix;
    mixin JSONCommon;
}
