module tagion.service.SecureFactory;

import tagion.gossip.InterfaceNet;
import tagion.gossip.GossipNet;
import tagion.crypto.secp256k1.NativeSecp256k1;

@safe
synchronized class SecureFactory : FactoryNet {
    protected {
        shared(StdSecureNet) net;
        shared(bool) keyset;
    }
    this(NativeSecp256k1 crypt) {
        net = new shared(StdSecureNet)(crypt);
    }

    HashNet hashnet() const {
        return HashNet;
    }
    SecureNet securenet() {

    }

    void generateKeyPair(string passphrase)
        in {
            assert(!keyset, "Passphase has already been initialized");
        }
    do {
        net.generateKeyPair(passphrase);
        keyset = true;
    }

}
