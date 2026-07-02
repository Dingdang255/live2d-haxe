package live2d.cubism;

import flixel.FlxBasic;
import flixel.graphics.FlxGraphic;
import openfl.display.Graphics;
import openfl.display.Sprite;
import openfl.geom.Matrix;
import openfl.Vector;
import haxe.io.Bytes;
import openfl.display.BitmapData;

/**
 * Live2D Render Component
 * Uses per-drawable Sprites for proper opacity and masking support
 *
 * Usage:
 *   var model = new L2DComponent('assets/live2d/Haru/', 'Haru.model3.json');
 *   add(model);
 *   // In your state's update():
 *   model.update(elapsed);
 *   // In your state's draw():
 *   model.render();
 */
class L2DComponent extends FlxBasic
{
    public var model:L2DModel = L2DModel.NULL;
    public var modelDir(default, null):String;
    public var modelFileName(default, null):String;

    var textures:Array<FlxGraphic> = [];
    var time:Float = 0;

    // Render parameters
    public var x:Float = 0;
    public var y:Float = 0;
    public var scale:Float = 1.0;
    public var alpha:Float = 1.0;

    // Model bounds (computed from all drawables)
    var modelCenterX:Float = 0;
    var modelCenterY:Float = 0;
    public var modelWidth:Float = 1;
    public var modelHeight:Float = 1;

    // Cached buffers (avoid alloc each frame)
    var vertexBuffers:Array<Bytes> = [];
    var uvBuffers:Array<Bytes> = [];
    var indexBuffers:Array<Bytes> = [];

    // Per-drawable Sprites for opacity support
    var drawableSprites:Array<Sprite> = [];
    // Mask Sprites (one per drawable that has masks, null otherwise)
    var maskSprites:Array<Sprite> = [];
    var containerSprite:Sprite;

    // Static flag to prevent double init
    static var frameworkInitialized:Bool = false;

    // Prevent double destroy
    var destroyed:Bool = false;

    // Whether this component owns its textures (if false, cache manages them)
    var ownsTextures:Bool = true;

    // First frame debug flag
    var firstFrame:Bool = true;

    /**
     * Load texture from file (can be overridden for caching)
     */
    function loadTexture(fullPath:String):FlxGraphic
    {
        #if sys
        var bmpData = BitmapData.fromFile(fullPath);
        if (bmpData != null)
        {
            return FlxGraphic.fromBitmapData(bmpData, false, fullPath, false);
        }
        #end
        return null;
    }

