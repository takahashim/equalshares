// Harness to run the original JS worker algorithm in Node and dump reference output.
// Regenerate: node test/fixtures/generate_js_reference.js test/fixtures/js_reference.json
const fs = require('fs');
const path = require('path');
// This dev-only script needs the original JavaScript source (js/) and the Wieliczka
// sample from the equalshares-compute-tool repo. Point EQUALSHARES_JS_REPO at it, or
// keep that repo as a sibling of this gem.
const repo = process.env.EQUALSHARES_JS_REPO ||
  path.resolve(__dirname, '..', '..', '..', 'equalshares-compute-tool');

// --- shims for the worker environment ---
global.self = global;
const fractionSrc = fs.readFileSync(path.join(repo, 'js/libraries/fraction.min.js'), 'utf8');
// fraction.min.js is a UMD module; evaluate it and grab Fraction
const moduleShim = { exports: {} };
(function(module, exports){ eval(fractionSrc); }).call(global, moduleShim, moduleShim.exports);
global.Fraction = global.Fraction || moduleShim.exports.Fraction || moduleShim.exports;
if (typeof global.Fraction !== 'function' && global.Fraction && global.Fraction.default) {
  global.Fraction = global.Fraction.default;
}

global.importScripts = function(){}; // already loaded Fraction above
global.postMessage = function(){};   // ignore progress
global.performance = { now: () => 0 };

// Load worker source, strip the importScripts line, expose equalShares
let workerSrc = fs.readFileSync(path.join(repo, 'js/methodOfEqualSharesWorker.js'), 'utf8');
workerSrc = workerSrc.replace(/importScripts\([^)]*\);/, '');
// remove the onmessage assignment (references e.data)
workerSrc = workerSrc.replace(/onmessage[\s\S]*$/, '');
eval(workerSrc);

// Parser
const parserSrc = fs.readFileSync(path.join(repo, 'js/pabulibParser.js'), 'utf8')
  .replace('export function', 'function');
eval(parserSrc);

const pbText = fs.readFileSync(path.join(repo, 'pb/poland_wieliczka_2023_green-budget.pb'), 'utf8');

function run(params) {
  const instance = parsePabulibFromString(pbText);
  const { winners, notes } = equalShares(instance, params);
  return {
    winners,
    totalCost: notes.stats.totalCost,
    avgApprovedProjects: notes.stats.avgApprovedProjects,
    utilityDistribution: notes.stats.utilityDistribution,
    endowment: notes.endowment,
  };
}

const cases = {
  'floats_none':        { tieBreaking: [], completion: 'none', add1options: ['exhaustive','integral'], comparison: 'none', accuracy: 'floats', increment: 1 },
  'fractions_none':     { tieBreaking: [], completion: 'none', add1options: ['exhaustive','integral'], comparison: 'none', accuracy: 'fractions', increment: 1 },
  'floats_add1u':       { tieBreaking: [], completion: 'add1u', add1options: ['exhaustive','integral'], comparison: 'none', accuracy: 'floats', increment: 1 },
  'fractions_add1u':    { tieBreaking: [], completion: 'add1u', add1options: ['exhaustive','integral'], comparison: 'none', accuracy: 'fractions', increment: 1 },
  'floats_add1':        { tieBreaking: [], completion: 'add1', add1options: ['exhaustive','integral'], comparison: 'none', accuracy: 'floats', increment: 1 },
  'floats_utilitarian': { tieBreaking: [], completion: 'utilitarian', add1options: ['exhaustive','integral'], comparison: 'none', accuracy: 'floats', increment: 1 },
  'floats_add1u_satisfaction': { tieBreaking: ['maxVotes'], completion: 'add1u', add1options: ['exhaustive','integral'], comparison: 'satisfaction', accuracy: 'floats', increment: 1 },
  'floats_add1_maxVotes_minCost': { tieBreaking: ['maxVotes','minCost'], completion: 'add1', add1options: ['exhaustive','integral'], comparison: 'none', accuracy: 'floats', increment: 1 },
};

const out = {};
for (const [name, params] of Object.entries(cases)) {
  out[name] = { params, result: run(params) };
}
fs.writeFileSync(process.argv[2], JSON.stringify(out, null, 2));
console.log('wrote', process.argv[2]);
