package;

#if heaps

import haxe.Json;
import sys.io.File;
import h2d.Text;
import h2d.filter.Blur;
import h2d.filter.Glow;
import h2d.filter.Outline;
import hxd.App;
import hxd.Key;
import hxd.Window;
import hxd.res.DefaultFont;
import live2d.cubism.ext.L2DCallbackAudioSource;
import live2d.cubism.ext.L2DEventDispatcher;
import live2d.cubism.ext.L2DLipSync;
import live2d.cubism.ext.L2DLookAt;
import live2d.cubism.ext.L2DMotionQueue;
import live2d.cubism.ext.L2DParts;
import live2d.cubism.ext.heaps.L2DHeapsInputAdapter;
import live2d.cubism.ext.heaps.L2DHeapsPerfPanel;
import live2d.cubism.ext.L2DPhysicsTuner;
import live2d.cubism.ext.L2DVTubeModel;
import live2d.cubism.ext.L2DVTubeModel.VTuberExpression;
import live2d.cubism.ext.L2DVTubeModel.VTuberMotion;

using StringTools;
import live2d.cubism.heaps.L2DHeapsObject;

/**
 * Heaps Demo for Live2D Cubism.
 *
 * Uses L2DHeapsObject for clean, framework-idiomatic integration.
 * The model auto-updates and renders in sync(ctx); this demo only
 * handles input and model switching.
 *
 * Controls:
 *   Click (no Ctrl): hit test + play TapBody motion
 *   Hold mouse (no Ctrl): eye tracking
 *   Ctrl + drag: move model
 *   Wheel: scale (Shift = faster)
 *   E: show expression list (0-9 to select, 0=random)
 *   M: show motion list (0-9 to select, 0=random)
 *   B / P / L: toggle Breath / Physics / LipSync
 *   N: toggle motion blend demo (two-layer blend)
 *   T: toggle first part opacity (L2DParts chain DSL demo)
 *   H: toggle hot-reload (watch model files for changes)
 *   F: cycle filter chain (none -> glow -> blur -> outline -> glow+blur)
 *   V: toggle LipSync (synthesized amplitude demo)
 *   G: toggle performance panel
 *   LEFT / RIGHT: switch model
 */
class HeapsDemo extends App
{
	static var MODEL_LIST:Array<String> = ['OfficialModelName', 'VTuber:ModelName'];

	/** Base path for VTuber models (relative to bin/heaps/ working dir at runtime). */
	static inline var VTUBER_MODEL_BASE:String = 'assets/live2d/';

	var l2d:L2DHeapsObject;
	var currentModelIndex:Int = 0;
	/** Current model's display name (strips 'VTuber:' prefix). */
	var currentModelName:String = 'OfficialModelName';

	var infoText:Text;
	var statusText:Text;

	var dragging:Bool = false;
	var dragOffsetX:Float = 0;
	var dragOffsetY:Float = 0;

	var dispatcher:L2DEventDispatcher;
	var motionQueue:L2DMotionQueue;
	var lookAt:L2DLookAt;
	/** Parts manager (L2DParts chain DSL + tween). */
	var parts:L2DParts;

	/** LipSync controller (synthesized amplitude demo). */
	var lipSync:L2DLipSync;
	/** Callback audio source for LipSync demo (synthesized amplitude). */
	var audioSource:L2DCallbackAudioSource;
	/** Current filter mode (0=none, 1=glow, 2=blur, 3=outline, 4=glow+blur). */
	var filterMode:Int = 0;

	/** Event-based mouse input adapter (demonstrates IL2DInputAdapter). */
	var input:L2DHeapsInputAdapter;
	/** Whether the left mouse button is currently held (tracked from adapter events). */
	var mouseDown:Bool = false;
	/** Whether Ctrl was held when the current press began (distinguishes drag vs. follow). */
	var mouseDownCtrl:Bool = false;
	/** Last mouse position from adapter (stage coords), consumed in update(). */
	var lastMouseX:Float = 0;
	var lastMouseY:Float = 0;

	/** Hit area names for the current model (from compile-time constants). */
	var currentHitAreas:Array<String> = [];
	/** TapBody motion group name for the current model, or null if the model has none. */
	var currentTapBodyGroup:String = null;

