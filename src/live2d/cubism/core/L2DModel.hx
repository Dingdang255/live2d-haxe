package live2d.cubism.core;

#if cpp

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

#elseif hl

/**
 * L2DModel type (HashLink target)
 * Stores C-side model pointer as hl.I64 (int64_t via .hdll FFI)
 * Use 0 for null — symmetric with cpp target
 */
abstract L2DModel(hl.I64) from hl.I64 to hl.I64
{
    public inline function new(v:hl.I64) this = v;

    @:from public static inline function fromInt(v:Int):L2DModel
        return new L2DModel(cast v);

    public inline function isNull():Bool return this == cast 0;
    public inline function notNull():Bool return this != cast 0;
    public inline function toInt():Int return cast this;

    public static inline var NULL:L2DModel = cast 0;
}

#end
