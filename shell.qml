//@ pragma Env QS_CRASHREPORT_URL=https://github.com/caelestia-dots/shell/issues/new?template=crash.yml
//@ pragma DefaultEnv QS_NO_RELOAD_POPUP=1
//@ pragma DefaultEnv QS_DROP_EXPENSIVE_FONTS=1
//@ pragma DefaultEnv QSG_RENDER_LOOP=threaded
//@ pragma DefaultEnv QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000
// Rewritten to the installing user's path by install.sh / deploy.sh; the C++
// plugin's QML modules are installed there (see manifest.toml post_install).
//@ pragma Env QML_IMPORT_PATH=__CAELESTIA_QML_IMPORT__

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
import qs.modules.overview.ui
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
    Overview {}
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
