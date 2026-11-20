// Quick local test for scanZip, no AWS needed: npm test
import assert from 'assert';
import path from 'path';
import { fileURLToPath } from 'url';
import AdmZip from 'adm-zip';
import { scanZip } from '../scan.mjs';

const zip = new AdmZip();
zip.addFile('src/app.js', Buffer.from("const password = 'hunter2hunter2';\n"));
zip.addFile('src\\windows.js', Buffer.from('eval(userInput);\n'));
zip.addFile('node_modules/lib/index.js', Buffer.from('eval(x);\n'));
zip.addFile('.git/hooks/pre-commit.js', Buffer.from('eval(x);\n'));
zip.addFile('README.md', Buffer.from("password = 'notcode'\n"));

const result = scanZip(zip.toBuffer());
assert.deepStrictEqual(result.files.sort(), ['src/app.js', 'src/windows.js']);
assert.ok(result.vulnerabilities.some(v => v.id === 'HARDCODED_SECRET' && v.file === 'src/app.js'));
assert.ok(result.vulnerabilities.some(v => v.id === 'INSECURE_FUNCTION' && v.file === 'src/windows.js'));
assert.throws(() => scanZip(Buffer.from('this is not a zip')));
console.log('scanZip tests passed\n');

// Scan the repo's sample app the same way the Lambda would
const here = path.dirname(fileURLToPath(import.meta.url));
const sample = new AdmZip();
sample.addLocalFolder(path.join(here, '../../sample-app'));
const report = scanZip(sample.toBuffer());

console.log('sample-app summary:', report.summary);
for (const v of report.vulnerabilities) {
  console.log(`  ${v.severity.padEnd(6)} ${v.id.padEnd(18)} ${v.file}:${v.line}  ${v.description}`);
}