	// ---- Expression / Motion list selection ----
    /** Expression names parsed from model3.json FileReferences.Expressions. */
    var expressionList:Array<String> = [];
    /** Motion groups with counts parsed from model3.json FileReferences.Motions. */
    var motionList:Array<{group:String, count:Int}> = [];
    /** Whether the expression selection menu is currently open. */
    var expressionMenuOpen:Bool = false;
    /** Whether the motion selection menu is currently open. */
    var motionMenuOpen:Bool = false;

    /** Performance panel overlay. */
    var perfPanel:L2DHeapsPerfPanel;

    /** Physics parameter tuner (null if model has no physics3.json). */
    var physicsTuner:L2DPhysicsTuner;

    /** VTuber model adapter (non-null if the model has a .vtube.json). */
    var vtubeModel:L2DVTuberModel;
    /** Whether the current model is a VTuber-style model. */
    var isVTubeModel:Bool = false;
    /** Cached VTuber expression entries for the menu. */
    var vtubeExpressionEntries:Array<VTuberExpression> = [];
    /** Cached VTuber motion entries for the menu. */
    var vtubeMotionEntries:Array<VTuberMotion> = [];

    /** Pending key input buffer (cumulative string of digits). */
	var menuKeyBuffer:String = "";
	/** Time elapsed since the last digit was pressed (for auto-submit timeout). */
	var menuKeyBufferTime:Float = 0;
	/** Timeout in seconds before auto-submitting buffered digits. */
	static inline var MENU_KEY_TIMEOUT:Float = 0.8;
	/** Bitmask of digit keys held last frame (for just-pressed detection with Key.isPressed). */
	var menuPrevDigitMask:Int = 0;

	/** When set, waiting for motion sub-index input after selecting a multi-motion group. */
		var motionIndexPendingGroup:{group:String, count:Int} = null;
		var motionIndexPendingOpen:Bool = false;

	static function main()
	{
		new HeapsDemo();
	}

	override function init()
	{
		engine.backgroundColor = 0xFF222222;
		Window.getInstance().title = 'Live2D Haxe - Heaps Demo';

		var font = DefaultFont.get();
		infoText = new Text(font, s2d);
		infoText.textColor = 0xFFFFFFFF;
		infoText.x = 8;
		infoText.y = 8;
		infoText.text = 'Live2D Haxe - Heaps Demo v1.1\n'
			+ 'Click: Hit test + motion\n'
			+ 'Hold mouse: Eye tracking\n'
			+ 'Ctrl + drag: Move model\n'
			+ 'Wheel: Scale (Shift=fast)\n'
			+ 'E: Expressions | M: Motions\n'
			+ 'B: Breath | P: Physics | L: LipSync\n'
				+ 'Y: Gravity | W: Wind | R: Reset phys | S: Stabilize\n'
				+ 'T: Toggle first part (L2DParts)\n'
			+ 'H: Hot-reload | F: Filter | V: LipSync(synth)\n'
			+ 'G: Perf panel | LEFT/RIGHT: Switch model\n'
			+ 'v1.1: Perf panel + GPU fence + Mask SSAA + VTuber models';

		statusText = new Text(font, s2d);
		statusText.textColor = 0xFFCCCCCC;
		statusText.x = 8;
		updateStatusY();

		// Event-based mouse input via IL2DInputAdapter (Heaps implementation).
		input = new L2DHeapsInputAdapter();
		input.bindDown((x, y) -> {
			mouseDown = true;
			mouseDownCtrl = Key.isDown(Key.CTRL);
			lastMouseX = x;
			lastMouseY = y;
			if (l2d == null || !l2d.model.notNull()) return;
			if (mouseDownCtrl)
			{
				// Begin dragging
				dragging = true;
				dragOffsetX = l2d.core.x - x;
				dragOffsetY = l2d.core.y - y;
			}
			else
			{
				// Click (no Ctrl): hit test via dispatcher, enqueue TapBody on hit
				if (currentHitAreas.length > 0 && dispatcher.hitTestAreas(currentHitAreas, x, y))
				{
					if (currentTapBodyGroup != null) motionQueue.enqueue(currentTapBodyGroup, 0, 3);
				}
			}
		});
		input.bindUp((x, y) -> {
			mouseDown = false;
			dragging = false;
		});
		input.bindMove((x, y) -> {
			lastMouseX = x;
			lastMouseY = y;
		});

		loadModel(currentModelIndex);
	}

