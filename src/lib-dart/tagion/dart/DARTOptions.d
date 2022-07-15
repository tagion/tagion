module tagion.dart.DARTOptions;

import tagion.basic.Basic : basename;
import tagion.basic.TagionExceptions;

struct DARTOptions
{
    import tagion.utils.JSONCommon;
    import tagion.options.HostOptions;

    string task_name; /// Name of the DART service
    string protocol_id;
    HostOptions host;
    string name;
    string prefix;
    string path;
    ushort from_ang;
    ushort to_ang;
    ubyte ringWidth;
    int rings;
    bool initialize;
    bool generate;
    bool synchronize;
    bool angle_from_port;
    bool request;
    bool fast_load;
    ulong tick_timeout;
    bool master_from_port;

    struct Synchronize
    {
        ulong maxSlaves;
        ulong maxMasters;
        ushort maxSlavePort;
        ushort netFromAng;
        ushort netToAng;
        ulong tick_timeout;
        ulong replay_tick_timeout;
        string task_name;
        string protocol_id;

        uint attempts;

        bool master_angle_from_port;
        uint max_handlers;
        import tagion.options.HostOptions;

        HostOptions host;
        mixin JSONCommon;
    }

    Synchronize sync;

    struct Subscribe
    {
        ulong master_port;
        import tagion.utils.JSONCommon;

        HostOptions host;
        string master_task_name;
        string slave_task_name;
        string protocol_id;
        ulong tick_timeout;
        mixin JSONCommon;
    }

    Subscribe subs;

    struct Commands
    {
        ulong read_timeout;
        mixin JSONCommon;
    }

    Commands commands;

    mixin JSONCommon;
}
