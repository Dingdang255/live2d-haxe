package;

/**
 * Aggregates @:build-generated compile-time constant classes for demo models.
 * Each class is generated from its model3.json by L2DModelConstants.build(),
 * exposing Motions/Expressions/HitAreas/Groups/Textures as `public static var`
 * fields with names checked at compile time.
 *
 * ## IMPORTANT: Import Syntax
 *
 * Do NOT use `import ModelConstants.*;` — the `.*` syntax imports all classes
 * in the *package* named `ModelConstants`, not the sub-types defined within
 * this file. That will fail with "Class not found" errors.
 *
 * Instead, import each model's constants class explicitly:
 *
 * ```haxe
 * import ModelConstants.HaruModelConstants;
 * import ModelConstants.HiyoriModelConstants;
 * import ModelConstants.MaoModelConstants;
 * // etc.
 * ```
 *
 * ## Usage Example
 *
 * ```haxe
 * import ModelConstants.HaruModelConstants;
 *
 * // Access compile-time constants:
 * trace(HaruModelConstants.HitAreas.Head);       // "Head"
 * trace(HaruModelConstants.Motions.TapBody);     // "TapBody"
 * trace(HaruModelConstants.Expressions[0]);      // first expression name
 * ```
 *
 * ## How to Add Your Model
 *
 * Uncomment and adjust the example below, replacing `YourModel` with your
 * actual model name and path:
 *
 * ```haxe
 * @:build(live2d.cubism.ext.L2DModelConstants.build("assets/live2d/YourModel/YourModel.model3.json"))
 * class YourModelConstants {}
 * ```
 */
class ModelConstants {}

// =============================================================================
// EXAMPLE: Uncomment and adjust for your model
// =============================================================================
//
// @:build(live2d.cubism.ext.L2DModelConstants.build("assets/live2d/YourModel/YourModel.model3.json"))
// class YourModelConstants {}
//
// =============================================================================
// DEVELOPMENT: Restore these lines when testing with official sample models
// =============================================================================
//
// @:build(live2d.cubism.ext.L2DModelConstants.build("assets/live2d/Haru/Haru.model3.json"))
// class HaruModelConstants {}
//
// @:build(live2d.cubism.ext.L2DModelConstants.build("assets/live2d/Hiyori/Hiyori.model3.json"))
// class HiyoriModelConstants {}
//
// @:build(live2d.cubism.ext.L2DModelConstants.build("assets/live2d/Mao/Mao.model3.json"))
// class MaoModelConstants {}
//
// @:build(live2d.cubism.ext.L2DModelConstants.build("assets/live2d/Mark/Mark.model3.json"))
// class MarkModelConstants {}
//
// @:build(live2d.cubism.ext.L2DModelConstants.build("assets/live2d/Natori/Natori.model3.json"))
// class NatoriModelConstants {}
//
// @:build(live2d.cubism.ext.L2DModelConstants.build("assets/live2d/Rice/Rice.model3.json"))
// class RiceModelConstants {}