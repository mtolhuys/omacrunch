function rootEntries() {
  return [
    { key: "T", label: "Terminal", action: "terminal" },
    { key: "F", label: "Files", action: "files" },
    { key: "W", label: "Web browser", action: "browser" },
    { key: "A", label: "Applications", route: "apps" },
    { key: "B", label: "Wallpaper", route: "background" },
    { key: "H", label: "Theme", route: "theme" },
    { key: "S", label: "Style", route: "style" },
    { key: "I", label: "Widgets", action: "widgets" },
    { key: "K", label: "Keybindings", action: "keybindings" },
    { key: "P", label: "Power", route: "system" }
  ]
}

function commandFor(entry) {
  if (!entry) return []
  if (entry.route) return ["omarchy-menu", "toggle", entry.route]
  if (entry.action === "terminal") return ["omarchy-launch-terminal"]
  if (entry.action === "files") return ["omarchy-launch-nautilus"]
  if (entry.action === "browser") return ["omarchy-launch-browser"]
  if (entry.action === "keybindings") return ["omarchy-menu-keybindings"]
  return []
}