	function loadModel(index:Int)
	{
		if (l2d != null)
		{
			l2d.remove();
			l2d = null;
		}
		// LipSync is bound to the old core — discard on model switch
		if (lipSync != null) { lipSync.disable(); lipSync = null; audioSource = null; }
		// Reset filters on model switch
		filterMode = 0;

		// Close any open menus
		expressionMenuOpen = false;
		motionMenuOpen = false;
			motionIndexPendingOpen = false;
			motionIndexPendingGroup = null;

		// Reset VTuber-specific state (prevent stale state on failed load)
		isVTubeModel = false;
		vtubeModel = null;
		vtubeExpressionEntries = [];
		vtubeMotionEntries = [];

		var modelName = MODEL_LIST[index];
		var dir:String;
		var modelJson:String;
		var displayName:String = modelName;
		var isVTube:Bool = false;

		if (modelName.startsWith('VTuber:'))
		{
			isVTube = true;
			displayName = modelName.substr(7);
			currentModelName = displayName;
			var vtubeDir = VTUBER_MODEL_BASE + displayName + '/';
			var vtubePath = findVTubeJson(vtubeDir);
			if (vtubePath == null)
			{
				updateStatus('ERROR: No .vtube.json found for $displayName');
				trace('[HeapsDemo] ERROR: No .vtube.json in $vtubeDir');
				updateStatusY();
				return;
			}

			// Parse vtube.json to get model entry
			vtubeModel = new L2DVTuberModel(vtubePath);
			if (!vtubeModel.isValid)
			{
				updateStatus('ERROR: Failed to parse vtube.json for $displayName');
				trace('[HeapsDemo] ERROR: Invalid vtube.json: $vtubePath');
				updateStatusY();
				return;
			}

			trace('[HeapsDemo] VTuber model: ${vtubeModel.modelName} | Entry: ${vtubeModel.modelEntry}');
			dir = vtubeModel.baseDir;
			modelJson = vtubeModel.modelEntry;
		}
		else
		{
			currentModelName = modelName;
			dir = 'assets/live2d/$modelName/';
			modelJson = '$modelName.model3.json';
		}

		l2d = new L2DHeapsObject(dir, modelJson, s2d);

		if (l2d.model.notNull())
		{
			l2d.core.x = s2d.width / 2;
			l2d.core.y = s2d.height / 2;
			l2d.core.scale = (s2d.height * 0.8) / l2d.modelHeight;

			// Recreate extensions bound to the new core (MUST be before idle start for VTuber models)
			dispatcher = new L2DEventDispatcher(l2d.core);
			motionQueue = new L2DMotionQueue(l2d.core, dispatcher);
			lookAt = new L2DLookAt(l2d.core);
			parts = new L2DParts(l2d.core);

			// Idle animation: for VTuber models, use queue-based file idle;
			// for standard models, use the built-in group idle.
			if (isVTube && vtubeModel != null && vtubeModel.idleAnimation != null)
			{
				// Start idle immediately via queue, then enable file-based idle recovery
				// so idle restarts after any VTuber motion finishes.
				trace('[HeapsDemo] Starting VTuber idle: ${vtubeModel.idleAnimation}');
				motionQueue.enqueueMotionFile("main", vtubeModel.idleAnimation, 1);
				motionQueue.enableSlotIdleRecoveryFile("main", vtubeModel.idleAnimation, 3.0);
			}
			else
			{
				l2d.core.startIdleMotion();
			}

			dispatcher.onMotionFinished((group, no, handle) -> {
				trace('[HeapsDemo] Motion finished: $group#$no');
			});
			dispatcher.onHitTest((area, x, y) -> {
				trace('[HeapsDemo] Hit: $area @ ($x, $y)');
			});

			dispatcher.onMotionUserDataEvent = (value) -> {
				trace('[HeapsDemo] UserData (dynamic): $value');
			};
			dispatcher.onMotionUserData((value) -> {
				trace('[HeapsDemo] UserData (typed): $value');
			});

			if (parts.count > 0)
			{
				var names = [for (i in 0...parts.count) parts.at(i).name];
				trace('[HeapsDemo] Parts (${parts.count}): ${names.join(", ")}');
			}

			// Physics tuner: attach if the model has a physics3.json file
			physicsTuner = null;
			var physicsPath = l2d.core.modelDir + l2d.core.modelFileName.replace('.model3.json', '.physics3.json');
			if (sys.FileSystem.exists(physicsPath))
			{
				physicsTuner = new L2DPhysicsTuner();
				physicsTuner.attachTo(l2d.core, physicsPath);
				l2d.physicsTuner = physicsTuner;
				trace('[HeapsDemo] Physics tuner loaded: ${physicsTuner.getSummary()}');
			}

			// Parse model3.json for expression and motion lists
			if (isVTube)
			{
				// VTuber model already parsed; populate fields from vtubeModel
				isVTubeModel = true;
				expressionList = [];
				motionList = [];
				vtubeExpressionEntries = vtubeModel.getExpressions();
				vtubeMotionEntries = vtubeModel.getMotions();

				// Pre-load all expression files
				for (expr in vtubeExpressionEntries)
				{
					var fullPath = vtubeModel.baseDir + expr.file;
					l2d.core.loadExpressionFile(fullPath);
					trace('[HeapsDemo]   Loaded expression: ${expr.name} (${expr.file})');
				}

				if (vtubeMotionEntries.length > 0)
				{
					trace('[HeapsDemo]   VTuber motions: ${vtubeMotionEntries.length}');
					for (m in vtubeMotionEntries)
						trace('[HeapsDemo]     ${m.name} (${m.file})');
				}
			}
			else
			{
				parseModelManifest('assets/live2d/$modelName/$modelName.model3.json');
			}

			// Select compile-time constants for the current model.
			// VTuber models don't have compile-time constants.
			if (!isVTube)
			{
				switch (modelName)
					{
						case 'OfficialModelName':
							currentHitAreas = [];
							currentTapBodyGroup = null;
						default:
							currentHitAreas = [];
							currentTapBodyGroup = null;
					}
			}
			else
			{
				currentHitAreas = [];
				currentTapBodyGroup = null;
			}

			updateStatus('Model: $displayName | Scale: ${l2d.core.scale:.2f} | ${l2d.modelWidth}x${l2d.modelHeight}');
			trace('[HeapsDemo] Loaded $displayName: ${l2d.modelWidth}x${l2d.modelHeight}, scale=${l2d.core.scale}');

			// Attach perf panel (once, on first load)
			if (perfPanel == null)
			{
				perfPanel = new L2DHeapsPerfPanel();
				perfPanel.attachToExt(l2d.core, l2d.heapsRenderer, s2d);
			}
			else
			{
				// Re-attach to the new core/renderer
				perfPanel.attachTo(l2d.core, s2d);
				perfPanel.renderer = l2d.heapsRenderer;
			}
			// Position below all demo text so it's not covered
			perfPanel.setPosition(8, statusText.y + statusText.textHeight + 8);
		}
		else
		{
			updateStatus('ERROR: Failed to load model $displayName');
			trace('[HeapsDemo] ERROR: Failed to load model $displayName');
		}

		updateStatusY();
	}

