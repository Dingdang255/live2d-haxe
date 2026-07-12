package;

import haxe.Json;
import sys.FileSystem;
import sys.io.File;
import flixel.FlxG;
import flixel.FlxState;
import flixel.text.FlxText;
import flixel.math.FlxPoint;
import live2d.cubism.flixel.L2DFlixelComponent;
import live2d.cubism.flixel.L2DFlixelManager;
import live2d.cubism.ext.L2DCallbackAudioSource;
import live2d.cubism.ext.L2DEventDispatcher;
import live2d.cubism.ext.L2DLipSync;
import live2d.cubism.ext.L2DLookAt;
import live2d.cubism.ext.L2DMotionQueue;
import live2d.cubism.ext.L2DParts;
import live2d.cubism.ext.L2DPhysicsTuner;
import live2d.cubism.ext.L2DVTubeModel;
import live2d.cubism.ext.L2DVTubeModel.VTuberExpression;
import live2d.cubism.ext.L2DVTubeModel.VTuberMotion;

using StringTools;
import live2d.cubism.ext.flixel.L2DFlixelPerfPanel;

/**
 * Demo state showing Live2D Cubism usage with Flixel + v1.1 Extension Layer.
 *
 * Controls:
 *   - Click on model hit areas to trigger motions
 *   - Hold mouse (non-Ctrl): Eye tracking
 *   - Ctrl + drag: Move model position
 *   - Mouse wheel: Scale model (Shift for faster)
 *   - E: show expression list (0-9 to select, 0=random)
 *   - M: show motion list (0-9 to select, 0=random)
 *   - B: Toggle breath
 *   - P: Toggle physics
 *   - T: Toggle first part opacity (L2DParts chain DSL demo)
 *   - V: Toggle LipSync (synthesized amplitude demo)
 *   - G: Toggle performance panel
 *   - LEFT/RIGHT: Switch model
 */
class L2DDemoState extends FlxState
{
	var modelList:Array<String> = ['OfficialModelName', 'VTuber:ModelName'];
	var currentModelIndex:Int = 0;
	/** Current model's display name (strips 'VTuber:' prefix). */
	var currentModelName:String = 'OfficialModelName';
	/** Base path for VTuber models (relative to test/ working dir at runtime). */
	static inline var VTUBER_MODEL_BASE:String = 'assets/live2d/';

	var l2d:L2DFlixelComponent;
	var infoText:FlxText;
	var statusText:FlxText;
	var dragging:Bool = false;
	var dragOffset:FlxPoint;

	var dispatcher:L2DEventDispatcher;
	var motionQueue:L2DMotionQueue;
	var lookAt:L2DLookAt;
	/** Parts manager (L2DParts chain DSL + tween). */
	var parts:L2DParts;

	/** VTuber model adapter (non-null if the model has a .vtube.json). */
	var vtubeModel:L2DVTuberModel;
	/** Whether the current model is a VTuber-style model. */
	var isVTubeModel:Bool = false;
	/** Cached VTuber expression entries for the menu. */
	var vtubeExpressionEntries:Array<VTuberExpression> = [];
	/** Cached VTuber motion entries for the menu. */
	var vtubeMotionEntries:Array<VTuberMotion> = [];

	/** LipSync controller (synthesized amplitude demo). */
	var lipSync:L2DLipSync;
	/** Callback audio source for LipSync demo (synthesized amplitude). */
	var audioSource:L2DCallbackAudioSource;

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
	var perfPanel:L2DFlixelPerfPanel;

	/** Physics parameter tuner (null if model has no physics3.json). */
	var physicsTuner:L2DPhysicsTuner;

	/** Accumulated digit buffer for menu selection ("" = no input). */
	var menuKeyBuffer:String = "";
	/** Time elapsed since the last digit was pressed (for auto-submit timeout). */
	var menuKeyBufferTime:Float = 0;
	/** Timeout in seconds with no digit input before auto-submitting. */
	static inline var MENU_KEY_TIMEOUT:Float = 0.5;

