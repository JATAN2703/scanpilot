import path from 'path';
import AdmZip from 'adm-zip';
import { scanCode } from './scanner.js';

const EXTENSIONS = ['.js', '.mjs', '.cjs', '.ts'];
const MAX_FILE_SIZE = 1024 * 1024;        // 1 MB per file
const MAX_TOTAL_SIZE = 20 * 1024 * 1024;  // 20 MB for the whole upload

const severityOrder = { HIGH: 0, MEDIUM: 1, LOW: 2 };

// The zip is read in memory and each file is scanned as text.
// Nothing from the upload gets written to disk or run.
export const scanZip = (buffer) => {
  const zip = new AdmZip(buffer);
  const files = [];
  const skipped = [];
  const vulnerabilities = [];
  let totalSize = 0;

  for (const entry of zip.getEntries()) {
    if (entry.isDirectory) continue;

    // zips made on Windows can use backslashes
    const name = entry.entryName.replace(/\\/g, '/');
    const folders = name.split('/').slice(0, -1);
    if (folders.some(f => f === 'node_modules' || f.startsWith('.'))) continue;
    if (!EXTENSIONS.includes(path.extname(name).toLowerCase())) continue;

    // check the size before unzipping, so a zip bomb can't fill up memory
    if (entry.header.size > MAX_FILE_SIZE) {
      skipped.push(name);
      continue;
    }
    totalSize += entry.header.size;
    if (totalSize > MAX_TOTAL_SIZE) {
      throw new Error('Upload is too large (over 20 MB of source code)');
    }

    const code = entry.getData().toString('utf-8');
    files.push(name);
    vulnerabilities.push(...scanCode(code, name));
  }

  vulnerabilities.sort((a, b) => severityOrder[a.severity] - severityOrder[b.severity]);

  return {
    summary: {
      filesScanned: files.length,
      totalVulnerabilities: vulnerabilities.length,
      high: vulnerabilities.filter(v => v.severity === 'HIGH').length,
      medium: vulnerabilities.filter(v => v.severity === 'MEDIUM').length,
      low: vulnerabilities.filter(v => v.severity === 'LOW').length
    },
    files,
    skipped,
    vulnerabilities
  };
};
