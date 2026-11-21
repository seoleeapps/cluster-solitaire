extends SceneTree
const Driver = preload("res://tests/common/e2e_driver.gd")
const State = preload("res://addons/seorilabs_game/flow/state.gd")
const HomeStage = preload("res://game/features/home/home.gd")
var d
var save_dir := ""

func _initialize() -> void: call_deferred("run")
func arg(args: PackedStringArray, key: String, fallback: String) -> String:
 return args[args.find(key) + 1] if args.has(key) else fallback
func b(main: Node, name: String) -> Control: return main.find_child(name, true, false) as Control
func text_button(main: Node, value: String) -> Button:
 for child in main.find_children("*", "Button", true, false):
  if child.text == value: return child
 return null
func home_stage(main: Control) -> Control:
 for child in main.content.get_children():
  if child is HomeStage: return child
 return null
func in_scroll(control: Control) -> bool:
 var node := control.get_parent()
 while node != null and not node is ScrollContainer: node = node.get_parent()
 return node != null
## 세로 화면의 버튼이 화면 밖으로 나가거나 서로 겹치지 않는지 본다. 목록 안의 버튼은 스크롤로 닿으므로 제외한다.
func fits(main: Control) -> String:
 var screen := Rect2(Vector2.ZERO, Vector2(d.viewport.size))
 var placed: Array[Control] = []
 for button in main.content.find_children("*", "BaseButton", true, false):
  if not button.is_visible_in_tree() or in_scroll(button): continue
  var rect: Rect2 = button.get_global_rect()
  if not screen.encloses(rect): return "%s leaves the screen: %s" % [button.name, rect]
  for other in placed:
   if other.get_global_rect().intersects(rect) and not other.is_ancestor_of(button): return "%s overlaps %s" % [button.name, other.name]
  placed.append(button)
 return "" if not placed.is_empty() else "no visible button"
func fit_step(main: Control, name: String) -> void:
 var problem := fits(main)
 d.step(name + " fits the portrait screen", problem.is_empty(), problem)
func mount_game(path: String) -> Control:
 var main: Control = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
 main.state = State.new(path)
 main.device_locale = "en-US"
 await d.mount(main)
 d.step("actual startup completes", await d.wait_for(func(): return main.initialized))
 return main