	/** When set, waiting for motion sub-index input after selecting a multi-motion group. */
	var motionIndexPendingGroup:{group:String, count:Int} = null;
	var motionIndexPendingOpen:Bool = false;

	override public function create()
	{
		super.create();
		FlxG.mouse.visible = true;
		dragOffset = FlxPoint.get();

		// Info text
		infoText = new FlxText(10, 10, FlxG.width - 20,
			'Live2D Haxe Demo v1.1\n'
			+ 'Click: Hit test + motion\n'
			+ 'Hold mouse: Eye tracking\n'
			+ 'Ctrl + drag: Move model\n'
			+ 'Wheel: Scale (Shift=fast)\n'
			+ 'E: Expressions | M: Motions\n'
			+ 'B: Breath | P: Physics\n'
			+ 'Y: Gravity | W: Wind | R: Reset phys | S: Stabilize\n'
			+ 'T: Toggle first part (L2DParts)\n'
			+ 'V: LipSync (synth)\n'
			+ 'G: Perf panel | LEFT/RIGHT: Switch model\n'
			+ 'v1.1: Perf panel + VTuber models + Expr/Motion menus'
		);
		infoText.setFormat(null, 14, 0xFFFFFFFF);
		add(infoText);

		statusText = new FlxText(10, 10, FlxG.width - 20, '');
		statusText.setFormat(null, 12, 0xFFCCCCCC);
		add(statusText);
		updateStatusY();

		loadModel(currentModelIndex);
	}

	function loadModel(index:Int)
	{
		// Remove old model
		if (l2d != null)
		{
			FlxG.removeChild(l2d.getSprite());
			L2DFlixelManager.destroy(l2d);
			l2d = null;
		}
		// LipSync is bound to the old core — discard on model switch
		if (lipSync != null) { lipSync.disable(); lipSync = null; audioSource = null; }

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

		var modelName = modelList[index];
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
				statusText.text = 'ERROR: No .vtube.json found for $displayName';
				trace('[FlixelDemo] ERROR: No .vtube.json in $vtubeDir');
				updateStatusY();
				return;
			}

			vtubeModel = new L2DVTuberModel(vtubePath);
			if (!vtubeModel.isValid)
			{
				statusText.text = 'ERROR: Failed to parse vtube.json for $displayName';
				trace('[FlixelDemo] ERROR: Invalid vtube.json: $vtubePath');
				updateStatusY();
				return;
			}

