import { Wasi } from "./wasi.js";

const wasi = new Wasi({
	stdin: "stdio",
	env: {
		FOO: "FOO",
		BAR: "BAR"
	},
	args: ["--my-arg"]
});

const { instance } = await WebAssembly.instantiateStreaming(fetch("tauon_test.wasm"), {
	"wasi_snapshot_preview1": wasi
});
wasi.instance = instance;

instance.exports._start();
