module tagion.tools.tools;

import std.meta;

import tagion.tools.OneMain;

int main(string[] args) {
    import neuewelle = tagion.tools.neuewelle;
    import subscribe = tagion.tools.subscribe;
    import dartutil = tagion.tools.dartutil.dartutil;
    import hibonutil = tagion.tools.hibonutil;
    import blockutil = tagion.tools.blockutil;
    import tprofview = tagion.tools.tprofview;
    import graphview = tagion.tools.graphview;
    import signs = tagion.tools.signs;
    import wasmutil = tagion.tools.wasmutil.wasmutil;
    import geldbeutel = tagion.tools.wallet.geldbeutel;
    import tagionshell = tagion.tools.tagionshell;
    import stiefel = tagion.tools.boot.stiefel;
    import hirep = tagion.tools.hirep.hirep;

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
    );
    mixin doOneMain!(alltools);
    return do_main(args);
}
