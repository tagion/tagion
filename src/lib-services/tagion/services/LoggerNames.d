module tagion.services.LoggerNames;

enum LoggerNames {
    test,
    test2,
}

unittest {
    // make loggernames
    LoggerNames logger_id;
    // Inside the code you use enum LoggerServices
    with(LoggerNames) final switch(logger_id) {
            static foreach(E; EnumMembers!LoggerName) {
            case E:
                break;
            }
        }

    /// Subscription
    /// From outside you use string names
    string name;
    switch(name) {
        static foreach(E; EnumMembers!LoggerNames) {
        case E.stringof:
            send(E);
            break;

        default:
            writefln("Error not supperd %s", name);
        }
    }
}
