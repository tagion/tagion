module tagion.tools.collider.runner;

import tagion.utils.JSONCommon;

struct RunElement {
    string[] stages;
    string[string] envs;
    string[] args;
    mixin JSONCommon;
}

struct Schedule {
    RunElement[string] schedules;
    mixin JSONCommon;
    mixin JSONConfig;
}

void runSchedule(const Schedule schedule, string[] stages, const uint jobs) {
   import std.stdio;
schedule.toJSON.toPrettyString.writeln;
}
