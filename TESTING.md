# 测试

在根目录运行Godot4.6.3：

```sh
godot --headless --path game --editor --import --quit
godot --headless --path game --script res://tests/run_tests.gd -- --test-world
godot --headless --path game --script res://tests/playthrough.gd -- --test-world
godot --headless --path game --script res://tests/ui_layout_tests.gd -- --test-world
godot --headless --path game --script res://tests/usability_regression.gd -- --test-world
godot --headless --path game --script res://tests/third_letter_tests.gd -- --test-world
godot --headless --path game --script res://tests/touch_ui_tests.gd -- --test-world
node tests/web-resources.test.mjs
```

v0.3-r1共174项游戏断言：规则/存档67，全邮路控制器43，UI布局31，易用性17，光路与第三封16。故意损坏JSON的存档测试应进入只读保护，不应覆盖原文件。

Web测试在本机HTTP服务器的/dusk-post-valley/前缀下提供真实资源，验证相对路径、gzip解码、SHA、实际WASM编译及错误反馈，不需要联网账户。它不模拟WebGL渲染。

原生键鼠已分段核过第三封的灯镜操作、拾取、过桥、抵达观星屋和送达。UI检查包含375×812和812×375尺寸；这仍不是实际手机触屏验收。完整路线控制器的35.2模拟秒是最短测试路线，不能当成首次玩家时长。

当前尚未完成真实手机性能与声音听验。发布后的浏览器启动结果应另行记录，不将下载成功写成游戏通关。

## v0.3-r3触屏输入修复

原有174项断言全部通过，新增27项主场景原生触摸事件回归，共201项。覆盖开始、暂停恢复、独立双指摇杆与互动、拖出重入、触点取消、焦点丢失、重复触点、长说明滚动和滑到按钮时不误触，另保留桌面鼠标对照。使用Godot4.6.3 headless注入InputEventScreenTouch/ScreenDrag，不调用按钮回调冒充触摸。

事件管线修复仍不是手机实玩验收。812×375仅用于确定输入命中坐标；真实手机、移动浏览器WebGL2、触摸手感、滚动惯性、声音和性能仍待验证。发布前重新导出r3 PCK，再运行6项Web测试验证新资源链。

对正式导出的r3 PCK另外执行同样27项触摸断言，另加打包版本检查（28/28），确认测试没有只覆盖源工程。r2/r3包内water.gdshader与world_builder.gdc逐字节SHA-256一致。WASM gzip字节、解压魔数与引擎SHA不变。

## v0.3-r4存档只读保护

新增92项检查：未知版本、缺失或未知字段、错误类型及相互冲突的任务状态，在恢复前整体拒绝，不部分修改内存。合法v1保持原来的恢复方式，包括已解谜后转开镜面、位置越界返回起点、长会话时间归一化。既有201项断言保持通过。另穷举3003种公开可达状态、36036条转换，涵盖重复点灯、解谜后继续转镜、结尾后操作和重开，全部通过JSON序列化后完整恢复；穷举作为新增92项中的1项性质断言，不重复相加。

7组坏档通过真实主场景启动链验证：加载后自动保存、状态变化、退出保存都保留原字节；显示暂不保存警告，取消重新开始仍保留原档，仅明确重新开始才写入新进度。另验证完整合法v1的启动恢复和自动保存。测试必须使用一次性用户目录，且不能加会跳过真实存档流程的`--test-world`：

```sh
qa_dir="$(mktemp -d)"
HOME="$qa_dir/home" XDG_DATA_HOME="$qa_dir/data" XDG_CONFIG_HOME="$qa_dir/config" XDG_CACHE_HOME="$qa_dir/cache" DUSK_DISPOSABLE_TEST_DATA=1 \
  godot --headless --path game --script res://tests/save_recovery_tests.gd
```

源码与新导出的r4 PCK分别运行同一92项存档回归；PCK另核版本与编译后的触控事件。6项Web资源检查针对新版清单与包体。以上不等同于WebGL/IndexedDB与手机实机验证。

## v0.3-r5中断回归

新增23项中断检查，使用InputEventKey和ScreenTouch/ScreenDrag走实际输入管线：暂停及邮袋/说明/重开确认的输入清空、恢复后旧键与自动重复不再行走、旋转和同方向窗口缩放清理按钮/滚动捕获、新触摸与新按键恢复、焦点切回不重放移动。

```sh
godot --headless --path game --script res://tests/interruption_tests.gd -- --test-world
```

既有201项玩法/触摸和92项存档检查继续运行。源码与正式PCK分开验证，不将原生输入注入等同真机触屏、声音、性能或IndexedDB测试。

## v0.3-r6探索存盘与 Web 后台

中断套件增至24项：在仅改变 `player_pos`、无任务事件时，打开暂停菜单也会把坐标写入 `user://` 存档。Web 壳页在引擎启动后监听 `visibilitychange`/`pagehide` 并对隐藏状态 blur 画布；游戏内 `JavaScriptBridge` 回调与 `NOTIFICATION_APPLICATION_FOCUS_OUT` 共用 `_handle_interrupt()`。安全区 inset 仅在 Web 导出路径通过 headless 无法断言，需真机横屏看右下角互动钮是否离 Home 条足够远。

本轮Web检查以`node --max-old-space-size=96 --wasm-num-compilation-tasks=1 --liftoff-only tests/web-resources.test.mjs`限制编译并发及堆大小，6项通过；仍编译完整官方WASM，未启用浏览器安全绕过。默认Node运行曾触及400MiB预算并被停止，不计为通过。r4/r5包内水面shader、世界构建器及全部美术资源SHA一致。
