import QtQuick
import QtQuick.Layouts
import qs.Commons
import "Metrics.js" as Metrics
import "WidgetLayout.js" as Layout

Column {
  id: root
  required property string kind
  required property color ink
  required property var feed
  required property date today
  readonly property var report: feed ? feed.report : ({})
  readonly property var rows: report.rows || []
  readonly property var current: report.current || ({})
  spacing: Style.space(10)

  function condition(code) {
    if (code === 0) return "Clear sky"
    if (code <= 3) return "Cloudy"
    if (code <= 48) return "Fog"
    if (code <= 57) return "Drizzle"
    if (code <= 67 || (code >= 80 && code <= 82)) return "Rain"
    if (code <= 86) return "Snow"
    return "Thunderstorms"
  }
  function number(value, unit) { return typeof value === "number" ? Math.round(value) + unit : "—" }
  function age(value) {
    var stamp = Date.parse(value)
    if (!isFinite(stamp)) return "Update time unknown"
    var minutes = Math.max(0, Math.floor((today.getTime() - stamp) / 60000))
    return (minutes >= 30 ? "Stale · " : "Updated ") + (minutes >= 60 ? Math.floor(minutes / 60) + "h" : minutes + "m") + " ago"
  }
  Label { text: ({weather: "WEATHER", agents: "AGENT USAGE", disk: "DISK USAGE", calendar: "CALENDAR"})[root.kind]; font.bold: true; font.letterSpacing: 1.3 }

  Loader {
    width: parent.width
    sourceComponent: root.kind === "weather" ? weather : root.kind === "agents" ? agents : root.kind === "disk" ? disk : calendar
  }
  Label {
    visible: !!root.feed && root.feed.error !== ""
    text: root.feed ? root.feed.error : ""
    wrapMode: Text.WordWrap
    font.pixelSize: Style.font.caption
  }

  component Label: Text {
    width: parent.width
    color: root.ink
    textFormat: Text.PlainText
    font.family: "monospace"
    font.pixelSize: Style.font.body
    elide: Text.ElideRight
  }
  component Meter: Rectangle {
    property real fraction: 0
    width: parent.width
    height: Style.space(3)
    color: Util.alpha(root.ink, 0.18)
    Rectangle { width: parent.width * Math.max(0, Math.min(1, parent.fraction)); height: parent.height; color: root.ink }
  }
  Component {
    id: weather
    Column {
      spacing: Style.space(8)
      Label { text: root.report.city || "Choose your location"; font.pixelSize: Style.font.caption }
      Label { text: root.number(root.current.temperature_2m, "°C"); font.pixelSize: Style.space(40); font.bold: true }
      Label { text: root.current.weather_code === undefined ? "" : root.condition(root.current.weather_code) }
      Label { text: "Feels " + root.number(root.current.apparent_temperature, "°") + "  ·  " + root.number(root.current.wind_speed_10m, " km/h"); font.pixelSize: Style.font.caption }
      Repeater {
        model: root.report.daily && root.report.daily.time ? root.report.daily.time : []
        delegate: Label {
          required property int index
          required property string modelData
          text: Qt.formatDate(new Date(modelData + "T12:00:00"), "ddd") + "    "
            + root.number(root.report.daily.temperature_2m_min[index], "°") + " / "
            + root.number(root.report.daily.temperature_2m_max[index], "°")
          font.pixelSize: Style.font.caption
        }
      }
      Label { text: (root.report.updatedAt ? root.age(root.report.updatedAt) + " · " : "") + "Open-Meteo"; font.pixelSize: Style.font.caption }
    }
  }
  Component {
    id: disk
    Column {
      spacing: Style.space(12)
      Repeater {
        model: root.rows
        delegate: Column {
          required property var modelData
          width: parent.width
          spacing: Style.space(5)
          Label { text: modelData.name + "    " + Math.round(modelData.percent) + "%"; font.bold: true }
          Meter { fraction: modelData.percent / 100 }
          Label { text: Metrics.formatBytes(modelData.available) + " free / " + Metrics.formatBytes(modelData.total); font.pixelSize: Style.font.caption }
        }
      }
      Label { visible: !root.rows.length; text: "Reading filesystems…" }
    }
  }
  Component {
    id: agents
    Column {
      spacing: Style.space(12)
      Repeater {
        model: root.rows.slice(0, 4)
        delegate: Column {
          id: agent
          required property var modelData
          width: parent.width
          spacing: Style.space(4)
          Label { text: agent.modelData.name; font.bold: true }
          Label { visible: !!agent.modelData.status; text: agent.modelData.status; wrapMode: Text.WordWrap; font.pixelSize: Style.font.caption }
          Repeater {
            model: agent.modelData.limits
            delegate: Column {
              required property var modelData
              width: parent.width
              spacing: Style.space(4)
              Label { text: modelData.label + "  " + Math.round(modelData.percent) + "% used"; font.pixelSize: Style.font.caption }
              Meter { fraction: modelData.percent / 100 }
            }
          }
          Label { text: typeof agent.modelData.tokens === "number" ? agent.modelData.tokens.toLocaleString() + " tokens today" : "No token count available"; font.pixelSize: Style.font.caption }
          Label { text: root.age(agent.modelData.updatedAt); opacity: 0.82; font.pixelSize: Style.font.caption }
        }
      }
      Label { visible: !root.rows.length; text: "No Omarchy usage records yet."; wrapMode: Text.WordWrap }
    }
  }
  Component {
    id: calendar
    Column {
      spacing: Style.space(12)
      Label { text: Qt.formatDate(root.today, "MMMM yyyy"); font.pixelSize: Style.font.title; font.bold: true }
      Grid {
        width: parent.width
        columns: 7
        Repeater {
          model: ["M", "T", "W", "T", "F", "S", "S"]
          delegate: Text {
            required property string modelData
            width: parent.width / 7; height: Style.space(26)
            text: modelData; color: root.ink; font.family: "monospace"; font.pixelSize: Style.font.caption
            horizontalAlignment: Text.AlignHCenter
          }
        }
        Repeater {
          model: Layout.month(root.today)
          delegate: Rectangle {
            required property var modelData
            width: parent.width / 7; height: Style.space(27)
            color: modelData.today ? root.ink : "transparent"
            Text {
              anchors.centerIn: parent
              text: modelData.day || ""
              font.family: "monospace"; font.pixelSize: Style.font.body; font.bold: modelData.today
              color: modelData.today ? (root.ink.r > 0.5 ? "#111111" : "#f2f2f2") : root.ink
            }
          }
        }
      }
    }
  }
}
