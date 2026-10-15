import { spawnSync } from 'node:child_process';
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const root = resolve(here, '../../..');
const files = [
  ['entry/src/main/ets/model/D4Types.ets', 'D4Types.ts'],
  ['entry/src/main/ets/probe/ProbeTypes.ets', 'ProbeTypes.ts'],
  ['entry/src/main/ets/probe/ProbeCodec.ets', 'ProbeCodec.ts'],
  ['entry/src/main/ets/probe/SandboxIsolationProbe.ets', 'SandboxIsolationProbe.ts'],
  ['entry/src/test/ProbeCodec.test.ets', 'ProbeCodec.test.ts'],
  ['entry/src/test/SandboxProbe.test.ets', 'SandboxProbe.test.ts']
];

function prep(source) {
  return source
    .replace(/@Observed\r?\n/g, '')
    .replace("import { common } from '@kit.AbilityKit';\n", '')
    .replace(/common\.UIAbilityContext/g, 'Object')
    .replaceAll("from '../main/ets/model/D4Types'", "from './D4Types.ts'")
    .replaceAll("from '../main/ets/probe/ProbeCodec'", "from './ProbeCodec.ts'")
    .replaceAll("from '../main/ets/probe/ProbeTypes'", "from './ProbeTypes.ts'")
    .replaceAll("from '../main/ets/probe/SandboxIsolationProbe'", "from './SandboxIsolationProbe.ts'")
    .replaceAll("from './ProbeTypes'", "from './ProbeTypes.ts'")
    .replaceAll("from '../model/D4Types'", "from './D4Types.ts'")
    .replace(/import \{ LiveStore \} from '\.\.\/model\/LiveStore';\n/,
      "const LiveStore = { shelf() { return { sidecarPresent: false, sidecar: { imageTag: '' } }; } };\n")
    .replace(/import \{ closeSync, openSync, statSync, OpenMode \} from '@ohos\.file\.fs';\n/,
      "const OpenMode = { READ_ONLY: 0 };\nfunction statSync() { throw { code: 13900012 }; }\nfunction openSync() { throw { code: 13900002 }; }\nfunction closeSync() {}\n")
    .replace(/import \{ hilog \} from '@kit\.PerformanceAnalysisKit';\n/,
      "const hilog = { error() {}, info() {} };\n");
}

const dir = mkdtempSync(join(tmpdir(), 'probe-codec-'));
try {
  for (const [from, to] of files) {
    writeFileSync(join(dir, to), prep(readFileSync(resolve(root, from), 'utf8')));
  }
  writeFileSync(join(dir, 'main.ts'),
    "import { runProbeCodecChecks } from './ProbeCodec.test.ts';\nimport { runSandboxProbeChecks } from './SandboxProbe.test.ts';\nrunProbeCodecChecks();\nrunSandboxProbeChecks();\n");
  const run = spawnSync(process.execPath, ['--experimental-strip-types', join(dir, 'main.ts')], {
    encoding: 'utf8'
  });
  if (run.status !== 0) {
    process.stderr.write(run.stdout || '');
    process.stderr.write(run.stderr || '');
    process.exit(run.status === null ? 1 : run.status);
  }
} finally {
  rmSync(dir, { recursive: true, force: true });
}
