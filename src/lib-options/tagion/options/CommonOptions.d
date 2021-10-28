module tagion.options.CommonOptions;

import tagion.utils.JSONCommon;

struct CommonOptions {
    string nodeprefix; /// Node name prefix used in emulator mode to set the node name and generate keypairs
    string separator; /// Name separator
    uint node_id; /// This is use to set the node_id in emulator mode in normal node this is allways 0

    mixin JSONCommon;
}