			trace('[FlixelDemo] VTuber model: ${vtubeModel.modelName} | Entry: ${vtubeModel.modelEntry}');
			dir = vtubeModel.baseDir;
			modelJson = vtubeModel.modelEntry;
		}
		else
		{
			currentModelName = modelName;
			dir = 'assets/live2d/$modelName/';
			modelJson = '$modelName.model3.json';
		}

		l2d = L2DFlixelManager.create(dir, modelJson);

		if (l2d.model.notNull())
		{
			l2d.x = FlxG.width / 2;
			l2d.y = FlxG.height / 2;
			l2d.scale = (FlxG.height * 0.8) / l2d.modelHeight;

			FlxG.addChildBelowMouse(l2d.getSprite());

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
				trace('[FlixelDemo] Starting VTuber idle: ${vtubeModel.idleAnimation}');
				motionQueue.enqueueMotionFile("main", vtubeModel.idleAnimation, 1);
				motionQueue.enableSlotIdleRecoveryFile("main", vtubeModel.idleAnimation, 3.0);
			}
			else
			{
				l2d.core.startIdleMotion();
			}

			dispatcher.onMotionFinished((group, no, handle) -> {
				trace('[FlixelDemo] Motion finished: $group#$no');
			});
			dispatcher.onHitTest((area, x, y) -> {
				trace('[FlixelDemo] Hit: $area @ ($x, $y)');
			});

			dispatcher.onMotionUserDataEvent = (value) -> {
				trace('[FlixelDemo] UserData (dynamic): $value');
			};
			dispatcher.onMotionUserData((value) -> {
				trace('[FlixelDemo] UserData (typed): $value');
			});

			if (parts.count > 0)
			{
				var names = [for (i in 0...parts.count) parts.at(i).name];
				trace('[FlixelDemo] Parts (${parts.count}): ${names.join(", ")}');
			}

			// Physics tuner: attach if the model has a physics3.json file
			physicsTuner = null;
			l2d.physicsTuner = null;
			var physicsPath = l2d.core.modelDir + l2d.core.modelFileName.replace('.model3.json', '.physics3.json');
			if (sys.FileSystem.exists(physicsPath))
			{
				physicsTuner = new L2DPhysicsTuner();
				physicsTuner.attachTo(l2d.core, physicsPath);
				l2d.physicsTuner = physicsTuner;
				trace('[FlixelDemo] Physics tuner loaded: ${physicsTuner.getSummary()}');
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
					trace('[FlixelDemo]   Loaded expression: ${expr.name} (${expr.file})');
				}

				if (vtubeMotionEntries.length > 0)
				{
					trace('[FlixelDemo]   VTuber motions: ${vtubeMotionEntries.length}');
					for (m in vtubeMotionEntries)
						trace('[FlixelDemo]     ${m.name} (${m.file})');
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

			statusText.text = 'Model: $displayName | Scale: ${l2d.scale:.1f} | Bounds: ${l2d.modelWidth} x ${l2d.modelHeight}';

			if (perfPanel == null)
			{
				perfPanel = new L2DFlixelPerfPanel();
				perfPanel.attachTo(l2d.core, this);
			}
			else
			{
				perfPanel.attachTo(l2d.core, this);
			}
		}
		else
		{
			statusText.text = 'ERROR: Failed to load model $displayName';
		}

		updateStatusY();
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

			if (refs.Expressions != null)
			{
				for (exp in cast(refs.Expressions, Array<Dynamic>))
				{
					expressionList.push(exp.Name);
				}
			}

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
			trace('[FlixelDemo] Failed to parse model3.json: $e');
		}

		// Check for .vtube.json in the same directory (VTuber-style models)
		var dir = path.substr(0, path.lastIndexOf('/') + 1);
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
				trace('[FlixelDemo] VTuber model detected: ${vtubeModel.modelName} | Entry: ${vtubeModel.modelEntry}');

				// Replace expression/motion lists with VTuber entries
				vtubeExpressionEntries = vtubeModel.getExpressions();
				vtubeMotionEntries = vtubeModel.getMotions();

				// Pre-load all expression files
				for (expr in vtubeExpressionEntries)
				{
					var fullPath = vtubeModel.baseDir + expr.file;
					l2d.core.loadExpressionFile(fullPath);
					trace('[FlixelDemo]   Loaded expression: ${expr.name} (${expr.file})');
				}

				// Print motion entries (file-path motion is a stub)
				if (vtubeMotionEntries.length > 0)
				{
					trace('[FlixelDemo]   VTuber motions (file-path motion not yet supported):');
					for (m in vtubeMotionEntries)
						trace('[FlixelDemo]     ${m.name} (${m.file})');
				}
			}
		}
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

	/** Reposition statusText below infoText based on actual rendered height. */
	function updateStatusY()
	{
		statusText.y = infoText.y + infoText.height + 4;
	}

	function showExpressionMenu()
	{
		expressionMenuOpen = true;
		motionMenuOpen = false;

		if (isVTubeModel)
		{
			if (vtubeExpressionEntries.length == 0)
			{
				statusText.text = 'No VTuber expressions available.';
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
			statusText.text = buf.toString();
			return;
		}

		if (expressionList.length == 0)
		{
			statusText.text = 'No expressions available for this model.';
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
		statusText.text = buf.toString();
	}

	function showMotionMenu()
	{
		motionMenuOpen = true;
		expressionMenuOpen = false;

		if (isVTubeModel)
		{
			if (vtubeMotionEntries.length == 0 && vtubeModel.idleAnimation == null)
			{
				statusText.text = 'No VTuber motions available.';
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
			statusText.text = buf.toString();
			return;
		}

		if (motionList.length == 0)
		{
			statusText.text = 'No motions available for this model.';
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
		statusText.text = buf.toString();
	}

	function handleMenuKey(num:Int):Bool
	{
		if (motionIndexPendingOpen)
		{
			motionIndexPendingOpen = false;
			var g = motionIndexPendingGroup;
			motionIndexPendingGroup = null;
			if (num >= 0 && num < g.count)
			{
				motionQueue.enqueue(g.group, num, 3);
				statusText.text = 'Motion: ${g.group}#$num';
			}
			else
			{
				statusText.text = 'Motion cancelled (invalid index $num)';
			}
			return true;
		}

		if (!expressionMenuOpen && !motionMenuOpen) return false;

		if (expressionMenuOpen)
		{
			expressionMenuOpen = false;

			if (isVTubeModel)
			{
				if (num == 0)
				{
					l2d.core.clearFileExpressions();
					statusText.text = 'Cleared all expressions';
				}
				else if (num > 0 && num <= vtubeExpressionEntries.length)
				{
					var expr = vtubeExpressionEntries[num - 1];
					var fullPath = vtubeModel.baseDir + expr.file;
					l2d.core.toggleExpressionFile(fullPath);
					var active = l2d.core.isExpressionFileActive(fullPath);
					statusText.text = 'Expression: ${expr.name} -> ${active ? "ON" : "OFF"}';
				}
				else
				{
					statusText.text = 'Expression $num: out of range (1-${vtubeExpressionEntries.length})';
				}
				return true;
			}

			if (num == 0 || num > expressionList.length)
			{
				l2d.core.setRandomExpression();
				statusText.text = 'Expression: random';
			}
			else
			{
				var name = expressionList[num - 1];
				l2d.core.setExpression(name);
				statusText.text = 'Expression: $name';
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
					statusText.text = 'VTuber motion: out of range (1-${maxMotion})';
				}
				else if (vtubeModel.idleAnimation != null && num == maxMotion)
				{
					motionQueue.forceIdleRecovery("main");
					statusText.text = 'VTuber motion: idle (tear)';
				}
				else
				{
					var m = vtubeMotionEntries[num - 1];
					motionQueue.enqueueMotionFile("main", m.file, 3);
					statusText.text = 'VTuber motion: ${m.name}';
				}
				return true;
			}

			if (num == 0 || num > motionList.length)
			{
				var m = motionList[Std.random(motionList.length)];
				var no = Std.random(m.count);
				motionQueue.enqueue(m.group, no, 3);
				statusText.text = 'Motion: ${m.group}#$no (random)';
			}
			else
			{
				var m = motionList[num - 1];
				if (m.count > 1)
				{
					motionIndexPendingGroup = m;
					motionIndexPendingOpen = true;
					statusText.text = 'Motion: ${m.group} (${m.count} entries)\nPress index (0-${m.count - 1}) or wait to cancel';
				}
				else
				{
					motionQueue.enqueue(m.group, 0, 3);
					statusText.text = 'Motion: ${m.group}#0';
				}
			}
			return true;
		}

		return false;
		}

		override public function update(elapsed:Float)
	{
		super.update(elapsed);

		// Model switching
		if (FlxG.keys.justPressed.LEFT)
		{
			currentModelIndex--;
			if (currentModelIndex < 0) currentModelIndex = modelList.length - 1;
			loadModel(currentModelIndex);
		}
		if (FlxG.keys.justPressed.RIGHT)
		{
			currentModelIndex++;
			if (currentModelIndex >= modelList.length) currentModelIndex = 0;
			loadModel(currentModelIndex);
		}

		if (l2d == null || l2d.model.isNull()) return;

		// Handle menu number key selection first
		#if FLX_KEYBOARD
		var menuKey = -1;
		if (FlxG.keys.justPressed.ZERO || FlxG.keys.justPressed.NUMPADZERO) menuKey = 0;
		if (FlxG.keys.justPressed.ONE || FlxG.keys.justPressed.NUMPADONE) menuKey = 1;
		if (FlxG.keys.justPressed.TWO || FlxG.keys.justPressed.NUMPADTWO) menuKey = 2;
		if (FlxG.keys.justPressed.THREE || FlxG.keys.justPressed.NUMPADTHREE) menuKey = 3;
		if (FlxG.keys.justPressed.FOUR || FlxG.keys.justPressed.NUMPADFOUR) menuKey = 4;
		if (FlxG.keys.justPressed.FIVE || FlxG.keys.justPressed.NUMPADFIVE) menuKey = 5;
		if (FlxG.keys.justPressed.SIX || FlxG.keys.justPressed.NUMPADSIX) menuKey = 6;
		if (FlxG.keys.justPressed.SEVEN || FlxG.keys.justPressed.NUMPADSEVEN) menuKey = 7;
		if (FlxG.keys.justPressed.EIGHT || FlxG.keys.justPressed.NUMPADEIGHT) menuKey = 8;
		if (FlxG.keys.justPressed.NINE || FlxG.keys.justPressed.NUMPADNINE) menuKey = 9;
		if (menuKey >= 0)
		{
			if (expressionMenuOpen || motionMenuOpen || motionIndexPendingOpen)
			{
				menuKeyBuffer += Std.string(menuKey);
				menuKeyBufferTime = 0;
				updateMenuKeyBufferStatus();
			}
		}
		if (FlxG.keys.justPressed.G)
		{
			perfPanel.enabled = !perfPanel.enabled;
			if (perfPanel.enabled)
			{
				perfPanel.visible = true;
				statusText.text = 'Perf panel: ON';
			}
			else
			{
				perfPanel.visible = false;
				statusText.text = 'Perf panel: OFF';
			}
		}
		#end

		var mx = FlxG.mouse.x;
		var my = FlxG.mouse.y;
		var ctrlDown = FlxG.keys.pressed.CONTROL;

		// Ctrl + press: begin dragging model position
		if (FlxG.mouse.justPressed && ctrlDown)
		{
			dragging = true;
			dragOffset.set(l2d.x - mx, l2d.y - my);
		}
		if (dragging && FlxG.mouse.pressed)
		{
			l2d.x = dragOffset.x + mx;
			l2d.y = dragOffset.y + my;
		}
		if (FlxG.mouse.justReleased)
		{
			dragging = false;
		}

		// Eye tracking
		if (FlxG.mouse.pressed && !ctrlDown)
		{
			lookAt.setTarget(mx, my);
		}
		else
		{
			lookAt.release();
		}

		// Click (no Ctrl): hit test
		if (FlxG.mouse.justPressed && !ctrlDown)
		{
			if (currentHitAreas.length > 0 && dispatcher.hitTestAreas(currentHitAreas, mx, my))
			{
				if (currentTapBodyGroup != null)
				{
					motionQueue.enqueue(currentTapBodyGroup, 0, 3);
				}
			}
		}

		// Mouse wheel: scale
		if (FlxG.mouse.wheel != 0)
		{
			var s = l2d.scale;
			s += FlxG.mouse.wheel * (6 * (FlxG.keys.pressed.SHIFT ? 3 : 1));
			if (s < (FlxG.height * 0.8) / l2d.modelHeight) s = (FlxG.height * 0.8) / l2d.modelHeight;
			l2d.scale = s;
			statusText.text = 'Model: $currentModelName | Scale: ${l2d.scale:.1f}';
		}

		// Keyboard actions
		#if FLX_KEYBOARD
		// Handle menu key buffer timeout
		if (menuKeyBuffer != "" && (expressionMenuOpen || motionMenuOpen || motionIndexPendingOpen))
		{
			menuKeyBufferTime += elapsed;
			if (menuKeyBufferTime >= MENU_KEY_TIMEOUT)
			{
				var num = Std.parseInt(menuKeyBuffer);
				menuKeyBuffer = "";
				if (num != null) handleMenuKey(num);
			}
		}
		else if (menuKeyBuffer != "")
		{
			menuKeyBuffer = ""; // menu closed while buffering
		}

		if (FlxG.keys.justPressed.E)
		{
			motionIndexPendingOpen = false;
			motionIndexPendingGroup = null;
			menuKeyBuffer = "";
			if (expressionMenuOpen)
			{
				expressionMenuOpen = false;
				statusText.text = 'Model: $currentModelName | Scale: ${l2d.scale:.1f}';
			}
			else
			{
				showExpressionMenu();
			}
		}
		if (FlxG.keys.justPressed.M)
		{
			motionIndexPendingOpen = false;
			motionIndexPendingGroup = null;
			menuKeyBuffer = "";
			if (motionMenuOpen)
			{
				motionMenuOpen = false;
				statusText.text = 'Model: $currentModelName | Scale: ${l2d.scale:.1f}';
			}
			else
			{
				showMotionMenu();
			}
		}
		if (FlxG.keys.justPressed.B)
			{
				l2d.core.setBreathEnabled(!l2d.core.breathEnabled);
				statusText.text = 'Breath: ${l2d.core.breathEnabled}';
			}
		if (FlxG.keys.justPressed.P)
		{
			l2d.core.setPhysicsEnabled(!l2d.core.physicsEnabled);
			statusText.text = 'Physics: ${l2d.core.physicsEnabled}';
		}
		// Physics tuner shortcuts (Y=gravity, W=wind, R=reset, S=stabilize)
		if (physicsTuner != null && physicsTuner.isLoaded)
		{
			if (FlxG.keys.justPressed.Y)
			{
				var g = physicsTuner.gravityY;
				if (g >= -1.1) physicsTuner.setGravity(0, -2);
				else if (g >= -1.6) physicsTuner.setGravity(0, -0.5);
				else physicsTuner.setGravity(0, -1);
				statusText.text = 'Gravity: (${physicsTuner.gravityX}, ${physicsTuner.gravityY})';
			}
			if (FlxG.keys.justPressed.W)
			{
				var w = physicsTuner.windX;
				if (w < 0.1) physicsTuner.setWind(0.5, 0);
				else if (w < 0.6) physicsTuner.setWind(1, 0);
				else physicsTuner.setWind(0, 0);
				statusText.text = 'Wind: (${physicsTuner.windX}, ${physicsTuner.windY})';
			}
			if (FlxG.keys.justPressed.R)
			{
				physicsTuner.reset();
				statusText.text = 'Physics reset (gravity/wind to defaults)';
			}
			if (FlxG.keys.justPressed.S)
			{
				physicsTuner.stabilize();
				statusText.text = 'Physics stabilized';
			}
		}
		if (FlxG.keys.justPressed.T)
		{
			if (parts != null && parts.count > 0)
			{
				var p = parts.at(0);
				parts.tween(p.name, p.get() > 0.5 ? 0.0 : 1.0, 0.3);
				statusText.text = 'Part "${p.name}" -> ${p.get() > 0.5 ? "hide" : "show"}';
			}
		}
		if (FlxG.keys.justPressed.V)
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
			statusText.text = 'LipSync (synth): ${lipSync.enabled ? "ON" : "OFF"}';
		}
		#end

		// Update extensions BEFORE native update
			if (motionQueue != null) motionQueue.update(elapsed);
		if (lookAt != null) lookAt.update(elapsed);
		if (parts != null) parts.update(elapsed);
		if (lipSync != null && lipSync.enabled) lipSync.update(elapsed);

		if (perfPanel != null) perfPanel.update(elapsed);

		L2DFlixelManager.updateAll(elapsed);
		L2DFlixelManager.renderAll();
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

	override public function destroy()
	{
		if (l2d != null && l2d.getSprite() != null)
		{
			FlxG.removeChild(l2d.getSprite());
		}
		L2DFlixelManager.destroyAll();
		L2DFlixelManager.clearTextureCache();
		FlxG.mouse.visible = false;
		super.destroy();
	}
}
