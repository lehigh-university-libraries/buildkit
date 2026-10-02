const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const root = path.resolve(__dirname, '../..');
const config = vm.runInNewContext(`(${fs.readFileSync(path.join(root, 'renovate.json5'), 'utf8')})`);
const manager = config.customManagers.find(m => m.description.includes('_VERSION'));
const pattern = manager.matchStrings[0];

// Match the actual configuration, including quotes and multiline Docker ARGs.
for (const version of ['8.5.0-2ubuntu10.15', '10.02.1~dfsg1-0ubuntu7.9', '1:5.2.21-2ubuntu4', '1.8.2-r0', '2.334.0']) {
  for (const quote of ['', '"', "'"]) {
    for (const prefix of ['ARG ', '  ']) {
      const assignment = `${prefix}SOFTWARE_VERSION=${quote}${version}${quote}`;
      const input = `# renovate: datasource=repology depName=ubuntu_24_04/example\n${assignment} \\\n`;
      const match = new RegExp(pattern).exec(input);
      assert.equal(match?.groups.currentValue, version, input);
      assert.equal(match.groups.depName, 'ubuntu_24_04/example');
      // Replacement must leave Docker's quoting and line continuation intact.
      const updated = input.replace(match[0], match[0].replace(match.groups.currentValue, '9.0-1ubuntu1'));
      assert.equal(updated, input.replace(version, '9.0-1ubuntu1'));
    }
  }
}

// Cover every real distribution dependency, not just the originally reported file.
let dependencies = 0;
for (const file of fs.readdirSync(path.join(root, 'images'), {recursive: true})) {
  if (!file.endsWith('/Dockerfile')) continue;
  const content = fs.readFileSync(path.join(root, 'images', file), 'utf8');
  const expected = [...content.matchAll(/# renovate: datasource=repology /g)].length;
  const matches = [...content.matchAll(new RegExp(pattern, 'g'))].filter(m => m.groups.datasource === 'repology');
  assert.equal(matches.length, expected, file);
  for (const match of matches) {
    assert.match(match.groups.currentValue, /^[0-9][^\s"'\\]*$/, file);
  }
  dependencies += matches.length;
}
assert(dependencies > 0);

const distroRule = config.packageRules.find(r => r.matchDatasources?.includes('repology') && r.versioning === 'loose');
assert.equal(distroRule.allowedVersions, null);
const debRule = config.packageRules.find(r => r.versioning === 'deb');
assert(debRule.matchDatasources.includes('repology'));
const names = new RegExp(debRule.matchPackageNames[0].slice(1, -1));
assert(names.test('ubuntu_24_04/curl'));
assert(names.test('ubuntu_22_04/gosu'));
assert(names.test('debian_13/bash'));
assert(!names.test('alpine_3_24/curl'));
assert(config.packageRules.indexOf(debRule) > config.packageRules.indexOf(distroRule));

for (const depName of ['gha-runner', 'crosswalk']) {
  const rule = config.packageRules.find(r => r.matchDepNames?.includes(depName) && r.extractVersion);
  for (const version of ['0.6.0', '2.337.0']) {
    for (const prefix of ['', 'v']) {
      assert.equal(new RegExp(rule.extractVersion).exec(prefix + version)?.groups.version, version);
    }
  }
}

for (const minor of [13, 14]) {
  const file = `images/python3-${minor}/Dockerfile`;
  const rule = config.packageRules.find(r => r.matchFileNames?.includes(file));
  assert(rule.matchManagers.includes('dockerfile'));
  assert(rule.matchPackageNames.includes('python'));
  const allowed = new RegExp(rule.allowedVersions.slice(1, -1));
  for (const tag of [`3.${minor}`, `3.${minor}-alpine3.24`, `3.${minor}.9-alpine3.25`]) {
    assert(allowed.test(tag), `${file} must allow ${tag}`);
  }
  for (const tag of ['3.12-alpine3.24', `3.${minor + 1}-alpine3.24`, `3.${minor}0-alpine3.24`, '4.0-alpine3.24']) {
    assert(!allowed.test(tag), `${file} must reject ${tag}`);
  }
  const dockerfile = fs.readFileSync(path.join(root, file), 'utf8');
  assert(allowed.test(dockerfile.match(/^FROM python:([^@]+)/)[1]));
}
console.log(`Renovate extraction checks passed for ${dependencies} distribution dependencies.`);
