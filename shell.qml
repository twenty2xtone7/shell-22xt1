//@ pragma Env QS_CRASHREPORT_URL=https://github.com/caelestia-dots/shell/issues/new?template=crash.yml
//@ pragma DefaultEnv QS_NO_RELOAD_POPUP=1
//@ pragma DefaultEnv QS_DROP_EXPENSIVE_FONTS=1
//@ pragma DefaultEnv QSG_RENDER_LOOP=threaded
//@ pragma DefaultEnv QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000
// The C++ plugin is built from this tree by the manifest's post_install hook and
// copied here, so `qs -c caelestia` finds Caelestia.* without a system install.
//@ pragma Env QML_IMPORT_PATH=/home/twenty2xtone/.local/share/caelestia/qml

import QtQuick
import Quickshell
import Caelestia.Config
import qs.services
import qs.utils
import qs.modules.areapicker
import qs.modules.background
import qs.modules.drawers
import qs.modules.lock
import qs.modules.radial
import qs.modules.launcher.services
import qs.daemons

ShellRoot {
    id: root

    settings.watchFiles: true

    Component.onCompleted: {
        // Force certain singletons to load on shell init instead of lazily
        Night;
        Radial;
        LiquidGlass;
        RainbowAnimator;

        Notifs;
        Players;
        Brightness;
        Weather.reload();

        ClipboardService;
        CalendarData;
        CommandRegistry;
        FanCtl;

        if (GlobalConfig.utilities.vpn.enabled)
            VPN;
    }

    FontLoader {
        source: Quickshell.shellPath("assets/google-sans-flex/GoogleSansFlex-VariableFont_GRAD,ROND,opsz,slnt,wdth,wght.ttf")
    }

    Binding {
        target: ShellState
        property: "shellRoot"
        value: root
    }

    // Modules
    Background {}
    Drawers {}
    AreaPicker {}
    RadialMenu {}
    Lock {
        id: lock
    }

    // Daemons
    Shortcuts {}
    BatteryMonitor {}
    GameMode {}
    IdleInhibit {}
    IdleMonitors {
        lock: lock
    }
}
