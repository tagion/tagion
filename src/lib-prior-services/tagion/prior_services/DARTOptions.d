/// Options for the DART
module tagion.prior_services.DARTOptions;

import tagion.basic.basic : basename;
import tagion.basic.tagionexceptions;

/**
 * Options for DART
 */
struct DARTOptions {
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
    /** prefixt for DART file name */
    string prefix;
    /** path to DART file */
    string path;
    /** flag for initialize DART */
    bool initialize;
    /** flag for synchronize DART */
    bool synchronize;
    /** flag for load full dart */
    bool fast_load;
    /** timeout in miliseconds */
    ulong tick_timeout;

    /** 
     * Options for synchronization
     */
    struct Synchronize {
        /** timeout in miliseconds */
        ulong tick_timeout;
        /** timeout in miliseconds before receive*/
        ulong reply_tick_timeout;
        /** name of the DART service */
        string task_name;
        /** pid for node listen*/
        string protocol_id;
        /** max amount of nodes, that could be synchronized */
        uint max_handlers;
        import tagion.options.HostOptions;

        /** host info */
        HostOptions host;
        mixin JSONCommon;
    }

    Synchronize sync;

    /** 
     * Options for subscribe
     */
    struct Subscribe {
        /** port for master node */
        ulong master_port;
        import tagion.utils.JSONCommon;

        /** host info */
        HostOptions host;

        /** task name for register master task name*/
        string master_task_name;
        /** task name for register slave task name*/
        string slave_task_name;
        /** pid for node listen*/
        string protocol_id;
        /** timeout in miliseconds */
        ulong tick_timeout;
        mixin JSONCommon;
    }

    Subscribe subs;

    struct Commands {
        /** timeout in miliseconds before read data */
        ulong read_timeout;
        mixin JSONCommon;
    }

    Commands commands;

    mixin JSONCommon;
}
