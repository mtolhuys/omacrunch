const assert = require('node:assert/strict')
const { entries, sameIds } = require('../PluginShelfModel.js')
const external = (id, defaults = {}) => ({component: {}, metadata: {
  source: 'plugin', firstParty: false, pluginId: id, displayName: id, defaults
}})
const widgets = {a: external('a', {size: 30, alt: false}), b: external('b'),
  c: external('c'), unconfigured: external('unconfigured'), self: external('self'),
  native: {component: {}, metadata: {source: 'plugin', firstParty: true}},
  noComponent: {metadata: {source: 'plugin', firstParty: false}}}
const config = {layout: {left: ['native', {id: 'a', size: 40}, 'missing', 'self'],
  center: [null, {}, 'b', 'a', 'noComponent'], right: ['c']}}
const found = entries(config, widgets, 'self')
assert.deepEqual(found.map(e => e.id), ['a', 'b', 'c'])
assert.deepEqual(found[0].settings, {id: 'a', size: 40, alt: false})
assert.deepEqual(found.map(e => e.originalRegion), ['left', 'center', 'right'])
assert.equal(widgets.a.metadata.defaults.size, 30, 'defaults must not mutate')
assert.deepEqual(entries({}, widgets, 'self'), [])
assert.deepEqual(entries(config, {}, 'self'), [])
assert.deepEqual(entries(null, null, ''), [])
const legacy = {old: {component: {}, metadata: {source: 'plugin'}},
  builtin: {component: {}, metadata: {source: 'plugin'}}}
const oldConfig = {layout: {left: ['old', 'builtin']}}
assert.deepEqual(entries(oldConfig, legacy, '', {}).map(e => e.id), [], 'unknown classification stays excluded')
assert.deepEqual(entries(oldConfig, legacy, '', {
  old: {__isFirstParty: false}, builtin: {__isFirstParty: true}
}).map(e => e.id), ['old'], 'legacy injected manifest classification')
assert.equal(sameIds(['a', 'b'], ['a', 'b']), true)
assert.equal(sameIds(['a'], ['b']), false)
assert.equal(sameIds(['a'], ['a', 'b']), false)
console.log('plugin shelf: configured/enabled only, external only, ordering, defaults, deduplication ok')
