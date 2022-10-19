module tagion.testbench.bdd_services;

import tagion.behaviour.Behaviour;
import tagion.testbench.services;
import tagion.testbench.services.Transaction_service;


import tagion.hibon.HiBONRecord : fwrite;
int main(string[] args)
{
    auto transaction_feature = automation!(Transaction_service)();
    auto result = transaction_feature.run;

    "/tmp/result.hibon".fwrite(result);

    return 0;
}
