module tagion.wallet.Basic;

import tagion.basic.Types : Buffer;
import tagion.crypto.SecureInterfaceNet : HashNet;

/**
     * Calculates the check-sum hash
     * Params:
     *   value = value to be checked
     *   salt = optional salt value
     * Returns: the double hash
     */
@safe
Buffer saltHash(scope const HashNet net, scope const(ubyte[]) value, scope const(ubyte[]) salt = null) scope {
    return net.rawCalcHash(net.rawCalcHash(value) ~ salt);
}
