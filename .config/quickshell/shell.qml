import Quickshell
import Quickshell.Io
import "."

ShellRoot {
    id: shellRoot

    NetworkPanel { id: networkPanel }
    BluetoothPanel { id: bluetoothPanel }

    IpcHandler {
        target: "shell"

        function toggleNetwork() {
            var willOpen = !networkPanel.opened
            bluetoothPanel.closePanel()
            networkPanel.opened = willOpen
            if (networkPanel.opened) networkPanel.refresh(true)
        }

        function toggleBluetooth() {
            var willOpen = !bluetoothPanel.opened
            networkPanel.closePanel()
            bluetoothPanel.opened = willOpen
            if (bluetoothPanel.opened) bluetoothPanel.refresh()
        }
    }
}
