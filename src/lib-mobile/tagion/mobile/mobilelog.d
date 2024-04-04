module tagion.mobile.mobilelog;
import std.file;
import std.path;

version(WRITE_LOGS) 
@safe void write_log(const(string) message) pure nothrow {
    if (!__ctfe) { 
        debug {
            string logPath = "/data/user/0/io.decard.tagion_wallet_api_example/app_flutter/";
            if (logPath.exists) {
                string logFileName = "logfile.txt";
                string logFile = buildPath(logPath, logFileName);
                logFile.append(message);
            }
        }
    }
}
