package;

/**
 * Aggregates @:build-generated compile-time constant classes for all demo
 * models. Each class below is generated from its model3.json by
 * L2DModelConstants.build(), exposing Motions/Expressions/HitAreas/Groups/
 * Textures as `public static var` fields with names checked at compile time.
 *
 * Usage from other modules:
 * ```haxe
 * import ModelConstants.*;
 * // Then: HaruModelConstants.HitAreas.Head, etc.
 * ```
 *
 * The empty `ModelConstants` class below is the module's main type (required
 * by Haxe so `import ModelConstants.*;` resolves the module path). The
 * generated per-model classes are sub-types of this module, which avoids
 * needing one .hx file per model.
 */
class ModelConstants {}

@:build(live2d.cubism.ext.L2DModelConstants.build("assets/live2d/Haru/Haru.model3.json"))
class HaruModelConstants {}

@:build(live2d.cubism.ext.L2DModelConstants.build("assets/live2d/Hiyori/Hiyori.model3.json"))
class HiyoriModelConstants {}

@:build(live2d.cubism.ext.L2DModelConstants.build("assets/live2d/Mao/Mao.model3.json"))
class MaoModelConstants {}

@:build(live2d.cubism.ext.L2DModelConstants.build("assets/live2d/Mark/Mark.model3.json"))
class MarkModelConstants {}

@:build(live2d.cubism.ext.L2DModelConstants.build("assets/live2d/Natori/Natori.model3.json"))
class NatoriModelConstants {}

@:build(live2d.cubism.ext.L2DModelConstants.build("assets/live2d/Rice/Rice.model3.json"))
class RiceModelConstants {}
