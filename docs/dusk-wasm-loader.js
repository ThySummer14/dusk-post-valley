/* Application-level gzip delivery for the unchanged Godot 4.6.3 WASM.
 * This file is not a Godot API extension. index.js has one documented,
 * source-tracked loader-chain adaptation that calls decodeResponse below.
 */
(function (root) {
 'use strict';
 const expectedBytes = 37700666;
 const expectedSHA256 = '26b61ce95247012ab3dca3ff51e96d1cdbff44ee91a8c20a83e150afca83f1b6';
 const wasmHeader = [0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00];
 async function decodeResponse(response) {
  if (!response.ok) throw new Error('引擎下载失败（HTTP ' + response.status + '）。请刷新后重试。');
  let bytes = new Uint8Array(await response.arrayBuffer());
  // Inspect actual bytes: some hosts transparently decode HTTP gzip, others
  // serve a .gz asset as-is. Never rely on a possibly stale response header.
  if (bytes[0] === 0x1f && bytes[1] === 0x8b) {
   if (typeof root.DecompressionStream !== 'function') {
    throw new Error('当前浏览器不支持解压游戏。请使用 Safari / iOS 16.4、Firefox 113、Chrome 95 或更新版本。');
   }
   try {
    const compressed = bytes;
    bytes = null;
    bytes = new Uint8Array(await new Response(
     new Blob([compressed]).stream().pipeThrough(new root.DecompressionStream('gzip'))
    ).arrayBuffer());
   } catch (error) {
    throw new Error('引擎压缩文件解压失败，可能下载不完整。请刷新后重试。');
   }
  }
  if (!wasmHeader.every((value, i) => bytes[i] === value)) {
   throw new Error('下载内容不是游戏引擎文件，可能收到了错误页或不完整文件。请刷新后重试。');
  }
  if (bytes.byteLength !== expectedBytes) throw new Error('引擎文件长度校验失败，请刷新后重试。');
  if (!root.crypto || !root.crypto.subtle) throw new Error('浏览器缺少安全文件校验能力。请使用 HTTPS 和受支持的浏览器。');
  const digest = await root.crypto.subtle.digest('SHA-256', bytes);
  const hex = Array.from(new Uint8Array(digest), n => n.toString(16).padStart(2, '0')).join('');
  if (hex !== expectedSHA256) throw new Error('引擎文件完整性校验失败，请刷新后重试。');
  // Fresh metadata describes decoded bytes, avoiding double decompression.
  return new Response(bytes, {status: 200, headers: {
   'Content-Type': 'application/wasm', 'Content-Length': String(bytes.byteLength)
  }});
 }
 root.DuskWasmDelivery = Object.freeze({decodeResponse, expectedBytes, expectedSHA256});
}(globalThis));
