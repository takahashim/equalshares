// Generate regression reference output from the ORIGINAL JavaScript implementation
// for every fixture in test/fixtures/pb/, across a matrix of parameter sets.
//
// For each (fixture, params) it records either the winners+stats or, when the JS
// throws (e.g. an unbroken tie), an { error } marker. The Ruby suite then checks
// that its port matches on the exact same bytes and parameters.
//
// Regenerate: node test/fixtures/generate_pb_reference.js test/fixtures/pb_reference.json
const fs = require('fs');
const path = require('path');
// Needs the original JavaScript source (js/) from the equalshares-compute-tool repo;
// set EQUALSHARES_JS_REPO or keep that repo as a sibling of this gem.
const repo = process.env.EQUALSHARES_JS_REPO ||
  path.resolve(__dirname, '..', '..', '..', 'equalshares-compute-tool');

// --- bootstrap the worker environment (same shims as generate_js_reference.js) ---
global.self = global;
const fractionSrc = fs.readFileSync(path.join(repo, 'js/libraries/fraction.min.js'), 'utf8');
const moduleShim = { exports: {} };
(function (module, exports) { eval(fractionSrc); }).call(global, moduleShim, moduleShim.exports);
global.Fraction = global.Fraction || moduleShim.exports.Fraction || moduleShim.exports;
if (typeof global.Fraction !== 'function' && global.Fraction && global.Fraction.default) {
  global.Fraction = global.Fraction.default;
}
global.importScripts = function () {};
global.postMessage = function () {};
global.performance = { now: () => 0 };

let workerSrc = fs.readFileSync(path.join(repo, 'js/methodOfEqualSharesWorker.js'), 'utf8')
  .replace(/importScripts\([^)]*\);/, '')
  .replace(/onmessage[\s\S]*$/, '');
eval(workerSrc);

const parserSrc = fs.readFileSync(path.join(repo, 'js/pabulibParser.js'), 'utf8')
  .replace('export function', 'function');
eval(parserSrc);

// Per-fixture budget increment chosen so Add1 converges quickly on these budgets.
const INCREMENT = {
  'netherlands_amsterdam_2022_west.pb': 1,
  'poland_warszawa_2021_bielany.pb': 1000,
  'hungary_budapest_2024.pb': 100000,
};

// Case templates. `inc` = true means substitute the per-fixture increment.
const TIE = ['maxVotes', 'minCost'];
const CASES = [
  { label: 'none_floats_tie',        completion: 'none',        accuracy: 'floats',    tieBreaking: TIE },
  { label: 'none_fractions_tie',     completion: 'none',        accuracy: 'fractions', tieBreaking: TIE },
  { label: 'utilitarian_floats_tie', completion: 'utilitarian', accuracy: 'floats',    tieBreaking: ['maxVotes', 'maxCost'] },
  { label: 'add1_floats_tie',        completion: 'add1',        accuracy: 'floats',    tieBreaking: TIE, inc: true },
  { label: 'add1u_fractions_tie',    completion: 'add1u',       accuracy: 'fractions', tieBreaking: TIE, inc: true },
  { label: 'none_floats_notie',      completion: 'none',        accuracy: 'floats',    tieBreaking: [] },
];

function makeParams(fixture, c) {
  return {
    tieBreaking: c.tieBreaking,
    completion: c.completion,
    add1options: ['exhaustive', 'integral'],
    comparison: 'none',
    accuracy: c.accuracy,
    increment: c.inc ? INCREMENT[fixture] : 1,
  };
}

const pbDir = path.join(__dirname, 'pb');
const fixtures = fs.readdirSync(pbDir).filter((f) => f.endsWith('.pb')).sort();

const out = {};
for (const fixture of fixtures) {
  const text = fs.readFileSync(path.join(pbDir, fixture), 'utf8');
  for (const c of CASES) {
    const params = makeParams(fixture, c);
    const key = `${fixture}::${c.label}`;
    try {
      const instance = parsePabulibFromString(text);
      const { winners, notes } = equalShares(instance, params);
      out[key] = {
        fixture, params,
        result: {
          winners,
          totalCost: notes.stats.totalCost,
          avgApprovedProjects: notes.stats.avgApprovedProjects,
          utilityDistribution: notes.stats.utilityDistribution,
          endowment: notes.endowment,
        },
      };
    } catch (e) {
      out[key] = { fixture, params, error: String(e && e.message ? e.message : e) };
    }
  }
}

fs.writeFileSync(process.argv[2], JSON.stringify(out, null, 2));
console.log('wrote', process.argv[2], 'with', Object.keys(out).length, 'cases');
