package live2d.cubism.backend;

/**
 * Renderer interface for Live2D model rendering.
 *
 * L2DCore computes "what to draw" (transformed vertices, UVs, indices,
 * blend modes, colors, masks) and calls IL2DRenderer to decide "how to draw".
 * All vertex data passed to draw methods is already in screen-space
 * coordinates with UV flipping applied.
 */
interface IL2DRenderer
{
    // ===== Texture management =====

    /** Load a texture from file path, return an opaque handle */
    function loadTexture(path:String):L2DTextureHandle;

    /** Destroy a previously loaded texture */
    function destroyTexture(tex:L2DTextureHandle):Void;

    // ===== Display object management =====

    /** Create the root container that holds all child display objects */
    function createContainer():L2DDisplayHandle;

    /** Destroy the container and all its children */
    function destroyContainer():Void;

    /** Create a reusable display object and add it to the container */
    function createDisplayObject():L2DDisplayHandle;

    /** Reset a display object to default state (clear graphics, reset alpha/blend/color/mask) */
    function resetDisplayObject(obj:L2DDisplayHandle):Void;

    /** Set display object visibility */
    function setVisible(obj:L2DDisplayHandle, visible:Bool):Void;

    /** Set display object opacity (0..1) */
    function setAlpha(obj:L2DDisplayHandle, alpha:Float):Void;

    /** Set blend mode using Live2D raw value (0=Normal, 1=AddCompatible, 2=MultiplyCompatible, 3=Add, 6=Multiply, 10=Screen) */
    function setBlendMode(obj:L2DDisplayHandle, blendValue:Int):Void;

    /** Set color transform with separate RGBA multipliers and offsets */
    function setColorTransform(obj:L2DDisplayHandle,
        mulR:Float, mulG:Float, mulB:Float, mulA:Float,
        addR:Float, addG:Float, addB:Float, addA:Float):Void;

    /** Reset color transform to identity (no tinting) */
    function resetColorTransform(obj:L2DDisplayHandle):Void;

    /** Set a mask display object on a target. When isInverted is true, the mask
        region is clipped OUT instead of IN (used for inverted mask groups). */
    function setMask(obj:L2DDisplayHandle, mask:L2DDisplayHandle, ?isInverted:Bool = false):Void;

    /** Remove mask from a display object */
    function clearMask(obj:L2DDisplayHandle):Void;

    /** Get the fallback mask RT texture for a mask display object.
        Returns null if no RT has been created for this object.
        Used by the shader path to bind pre-rendered mask RT as u_maskTexture. */
    function getFallbackMaskTexture(obj:L2DDisplayHandle):L2DTextureHandle;

    /** Set fallback mask RT dimensions computed from actual vertex AABB.
        Called by L2DCore.preRenderFallbackMasks() before rendering fallback mask shapes.
        Non-Heaps backends may ignore this. */
    function setFallbackMaskDimensions(minX:Float, minY:Float, width:Float, height:Float):Void;

    /** Whether this renderer supports GPU shader-based rendering (mask + color) */
    function supportsShaderMask():Bool;

    /** Render mask shapes to an offscreen texture, packing up to 3 groups into RGB channels */
    function renderMaskToBitmapData(
        maskShapes:Array<{groupIndex:Int, channelFlag:Array<Float>,
                          vertices:Array<Array<Float>>, indices:Array<Array<Int>>}>,
        width:Int, height:Int, offsetX:Float, offsetY:Float
    ):L2DTextureHandle;

    /** Draw textured triangles with unified shader (mask + color + opacity) */
    function drawShaderTexturedTriangles(obj:L2DDisplayHandle,
        texture:L2DTextureHandle,
        vertices:Array<Float>, uvs:Array<Float>, indices:Array<Int>,
        ?maskTexture:L2DTextureHandle,
        ?channelFlag:Array<Float>,
        ?maskOffset:Array<Float>, ?maskScale:Array<Float>,
        ?isInverted:Bool,
        ?mulColor:Array<Float>,
        ?scrColor:Array<Float>,
        ?opacity:Float):Void;

    // ===== Drawing =====

    /** Draw textured triangles onto a display object */
    function drawTexturedTriangles(obj:L2DDisplayHandle,
        texture:L2DTextureHandle,
        vertices:Array<Float>, uvs:Array<Float>, indices:Array<Int>):Void;

    /** Draw solid-color triangles onto a display object (used for mask shapes) */
    function drawSolidTriangles(obj:L2DDisplayHandle,
        vertices:Array<Float>, indices:Array<Int>):Void;

    // ===== Display list =====

    /** Set the z-order index of a child display object within the container */
    function setChildIndex(child:L2DDisplayHandle, index:Int):Void;

    /** Get a unique integer ID for a display object (for dirty tracking) */
    function getObjectId(obj:L2DDisplayHandle):Int;

    /** Get the root container display object */
    function getContainer():L2DDisplayHandle;
}