    public function new(dir:String, fileName:String)
    {
        super();
        modelDir = dir;
        modelFileName = fileName;

        trace('[L2D] Loading model from: $dir$fileName');

        // Initialize Framework (only once)
        if (!frameworkInitialized)
        {
            trace('[L2D] Initializing framework...');
            L2D.frameworkStartUp();
            frameworkInitialized = true;
            trace('[L2D] Framework initialized');
        }

        // Load model
        trace('[L2D] Calling loadModel...');
        model = L2D.loadModel(dir, fileName);

        if (model.isNull())
        {
            trace('[L2D] ERROR: Model is null after load!');
            return;
        }

        trace('[L2D] Model loaded, model pointer: $model');

        // Get texture count
        var texCount = L2D.getTextureCount(model);
        trace('[L2D] Texture count: $texCount');

        // Load textures (use cache if available)
        for (i in 0...texCount)
        {
            var texPath = L2D.getTexturePath(model, i);
            var fullPath = dir + texPath;
            trace('[L2D] Texture $i path: $fullPath');

            var graphic = loadTexture(fullPath);
            if (graphic != null)
            {
                textures.push(graphic);
                trace('[L2D] Texture $i loaded successfully');
            }
            else
            {
                trace('[L2D] ERROR: Failed to load texture: $fullPath');
            }
        }

        // Initialize buffer cache and compute model bounds
        var drawableCount = L2D.getDrawableCount(model);
        trace('[L2D] Drawable count: $drawableCount');

        vertexBuffers = [];
        uvBuffers = [];
        indexBuffers = [];

        // Compute model bounding box across all drawables
        var bMinX = 999999.0, bMaxX = -999999.0;
        var bMinY = 999999.0, bMaxY = -999999.0;

        // Also log mask info
        var maskedCount = 0;

        for (i in 0...drawableCount)
        {
            var vertCount = L2D.getDrawableVertexCount(model, i);
            var idxCount = L2D.getDrawableIndexCount(model, i);

            vertexBuffers.push(Bytes.alloc(vertCount * 2 * 4));
            uvBuffers.push(Bytes.alloc(vertCount * 2 * 4));
            indexBuffers.push(Bytes.alloc(idxCount * 2));

            // Sample vertices for bounding box
            if (vertCount > 0)
            {
                var testBuf = Bytes.alloc(vertCount * 2 * 4);
                L2D.getDrawableVertexPositions(model, i, testBuf);
                for (v in 0...vertCount)
                {
                    var vx = testBuf.getFloat(v * 8);
                    var vy = testBuf.getFloat(v * 8 + 4);
                    if (vx < bMinX) bMinX = vx;
                    if (vx > bMaxX) bMaxX = vx;
                    if (vy < bMinY) bMinY = vy;
                    if (vy > bMaxY) bMaxY = vy;
                }
            }

            // Check masks
            var maskCount = L2D.getDrawableMaskCount(model, i);
            if (maskCount > 0)
            {
                maskedCount++;
                var maskBuf = Bytes.alloc(maskCount * 4);
                L2D.getDrawableMasks(model, i, maskBuf);
                var maskIndices = [];
                for (mIdx in 0...maskCount) maskIndices.push(maskBuf.getInt32(mIdx * 4));
                if (maskedCount <= 5) // Only trace first few
                    trace('[L2D] Drawable $i has $maskCount masks: $maskIndices');
            }
        }

        modelCenterX = (bMinX + bMaxX) / 2;
        modelCenterY = (bMinY + bMaxY) / 2;
        modelWidth = bMaxX - bMinX;
        modelHeight = bMaxY - bMinY;

        trace('[L2D] Canvas size: ${L2D.getCanvasWidth(model)} x ${L2D.getCanvasHeight(model)}');
        trace('[L2D] Model bounds: X[$bMinX, $bMaxX], Y[$bMinY, $bMaxY]');
        trace('[L2D] Model center: ($modelCenterX, $modelCenterY), size: $modelWidth x $modelHeight');
        trace('[L2D] Drawables with masks: $maskedCount');

        // Create container and per-drawable Sprites
        containerSprite = new Sprite();
        for (i in 0...drawableCount)
        {
            var s = new Sprite();
            containerSprite.addChild(s);
            drawableSprites.push(s);
            maskSprites.push(null);
        }

        trace('[L2D] Component initialized successfully');
    }

    override function update(elapsed:Float):Void
    {
        super.update(elapsed);

        if (model.isNull()) return;

        time += elapsed;

        L2D.setDeltaTime(elapsed);
        L2D.update(model);
    }

    public function getSprite():Sprite
    {
        return containerSprite;
    }

    public function render():Void
    {
        if (model.isNull() || destroyed) return;

        var count = L2D.getDrawableCount(model);

        // Sort by renderOrder
        var order:Array<{idx:Int, order:Int}> = [];
        for (i in 0...count)
        {
            if (L2D.isDrawableVisible(model, i))
            {
                order.push({idx: i, order: L2D.getDrawableRenderOrder(model, i)});
            }
        }
        order.sort(function(a, b) return a.order - b.order);

        if (firstFrame)
        {
            trace('[L2D] Rendering ${order.length} visible drawables out of $count');
        }

        // Hide all Sprites first
        for (i in 0...drawableSprites.length)
        {
            drawableSprites[i].visible = false;
        }

        // Clear all mask Sprites
        for (i in 0...maskSprites.length)
        {
            if (maskSprites[i] != null)
            {
                maskSprites[i].graphics.clear();
            }
        }

        // Draw visible drawables with masking
        for (item in order)
        {
            var sprite = drawableSprites[item.idx];
            sprite.visible = true;
            sprite.graphics.clear();
            drawDrawableToSprite(sprite, item.idx, firstFrame && item.idx == order[0].idx);

            // Handle masking
            var maskCount = L2D.getDrawableMaskCount(model, item.idx);
            if (maskCount > 0)
            {
                // Create mask Sprite if not yet created
                if (maskSprites[item.idx] == null)
                {
                    var ms = new Sprite();
                    containerSprite.addChild(ms);
                    maskSprites[item.idx] = ms;
                }

                var maskSprite = maskSprites[item.idx];
                maskSprite.graphics.clear();

                // Draw all mask shapes to the mask sprite
                var maskBuf = Bytes.alloc(maskCount * 4);
                L2D.getDrawableMasks(model, item.idx, maskBuf);
                for (mIdx in 0...maskCount)
                {
                    var maskIdx = maskBuf.getInt32(mIdx * 4);
                    drawMaskShape(maskSprite, maskIdx);
                }

                sprite.mask = maskSprite;
            }
            else
            {
                sprite.mask = null;
            }
        }

        // Reorder children: visible drawables first (by renderOrder), then invisible, then mask Sprites
        var targetIndex = 0;
        for (item in order)
        {
            containerSprite.setChildIndex(drawableSprites[item.idx], targetIndex++);
        }
        for (i in 0...drawableSprites.length)
        {
            if (!drawableSprites[i].visible)
            {
                containerSprite.setChildIndex(drawableSprites[i], targetIndex++);
            }
        }
        for (i in 0...maskSprites.length)
        {
            if (maskSprites[i] != null)
            {
                containerSprite.setChildIndex(maskSprites[i], targetIndex++);
            }
        }

        firstFrame = false;
    }

