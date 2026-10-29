// Build from a private code snapshot, then serve assets only on loopback.
import { createRequire } from 'node:module';
import { createHash } from 'node:crypto';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { dirname, resolve, join, extname } from 'node:path';
import { cp, mkdtemp, readFile, readdir, rm } from 'node:fs/promises';
import { createServer } from 'node:http';
import { freemem } from 'node:os';
const here = dirname(fileURLToPath(import.meta.url));
const root = resolve(here, '../..');
const frontend = join(root, 'dimax-operations-suite-main');
if (freemem() < 768 * 1024 * 1024) throw new Error('At least 768 MiB available RAM required for the build; no files or servers created');
const require = createRequire(join(frontend, 'package.json'));
const { build } = await import(pathToFileURL(require.resolve('vite')).href);
const { default: react } = await import(pathToFileURL(require.resolve('@vitejs/plugin-react')).href);
const temp = await mkdtemp(join(root, 'artifacts', 'recovery-ui-'));
const snapshot = join(temp, 'source'), output = join(temp, 'dist');
let server;
async function hashTree(directory) {
  const hashes = [];
  for (const entry of (await readdir(directory, { withFileTypes: true })).sort((a,b) => a.name.localeCompare(b.name))) {
    const path = join(directory, entry.name);
    if (entry.name.startsWith('.env')) throw new Error('Dotenv files forbidden in source snapshot');
    if (entry.isSymbolicLink()) throw new Error('Symlinks forbidden in source snapshot');
    hashes.push(entry.isDirectory() ? entry.name + await hashTree(path) : entry.name + createHash('sha256').update(await readFile(path)).digest('hex'));
  }
  return createHash('sha256').update(hashes.join('\n')).digest('hex');
}
async function cleanup() {
  if (server) await new Promise(done => server.close(done));
  // mkdtemp's exact result, never a user-supplied deletion target.
  if (dirname(temp) !== join(root, 'artifacts') || !temp.startsWith(join(root, 'artifacts', 'recovery-ui-'))) throw new Error('Unsafe cleanup path');
  await rm(temp, { recursive: true, force: true });
}
try {
  const before = await hashTree(join(frontend, 'src'));
  await cp(join(frontend, 'src'), snapshot, { recursive: true });
  if (before !== await hashTree(join(frontend, 'src')) || before !== await hashTree(snapshot)) throw new Error('Concurrent source edit; retry later');
  for (const name of ['index.html', 'entry.tsx', 'mock.mjs', 'shims.tsx']) await cp(join(here, name), join(temp, name));
  const tailwind = require('tailwindcss');
  const loadConfig = require('tailwindcss/loadConfig');
  const config = loadConfig(join(frontend, 'tailwind.config.ts'));
  config.content = [join(snapshot, '**/*.{ts,tsx}').replaceAll('\\', '/')];
  await build({ root: temp, configFile: false, envDir: false, publicDir: false,
    plugins: [react()], resolve: { alias: [
      { find: '@/lib/api', replacement: join(temp, 'mock.mjs') },
      { find: '@/hooks/use-auth-session', replacement: join(temp, 'shims.tsx') },
      { find: /^next\/(link|navigation)$/, replacement: join(temp, 'shims.tsx') },
      { find: '@', replacement: snapshot },
      ...['react', 'react-dom', '@tanstack/react-query', 'zod', 'lucide-react', 'next-themes', 'sonner', 'clsx', 'tailwind-merge', 'class-variance-authority'].map(name => ({ find: name, replacement: join(frontend, 'node_modules', name) })),
      { find: /^@radix-ui\/(.+)$/, replacement: join(frontend, 'node_modules', '@radix-ui', '$1') },
    ] }, css: { postcss: { plugins: [tailwind(config), require('autoprefixer')] } },
    build: { outDir: output, emptyOutDir: true, minify: false, sourcemap: false },
  });
  const mime = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript', '.css': 'text/css', '.woff2': 'font/woff2' };
  server = createServer(async (req, res) => {
    const path = new URL(req.url, 'http://127.0.0.1').pathname;
    if (!['GET', 'HEAD'].includes(req.method) || (path !== '/' && !/^\/assets\/[\w.-]+$/.test(path))) { res.writeHead(404); res.end(); return; }
    try {
      const file = path === '/' ? 'index.html' : path.slice(1);
      const bytes = await readFile(join(output, file));
      res.writeHead(200, { 'Content-Type': mime[extname(file)] || 'application/octet-stream', 'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff',
        'Content-Security-Policy': "default-src 'self'; connect-src 'none'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self'; form-action 'none'; object-src 'none'; base-uri 'none'; frame-ancestors 'none'" });
      res.end(req.method === 'HEAD' ? undefined : bytes);
    } catch { res.writeHead(404); res.end(); }
  });
  await new Promise((done, reject) => { server.once('error', reject); server.listen(4197, '127.0.0.1', done); });
  console.log(`SYNTHETIC UI ONLY http://127.0.0.1:4197/ source_sha256=${before}`);
  await new Promise(done => { process.once('SIGINT', done); process.once('SIGTERM', done); });
} finally { await cleanup(); }
