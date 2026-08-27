import Quickshell
import Quickshell.Io
import "."

ShellRoot {
    id: shellRoot

    NetworkPanel { id: networkPanel }
    BluetoothPanel { id: bluetoothPanel }
    PowerPanel { id: powerPanel }

    IpcHandler {
        target: "shell"

        function toggleNetwork() {
            var willOpen = !networkPanel.opened
            bluetoothPanel.closePanel()
            powerPanel.closePanel()
            networkPanel.opened = willOpen
            if (networkPanel.opened) networkPanel.refresh(true)
        }

        function toggleBluetooth() {
            var willOpen = !bluetoothPanel.opened
            networkPanel.closePanel()
            powerPanel.closePanel()
            bluetoothPanel.opened = willOpen
            if (bluetoothPanel.opened) bluetoothPanel.refresh()
        }

        function togglePower() {
            var willOpen = !powerPanel.opened
            networkPanel.closePanel()
            bluetoothPanel.closePanel()
            powerPanel.opened = willOpen
        }
    }
}