func run() -> void:
 var args := OS.get_cmdline_user_args()
 var size := arg(args, "--size", "390x844").split("x")
 d = Driver.new(self, Vector2i(int(size[0]), int(size[1])), arg(args, "--out", "user://e2e/game"), args.has("--capture"))
 save_dir = "user://e2e-game-%d" % Time.get_ticks_usec()
 DirAccess.make_dir_recursive_absolute(save_dir)
 print("Isolated save: ", ProjectSettings.globalize_path(save_dir))
 d.begin("offline-first-play-restart", ["startup", "tutorial", "account_save", "inbox", "commerce", "operations", "observability", "ui_leaderboard", "ui_kit"])
 var main: Control = await mount_game(save_dir + "/play.json")
 d.step("portrait flow on a portrait screen", not main.landscape and d.viewport.size.x < d.viewport.size.y)
 fit_step(main, "title")
 await d.shot("title")
 d.step("start actual sample", await d.tap(b(main, "start")) and main.screen == "play")
 fit_step(main, "sample round")
 await d.shot("tutorial")
 for i in 3: d.step("collect star", await d.tap(text_button(main, "★")))
 d.step("collect reward", await d.tap(text_button(main, "Collect +10")))
 d.expect_equal("persisted reward", main.state.data.coins, 10)
 d.step("reward ceremony impact", await d.wait_for(func(): return main.ceremony.phase == "impact"))
 await d.shot("reward-impact", false)
 d.step("reward ceremony settle", await d.wait_for(func(): return main.ceremony.phase == "settle"))
 await d.shot("reward-settle", false)
 d.step("reward ceremony finished", await d.wait_for(func(): return main.ceremony.phase == "done"))
 fit_step(main, "result")
 await d.shot("result")
 d.step("return to lobby", await d.tap(b(main, "reward_continue")) and main.screen == "home")
 d.step("unsupported commerce and ranking hidden", b(main, "shop") == null and b(main, "leaderboard") == null)
 d.expect_equal("product home profile", main.home_profile, "map")
 var stage := home_stage(main)
 d.step("product stage fills the home center", stage != null and stage.size.y >= 120 and Rect2(Vector2.ZERO, Vector2(d.viewport.size)).encloses(stage.get_global_rect()))
 fit_step(main, "home")
 await d.shot("home")
 d.step("open inbox", await d.tap(b(main, "inbox")) and main.screen == "inbox")
 await d.shot("popup-open", false)
 await d.shot("inbox")
 d.step("close to home", await d.tap(b(main, "close")) and main.screen == "home")
 await d.unmount(main)
 main = await mount_game(save_dir + "/play.json")
 d.step("restart returns home", await d.tap(b(main, "start")) and main.screen == "home")
 d.expect_equal("reward restored", main.state.data.coins, 10)
 d.end()
 d.begin("settings-language-support-focus", ["settings_support", "account_save", "ui_support_entry", "ui_analytics_opt_out", "ui_locale_offline", "ui_navigation"])
 d.step("settings", await d.tap(b(main, "settings")))
 d.step("turn analytics off", await d.tap(b(main, "analytics")) and not main.state.data.settings.analytics and not main.analytics.effective)
 await d.shot("settings")
 d.step("support is directly reachable", await d.tap(b(main, "support")) and main.screen == "support")
 d.step("local support unavailable without invented identity", main.support.code.is_empty() and b(main, "copy").disabled)
 await d.shot("support")
 d.step("back restores settings", await d.tap(b(main, "back")) and main.screen == "settings")
 d.step("language", await d.tap(b(main, "language")))
 d.step("Korean selection", await d.tap(b(main, "ko")) and main.language() == "ko")
 await d.shot("korean")
 d.step("settings return", await d.tap(b(main, "back")))
 d.step("accessibility", await d.tap(b(main, "accessibility")))
 d.step("larger text", await d.tap(b(main, "large_text")) and main.state.data.settings.large_text)
 await d.shot("large-text")
 d.step("back to settings", await d.tap(b(main, "back")))
 var reached := false
 for i in 20:
  var ev := InputEventKey.new(); ev.keycode = KEY_TAB; ev.pressed = true
  d.viewport.push_input(ev, true)
  ev = InputEventKey.new(); ev.keycode = KEY_TAB; ev.pressed = false
  d.viewport.push_input(ev, true)
  await d.frames()
  var focus: Control = d.viewport.gui_get_focus_owner()
  if focus != null and focus.name == "support":
   var scroll: ScrollContainer = main.content.find_children("*", "ScrollContainer", true, false)[0]
   reached = scroll.get_global_rect().encloses(focus.get_global_rect())
   await d.shot("keyboard-focus")
   break
 d.step("keyboard focus scrolls into view", reached)
 d.step("close settings to home", await d.tap(b(main, "close")) and main.screen == "home")
 fit_step(main, "Korean large-text home")
 await d.shot("home-korean-large-text")
 await d.unmount(main)
 main = await mount_game(save_dir + "/play.json")
 d.step("language and analytics survive restart", main.language() == "ko" and not main.state.data.settings.analytics and main.state.data.settings.large_text)
 await d.unmount(main)
 d.end()
 d.begin("skip-guide-home-replay", ["startup", "tutorial", "account_save", "ui_navigation"])
 main = await mount_game(save_dir + "/skip.json")
 d.step("first start opens the guide", await d.tap(b(main, "start")) and main.screen == "play")
 d.step("skip guide on screen", await d.tap(text_button(main, "Skip guide")) and main.screen == "home")
 d.expect_equal("skipped guide grants nothing", main.state.data.coins, 0)
 await d.unmount(main)
 main = await mount_game(save_dir + "/skip.json")
 d.step("skipped guide is not forced after restart", await d.tap(b(main, "start")) and main.screen == "home")
 d.step("home play action is primary skin", b(main, "play") != null and b(main, "play").theme_type_variation == &"PrimaryButton")
 stage = home_stage(main)
 d.step("stage play button starts the round", stage != null and await d.tap(text_button(stage, "▶")) and main.screen == "play")
 fit_step(main, "replayed round")
 d.step("back returns home", await d.tap(b(main, "back")) and main.screen == "home")
 d.step("home play button starts the round", await d.tap(b(main, "play")) and main.screen == "play")
 await d.unmount(main)
 d.end()
 for name in DirAccess.get_files_at(save_dir): DirAccess.remove_absolute(ProjectSettings.globalize_path(save_dir.path_join(name)))
 DirAccess.remove_absolute(ProjectSettings.globalize_path(save_dir))
 quit(d.finish({"sourceSha": OS.get_environment("GITHUB_SHA")}))
