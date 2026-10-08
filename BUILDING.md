# 构建与发布

Godot4.6.3和Python3即可更新游戏数据包；Node22用于资源测试。请从官方渠道安装工具。

## 更新游戏

在仓库根目录执行：

```sh
godot --headless --path game --editor --import --quit
godot --headless --path game --export-pack Web docs/index.pck
python3 tools/update_build.py
node tests/web-resources.test.mjs
```

导出使用game/export_presets.cfg。它排除qa、测试、制作文档及生成脚本，不包含玩家存档。保留官方4.6.3引擎时，仅需重新导出PCK；升级Godot引擎须同时更新对应JS、WASM、解码长度/SHA与第三方通知，重新验证完整加载链。

## 本地试玩

```sh
python3 -m http.server 8765 --directory docs --bind 127.0.0.1
```

访问http://127.0.0.1:8765/。不要直接双击HTML。页面以相对路径加载资源，可部署在/dusk-post-valley/这样的项目目录。

## GitHub Pages

Settings → Pages → Deploy from a branch → main → /docs → Save。docs/.nojekyll确保直接分发静态文件。不要把原始gzip字节当作WASM文件；index.wasm.gz由dusk-wasm-loader.js读取实际字节、解压并校验，故无需Content-Encoding配置。

发布后核对Pages首页、index.pck、index.wasm.gz均返回成功，下载数据包与build-manifest.json的SHA-256一致，再检查浏览器启动画面。资源HTTP成功不等于WebGL游戏已运行。

官方说明：[Pages发布来源](https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site)、[Godot Web导出](https://docs.godotengine.org/en/4.6/tutorials/export/exporting_for_web.html)。