    /**
     * Draw a mask shape (from a mask drawable) to a Sprite's graphics
     * The shape defines the clipping region for masked drawables
     */
    function drawMaskShape(sprite:Sprite, maskDrawableIndex:Int):Void
    {
        var vertCount = L2D.getDrawableVertexCount(model, maskDrawableIndex);
        var idxCount = L2D.getDrawableIndexCount(model, maskDrawableIndex);
        if (vertCount == 0 || idxCount == 0) return;

        var vertBuf = Bytes.alloc(vertCount * 2 * 4);
        var idxBuf = Bytes.alloc(idxCount * 2);
        L2D.getDrawableVertexPositions(model, maskDrawableIndex, vertBuf);
        L2D.getDrawableIndices(model, maskDrawableIndex, idxBuf);

        var vertices = new Vector<Float>(vertCount * 2);
        var indices = new Vector<Int>(idxCount);

        for (v in 0...vertCount)
        {
            var vx = vertBuf.getFloat(v * 8);
            var vy = vertBuf.getFloat(v * 8 + 4);
            vertices[v * 2] = (vx - modelCenterX) * scale + x;
            vertices[v * 2 + 1] = -(vy - modelCenterY) * scale + y;
        }
        for (n in 0...idxCount)
        {
            indices[n] = idxBuf.getUInt16(n * 2);
        }

        var g = sprite.graphics;
        g.beginFill(0xFFFFFF);
        g.drawTriangles(vertices, indices);
        g.endFill();
    }

