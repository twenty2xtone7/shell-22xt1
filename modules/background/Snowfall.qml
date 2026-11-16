pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import QtQuick.Particles
import qs.components
import qs.services

// Desktop-only snowfall, on the background layer behind windows and panels.
//
// Runs on Qt's C++ particle engine (QtQuick.Particles), not on a per-frame QML
// JS loop: motion, respawn, rotation and fade are batched on the render thread,
// so a snowfall never competes with the GUI thread for frame budget. The previous
// implementation drove up to 1000 Rectangles from FrameAnimation (~4 property
// writes each per frame), which starved the first frames of any panel animation.
Item {
    id: root

    required property ShellScreen screen

    // A fullscreen window covers the desktop, so snow isn't visible — stop the system
    readonly property bool covered: (Hypr.monitorFor(screen)?.activeWorkspace?.toplevels?.values ?? []).some(t => (t.lastIpcObject?.fullscreen ?? 0) > 1)
    readonly property bool active: Snow.enabled && Snow.count > 0

    visible: opacity > 0
    opacity: active && !covered ? 1 : 0

    Behavior on opacity {
        Anim {
            type: Anim.SlowEffects
        }
    }

    ParticleSystem {
        id: sys

        running: root.opacity > 0
    }

    Emitter {
        id: emitter

        system: sys
        // Spawn along the top edge so flakes enter from off-screen
        y: -24
        width: parent.width
        height: 1
        lifeSpan: 16000
        lifeSpanVariation: 2000
        // Steady-state population = emitRate * lifeSpan / 1000
        emitRate: Snow.count / (lifeSpan / 1000)
        size: (Snow.minSize + Snow.maxSize) / 2
        sizeVariation: (Snow.maxSize - Snow.minSize) / 2
        velocity: AngleDirection {
            // 90deg is straight down; wind tilts the fall direction
            angle: 90 - 31 * Snow.wind
            angleVariation: 4
            magnitude: (Snow.minSpeed + Snow.maxSpeed) / 2
            magnitudeVariation: (Snow.maxSpeed - Snow.minSpeed) / 2
        }
    }

    Wander {
        system: sys
        // xVariance is a lateral speed (px/s); pace is the time between direction
        // changes in ms, so it has to be the sway period, not the rate.
        xVariance: Snow.sway
        pace: Snow.swaySpeed > 0 ? Math.round(1000 / Snow.swaySpeed) : 1000
    }

    ImageParticle {
        system: sys

        source: Snow.shape === 0 ? Qt.resolvedUrl("../../assets/snow/flake-round.png") : Qt.resolvedUrl("../../assets/snow/flake-square.png")
        color: Snow.color
        alpha: Snow.maxOpacity
        alphaVariation: Snow.maxOpacity - Snow.minOpacity
        // Fade out over the last fifth of each flake's life instead of popping
        opacityTable: Qt.resolvedUrl("../../assets/snow/fade.png")
        sizeTable: Snow.decayEnabled ? Qt.resolvedUrl("../../assets/snow/fade.png") : ""
        autoRotation: Snow.spin
        rotationVelocity: Snow.spin ? Snow.spinSpeed : 0
        rotationVelocityVariation: Snow.spin ? Snow.spinSpeed * 0.4 : 0
    }
}
