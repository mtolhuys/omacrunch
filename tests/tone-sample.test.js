const fs = require("node:fs")
const vm = require("node:vm")
const assert = require("node:assert/strict")
const path = require("node:path")

const source = fs.readFileSync(path.join(__dirname, "..", "ToneSample.js"), "utf8")
const context = {}
vm.createContext(context)
vm.runInContext(source, context)

assert.deepEqual(
  JSON.parse(JSON.stringify(context.parsePixelLine("3,7: (17,34,51)  #112233  srgb(17,34,51)"))),
  { x: 3, y: 7, red: 17, green: 34, blue: 51 }
)

assert.deepEqual(
  JSON.parse(JSON.stringify(context.parsePixelLine("11,17: (0,0,0,255)  #000000FF  black"))),
  { x: 11, y: 17, red: 0, green: 0, blue: 0 }
)

assert.deepEqual(
  JSON.parse(JSON.stringify(context.parsePixelLine("0,0: (242,242,242,128)  #F2F2F280  srgba"))),
  { x: 0, y: 0, red: 242, green: 242, blue: 242 }
)

assert.equal(context.parsePixelLine("#000000FF"), null)
assert.equal(context.parsePixelLine("0,0: no hexadecimal pixel"), null)

console.log("tone sample: ok")