    function drawDrawableToSprite(sprite:Sprite, drawableIndex:Int, debugFirst:Bool = false):Void
    {
        if (drawableIndex >= vertexBuffers.length) return;

        var vertCount = L2D.getDrawableVertexCount(model, drawableIndex);
        var idxCount = L2D.getDrawableIndexCount(model, drawableIndex);

        if (vertCount == 0 || idxCount == 0) return;

        // Check opacity - skip nearly invisible drawables
        var opacity = L2D.getDrawableOpacity(model, drawableIndex) * alpha;
        if (opacity < 0.01) return;

        // Resize buffer if needed
        var needVertBytes = vertCount * 2 * 4;
        var needIdxBytes = idxCount * 2;

        if (vertexBuffers[drawableIndex].length < needVertBytes)
            vertexBuffers[drawableIndex] = Bytes.alloc(needVertBytes);
        if (uvBuffers[drawableIndex].length < needVertBytes)
            uvBuffers[drawableIndex] = Bytes.alloc(needVertBytes);
        if (indexBuffers[drawableIndex].length < needIdxBytes)
            indexBuffers[drawableIndex] = Bytes.alloc(needIdxBytes);

        // Get data from C++
        L2D.getDrawableVertexPositions(model, drawableIndex, vertexBuffers[drawableIndex]);
        L2D.getDrawableVertexUvs(model, drawableIndex, uvBuffers[drawableIndex]);
        L2D.getDrawableIndices(model, drawableIndex, indexBuffers[drawableIndex]);

        var texIdx = L2D.getDrawableTextureIndex(model, drawableIndex);

        // Set per-drawable alpha via Sprite
        sprite.alpha = opacity;

        var graphics = sprite.graphics;

        // Convert Bytes to openfl.Vector
        var vertices = new Vector<Float>(vertCount * 2);
        var uvtData = new Vector<Float>(vertCount * 2);
        var indices = new Vector<Int>(idxCount);

        var vertBuf = vertexBuffers[drawableIndex];
        var uvBuf = uvBuffers[drawableIndex];
        var idxBuf = indexBuffers[drawableIndex];

        for (v in 0...vertCount)
        {
            var vx = vertBuf.getFloat(v * 8);
            var vy = vertBuf.getFloat(v * 8 + 4);

            // Uniform coordinate transform:
            // Center on model center, apply scale, flip Y
            vertices[v * 2] = (vx - modelCenterX) * scale + x;
            vertices[v * 2 + 1] = -(vy - modelCenterY) * scale + y;

            // Debug output
            if (debugFirst && v == 0)
            {
                trace('[L2D] First vertex: raw ($vx, $vy) -> screen (${vertices[0]}, ${vertices[1]})');
                trace('[L2D] Model center: ($modelCenterX, $modelCenterY), Scale: $scale');
            }

            var u = uvBuf.getFloat(v * 8);
            var vt = uvBuf.getFloat(v * 8 + 4);
            uvtData[v * 2] = u;
            uvtData[v * 2 + 1] = 1.0 - vt; // Flip UV.y
        }

        for (n in 0...idxCount)
        {
            indices[n] = idxBuf.getUInt16(n * 2);
        }

        // Get texture
        var texture:FlxGraphic = null;
        if (texIdx >= 0 && texIdx < textures.length)
        {
            texture = textures[texIdx];
        }

        // Draw using Graphics.drawTriangles
        if (texture != null)
        {
            graphics.beginBitmapFill(texture.bitmap, null, false, true);
        }
        else
        {
            graphics.beginFill(0xFFFFFF, 1.0);
        }

        graphics.drawTriangles(vertices, indices, uvtData);
        graphics.endFill();
    }

    override function destroy():Void
    {
        if (destroyed) return;
        destroyed = true;

        if (model.notNull())
        {
            L2D.releaseModel(model);
            model = L2DModel.NULL;
        }

        if (textures != null)
        {
            if (ownsTextures)
            {
                for (t in textures)
                {
                    if (t != null) t.destroy();
                }
            }
            textures = null;
        }

        if (containerSprite != null)
        {
            containerSprite.removeChildren();
            if (containerSprite.parent != null)
                containerSprite.parent.removeChild(containerSprite);
            containerSprite = null;
        }
        drawableSprites = null;
        maskSprites = null;

        vertexBuffers = null;
        uvBuffers = null;
        indexBuffers = null;

        super.destroy();
    }

    // ===== Convenience API =====

    public function startMotion(group:String, no:Int = 0, priority:Int = 2):cpp.Int64
    {
        if (model.isNull()) return -1;
        return L2D.startMotion(model, group, no, priority);
    }

    public function startIdleMotion():cpp.Int64
    {
        if (model.isNull()) return -1;
        return L2D.startRandomMotion(model, 'Idle', 1);
    }

    public function setExpression(id:String):Void
    {
        if (model.isNull()) return;
        L2D.setExpression(model, id);
    }

    public function setRandomExpression():Void
    {
        if (model.isNull()) return;
        L2D.setRandomExpression(model);
    }

    public function hitTest(areaName:String, px:Float, py:Float):Bool
    {
        if (model.isNull()) return false;
        return L2D.hitTest(model, areaName, px - x, py - y);
    }

    /**
     * Set dragging - converts screen coords to normalized model coords
     */
    public function setDragging(screenX:Float, screenY:Float):Void
    {
        if (model.isNull()) return;
        // Convert screen coords to model coords, then normalize to [-1, 1]
        var modelX = (screenX - x) / scale + modelCenterX;
        var modelY = -((screenY - y) / scale) + modelCenterY;
        // Normalize based on model bounds
        var normX = (modelX - modelCenterX) / (modelWidth / 2);
        var normY = (modelY - modelCenterY) / (modelHeight / 2);
        L2D.setDragging(model, normX, normY);
    }

    public function getCanvasWidth():Float
    {
        if (model.isNull()) return 0;
        return L2D.getCanvasWidth(model);
    }

    public function getCanvasHeight():Float
    {
        if (model.isNull()) return 0;
        return L2D.getCanvasHeight(model);
    }
}
