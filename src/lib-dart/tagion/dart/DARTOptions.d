module tagion.dart.DARTOptions;

import tagion.basic.Basic : basename;
import tagion.basic.TagionExceptions;

/** Options for DART */
struct DARTOptions
{
    import tagion.utils.JSONCommon;
    import tagion.options.HostOptions;

    /** name of the DART service */
    string task_name;
    /** pid for node listen*/
    string protocol_id;
    /** host info */
    HostOptions host;
    /** filename for DART file */
    string name;
    string prefix;
    /** path to DART file */
    string path;
    ubyte ringWidth;
    int rings;
    /** flag for initialize DART */
    bool initialize;
    /** flag for synchronize DART */
    bool synchronize;  
    bool angle_from_port;
    bool request;
    /** flag for load full dart */
    bool fast_load;
    ulong tick_timeout;
    bool master_from_port;

    /** options for synchronization*/
    struct Synchronize
    {
        ulong maxSlaves;
        ulong maxMasters;
        ushort maxSlavePort;
        ushort netFromAng;
        ushort netToAng;
        ulong tick_timeout;
        ulong replay_tick_timeout;
        /** name of the DART service */
        string task_name;
        /** pid for node listen*/
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
        /** pid for node listen*/
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
