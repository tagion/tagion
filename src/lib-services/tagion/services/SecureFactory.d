module tagion.service.SecureFactory;

import tagion.gossip.InterfaceNet : FactoryNet;
import tagion.crypto.SecureInterface : HashNet;
import tagion.crypto.SecureNet : StdSecureNet;
import tagion.crypto.secp256k1.NativeSecp256k1;

@safe
class SecureFactory : FactoryNet {
    protected {
        StdSecureNet net;
    }
    this(ref StdSecureNet net) {
        this.net = net;
        net = null;
    }

    HashNet hashnet() const {
        return new StdHashNet;
    }
}

pragma(msg, typeof(SecureFactory.hashnet));
