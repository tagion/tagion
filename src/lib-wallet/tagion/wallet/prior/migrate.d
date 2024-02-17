module tagion.wallet.prior.migrate;

@safe:

import prior = tagion.wallet.prior.AccountDetails;
import current = tagion.wallet.AccountDetails;
import tagion.crypto.SecureNet;
import tagion.dart.DARTBasic;

current.AccountDetails migrate(prior.AccountDetails prior_account) pure {
    const net = new StdHashNet;

    current.AccountDetails new_account;

    /// Fields remain the same
    new_account.owner = prior_account.owner;
    new_account.derivers = prior_account.derivers;
    new_account.bills = prior_account.bills;
    new_account.used_bills = prior_account.used_bills;
    new_account.derive_state = prior_account.derive_state;
    new_account.requested_invoices = prior_account.requested_invoices.dup;
    new_account.hirpcs = prior_account.hirpcs;
    new_account.name = prior_account.name;

    // Locked and Requested bills changeed to be stored by dartIndex instead of by public key
    foreach(bill; prior_account.requested.byValue) {
        new_account.requested[net.dartIndex(bill)] = bill;
    }

    foreach(pair; prior_account.activated.byKeyValue) {
        new_account.activated[net.dartIndex(prior_account.requested[pair.key])] = pair.value;
    }

    return new_account;
}