	/**
	 * Find a .vtube.json file in the given directory.
	 * Returns the full path, or null if none found.
	 */
	static function findVTubeJson(dir:String):String
	{
		try
		{
			for (f in sys.FileSystem.readDirectory(dir))
			{
				if (f.toLowerCase().endsWith('.vtube.json'))
				{
					return dir + f;
				}
			}
		}
		catch (e:Dynamic) {}
		return null;
	}

	/**
	 * Parse model3.json to extract expression names and motion group names.
	 * Also checks for a .vtube.json in the same directory for VTuber-style models.
	 */
	function parseModelManifest(path:String)
	{
		expressionList = [];
		motionList = [];
		vtubeModel = null;
		isVTubeModel = false;
		vtubeExpressionEntries = [];
		vtubeMotionEntries = [];

		try
		{
			var content = File.getContent(path);
			var json:Dynamic = Json.parse(content);
			var refs:Dynamic = json.FileReferences;

			// Expressions: array of {Name: "exp_01", File: "..."}
			if (refs.Expressions != null)
			{
				for (exp in cast(refs.Expressions, Array<Dynamic>))
				{
					expressionList.push(exp.Name);
				}
			}

			// Motions: object of {GroupName: [{File: "..."}, ...]}
			if (refs.Motions != null)
			{
				var motions:Dynamic = refs.Motions;
				for (group in Reflect.fields(motions))
				{
					var entries:Array<Dynamic> = cast Reflect.field(motions, group);
					motionList.push({group: group, count: entries.length});
				}
			}
		}
		catch (e:Dynamic)
		{
			trace('[HeapsDemo] Failed to parse model3.json: $e');
		}

		// Check for .vtube.json in the same directory (VTuber-style models)
		var dir = path.substr(0, path.lastIndexOf('/') + 1);
		// Look for any .vtube.json in the directory
		var vtubePath = null;
		for (f in sys.FileSystem.readDirectory(dir))
		{
			if (f.toLowerCase().endsWith('.vtube.json'))
			{
				vtubePath = dir + f;
				break;
			}
		}

		if (vtubePath != null)
		{
			vtubeModel = new L2DVTuberModel(vtubePath);
			if (vtubeModel.isValid)
			{
				isVTubeModel = true;
				trace('[HeapsDemo] VTuber model detected: ${vtubeModel.modelName} | Entry: ${vtubeModel.modelEntry}');

				// Replace expression/motion lists with VTuber entries
				vtubeExpressionEntries = vtubeModel.getExpressions();
				vtubeMotionEntries = vtubeModel.getMotions();

				// Pre-load all expression files
				for (expr in vtubeExpressionEntries)
				{
					var fullPath = vtubeModel.baseDir + expr.file;
					l2d.core.loadExpressionFile(fullPath);
					trace('[HeapsDemo]   Loaded expression: ${expr.name} (${expr.file})');
				}

				// Print motion entries (file-path motion is a stub)
				if (vtubeMotionEntries.length > 0)
				{
					trace('[HeapsDemo]   VTuber motions (file-path motion not yet supported):');
					for (m in vtubeMotionEntries)
						trace('[HeapsDemo]     ${m.name} (${m.file})');
				}
			}
		}
	}

