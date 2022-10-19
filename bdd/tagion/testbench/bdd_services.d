module tagion.testbench.bdd_services;

import tagion.behaviour;
import tagion.testbench.services;

import tagion.hibon.HiBONRecord : fwrite;

int main(string[] args)
{
    import transaction_service = Transcation_service;

    auto transaction_feature = automation!(Transaction_service)();
    auto result = transaction_feature.run;

    "/tmp/result.hibon".fwrite(result);

    return 0;
}
