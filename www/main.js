import getPlatformEnv from "./seizer.js";
import getAudioEngineEnv from "./audio_engine.js";
import getCrossDBEnv from "./crossdb.js";
import getChronoEnv from "./chrono.js";

const canvas_element = document.getElementById("game-canvas");
var globalInstance;

let imports = {
    env: getPlatformEnv(canvas_element, () => globalInstance),
    audio_engine: getAudioEngineEnv(() => globalInstance),
    crossdb: getCrossDBEnv(() => globalInstance),
    chrono: getChronoEnv(() => globalInstance),
};

fetch("blockstacker.wasm")
    .then((response) => response.arrayBuffer())
    .then((bytes) => WebAssembly.instantiate(bytes, imports))
    .then((results) => results.instance)
    .then((instance) => {
        globalInstance = instance;
        instance.exports._start();
    });
