import QtQuick

// A mounted widget outlives the shelf's reveal animation. Only the scoped
// public API crosses this boundary, never the host bar or another service.
Item {
  id: host
  required property var hostBar
  required property string moduleId
  required property string screenName
  property bool revealHeld: false
  property bool hoverSuppressed: false
  property var ownedTargets: []
  property var ownedPopouts: []
  property var registeredItem: null
  readonly property var entry: hostBar.pluginEntry(moduleId)
  readonly property var widget: widgetLoader.item
  readonly property bool panelHeld: hoverSuppressed
    || (hostBar.activePopout !== null && ownedPopouts.indexOf(hostBar.activePopout) >= 0)
    || (!!widget && (("opened" in widget && widget.opened === true)
      || ("popupOpen" in widget && widget.popupOpen === true)))
  readonly property bool failed: widgetLoader.status === Loader.Error
  implicitWidth: failed ? 26 : (widget && widget.visible !== false ? widget.implicitWidth : 0)
  implicitHeight: hostBar.barSize

  // KeyboardPanel forwards clicks through registered targets. Concealed
  // buttons must not remain clickable through a native panel's input layer.
  onRevealHeldChanged: ownedTargets.forEach(function(target) {
    if (revealHeld) hostBar.registerClickTarget(target)
    else { hostBar.unregisterClickTarget(target); hostBar.hideTooltip(target) }
  })

  function inject() {
    if (!widget) return
    if ("bar" in widget) widget.bar = api
    if ("moduleName" in widget) widget.moduleName = moduleId
    if ("settings" in widget) widget.settings = Qt.binding(function() {
      return host.entry ? host.entry.settings : { id: host.moduleId }
    })
    registeredItem = widget
    hostBar.registerWidget(moduleId, "center", screenName, widget)
  }

  function remember(list, value) {
    return value && list.indexOf(value) < 0 ? list.concat([value]) : list
  }

  function cleanup() {
    ownedTargets.forEach(function(target) {
      hostBar.hideTooltip(target)
      hostBar.unregisterClickTarget(target)
    })
    ownedPopouts.forEach(function(owner) {
      if (owner && hostBar.activePopout === owner) {
        if (typeof owner.close === "function") owner.close()
        hostBar.releasePopout(owner)
      }
    })
    ownedTargets = []
    ownedPopouts = []
    hoverSuppressed = false
    if (registeredItem) hostBar.unregisterWidget(registeredItem)
    registeredItem = null
  }

  LegacyPluginShell {
    id: legacyApi
    // A scoped shell is never passed into this adapter.
    legacyShell: host.hostBar.shell
      && typeof host.hostBar.shell.pluginShellForBarEntry !== "function" ? host.hostBar.shell : null
    pluginId: host.entry ? host.entry.pluginId : host.moduleId
    moduleName: host.moduleId
  }

  PluginBarBridge {
    id: api
    pluginId: host.entry ? host.entry.pluginId : host.moduleId
    moduleName: host.moduleId
    shell: host.hostBar.shell && typeof host.hostBar.shell.pluginShellForBarEntry === "function"
      ? host.hostBar.shell.pluginShellForBarEntry(pluginId, moduleName) : legacyApi
    foreground: host.hostBar.foreground
    barForeground: host.hostBar.barForeground
    background: host.hostBar.background
    urgent: host.hostBar.urgent
    fontFamily: host.hostBar.fontFamily
    position: host.hostBar.position
    vertical: host.hostBar.vertical
    barSize: host.hostBar.barSize
    transparent: host.hostBar.transparent
    foregroundAnimationEnabled: host.hostBar.foregroundAnimationEnabled
    centerSectionRevealHeld: host.revealHeld
    _centerHoverRevealSuppressed: host.hoverSuppressed
    activePopout: host.ownedPopouts.indexOf(host.hostBar.activePopout) >= 0
      ? host.hostBar.activePopout : (host.hostBar.activePopout ? foreignPopoutMarker : null)
    clickTargets: host.revealHeld ? host.ownedTargets : []
    layoutConfig: host.hostBar.layoutConfig
    _showTooltip: function(target, text) { host.hostBar.showTooltip(target, text) }
    _hideTooltip: function(target) { host.hostBar.hideTooltip(target) }
    _registerClickTarget: function(target) {
      host.ownedTargets = host.remember(host.ownedTargets, target)
      if (host.revealHeld) host.hostBar.registerClickTarget(target)
    }
    _unregisterClickTarget: function(target) {
      host.ownedTargets = host.ownedTargets.filter(function(item) { return item !== target })
      host.hostBar.unregisterClickTarget(target)
    }
    _requestPopout: function(owner) {
      host.ownedPopouts = host.remember(host.ownedPopouts, owner)
      host.hostBar.requestPopout(owner)
    }
    _releasePopout: function(owner) {
      host.hostBar.releasePopout(owner)
      host.ownedPopouts = host.ownedPopouts.filter(function(item) { return item !== owner })
    }
    _switchPanelFrom: function(owner, direction) {
      return host.hostBar.switchPluginPanel(host.moduleId, host.screenName, direction)
    }
    _targetBelongsToWindow: function(target, window) {
      return host.hostBar.targetBelongsToWindow(target, window)
    }
    _moduleWidgets: function(id) { return id === host.moduleId ? host.hostBar.moduleWidgets(id) : [] }
    _run: function(command) { host.hostBar.run(command) }
    _setCenterHoverRevealSuppressed: function(value) { host.hoverSuppressed = value }
  }

  Loader {
    id: widgetLoader
    sourceComponent: host.hostBar.widgetComponent(host.moduleId)
    width: item ? item.implicitWidth : 0
    height: host.height
    onItemChanged: {
      host.cleanup()
      if (item) host.inject()
    }
    // Match the stock bar: a widget may install defaults in onCompleted.
    onLoaded: Qt.callLater(host.inject)
  }

  Text {
    anchors.centerIn: parent
    visible: host.failed
    text: "!"
    textFormat: Text.PlainText
    color: host.hostBar.urgent
  }
  MouseArea {
    anchors.fill: parent
    enabled: host.failed
    acceptedButtons: Qt.NoButton
    hoverEnabled: true
    onEntered: host.hostBar.showTooltip(host, "Could not load " + host.moduleId)
    onExited: host.hostBar.hideTooltip(host)
  }
  Component.onDestruction: cleanup()
}
