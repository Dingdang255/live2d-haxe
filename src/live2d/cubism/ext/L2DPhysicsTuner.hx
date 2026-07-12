package live2d.cubism.ext;

#if sys
import haxe.Json;
import sys.io.File;
#end
import live2d.cubism.L2DCore;
import live2d.cubism.core.CubismAPI;

/**
 * Runtime physics parameter tuner for Live2D models.
 *
 * Parses a `.physics3.json` file to extract physics metadata and identify
 * which parameters are affected by the physics simulation. Provides
 * runtime control over physics strength, wind, and gravity — similar to
 * VTube Studio's PhysicsSettings panel.
 *
 * **Two layers of control:**
 *
 * 1. **Native physics options** (gravity/wind vectors) — applied directly
 *    to the SDK's `CubismPhysics` instance via `L2DCore.setPhysicsOptions`.
 *    This is the proper way to change gravity/wind at runtime; the pendulum
 *    simulation uses these vectors on every evaluation.
 *
 * 2. **Haxe-side strength blending** (`physicsStrength`) — since the SDK
 *    has no built-in "physics strength multiplier", we snapshot physics-
 *    affected parameter values before `core.update()`, then blend between
 *    pre/post values after the update. 0.0 = no physics, 1.0 = full.
 *
 * **Reset / Stabilize:**
 * - `reset()` — clears pendulum state and restores default gravity/wind.
 *   Useful after large parameter jumps to avoid residual oscillation.
 * - `stabilize()` — single-shot settle using current parameter values.
 *   Useful right after model load to avoid initial swing.
 *
 * Usage:
 * ```haxe
 * var tuner = new L2DPhysicsTuner();
 * tuner.attachTo(core, "path/to/model.physics3.json");
 * tuner.setGravity(0, -1.5);   // 150% gravity
 * tuner.setWind(0.3, 0);       // light horizontal wind
 * tuner.physicsStrength = 0.5; // 50% physics output
 *
 * // In update loop:
 * tuner.applyPreUpdate();
 * core.update(dt);
 * tuner.applyPostUpdate();
 * ```
 */
class L2DPhysicsTuner
{
	// ===== Parsed from physics3.json (metadata, read-only) =====

	/** Target FPS the physics simulation was authored for. */
	public var physicsFPS(default, null):Float = 60;
	/** Total number of input parameters in the physics system. */
	public var totalInputCount(default, null):Int = 0;
	/** Total number of output parameters in the physics system. */
	public var totalOutputCount(default, null):Int = 0;
	/** Gravity X component (from physics3.json Meta, initial value). */
	public var initialGravityX(default, null):Float = 0;
	/** Gravity Y component (from physics3.json Meta, initial value). */
	public var initialGravityY(default, null):Float = -1;
	/** Wind X component (from physics3.json Meta, initial value). */
	public var initialWindX(default, null):Float = 0;
	/** Wind Y component (from physics3.json Meta, initial value). */
	public var initialWindY(default, null):Float = 0;
	/** Number of physics settings (groups) in the model. */
	public var settingCount(default, null):Int = 0;
	/** Dictionary of physics setting names (Id → Name). */
	public var settingNames(default, null):Map<String, String>;

	// ===== Current tunable values (applied to native physics engine) =====

	/** Current gravity X applied to the physics engine. */
	public var gravityX(default, set):Float = 0;
	/** Current gravity Y applied to the physics engine. */
	public var gravityY(default, set):Float = -1;
	/** Current wind X applied to the physics engine. */
	public var windX(default, set):Float = 0;
	/** Current wind Y applied to the physics engine. */
	public var windY(default, set):Float = 0;

	/**
	 * Global physics strength multiplier (0.0 = no physics, 1.0 = full).
	 * Applied as a Haxe-side blend between pre-update and post-update
	 * parameter values, since the SDK has no native strength multiplier.
	 */
	public var physicsStrength:Float = 1.0;

	var core:L2DCore;
	var loaded:Bool = false;

	/** Indices of ALL parameters referenced by the physics system. */
	var allPhysicsParamIndices:Array<Int> = [];
	/** Pre-update snapshot of physics parameter values. */
	var preUpdateSnapshots:Array<Float> = [];

	public function new()
	{
		settingNames = new Map();
	}

