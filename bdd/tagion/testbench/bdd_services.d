/// \file behaviour_test.d
module tagion.tools.behaviour_test;

import tagion.behaviour.Behaviour;
import tagion.hibon.HiBONRecord : fwrite;

int main(string[] args)
{
    import recorderchain = tagion.testbench.Add_the_recorder_chain_backup;

    auto recorder_chain_feature = automation!(recorderchain)();
    auto result = recorder_chain_feature.run;

    "/tmp/result.hibon".fwrite(result);

    return 0;
}