	function updateStatus(msg:String)
	{
		statusText.text = msg;
	}

	/** Reposition statusText below infoText based on actual rendered height. */
		function updateStatusY()
		{
			statusText.y = infoText.y + infoText.textHeight + 4;
		}

	/**
	 * Show the expression selection list in the status text.
	 */
	function showExpressionMenu()
	{
		expressionMenuOpen = true;
		motionMenuOpen = false;

		if (isVTubeModel)
		{
			if (vtubeExpressionEntries.length == 0)
			{
				updateStatus('No VTuber expressions available.');
				expressionMenuOpen = false;
				return;
			}
			var buf = new StringBuf();
			buf.add('Expressions (0=clear all):\n');
			for (i in 0...vtubeExpressionEntries.length)
			{
				if (i > 0 && i % 3 == 0) buf.add('\n');
				buf.add('${i + 1}:${vtubeExpressionEntries[i].name}  ');
			}
			updateStatus(buf.toString());
			return;
		}

		if (expressionList.length == 0)
		{
			updateStatus('No expressions available for this model.');
			expressionMenuOpen = false;
			return;
		}
		var buf = new StringBuf();
		buf.add('Expressions (0=random):\n');
		for (i in 0...expressionList.length)
		{
			if (i > 0 && i % 4 == 0) buf.add('\n');
			buf.add('${i + 1}:${expressionList[i]}  ');
		}
		updateStatus(buf.toString());
	}

	/**
	 * Show the motion selection list in the status text.
	 */
	function showMotionMenu()
	{
		motionMenuOpen = true;
		expressionMenuOpen = false;

		if (isVTubeModel)
		{
			if (vtubeMotionEntries.length == 0 && vtubeModel.idleAnimation == null)
			{
				updateStatus('No VTuber motions available.');
				motionMenuOpen = false;
				return;
			}
			var buf = new StringBuf();
			buf.add('VTuber Motions:\n');
			for (i in 0...vtubeMotionEntries.length)
			{
				if (i > 0 && i % 3 == 0) buf.add('\n');
				buf.add('${i + 1}:${vtubeMotionEntries[i].name}  ');
			}
			if (vtubeModel.idleAnimation != null)
			{
				buf.add('${vtubeMotionEntries.length + 1}:idle(tear)');
			}
			updateStatus(buf.toString());
			return;
		}

		if (motionList.length == 0)
		{
			updateStatus('No motions available for this model.');
			motionMenuOpen = false;
			return;
		}
		var buf = new StringBuf();
		buf.add('Motions (0=random):\n');
		for (i in 0...motionList.length)
		{
			var m = motionList[i];
			buf.add('${i + 1}:${m.group}(${m.count})  ');
			if (i % 3 == 2) buf.add('\n');
		}
		updateStatus(buf.toString());
	}

