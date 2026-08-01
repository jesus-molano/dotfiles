import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: root

    width: 1920
    height: 1080
    color: "#090a0d"

    readonly property color accent: config.stringValue("accent")
    readonly property color accentText: config.stringValue("accentText")
    readonly property color surface: config.stringValue("surface")
    readonly property color surfaceStrong: config.stringValue("surfaceStrong")
    readonly property color textColor: config.stringValue("text")
    readonly property color mutedColor: config.stringValue("muted")
    readonly property color outlineColor: config.stringValue("outline")
    property date now: new Date()
    property bool authenticating: false

    function submitLogin() {
        if (username.text.length === 0 || password.text.length === 0)
            return

        authenticating = true
        statusMessage.text = "Comprobando credenciales…"
        sddm.login(username.text, password.text, session.currentIndex)
    }

    Connections {
        target: sddm

        function onLoginFailed() {
            root.authenticating = false
            statusMessage.text = "No se pudo iniciar sesión. Revisa la contraseña."
            password.clear()
            password.forceActiveFocus()
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: root.now = new Date()
    }

    Image {
        id: wallpaper
        anchors.fill: parent
        source: Qt.resolvedUrl(config.stringValue("background"))
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "#ed090a0d" }
            GradientStop { position: 0.36; color: "#99090a0d" }
            GradientStop { position: 0.68; color: "#21090a0d" }
            GradientStop { position: 1.0; color: "#73090a0d" }
        }
    }

    Column {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.leftMargin: Math.max(48, parent.width * 0.06)
        anchors.topMargin: Math.max(42, parent.height * 0.07)
        spacing: 2

        Text {
            text: Qt.formatDateTime(root.now, "HH:mm")
            color: root.textColor
            font.family: "Inter"
            font.pixelSize: Math.max(48, root.height * 0.075)
            font.weight: Font.Light
        }

        Text {
            text: Qt.formatDateTime(root.now, "dddd, d MMMM")
            color: root.mutedColor
            font.family: "Inter"
            font.pixelSize: 18
            font.weight: Font.Medium
        }
    }

    Rectangle {
        id: loginCard
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Math.max(48, parent.width * 0.06)
        width: Math.min(440, parent.width - 96)
        height: 474
        radius: 24
        color: root.surface
        border.width: 1
        border.color: root.outlineColor

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 34
            spacing: 16

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 5

                Text {
                    text: "PROJECT ATLAS"
                    color: root.accent
                    font.family: "Inter"
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    font.letterSpacing: 2.4
                }

                Text {
                    text: "Bienvenido de nuevo"
                    color: root.textColor
                    font.family: "Inter"
                    font.pixelSize: 28
                    font.weight: Font.DemiBold
                }

                Text {
                    text: sddm.hostName
                    color: root.mutedColor
                    font.family: "Inter"
                    font.pixelSize: 14
                }
            }

            TextField {
                id: username
                Layout.fillWidth: true
                Layout.preferredHeight: 52
                text: userModel.lastUser
                placeholderText: "Usuario"
                color: root.textColor
                placeholderTextColor: root.mutedColor
                selectionColor: root.accent
                selectedTextColor: root.accentText
                font.family: "Inter"
                font.pixelSize: 15
                selectByMouse: true
                activeFocusOnTab: true
                KeyNavigation.tab: password

                background: Rectangle {
                    radius: 14
                    color: root.surfaceStrong
                    border.width: username.activeFocus ? 2 : 1
                    border.color: username.activeFocus ? root.accent : root.outlineColor
                }
            }

            TextField {
                id: password
                Layout.fillWidth: true
                Layout.preferredHeight: 52
                placeholderText: "Contraseña"
                echoMode: TextInput.Password
                passwordCharacter: "•"
                color: root.textColor
                placeholderTextColor: root.mutedColor
                selectionColor: root.accent
                selectedTextColor: root.accentText
                font.family: "Inter"
                font.pixelSize: 15
                selectByMouse: true
                activeFocusOnTab: true
                enabled: !root.authenticating
                onAccepted: root.submitLogin()
                KeyNavigation.backtab: username
                KeyNavigation.tab: session

                background: Rectangle {
                    radius: 14
                    color: root.surfaceStrong
                    border.width: password.activeFocus ? 2 : 1
                    border.color: password.activeFocus ? root.accent : root.outlineColor
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                ComboBox {
                    id: session
                    Layout.fillWidth: true
                    Layout.preferredHeight: 46
                    model: sessionModel
                    textRole: "name"
                    currentIndex: sessionModel.lastIndex
                    font.family: "Inter"
                    font.pixelSize: 14
                    activeFocusOnTab: true
                    KeyNavigation.backtab: password
                    KeyNavigation.tab: loginButton

                    contentItem: Text {
                        leftPadding: 15
                        rightPadding: 34
                        text: session.displayText
                        color: root.textColor
                        font: session.font
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }

                    background: Rectangle {
                        radius: 13
                        color: root.surfaceStrong
                        border.width: session.activeFocus ? 2 : 1
                        border.color: session.activeFocus ? root.accent : root.outlineColor
                    }
                }

                Text {
                    visible: keyboard.capsLock
                    text: "Bloq Mayús"
                    color: root.accent
                    font.family: "Inter"
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }
            }

            Text {
                id: statusMessage
                Layout.fillWidth: true
                Layout.preferredHeight: 18
                text: ""
                color: text.indexOf("Comprobando") === 0 ? root.mutedColor : "#d86f91"
                font.family: "Inter"
                font.pixelSize: 12
                wrapMode: Text.WordWrap
            }

            Button {
                id: loginButton
                Layout.fillWidth: true
                Layout.preferredHeight: 52
                text: root.authenticating ? "Entrando…" : "Iniciar sesión"
                enabled: !root.authenticating && username.text.length > 0 && password.text.length > 0
                activeFocusOnTab: true
                onClicked: root.submitLogin()
                KeyNavigation.backtab: session

                contentItem: Text {
                    text: loginButton.text
                    color: root.accentText
                    font.family: "Inter"
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                background: Rectangle {
                    radius: 15
                    color: loginButton.enabled ? root.accent : "#665e6673"
                    border.width: loginButton.activeFocus ? 2 : 0
                    border.color: root.textColor
                    opacity: loginButton.down ? 0.82 : 1.0
                }
            }
        }
    }

    Row {
        id: powerActions
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: Math.max(34, parent.width * 0.035)
        anchors.bottomMargin: Math.max(28, parent.height * 0.04)
        spacing: 8

        property bool expanded: false

        AtlasButton {
            text: "Suspender"
            visible: powerActions.expanded && sddm.canSuspend
            onClicked: sddm.suspend()
        }

        AtlasButton {
            text: "Reiniciar"
            visible: powerActions.expanded && sddm.canReboot
            onClicked: sddm.reboot()
        }

        AtlasButton {
            text: "Apagar"
            visible: powerActions.expanded && sddm.canPowerOff
            danger: true
            onClicked: sddm.powerOff()
        }

        AtlasButton {
            text: powerActions.expanded ? "Cerrar" : "Energía"
            emphasized: !powerActions.expanded
            onClicked: powerActions.expanded = !powerActions.expanded
        }
    }

    Component.onCompleted: {
        if (username.text.length > 0)
            password.forceActiveFocus()
        else
            username.forceActiveFocus()
    }

    component AtlasButton: Button {
        id: control
        property bool emphasized: false
        property bool danger: false

        implicitWidth: Math.max(92, contentItem.implicitWidth + 30)
        implicitHeight: 42
        activeFocusOnTab: true

        contentItem: Text {
            text: control.text
            color: control.danger ? "#f1f3f5" : (control.emphasized ? root.accentText : root.textColor)
            font.family: "Inter"
            font.pixelSize: 13
            font.weight: Font.Medium
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        background: Rectangle {
            radius: 13
            color: control.danger ? "#b94f70" : (control.emphasized ? root.accent : root.surfaceStrong)
            border.width: control.activeFocus ? 2 : 1
            border.color: control.activeFocus ? root.textColor : root.outlineColor
            opacity: control.down ? 0.8 : 1.0
        }
    }
}
