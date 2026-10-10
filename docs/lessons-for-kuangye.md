# 给《旷野》原 Godot 线的可迁移经验（来自《暮邮谷》）

本文写给 **kuangye** 在 ThySummer14/kuangye 仓库里、基于 **filisi/kuangye-original-godot-recovery-20261008** 分支与 **godot-prototype/** 目录的恢复线。经验来自 dusk-post-valley（暮邮谷）的 Godot 4.6.3 + GitHub Pages Web 导出实践。

**请勿**把本文当作 filisi/godot-town-exploration-20261008 分支下 **godot/** 目录那套探索方案的依据——该线已被 Hal 明确否决，不要混用代码、分支或设计假设。

---

## 1. Web 导出：资源能下载 ≠ 游戏能跑

- **gzip WASM 要客户端解压**：托管方未必给 `index.wasm` 正确的 `Content-Encoding`。暮邮谷把 `index.wasm.gz` 当普通静态文件，由 `dusk-wasm-loader.js` 读字节、必要时解压，再校验长度与 SHA-256 后交给引擎。kuangye 若走 Pages，建议同样保留「可核对哈希」的清单（如 `build-manifest.json`）。
- **相对路径**：HTML/JS 里资源 URL 用相对路径，才能挂在 `https://user.github.io/repo-name/` 子路径下。
- **单线程 Web**：`thread_support=false` 与模板一致；不要假设 Worker 线程可用。
- **验收分层**：Node 侧可测 gzip、PCK 魔数、WASM 编译；**WebGL 实机、IndexedDB 关页再开、手机横竖屏**必须单独列清单，不能由 headless 代替。

## 2. 触屏：关掉全局鼠标模拟，自己路由手指

- 在 `project.godot` 设 `input_devices/pointing/emulate_mouse_from_touch=false`，避免「走路手指」独占 UI。
- 行走区与 UI 分开：左半屏摇杆用 `InputEventScreenTouch/ScreenDrag`；按钮用 `TouchButton`（独立 `touch_id`、拖移阈值、取消时 `set_pressed_no_signal(false)`）；长文用 `TouchScroll`。
- 弹窗打开、横竖屏、窗口缩放、失焦、切后台时，统一 `call_group("valley_touch_capture", "cancel_touch")` 并 `Input.action_release` 行走键，否则会出现「松手还在走」「旋转后误触」。

## 3. 中断与暂停：输入状态要当垃圾回收

- 打开任意 modal 前先 `_cancel_controls()`，避免旧手势污染新界面。
- 键盘：记录 `interrupted_movement`，对 echo 的自动重复在恢复后 `action_release`，要求玩家重新按键（Safari/长按方向键常见）。
- 失焦 / 切标签：原生 `NOTIFICATION_APPLICATION_FOCUS_OUT` 在部分移动浏览器上不可靠；Web 可补 `visibilitychange` + `pagehide`，并在页面侧 `canvas.blur()`，游戏内用 `JavaScriptBridge` 回调同一套「清空输入 + 可选暂停 + 存盘」逻辑。

## 4. 存档：原子写 + 坏档只读，别静默覆盖

- 写 `user://`（Web 上多为 IndexedDB）：先写 `.tmp`，`flush` 成功后再 `rename` 到正式名；失败则 toast，**保留上一版字节**。
- 加载用严格 schema（版本、字段全集、类型、任务一致性）；解析失败则 `save_read_only`，自动保存与关页保存都不得覆盖原文件，只有玩家明确「重新开始」才写新档。
- **探索位置也要存**：仅 quest `changed` 时保存不够；暂停、切后台、关页前应把 `player_position` 写入，否则玩家只走路不收信会丢进度。

## 5. 分辨率与安全区：UI 与世界分开渲染

- 3D 世界进低分辨率 `SubViewport`，UI 在根视口用真实逻辑像素；`content_scale_size` 在 Web 上宜读 `window.innerWidth/innerHeight`（CSS 像素），与 DPR 解耦。
- 横竖屏切换时重算 subviewport 与 orthographic `camera.size`，并 **再次** `_cancel_controls()`。
- 刘海/底栏：用 `env(safe-area-inset-*)` 或 `DisplayServer.get_display_safe_area()` 给右下角互动钮和底栏留边距。

## 6. 像素斜俯视：相机对齐用相机平面，不是世界 XZ

- 正交 + 斜角时，移动应沿相机 right/forward 在地面上的投影组合，而不是直接加世界 X/Z。
- 相机 snap：在相机 right/up 方向按「一个世界 texel」取整，减轻走起来时的 shimmer（实现见暮邮谷 `main.gd` 的 `_update_camera`）。

## 7. 测试策略（可搬到 kuangye）

| 层级 | 做法 |
|------|------|
| 规则/存档 | headless `run_tests.gd`、穷举状态机、`save_recovery_tests.gd` 用 disposable `XDG_*` |
| 触摸/中断 | 注入 `InputEventScreenTouch`，不直接 `button.pressed.emit()` 冒充 |
| Web 资源 | `node tests/web-resources.test.mjs`，限制堆与 WASM 编译并发 |
| 真机 | 固定 URL + 勾选清单：载入、横屏、暂停恢复、滚动说明、三封信、关浏览器再开 |

## 8. 仓库与分支纪律

- **kuangye 应用对象**：`filisi/kuangye-original-godot-recovery-20261008` → `godot-prototype/`。
- **禁止混入**：`filisi/godot-town-exploration-20261008` → `godot/`（已否决的探索线）。
- 跨项目复用代码时，先核对许可证与素材归属；暮邮谷原创场景/邮路叙事不自动适用于 kuangye。

## 9. 暮邮谷仍待 kuangye 立项时复测的 P1

- 手机浏览器完整邮路（WebGL2 + 触控手感 + 音频）。
- IndexedDB：隐私模式、清站点数据、关页立刻再开、换设备。
- 长时间行走后的性能与发热（暮邮谷有定向光阴影与局部点光，kuangye 规模不同也要单独测）。

---

*维护：暮邮谷 Cloud Agent 轮次 · 对应游戏版本见 `game/project.godot` 与 `docs/build-manifest.json`。*
