const fs = require("node:fs")
const vm = require("node:vm")
const assert = require("node:assert/strict")
const path = require("node:path")

const source = fs.readFileSync(path.join(__dirname, "..", "Metrics.js"), "utf8")
const context = {}
vm.createContext(context)
vm.runInContext(source, context)

const firstCpu = context.parseCpu("cpu  100 0 50 850 0 0 0 0\n", null)
const nextCpu = context.parseCpu("cpu  130 0 60 910 0 0 0 0\n", firstCpu)
assert.equal(nextCpu.ready, true)
assert.equal(Math.round(nextCpu.percent), 40)

const memory = context.parseMemory("MemTotal: 1000 kB\nMemAvailable: 250 kB\nSwapTotal: 500 kB\nSwapFree: 400 kB\n")
assert.equal(memory.percent, 75)
assert.equal(memory.swapUsed, 100 * 1024)

const networkA = context.parseNetwork("eth0: 1000 0 0 0 0 0 0 0 2000 0 0 0 0 0 0 0\n", null, 1000)
const networkB = context.parseNetwork("eth0: 5000 0 0 0 0 0 0 0 6000 0 0 0 0 0 0 0\n", networkA, 3000)
assert.equal(networkB.down, 2000)
assert.equal(networkB.up, 2000)

assert.equal(context.parseUptime("90061.00 0.00").label, "1d 1h 1m")
assert.equal(context.formatBytes(1073741824), "1.0 GiB")
assert.deepEqual(Array.from(context.pushSample([1, 2, 3], 4, 3)), [2, 3, 4])

console.log("metrics: ok")
