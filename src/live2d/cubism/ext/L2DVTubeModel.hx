package live2d.cubism.ext;

#if sys
import haxe.Json;
import sys.io.File;
import sys.FileSystem;
#end

using StringTools;

/**
 * Parser and adapter for VTube Studio model format (.vtube.json).
 *
 * VTube Studio models differ from standard Live2D Cubism models in several ways:
 * - Expressions and motions are standalone `.exp3.json` / `.motion3.json` files
 *   referenced from `.vtube.json` Hotkeys, NOT from `model3.json` FileReferences.
 * - `model3.json` typically has NO `FileReferences.Motions` or `FileReferences.Expressions`
 * - Expressions often control part opacities for costume/accessory toggling
 * - The `.vtube.json` specifies the model entry point, idle animation, and hotkey bindings
 *
 * Path resolution:
 * VTube Studio's `.vtube.json` Hotkey `File` field often contains only a file name
 * (e.g. `"scene01.motion3.json"`), even when the actual file is in a subdirectory
 * like `motion/` or `expressions/`. VTube Studio searches the model directory and
 * common subdirectories at runtime. This parser replicates that behavior by scanning
 * the model directory and known subdirectories (`expressions/`, `expr/`, `motions/`,
 * `motion/`, `animations/`, `animation/`) and resolving each `File` field to a path
 * relative to the model directory. The resolved path is what gets stored in the
 * `VTuberExpression.file` / `VTuberMotion.file` fields and `idleAnimation`.
 *
 * Usage:
 *   var vtube = new L2DVTuberModel("path/to/model.vtube.json");
 *   var modelEntry = vtube.modelEntry;       // "model.model3.json"
 *   var idle = vtube.idleAnimation;          // "motion/idle.motion3.json" or null
 *   var exprs = vtube.getExpressions();      // [{name, file, hotkeyId}, ...]
 *   var motions = vtube.getMotions();        // [{name, file, hotkeyId}, ...]
 *
 * After loading the model via L2DCore with the entry model3.json, use
 * `L2DCore.loadExpressionFile()` and `L2DCore.applyExpressionFile()` to
 * control VTuber expressions. For motions, pass `motion.file` directly to
 * `L2DMotionQueue.enqueueMotionFile()` — the native layer resolves it
 * relative to the model home directory.
 */
class L2DVTuberModel
{
	/** The model3.json entry file path (relative to vtube.json directory). */
	public var modelEntry(default, null):String;
	/** The idle animation file path (relative to vtube.json directory, subdirectory-resolved), or null. */
	public var idleAnimation(default, null):String;
	/** Model name from vtube.json. */
	public var modelName(default, null):String;
	/** Model ID from vtube.json. */
	public var modelID(default, null):String;
	/** Base directory containing the vtube.json file (with trailing slash). */
	public var baseDir(default, null):String;

	var _expressions:Array<VTuberExpression> = [];
	var _motions:Array<VTuberMotion> = [];

	/** Mapping from bare filename (e.g. "scene01.motion3.json") to relative path (e.g. "motion/scene01.motion3.json"). */
	var _fileMap:Map<String, String> = new Map();

	/** Subdirectories to scan for motion/expression files (in addition to the model root). */
	static var SCAN_SUBDIRS:Array<String> = [
		"",               // model root
		"expressions/",
		"expr/",
		"motions/",
		"motion/",
		"animations/",
		"animation/",
	];

	public function new(vtubeJsonPath:String)
	{
		#if sys
		// Extract base directory
		var lastSlash = vtubeJsonPath.lastIndexOf("/");
		var lastBackslash = vtubeJsonPath.lastIndexOf("\\");
		var sep = (lastSlash > lastBackslash) ? lastSlash : lastBackslash;
		baseDir = (sep >= 0) ? vtubeJsonPath.substr(0, sep + 1) : "";
		modelName = "Unknown";

		try
		{
			var content = File.getContent(vtubeJsonPath);
			var json:Dynamic = Json.parse(content);

			modelName = Reflect.hasField(json, "Name") ? json.Name : "Unknown";
			modelID = Reflect.hasField(json, "ModelID") ? json.ModelID : "";

			// Build file map before resolving any File fields
			buildFileMap();

			// FileReferences
			if (json.FileReferences != null)
			{
				if (json.FileReferences.Model != null && json.FileReferences.Model != "")
					modelEntry = json.FileReferences.Model;
				if (json.FileReferences.IdleAnimation != null && json.FileReferences.IdleAnimation != "")
					idleAnimation = resolveFilePath(json.FileReferences.IdleAnimation);
			}

			// Hotkeys
			if (json.Hotkeys != null)
			{
				for (hk in cast(json.Hotkeys, Array<Dynamic>))
				{
					var action:String = hk.Action;
					var file:String = hk.File;
					var name:String = Reflect.hasField(hk, "Name") ? hk.Name : "";
					var hotkeyId:String = Reflect.hasField(hk, "HotkeyID") ? hk.HotkeyID : "";

					if (action == null) continue;

					switch (action)
					{
						case "ToggleExpression":
						if (file != null && file != "")
						{
							var resolved = resolveFilePath(file);
							_expressions.push({
								name: (name != "") ? name : stripFileExtension(resolved),
								file: resolved,
								hotkeyId: hotkeyId
							});
						}

					case "TriggerAnimation":
						if (file != null && file != "")
						{
							var resolved = resolveFilePath(file);
							_motions.push({
								name: (name != "") ? name : stripFileExtension(resolved),
								file: resolved,
								hotkeyId: hotkeyId
							});
						}

						// Skip: RemoveAllExpressions, ArtMeshColorPreset, etc.
						default:
					}
				}
			}
		}
		catch (e:Dynamic)
		{
			trace('[L2DVTuberModel] Failed to parse: $vtubeJsonPath ($e)');
			modelEntry = null;
		}
		#else
		modelEntry = null;
		baseDir = "";
		#end
	}

