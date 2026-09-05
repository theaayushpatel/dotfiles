import Quickshell
import Quickshell.Io
import "."

ShellRoot {
    id: shellRoot

    NetworkPanel { id: networkPanel }
    BluetoothPanel { id: bluetoothPanel }
    PowerPanel { id: powerPanel }
    ClockPanel { id: clockPanel }
    BrightnessPanel { id: brightnessPanel }
    AudioPanel { id: audioPanel }
    MediaPanel { id: mediaPanel }

    function getScreenByName(name) {
        if (!name) return null
        for (var i = 0; i < Quickshell.screens.length; i++) {
            if (Quickshell.screens[i].name === name) {
                return Quickshell.screens[i]
            }
        }
        return null
    }

    function togglePanelInternal(panelName, targetX, screenName) {
        var xVal = (targetX !== undefined && targetX !== null && targetX !== "") ? Number(targetX) : -1
        var scr = getScreenByName(screenName)

        var panelMap = {
            "network": networkPanel,
            "bluetooth": bluetoothPanel,
            "power": powerPanel,
            "clock": clockPanel,
            "brightness": brightnessPanel,
            "audio": audioPanel,
            "media": mediaPanel
        }

        var target = panelMap[panelName]
        if (!target) return

        var willOpen = !target.opened

        // Close all other panels
        for (var key in panelMap) {
            if (panelMap[key] !== target) {
                panelMap[key].closePanel()
            }
        }

        if (willOpen) {
            if (xVal >= 0) target.targetCenterX = xVal
            if (scr) target.screen = scr
            target.opened = true
            if (typeof target.refresh === "function") {
                target.refresh(panelName === "network")
            }
        } else {
            target.closePanel()
        }
    }

    IpcHandler {
        target: "shell"

        function togglePanel(panelName: string, targetX: real, screenName: string) {
            togglePanelInternal(panelName, targetX, screenName)
        }

        function toggleNetwork() {
            togglePanelInternal("network", -1, "")
        }

        function toggleBluetooth() {
            togglePanelInternal("bluetooth", -1, "")
        }

        function togglePower() {
            togglePanelInternal("power", -1, "")
        }

        function toggleClock() {
            togglePanelInternal("clock", -1, "")
        }

        function toggleBrightness() {
            togglePanelInternal("brightness", -1, "")
        }

        function toggleAudio() {
            togglePanelInternal("audio", -1, "")
        }

        function toggleMedia() {
            togglePanelInternal("media", -1, "")
        }
    }
}
