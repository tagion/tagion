/// Service for handling both text logs and variable logging
module tagion.services.logger;

@safe:

import std.array;
import std.conv : to;
import std.format;
import std.stdio;
import std.string;
import tagion.actor;
import tagion.hibon.Document : Document;
import tagion.hibon.HiBONRecord;
import tagion.logger.LogRecords;
import tagion.logger.Logger;
import tagion.json.JSONRecord;


/**
 * LoggerTask
 * Struct represents LoggerService which handles logs and provides passing them to LogSubscriptionService
 */
struct LoggerService {
    void task() {
        /** Task method that receives logs from Logger and sends them to console, file and LogSubscriptionService
         *      @param info - log info about passed log
         *      @param doc - log itself, that can be either TextLog or some HiBONRecord variable
         */
        void receiveLogs(immutable(LogInfo) info, immutable(Document) doc) {
            enum _msg = GetLabel!(TextLog.message).name;
            if (info.isTextLog && doc.hasMember(_msg)) {
                log.write(info.level, info.task_name, doc[_msg].get!string);
            }
        }

        run(&receiveLogs);
    }
}