	/**
		 * Process a menu selection by number (supports 0-99 for two-digit input).
		 * @return true if the key was consumed by a menu.
		 */
		function handleMenuKeyByNumber(num:Int):Bool
		{
			if (motionIndexPendingOpen)
		{
			motionIndexPendingOpen = false;
			var g = motionIndexPendingGroup;
			motionIndexPendingGroup = null;
			if (num >= 0 && num < g.count)
			{
				motionQueue.enqueue(g.group, num, 3);
				updateStatus('Motion: ${g.group}#$num');
			}
			else
			{
				updateStatus('Motion cancelled (invalid index $num)');
			}
			return true;
		}

		if (expressionMenuOpen)
		{
			expressionMenuOpen = false;

			if (isVTubeModel)
			{
				if (num == 0)
				{
					l2d.core.clearFileExpressions();
					updateStatus('Cleared all expressions');
				}
				else if (num > 0 && num <= vtubeExpressionEntries.length)
				{
					var expr = vtubeExpressionEntries[num - 1];
					var fullPath = vtubeModel.baseDir + expr.file;
					l2d.core.toggleExpressionFile(fullPath);
					var active = l2d.core.isExpressionFileActive(fullPath);
					updateStatus('Expression: ${expr.name} -> ${active ? "ON" : "OFF"}');
				}
				else
				{
					updateStatus('Expression $num: out of range (1-${vtubeExpressionEntries.length})');
				}
				return true;
			}

			if (num == 0 || num > expressionList.length)
			{
				l2d.core.setRandomExpression();
				updateStatus('Expression: random');
			}
			else
			{
				var name = expressionList[num - 1];
				l2d.core.setExpression(name);
				updateStatus('Expression: $name');
			}
			return true;
		}

		if (motionMenuOpen)
		{
			motionMenuOpen = false;

			if (isVTubeModel)
			{
				var maxMotion = vtubeMotionEntries.length + ((vtubeModel.idleAnimation != null) ? 1 : 0);
				if (num == 0 || num > maxMotion)
				{
					updateStatus('VTuber motion: out of range (1-${maxMotion})');
				}
				else if (vtubeModel.idleAnimation != null && num == maxMotion)
				{
					motionQueue.forceIdleRecovery("main");
					updateStatus('VTuber motion: idle (tear)');
				}
				else
				{
					var m = vtubeMotionEntries[num - 1];
					motionQueue.enqueueMotionFile("main", m.file, 3);
					updateStatus('VTuber motion: ${m.name}');
				}
				return true;
			}

			if (num == 0 || num > motionList.length)
			{
				// Random: pick a random motion group and entry
				var m = motionList[Std.random(motionList.length)];
				var no = Std.random(m.count);
				motionQueue.enqueue(m.group, no, 3);
				updateStatus('Motion: ${m.group}#$no (random)');
			}
			else
			{
				var m = motionList[num - 1];
				if (m.count > 1)
				{
					motionIndexPendingGroup = m;
					motionIndexPendingOpen = true;
					updateStatus('Motion: ${m.group} (${m.count} entries)\nPress index (0-${m.count - 1}) or wait to cancel');
				}
				else
				{
					motionQueue.enqueue(m.group, 0, 3);
					updateStatus('Motion: ${m.group}#0');
				}
			}
			return true;
		}

		return false;
	}

