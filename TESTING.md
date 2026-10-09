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
