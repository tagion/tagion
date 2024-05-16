module tagion.tools.tools;

import std.meta;
import tagion.tools.OneMain;

int main(string[] args) {
    import blockutil = tagion.tools.blockutil;
    import stiefel = tagion.tools.boot.stiefel;
    import auszahlung = tagion.tools.auszahlung.auszahlung;
    import callstack = tagion.tools.callstack.callstack;
    import dartutil = tagion.tools.dartutil.dartutil;
    import graphview = tagion.tools.graphview;
    import hibonutil = tagion.tools.hibonutil;
    import hirep = tagion.tools.hirep.hirep;
    import neuewelle = tagion.tools.neuewelle;
    import signs = tagion.tools.signs;
    import subscriber = tagion.tools.subscriber;
    import tagionshell = tagion.tools.tagionshell;
    import tprofview = tagion.tools.tprofview;
    import geldbeutel = tagion.tools.wallet.geldbeutel;
    import wasmutil = tagion.tools.wasmutil.wasmutil;
    import kette = tagion.tools.kette;
    import ifiler = tagion.tools.ifiler.ifiler;
    import vergangenheit = tagion.tools.vergangenheit.vergangenheit;
    import tvmutil = tagion.tools.tvmutil.tvmutil;
    import envelope = tagion.tools.envelope;

    alias alltools = AliasSeq!(
            subscriber,
            neuewelle,
            dartutil,
            hibonutil,
            blockutil,
            tprofview,
            graphview,
            signs,
            wasmutil,
            geldbeutel,
            tagionshell,
            stiefel,
            auszahlung,
            hirep,
            callstack,
            ifiler,
            kette,
            vergangenheit,
            tvmutil,
            envelope,
    );
    mixin doOneMain!(alltools);
    return do_main(args);
}
