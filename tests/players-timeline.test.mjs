import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const playersSource = readFileSync(new URL("../services/Players.qml", import.meta.url), "utf8");
const detailsSource = readFileSync(new URL("../modules/dashboard/media/Details.qml", import.meta.url), "utf8");

// Exercise the QML functions themselves with browser-like MPRIS snapshots.
const functions = Array.from(playersSource.matchAll(/^    function (trackKey|rememberLength|trackLength|seekTo)\((.*?)\): \w+ \{([\s\S]*?)^    \}/gm));
assert.equal(functions.length, 4);
const code = functions.map(([, name, args, body]) => `function ${name}(${args.replace(/:\s*\w+/g, "")}) {${body}}`).join("\n");
const root = { active: null, trackLengths: {} };
Object.assign(root, new Function("root", `${code}\nreturn { trackKey, rememberLength, trackLength, seekTo };`)(root));

function player(overrides = {}) {
    return {
        address: "org.mpris.MediaPlayer2.firefox.instance_test",
        uniqueId: 1,
        metadata: { "xesam:url": "https://music.youtube.com/watch?v=first" },
        trackTitle: "First song",
        lengthSupported: true,
        length: 240,
        canSeek: true,
        positionSupported: true,
        position: 60,
        ...overrides
    };
}

const first = player();
root.active = first;
root.rememberLength();
assert.equal(root.trackLength(first), 240);

// Quickshell substitutes elapsed position for unsupported length. Never cache it.
first.lengthSupported = false;
first.length = first.position;
root.rememberLength();
assert.equal(root.trackLength(first), 240);
assert.equal(first.position / root.trackLength(first), 0.25);
first.position = 120;
first.length = 120;
root.rememberLength();
assert.equal(root.trackLength(first), 240);

const second = player({
    uniqueId: 2,
    metadata: { "xesam:url": "https://music.youtube.com/watch?v=second" },
    trackTitle: "Second song",
    lengthSupported: false,
    length: 30,
    position: 30
});
root.active = second;
root.rememberLength();
assert.equal(root.trackLength(second), 0, "a new song must not inherit the previous duration");
root.seekTo(second, 15);
assert.equal(second.position, 30, "unknown duration must not issue a seek");
assert.equal(root.trackLength(null), 0);
root.seekTo(null, 15);

second.lengthSupported = true;
second.length = 180;
root.rememberLength();
assert.equal(root.trackLength(second), 180, "late duration enables the timeline");
root.seekTo(second, 90);
assert.equal(second.position, 90);
root.seekTo(second, -20);
assert.equal(second.position, 0);
root.seekTo(second, 999);
assert.equal(second.position, 180);
root.seekTo(second, NaN);
root.seekTo(second, Infinity);
assert.equal(second.position, 180);

second.canSeek = false;
root.seekTo(second, 60);
assert.equal(second.position, 180);
second.canSeek = true;
second.positionSupported = false;
root.seekTo(second, 60);
assert.equal(second.position, 180);
second.positionSupported = true;

for (const length of [0, -1, NaN, Infinity, 2147483648]) {
    root.active = player({ uniqueId: 3, length });
    root.rememberLength();
    assert.equal(root.trackLength(root.active), 0);
}

// Some browsers reuse the MPRIS track path; title and URL still distinguish songs.
assert.notEqual(root.trackKey(first), root.trackKey({ ...first, trackTitle: "Different song" }));
assert.notEqual(root.trackKey(first), root.trackKey({ ...first, metadata: { "xesam:url": "different" } }));
assert.notEqual(root.trackKey(first), root.trackKey({ ...first, address: "another-player" }));
for (let i = 0; i < 40; i++) {
    root.active = player({ uniqueId: i + 10, length: i + 100 });
    root.rememberLength();
}
assert.equal(Object.keys(root.trackLengths).length, 32);
assert.equal(root.trackLength(root.active), 139);

const interaction = detailsSource.match(/            onInteraction: value => \{([\s\S]*?)^            \}/m);
assert.ok(interaction);
const slider = { seekPlayer: second, seekTrackKey: root.trackKey(second), seekLength: 180 };
const onInteraction = new Function("root", "Players", "value", interaction[1]);
root.active = second;
onInteraction(slider, root, 0.5);
assert.equal(second.position, 90);
root.active = first;
onInteraction(slider, root, 0.75);
assert.equal(second.position, 90, "switching players during a drag must cancel the seek");
root.active = second;
second.uniqueId++;
onInteraction(slider, root, 0.75);
assert.equal(second.position, 90, "changing tracks during a drag must cancel the seek");

console.log("ok - missing and late durations, track isolation, bounded cache, seek limits, and drag cancellation");
