module tagion.script.godcontract;

import tagion.hibon.HiBONRecord;
import tagion.dart.DARTBasic;

version (GOD_CONTRACT) {
    @recordType("GodContract")
    struct GodContract {
        DartIndex[] remove;
        Documet[] add;
    }
}