	/**
	 * Parse the physics3.json file and attach to an L2DCore model.
	 * Must be called after the model is loaded (so parameter indices are resolvable).
	 * Reads the initial gravity/wind from the JSON and applies them to the native engine.
	 */
	public function attachTo(core:L2DCore, physicsJsonPath:String):Void
	{
		this.core = core;

		#if sys
		try
		{
			var content = File.getContent(physicsJsonPath);
			var json:Dynamic = Json.parse(content);

			// Meta section
			if (json.Meta != null)
			{
				var meta:Dynamic = json.Meta;
				if (meta.PhysicsSettingCount != null) settingCount = meta.PhysicsSettingCount;
				if (meta.TotalInputCount != null) totalInputCount = meta.TotalInputCount;
				if (meta.TotalOutputCount != null) totalOutputCount = meta.TotalOutputCount;
				if (meta.Fps != null && meta.Fps > 0) physicsFPS = meta.Fps;

				// Effective forces (initial values from JSON)
				if (meta.EffectiveForces != null)
				{
					if (meta.EffectiveForces.Gravity != null)
					{
						initialGravityX = meta.EffectiveForces.Gravity.X != null ? meta.EffectiveForces.Gravity.X : 0;
						initialGravityY = meta.EffectiveForces.Gravity.Y != null ? meta.EffectiveForces.Gravity.Y : -1;
					}
					if (meta.EffectiveForces.Wind != null)
					{
						initialWindX = meta.EffectiveForces.Wind.X != null ? meta.EffectiveForces.Wind.X : 0;
						initialWindY = meta.EffectiveForces.Wind.Y != null ? meta.EffectiveForces.Wind.Y : 0;
					}
				}

				// Physics dictionary (Id → Name mappings)
				if (meta.PhysicsDictionary != null)
				{
					for (entry in cast(meta.PhysicsDictionary, Array<Dynamic>))
					{
						if (entry.Id != null && entry.Name != null)
							settingNames.set(entry.Id, entry.Name);
					}
				}
			}

			// Collect all parameter IDs from PhysicsSettings
			var paramIdSet:Map<String, Bool> = new Map();
			if (json.PhysicsSettings != null)
			{
				for (setting in cast(json.PhysicsSettings, Array<Dynamic>))
				{
					// Input parameters
					if (setting.Input != null)
					{
						for (input in cast(setting.Input, Array<Dynamic>))
						{
							if (input.Source != null && input.Source.Id != null)
								paramIdSet.set(input.Source.Id, true);
						}
					}

					// Output parameters
					if (setting.Output != null)
					{
						for (output in cast(setting.Output, Array<Dynamic>))
						{
							if (output.Destination != null && output.Destination.Id != null)
								paramIdSet.set(output.Destination.Id, true);
						}
					}
				}
			}

			// Resolve parameter names to indices
			allPhysicsParamIndices = [];
			if (core != null && core.model.notNull())
			{
				for (paramId in paramIdSet.keys())
				{
					var idx = CubismAPI.findParameterIndex(core.model, paramId);
					if (idx >= 0)
						allPhysicsParamIndices.push(idx);
				}
			}

			preUpdateSnapshots = [];
			loaded = allPhysicsParamIndices.length > 0;

			// Initialize current values from JSON and apply to native engine
			gravityX = initialGravityX;
			gravityY = initialGravityY;
			windX = initialWindX;
			windY = initialWindY;
			applyOptionsToNative();

			trace('[L2DPhysicsTuner] Loaded: ${allPhysicsParamIndices.length} physics params, '
				+ 'FPS=$physicsFPS, settings=$settingCount, '
				+ 'gravity=($gravityX,$gravityY), wind=($windX,$windY)');
		}
		catch (e:Dynamic)
		{
			trace('[L2DPhysicsTuner] Failed to parse physics3.json: $e');
		}
		#end
	}

	/** Whether the physics tuner is loaded and ready. */
	public var isLoaded(get, never):Bool;
	inline function get_isLoaded():Bool return loaded;

	// ===== Setters: apply to native physics engine immediately =====

	function set_gravityX(v:Float):Float
	{
		gravityX = v;
		applyOptionsToNative();
		return v;
	}

	function set_gravityY(v:Float):Float
	{
		gravityY = v;
		applyOptionsToNative();
		return v;
	}

	function set_windX(v:Float):Float
	{
		windX = v;
		applyOptionsToNative();
		return v;
	}

	function set_windY(v:Float):Float
	{
		windY = v;
		applyOptionsToNative();
		return v;
	}

	/** Push current gravityX/Y/windX/Y to the native CubismPhysics instance. **/
	function applyOptionsToNative():Void
	{
		if (!loaded || core == null || core.model.isNull()) return;
		core.setPhysicsOptions(gravityX, gravityY, windX, windY);
	}

