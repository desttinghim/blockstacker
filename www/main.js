import getPlatformEnv from "./seizer.js";
import getAudioEngineEnv from "./audio_engine.js";

const canvas_element = document.getElementById("game-canvas");
var globalInstance;

let imports = {
    env: getPlatformEnv(canvas_element, () => globalInstance),
    audio_engine: getAudioEngineEnv(() => globalInstance),
};

fetch("blockstacker.wasm")
    .then((response) => response.arrayBuffer())
    .then((bytes) => WebAssembly.instantiate(bytes, imports))
    .then((results) => results.instance)
    .then((instance) => {
        globalInstance = instance;
        instance.exports._start();
    });