	/**
	 * Scan the model directory and known subdirectories for `.exp3.json` and
	 * `.motion3.json` files, building a map from bare filename to relative path
	 * (relative to baseDir). Used to resolve vtube.json `File` fields that only
	 * contain a filename.
	 */
	function buildFileMap():Void
	{
		#if sys
		for (sub in SCAN_SUBDIRS)
		{
			var dir = baseDir + sub;
			if (!FileSystem.exists(dir)) continue;
			try
			{
				var entries = FileSystem.readDirectory(dir);
				for (entry in entries)
				{
					// Only map motion/expression files (skip directories and unrelated files)
					if (entry.endsWith(".motion3.json") || entry.endsWith(".exp3.json"))
					{
						// First match wins: model root takes priority over subdirectories
						// because SCAN_SUBDIRS lists "" first.
						if (!_fileMap.exists(entry))
						{
							_fileMap.set(entry, sub + entry);
						}
					}
				}
			}
			catch (e:Dynamic) {}
		}
		#end
	}

	/**
	 * Resolve a vtube.json `File` field to a path relative to baseDir.
	 *
	 * - If the field already contains a path separator (`/` or `\`), it is
	 *   treated as already relative to the model directory and returned as-is.
	 * - Otherwise, look up the bare filename in `_fileMap` and return the
	 *   discovered relative path (e.g. `motion/scene01.motion3.json`).
	 * - If no match is found, return the original value so the downstream
	 *   caller can attempt a root-directory lookup (matching VTube Studio's
	 *   behavior of falling back to the model root).
	 */
	function resolveFilePath(file:String):String
	{
		if (file == null || file == "") return file;

		// Already contains a path separator → assume it's a relative path
		if (file.indexOf("/") >= 0 || file.indexOf("\\") >= 0)
			return file;

		// Bare filename → look up in map
		if (_fileMap.exists(file))
			return _fileMap.get(file);

		// Not found in any scanned directory → return as-is (let downstream try)
		return file;
	}

	/** Whether the vtube.json was successfully parsed. */
	public var isValid(get, never):Bool;
	function get_isValid():Bool return modelEntry != null;

	/** List of expressions (ToggleExpression hotkeys) with name, file path, and hotkey ID. */
	public function getExpressions():Array<VTuberExpression>
	{
		return _expressions.copy();
	}

	/** List of motions (TriggerAnimation hotkeys) with name, file path, and hotkey ID. */
	public function getMotions():Array<VTuberMotion>
	{
		return _motions.copy();
	}

	public function getExpressionCount():Int return _expressions.length;
	public function getMotionCount():Int return _motions.length;

	/** Strip file extension from a path (e.g. "tongue_out.exp3.json" -> "tongue_out"). */
	static function stripFileExtension(file:String):String
	{
		// Strip directory part first for nicer display names
		var baseName = file;
		var lastSlash = file.lastIndexOf("/");
		var lastBackslash = file.lastIndexOf("\\");
		var sep = (lastSlash > lastBackslash) ? lastSlash : lastBackslash;
		if (sep >= 0) baseName = file.substr(sep + 1);

		var dot = baseName.lastIndexOf(".");
		if (dot <= 0) return baseName;
		// Also strip known double extensions like ".exp3.json" or ".motion3.json"
		var prevDot = baseName.lastIndexOf(".", dot - 1);
		if (prevDot > 0)
		{
			var secondExt = baseName.substr(prevDot + 1, dot - prevDot - 1);
			if (secondExt == "exp3" || secondExt == "motion3")
				return baseName.substr(0, prevDot);
		}
		return baseName.substr(0, dot);
	}
}

/** A single expression entry from .vtube.json Hotkeys. */
typedef VTuberExpression =
{
	/** Display name (from Hotkey.Name, or file name if empty). */
	var name:String;
	/** Relative path to .exp3.json file (subdirectory-resolved). */
	var file:String;
	/** Hotkey ID for reference. */
	var hotkeyId:String;
}

/** A single motion entry from .vtube.json Hotkeys. */
typedef VTuberMotion =
{
	/** Display name (from Hotkey.Name, or file name if empty). */
	var name:String;
	/** Relative path to .motion3.json file (subdirectory-resolved). */
	var file:String;
	/** Hotkey ID for reference. */
	var hotkeyId:String;
}