	/**
	 * Set gravity vector. Convenience wrapper for `gravityX`/`gravityY` setters.
	 * Default is (0, -1). Larger |Y| = stronger downward pull.
	 */
	public function setGravity(x:Float, y:Float):Void
	{
		// Assign to backing fields first to avoid redundant native calls,
		// then apply once. (Setters would each trigger applyOptionsToNative.)
		gravityX = x;
		gravityY = y;
		applyOptionsToNative();
	}

	/**
	 * Set wind vector. Convenience wrapper for `windX`/`windY` setters.
	 * Default is (0, 0). Wind pushes pendulum strands horizontally/vertically.
	 */
	public function setWind(x:Float, y:Float):Void
	{
		windX = x;
		windY = y;
		applyOptionsToNative();
	}

	/**
	 * Restore gravity/wind to the initial values parsed from physics3.json.
	 */
	public function resetOptionsToInitial():Void
	{
		setGravity(initialGravityX, initialGravityY);
		setWind(initialWindX, initialWindY);
	}

	/**
	 * Reset physics pendulum state and restore default gravity/wind options
	 * (SDK defaults: gravity=(0,-1), wind=(0,0)). This clears the pendulum
	 * strand positions and velocities, eliminating residual oscillation.
	 *
	 * Note: SDK `Reset()` also resets `_options` to defaults; if you want to
	 * keep custom gravity/wind, re-apply them after calling this.
	 */
	public function reset():Void
	{
		if (!loaded || core == null || core.model.isNull()) return;
		core.resetPhysics();
		// SDK Reset() restores defaults (0,-1,0,0); sync local state.
		gravityX = 0;
		gravityY = -1;
		windX = 0;
		windY = 0;
	}

	/**
	 * Stabilize physics with current parameter values (single-shot settle).
	 * Computes a steady-state for the pendulum so the model does not swing
	 * from initial conditions. Useful right after model load or after
	 * large parameter jumps.
	 */
	public function stabilize():Void
	{
		if (!loaded || core == null || core.model.isNull()) return;
		core.stabilizePhysics();
	}

	/**
	 * Call BEFORE `core.update(dt)` to snapshot physics parameter values
	 * for the post-update strength blend.
	 */
	public function applyPreUpdate():Void
	{
		if (!loaded || core == null || core.model.isNull()) return;

		// Snapshot current values for strength blending
		preUpdateSnapshots = [];
		for (idx in allPhysicsParamIndices)
		{
			preUpdateSnapshots.push(CubismAPI.getParameterValue(core.model, idx));
		}
	}

	/**
	 * Call AFTER `core.update(dt)` to blend physics output parameters
	 * based on `physicsStrength`.
	 */
	public function applyPostUpdate():Void
	{
		if (!loaded || core == null || core.model.isNull()) return;
		if (preUpdateSnapshots.length != allPhysicsParamIndices.length) return;

		// No-op when physicsStrength is exactly 1.0
		if (physicsStrength >= 0.999 && physicsStrength <= 1.001) return;

		var strength = physicsStrength;
		if (strength < 0) strength = 0;
		if (strength > 2) strength = 2;

		for (i in 0...allPhysicsParamIndices.length)
		{
			var idx = allPhysicsParamIndices[i];
			var preVal = preUpdateSnapshots[i];
			var postVal = CubismAPI.getParameterValue(core.model, idx);

			// Blend: interpolate between pre (no physics) and post (full physics)
			var blended = preVal + (postVal - preVal) * strength;
			CubismAPI.setParameterValue(core.model, idx, blended, 1.0);
		}
	}

	/** Detach from the model and clean up. */
	public function detach():Void
	{
		core = null;
		allPhysicsParamIndices = [];
		preUpdateSnapshots = [];
		loaded = false;
	}

	/**
	 * Get a human-readable summary of the physics configuration.
	 */
	public function getSummary():String
	{
		if (!loaded) return "Physics tuner not loaded.";
		var buf = new StringBuf();
		buf.add('Physics: ${allPhysicsParamIndices.length} params, FPS=$physicsFPS\n');
		buf.add('  Settings: $settingCount, In/Out: $totalInputCount/$totalOutputCount\n');
		buf.add('  Initial: gravity=($initialGravityX, $initialGravityY), wind=($initialWindX, $initialWindY)\n');
		buf.add('  Current: gravity=($gravityX, $gravityY), wind=($windX, $windY)\n');
		buf.add('  Strength: ${physicsStrength:.2f}');
		return buf.toString();
	}
}
