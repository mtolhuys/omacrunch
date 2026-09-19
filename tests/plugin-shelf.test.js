const assert = require('node:assert/strict')
const { entries, sameIds, normalizeOrder, orderedEntries, mergeOrder, moveId } = require('../PluginShelfModel.js')
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
assert.deepEqual(normalizeOrder(['b', null, 4, 'b', '../escape', 'a', '__proto__', 'c']), ['b', 'a', 'c'])
assert.deepEqual(normalizeOrder(null), [])
assert.deepEqual(orderedEntries(found, ['c', 'disabled', 'a']).map(e => e.id), ['c', 'a', 'b'])
assert.equal(orderedEntries(found, ['c'])[0], found[2], 'retain entry settings and identity')
assert.deepEqual(mergeOrder(['a', 'hidden', 'b', 'c'], ['c', 'b', 'a', 'new']), ['c', 'hidden', 'b', 'a', 'new'])
assert.deepEqual(mergeOrder([], ['c', 'b', 'a']), ['c', 'b', 'a'])
assert.deepEqual(moveId(['a', 'b', 'c'], 'a', ''), ['b', 'c', 'a'])
assert.deepEqual(moveId(['a', 'b', 'c'], 'c', 'b'), ['a', 'c', 'b'])
assert.deepEqual(moveId(['a', 'b', 'c'], 'a', 'a'), ['a', 'b', 'c'])
assert.deepEqual(moveId(['a', 'b', 'c'], 'a', 'missing'), ['a', 'b', 'c'])
assert.deepEqual(moveId(['a', 'b'], 'missing', 'b'), ['a', 'b'])
console.log('plugin order: normalization, merge, disabled/new plugins, movement, identity ok')
