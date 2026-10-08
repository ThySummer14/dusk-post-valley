import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import http from 'node:http';
import { fileURLToPath } from 'node:url';
import { webcrypto, createHash } from 'node:crypto';
import { gunzipSync } from 'node:zlib';
const web=fileURLToPath(new URL('../docs/',import.meta.url));
const compressed=fs.readFileSync(path.join(web,'index.wasm.gz'));
const decoded=gunzipSync(compressed);
const adapter=fs.readFileSync(path.join(web,'dusk-wasm-loader.js'),'utf8');
const engine=fs.readFileSync(path.join(web,'index.js'),'utf8');
const page=fs.readFileSync(path.join(web,'index.html'),'utf8');
const manifest=JSON.parse(fs.readFileSync(path.join(web,'build-manifest.json'),'utf8'));
const results=[]; const prefix='/dusk-post-valley/'; const requests=[];
function ctx(engineCode,options={}) {
 const c=vm.createContext({console,fetch,Headers,Request,Response,Blob,ReadableStream,Uint8Array,ArrayBuffer,DecompressionStream,crypto:webcrypto,WebAssembly,setTimeout,clearTimeout,requestAnimationFrame:()=>0,...options});
 vm.runInContext(adapter,c);if(engineCode){vm.runInContext(engineCode,c);c.testEngine=vm.runInContext('Engine',c);}return c;
}
async function pass(name,action){await action();results.push({name,passed:true});console.log('PASS:',name);}
const server=http.createServer((req,res)=>{
 const u=new URL(req.url,'http://localhost');requests.push(u.pathname);
 if(!u.pathname.startsWith(prefix)){res.writeHead(404);res.end('Wrong project prefix');return;}
 const relative=decodeURIComponent(u.pathname.slice(prefix.length))||'index.html';
 const f=path.resolve(web,relative);
 if(!f.startsWith(path.resolve(web)+path.sep)||!fs.existsSync(f)||!fs.statSync(f).isFile()){res.writeHead(404);res.end('Not found');return;}
 const bytes=fs.readFileSync(f);
 const type=f.endsWith('.gz')?'application/gzip':f.endsWith('.html')?'text/html':f.endsWith('.js')?'text/javascript':'application/octet-stream';
 res.writeHead(200,{'Content-Type':type,'Content-Length':bytes.length});res.end(bytes); // no Content-Encoding
});
await new Promise(r=>server.listen(0,'127.0.0.1',r));
try{
 const base=`http://127.0.0.1:${server.address().port}${prefix}`;
 await pass('HTML resources use project-relative paths and the configured PCK size matches',async()=>{
  for(const match of page.matchAll(/<script[^>]+src="([^"]+)"/g)){assert(!match[1].startsWith('/'));assert.equal((await fetch(base+match[1])).status,200);}
  const config=JSON.parse(page.match(/const GODOT_CONFIG = (\{[^\n]+\});/)[1]);assert.equal(config.executable,'index');assert.equal(config.fileSizes['index.pck'],fs.statSync(path.join(web,'index.pck')).size);
  assert(page.includes('const GODOT_THREADS_ENABLED = false'));assert(fs.existsSync(path.join(web,'.nojekyll')));
  const project=fs.readFileSync(path.join(web,'../game/project.godot'),'utf8');
  const version='v'+project.match(/^config\/version="([^"]+)"/m)[1];
  assert.equal(manifest.game_version,version);assert(page.includes(version+'-web3-gzip'));
  assert.deepEqual(fs.readFileSync(path.join(web,'index.pck')).subarray(0,4),Buffer.from('GDPC'));
  assert.deepEqual(compressed.subarray(0,2),Buffer.from([0x1f,0x8b]));assert.deepEqual(decoded.subarray(0,4),Buffer.from([0,0x61,0x73,0x6d]));
 });
 await pass('Every published resource matches its manifest at a project-subdirectory URL',async()=>{
  for(const item of manifest.files){const r=await fetch(base+encodeURI(item.file));assert.equal(r.status,200,item.file);const b=Buffer.from(await r.arrayBuffer());assert.equal(b.length,item.bytes);assert.equal(createHash('sha256').update(b).digest('hex'),item.sha256,item.file);}
 });
 await pass('Engine.load decodes and compiles the actual WASM served without a gzip response header',async()=>{
  const c=ctx(engine);const r=await c.testEngine.load(base+'index');assert.equal(r.headers.get('Content-Type'),'application/wasm');assert.equal(r.headers.get('Content-Encoding'),null);assert.equal(r.headers.get('Content-Length'),String(decoded.length));assert(await WebAssembly.compileStreaming(r) instanceof WebAssembly.Module);assert(requests.includes(prefix+'index.wasm.gz'));
 });
 await pass('Already decoded WASM is not decompressed twice',async()=>{
  const c=ctx();const r=await c.DuskWasmDelivery.decodeResponse(new Response(decoded,{headers:{'Content-Encoding':'gzip'}}));assert.equal((await r.arrayBuffer()).byteLength,decoded.length);
 });
 await pass('Missing gzip support and damaged gzip produce clear errors',async()=>{
  const c=ctx(null,{DecompressionStream:undefined});await assert.rejects(c.DuskWasmDelivery.decodeResponse(new Response(compressed)),/浏览器不支持解压/);const ok=ctx();await assert.rejects(ok.DuskWasmDelivery.decodeResponse(new Response(compressed.subarray(0,100))),/解压失败/);
 });
 await pass('HTTP error pages and tampered WASM are rejected before engine startup',async()=>{
  const c=ctx();await assert.rejects(c.DuskWasmDelivery.decodeResponse(new Response('<html>Not found</html>')),/不是游戏引擎/);await assert.rejects(c.DuskWasmDelivery.decodeResponse(new Response('Forbidden',{status:403})),/HTTP 403/);const bad=Buffer.from(decoded);bad[bad.length-1]^=1;await assert.rejects(c.DuskWasmDelivery.decodeResponse(new Response(bad)),/完整性校验失败/);
 });
 console.log(JSON.stringify({passed:results.length,scope:'Static project-path, real HTTP/WASM resource checks; not WebGL gameplay or phone testing',wasm_sha256:createHash('sha256').update(decoded).digest('hex')}));
}finally{server.closeAllConnections();await new Promise(r=>server.close(r));}
