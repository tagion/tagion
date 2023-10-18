module tagion.logger.LoggerOptions;

import tagion.utils.JSONCommon;

struct LoggerOptions {
    string task_name; /// Name of the logger task
    string file_name; /// File used for the logger
    bool flush; /// Will automatic flush the logger file when a message has been received
    bool to_console; /// Will duplicate logger information to the console
    uint mask; /// Logger mask
    uint trunc_size; /// Truct size in bytes (if zero the logger file is not truncated)
    mixin JSONCommon;
}
