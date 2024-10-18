module tagion.services.tasknames;

@safe
struct TaskNames {
    private import std.traits;
    private import tagion.json.JSONRecord;

    string program = "tagion";
    string supervisor = "supervisor";
    string inputvalidator = "inputvalidator";
    string dart = "dart";
    string hirpc_verifier = "hirpc_verifier";
    string collector = "collector";
    string transcript = "transcript";
    string tvm = "tvm";
    string epoch_creator = "epoch_creator";
    string replicator = "replicator";
    string dart_interface = "dartinterface";
    string trt = "trt";
    string node_interface = "node_interface";

    mixin JSONCommon;

    /// Set a prefix for the default options
    this(const string prefix) pure {
        setPrefix(prefix);
    }

    /**
        Inserts a prefix for all the task_names
        This function is used in mode 0.
    */
    void setPrefix(const string prefix) pure nothrow {
        alias This = typeof(this);
        alias FieldsNames = FieldNameTuple!This;
        static foreach (i, T; Fields!This) {
            static if (is(T == string)) {
                this.tupleof[i] = prefix ~ this.tupleof[i];
            }
        }
    }
}
