module tagion.tools.collider.runner;

import tagion.utils.JSONCommon;

struct RunElement {
    string[] stages;
    string[string] envs;
    string args;
    mixin JSONCommon;
}

struct Runner {
    RunElement[string] elements;
}
