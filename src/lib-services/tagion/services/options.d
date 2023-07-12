module tagion.services.options;

import tagion.utils.JSONCommon;
import tagion.services.inputvalidator;
import tagion.services.supervisor;

struct Options {
    SupervisorOptions supervisor_options;
    InputValidatorOptions input_validator_options;
    mixin JSONCommon;
}
