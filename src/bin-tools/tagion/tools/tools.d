module tagion.tools.tools;

import std.meta;
import tagion.tools.OneMain;

int main(string[] args) {
    import blockutil = tagion.tools.blockutil;
    import stiefel = tagion.tools.boot.stiefel;
    import callstack = tagion.tools.callstack.callstack;
    import dartutil = tagion.tools.dartutil.dartutil;
    import graphview = tagion.tools.graphview;
    import hibonutil = tagion.tools.hibonutil;
    import hirep = tagion.tools.hirep.hirep;
    import neuewelle = tagion.tools.neuewelle;
    import recorderchain = tagion.tools.recorderchain;
    import signs = tagion.tools.signs;
    import subscribe = tagion.tools.subscribe;
    import tagionshell = tagion.tools.tagionshell;
    import tprofview = tagion.tools.tprofview;
    import geldbeutel = tagion.tools.wallet.geldbeutel;
    import wasmutil = tagion.tools.wasmutil.wasmutil;

    alias alltools = AliasSeq!(
            subscribe,
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
            hirep,
            recorderchain,
            callstack,
    );
    mixin doOneMain!(alltools);
    return do_main(args);
}
