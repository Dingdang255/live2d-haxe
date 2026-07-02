package live2d.cubism;

/**
 * L2DModel type
 * Stores C-side model pointer as cpp.Int64 (intptr_t)
 * Use 0 for null (primitive type can't be null on static platforms)
 */
abstract L2DModel(cpp.Int64) from cpp.Int64 to cpp.Int64
{
    public inline function new(v:cpp.Int64) this = v;

    @:from public static inline function fromInt(v:Int):L2DModel
        return new L2DModel(cast v);

    public inline function isNull():Bool return this == 0;
    public inline function notNull():Bool return this != 0;
    public inline function toInt():Int return cast this;

    // 0 replaces null for static platforms
    public static inline var NULL:L2DModel = cast 0;
}
