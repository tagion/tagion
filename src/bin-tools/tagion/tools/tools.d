module tagion.tools.tools;

import std.meta;

import tagion.tools.OneMain;

int main(string[] args) {
    import tagionwave = tagion.tools.tagionwave;
    import neuewelle = tagion.tools.neuewelle;
    import subscribe = tagion.tools.subscribe;
    import dartutil = tagion.tools.dartutil.dartutil;
    import hibonutil = tagion.tools.hibonutil;
    import tagionwallet = tagion.tools.tagionwallet;
    import tagionboot = tagion.tools.tagionboot;
    import blockutil = tagion.tools.blockutil;
    import tprofview = tagion.tools.tprofview;
    import recorderchain = tagion.tools.recorderchain;
    import graphview = tagion.tools.graphview;
    import signs = tagion.tools.signs;
    import wasmutil = tagion.tools.wasmutil.wasmutil;
    import geldbeutel = tagion.tools.wallet.geldbeutel;
    import tagionshell = tagion.tools.tagionshell;
    import stiefel = tagion.tools.boot.stiefel;

    alias alltools = AliasSeq!(
            tagionwave,
            subscribe,
            neuewelle,
            dartutil,
            hibonutil,
            tagionwallet,
            tagionboot,
            blockutil, tprofview,
            recorderchain,
            graphview,
            signs,
            wasmutil,
            geldbeutel,
            tagionshell,
            stiefel,
    );
    mixin doOneMain!(alltools);
    return do_main(args);
}