	override function update(dt:Float)
	{
		super.update(dt);

		if (Key.isPressed(Key.LEFT))
		{
			currentModelIndex--;
			if (currentModelIndex < 0) currentModelIndex = MODEL_LIST.length - 1;
			loadModel(currentModelIndex);
		}
		if (Key.isPressed(Key.RIGHT))
		{
			currentModelIndex++;
			if (currentModelIndex >= MODEL_LIST.length) currentModelIndex = 0;
			loadModel(currentModelIndex);
		}

		if (l2d == null || !l2d.model.notNull()) return;

		// Handle menu number key selection (cumulative string buffer with just-pressed detection)
		if (expressionMenuOpen || motionMenuOpen || motionIndexPendingOpen)
		{
			var digitKeys:Array<Int> = [
				Key.NUMBER_0, Key.NUMBER_1, Key.NUMBER_2, Key.NUMBER_3, Key.NUMBER_4,
				Key.NUMBER_5, Key.NUMBER_6, Key.NUMBER_7, Key.NUMBER_8, Key.NUMBER_9,
				Key.NUMPAD_0, Key.NUMPAD_1, Key.NUMPAD_2, Key.NUMPAD_3, Key.NUMPAD_4,
				Key.NUMPAD_5, Key.NUMPAD_6, Key.NUMPAD_7, Key.NUMPAD_8, Key.NUMPAD_9
			];
			var curMask = 0;
			for (i in 0...digitKeys.length)
			{
				if (Key.isPressed(digitKeys[i])) curMask |= (1 << i);
			}
			// Detect just-pressed digits (not held last frame)
			for (i in 0...digitKeys.length)
			{
				var bit = 1 << i;
				if ((curMask & bit) != 0 && (menuPrevDigitMask & bit) == 0 && menuKeyBuffer.length < 4)
				{
					var digit = i % 10; // 0-9 for NUMBER_*, 0-9 for NUMPAD_*
					menuKeyBuffer += Std.string(digit);
					menuKeyBufferTime = 0;
					updateMenuKeyBufferStatus();
				}
			}
			menuPrevDigitMask = curMask;

			// Timeout: auto-submit buffered digits
			if (menuKeyBuffer != "")
			{
				menuKeyBufferTime += dt;
				if (menuKeyBufferTime >= MENU_KEY_TIMEOUT)
				{
					var num = Std.parseInt(menuKeyBuffer);
					menuKeyBuffer = "";
					if (num != null) handleMenuKeyByNumber(num);
				}
			}
		}
		else
		{
			menuPrevDigitMask = 0;
			if (menuKeyBuffer != "") menuKeyBuffer = ""; // menu closed while buffering
		}

		var mx = lastMouseX;
		var my = lastMouseY;

		// Dragging
		if (dragging)
		{
			l2d.core.x = dragOffsetX + mx;
			l2d.core.y = dragOffsetY + my;
		}

		// Eye tracking
		if (mouseDown && !mouseDownCtrl)
		{
			lookAt.setTarget(mx, my);
		}
		else
		{
			lookAt.release();
		}

		// Mouse wheel: scale
		var wheelUp = Key.isPressed(Key.MOUSE_WHEEL_UP);
		var wheelDown = Key.isPressed(Key.MOUSE_WHEEL_DOWN);
		if (wheelUp || wheelDown)
		{
			var delta = wheelUp ? 1 : -1;
			var step = 12 * (Key.isDown(Key.SHIFT) ? 3 : 1);
			l2d.core.scale += delta * step;
			var minScale = (s2d.height * 0.3) / l2d.modelHeight;
			var maxScale = (s2d.height * 3.0) / l2d.modelHeight;
			if (l2d.core.scale < minScale) l2d.core.scale = minScale;
			if (l2d.core.scale > maxScale) l2d.core.scale = maxScale;
			updateStatus('Model: $currentModelName | Scale: ${l2d.core.scale:.2f}');
		}

		// Keyboard actions
		if (Key.isPressed(Key.E))
		{
			motionIndexPendingOpen = false;
			motionIndexPendingGroup = null;
			menuKeyBuffer = "";
			if (expressionMenuOpen)
			{
				// Dismiss menu on second press
				expressionMenuOpen = false;
				updateStatus('Model: $currentModelName | Scale: ${l2d.core.scale:.2f}');
			}
			else
			{
				showExpressionMenu();
			}
		}
		if (Key.isPressed(Key.M))
		{
			motionIndexPendingOpen = false;
			motionIndexPendingGroup = null;
			menuKeyBuffer = "";
			if (motionMenuOpen)
			{
				motionMenuOpen = false;
				updateStatus('Model: $currentModelName | Scale: ${l2d.core.scale:.2f}');
			}
			else
			{
				showMotionMenu();
			}
		}
		if (Key.isPressed(Key.B))
			{
				l2d.core.setBreathEnabled(!l2d.core.breathEnabled);
				updateStatus('Breath: ${l2d.core.breathEnabled}');
			}
		if (Key.isPressed(Key.P))
		{
			l2d.core.setPhysicsEnabled(!l2d.core.physicsEnabled);
			updateStatus('Physics: ${l2d.core.physicsEnabled}');
		}
		// Physics tuner shortcuts (Y=gravity, W=wind, R=reset, S=stabilize)
		if (physicsTuner != null && physicsTuner.isLoaded)
		{
			if (Key.isPressed(Key.Y))
			{
				// Cycle gravity: (0,-1) → (0,-2) → (0,-0.5) → (0,-1)
				var g = physicsTuner.gravityY;
				if (g >= -1.1) physicsTuner.setGravity(0, -2);
				else if (g >= -1.6) physicsTuner.setGravity(0, -0.5);
				else physicsTuner.setGravity(0, -1);
				updateStatus('Gravity: (${physicsTuner.gravityX}, ${physicsTuner.gravityY})');
			}
			if (Key.isPressed(Key.W))
			{
				// Cycle wind: (0,0) → (0.5,0) → (1,0) → (0,0)
				var w = physicsTuner.windX;
				if (w < 0.1) physicsTuner.setWind(0.5, 0);
				else if (w < 0.6) physicsTuner.setWind(1, 0);
				else physicsTuner.setWind(0, 0);
				updateStatus('Wind: (${physicsTuner.windX}, ${physicsTuner.windY})');
			}
			if (Key.isPressed(Key.R))
			{
				physicsTuner.reset();
				updateStatus('Physics reset (gravity/wind to defaults)');
			}
			if (Key.isPressed(Key.S))
			{
				physicsTuner.stabilize();
				updateStatus('Physics stabilized');
			}
		}
		if (Key.isPressed(Key.L))
		{
			l2d.core.setLipSyncEnabled(!l2d.core.lipSyncEnabled);
			updateStatus('LipSync: ${l2d.core.lipSyncEnabled}');
		}
		if (Key.isPressed(Key.T))
		{
			if (parts != null && parts.count > 0)
			{
				var p = parts.at(0);
				parts.tween(p.name, p.get() > 0.5 ? 0.0 : 1.0, 0.3);
				updateStatus('Part "${p.name}" -> ${p.get() > 0.5 ? "hide" : "show"}');
			}
		}
		if (Key.isPressed(Key.H))
		{
			l2d.hotReloadEnabled = !l2d.hotReloadEnabled;
			updateStatus('Hot-reload: ${l2d.hotReloadEnabled ? "ON" : "OFF"}');
		}
		if (Key.isPressed(Key.G))
		{
			perfPanel.enabled = !perfPanel.enabled;
			if (perfPanel.enabled)
			{
				perfPanel.visible = true;
				updateStatus('Perf panel: ON');
			}
			else
			{
				perfPanel.visible = false;
				updateStatus('Perf panel: OFF');
			}
		}
		if (Key.isPressed(Key.F))
		{
			filterMode = (filterMode + 1) % 5;
			l2d.clearFilters();
			switch (filterMode)
			{
				case 1: l2d.addFilter(new Glow(0xFFFFFF));
				case 2: l2d.addFilter(new Blur(3.0));
				case 3: l2d.addFilter(new Outline(4.0, 0xFF0000));
				case 4: l2d.addFilter(new Glow(0xFFFFFF)); l2d.addFilter(new Blur(3.0));
			}
			var names = ["none", "glow", "blur", "outline", "glow+blur"];
			updateStatus('Filter: ${names[filterMode]}');
		}
		if (Key.isPressed(Key.V))
		{
			if (lipSync == null)
			{
				audioSource = new L2DCallbackAudioSource(() -> {
					var t = haxe.Timer.stamp();
					var amp = 0.3 + 0.3 * Math.sin(t * 8) + 0.1 * Math.sin(t * 23);
					return amp < 0 ? 0 : (amp > 1 ? 1 : amp);
				});
				lipSync = new L2DLipSync(l2d.core, audioSource);
			}
			if (lipSync.enabled) lipSync.disable();
			else lipSync.enable();
			updateStatus('LipSync (synth): ${lipSync.enabled ? "ON" : "OFF"}');
		}

		// Update extensions
			if (motionQueue != null) motionQueue.update(dt);
		if (lookAt != null) lookAt.update(dt);
		if (parts != null) parts.update(dt);
		if (lipSync != null && lipSync.enabled) lipSync.update(dt);
		if (perfPanel != null) perfPanel.update(dt);
	}

	function updateMenuKeyBufferStatus()
	{
		var hint = '\n(Input: $menuKeyBuffer — auto-submit in ${MENU_KEY_TIMEOUT - menuKeyBufferTime:.1f}s)';
		if (expressionMenuOpen)
		{
			showExpressionMenu();
			statusText.text += hint;
		}
		else if (motionMenuOpen)
		{
			showMotionMenu();
			statusText.text += hint;
		}
	}

	override function onResize()
	{
		super.onResize();
		if (l2d != null && l2d.model.notNull())
		{
			l2d.core.x = s2d.width / 2;
			l2d.core.y = s2d.height / 2;
		}
	}
}

#end
