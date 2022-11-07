module tagion.testbench.bdd_mode1;

//import tagion.behaviour.Behaviour;
import tagion.testbench.services;
import tagion.hibon.HiBONRecord : fwrite;

import tagion.tools.Basic;


mixin Main!(_main, "mode1");

int _main(string[] args) {
 //   auto transaction_feature = automation!(Transaction_service)();
 //   auto result = transaction_feature.run;

 //   "/tmp/result.hibon".fwrite(result);

    return 0;
}
