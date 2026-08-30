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

    IpcHandler {
        target: "shell"

        function toggleNetwork() {
            var willOpen = !networkPanel.opened
            bluetoothPanel.closePanel()
            powerPanel.closePanel()
            clockPanel.closePanel()
            brightnessPanel.closePanel()
            audioPanel.closePanel()
            mediaPanel.closePanel()
            networkPanel.opened = willOpen
            if (networkPanel.opened) networkPanel.refresh(true)
        }

        function toggleBluetooth() {
            var willOpen = !bluetoothPanel.opened
            networkPanel.closePanel()
            powerPanel.closePanel()
            clockPanel.closePanel()
            brightnessPanel.closePanel()
            audioPanel.closePanel()
            mediaPanel.closePanel()
            bluetoothPanel.opened = willOpen
            if (bluetoothPanel.opened) bluetoothPanel.refresh()
        }

        function togglePower() {
            var willOpen = !powerPanel.opened
            networkPanel.closePanel()
            bluetoothPanel.closePanel()
            clockPanel.closePanel()
            brightnessPanel.closePanel()
            audioPanel.closePanel()
            mediaPanel.closePanel()
            powerPanel.opened = willOpen
        }

        function toggleClock() {
            var willOpen = !clockPanel.opened
            networkPanel.closePanel()
            bluetoothPanel.closePanel()
            powerPanel.closePanel()
            brightnessPanel.closePanel()
            audioPanel.closePanel()
            mediaPanel.closePanel()
            clockPanel.opened = willOpen
            if (clockPanel.opened) clockPanel.refresh()
        }

        function toggleBrightness() {
            var willOpen = !brightnessPanel.opened
            networkPanel.closePanel()
            bluetoothPanel.closePanel()
            powerPanel.closePanel()
            clockPanel.closePanel()
            audioPanel.closePanel()
            mediaPanel.closePanel()
            brightnessPanel.opened = willOpen
            if (brightnessPanel.opened) brightnessPanel.refresh()
        }

        function toggleAudio() {
            var willOpen = !audioPanel.opened
            networkPanel.closePanel()
            bluetoothPanel.closePanel()
            powerPanel.closePanel()
            clockPanel.closePanel()
            brightnessPanel.closePanel()
            mediaPanel.closePanel()
            audioPanel.opened = willOpen
            if (audioPanel.opened) audioPanel.refresh()
        }

        function toggleMedia() {
            var willOpen = !mediaPanel.opened
            networkPanel.closePanel()
            bluetoothPanel.closePanel()
            powerPanel.closePanel()
            clockPanel.closePanel()
            brightnessPanel.closePanel()
            audioPanel.closePanel()
            mediaPanel.opened = willOpen
            if (mediaPanel.opened) mediaPanel.refresh()
        }
    }
}
