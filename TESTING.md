# 测试

在根目录运行Godot4.6.3：

```sh
godot --headless --path game --editor --import --quit
godot --headless --path game --script res://tests/run_tests.gd -- --test-world
godot --headless --path game --script res://tests/playthrough.gd -- --test-world
godot --headless --path game --script res://tests/ui_layout_tests.gd -- --test-world
godot --headless --path game --script res://tests/usability_regression.gd -- --test-world
godot --headless --path game --script res://tests/third_letter_tests.gd -- --test-world
node tests/web-resources.test.mjs
```

v0.3-r1共174项游戏断言：规则/存档67，全邮路控制器43，UI布局31，易用性17，光路与第三封16。故意损坏JSON的存档测试会输出一次预期的解析错误，以最后的断言汇总判断结果。

Web测试在本机HTTP服务器的/dusk-post-valley/前缀下提供真实资源，验证相对路径、gzip解码、SHA、实际WASM编译及错误反馈，不需要联网账户。它不模拟WebGL渲染。

原生键鼠已分段核过第三封的灯镜操作、拾取、过桥、抵达观星屋和送达。UI检查包含375×812和812×375尺寸；这仍不是实际手机触屏验收。完整路线控制器的35.2模拟秒是最短测试路线，不能当成首次玩家时长。

当前尚未完成真实手机性能与声音听验。发布后的浏览器启动结果应另行记录，不将下载成功写成游戏通关。
