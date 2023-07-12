module tagion.services.options;

import tagion.utils.JSONCommon;
import tagion.services.inputvalidator;

struct Options {
    InputValidatorOptions input_validator_options;
    mixin JSONCommon;
}
