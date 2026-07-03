package live2d.cubism;

import flixel.FlxBasic;
import flixel.graphics.FlxGraphic;
import openfl.display.Sprite;
import openfl.Vector;
import haxe.io.Bytes;
import openfl.display.BitmapData;
import openfl.display.BlendMode;
import openfl.display.TriangleCulling;
import openfl.geom.ColorTransform;

/**
 * Live2D Render Component
 * Batched rendering: consecutive drawables sharing the same state
 * (texture, blendMode, maskGroup, default color) are merged into
 * a single drawTriangles call to minimize GPU draw calls.
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

    // Model bounds
    var modelCenterX:Float = 0;
    var modelCenterY:Float = 0;
    public var modelWidth:Float = 1;
    public var modelHeight:Float = 1;

    // Per-drawable cached buffers
    var vertexBuffers:Array<Bytes> = [];
    var uvBuffers:Array<Bytes> = [];
    var indexBuffers:Array<Bytes> = [];
    var colorBuf:Bytes;

    // Mask group pre-computation (static, computed once in constructor)
    var drawableMaskGroupId:Array<Int>;        // -1 = no mask
    var maskGroupMaskIndices:Array<Array<Int>>; // mask drawable indices per group

    // Batch Sprite pools
    var batchSprites:Array<Sprite>;
    var batchMaskSprites:Array<Sprite>;
    static inline var BATCH_POOL_SIZE = 32;
    static inline var MASK_POOL_SIZE = 16;

    // Individual drawable Sprites (lazy-created for non-batchable drawables only)
    var drawableSprites:Array<Sprite>;

    var containerSprite:Sprite;

    // Batch description (SoA, pre-allocated to avoid GC)
    var bTexIdx:Array<Int>;
    var bBlendVal:Array<Int>;
    var bMaskGroup:Array<Int>;
    var bIsBatchable:Array<Bool>;  // true = can merge into one drawTriangles
    var bDrawables:Array<Int>;     // flat list of drawable indices
    var bStart:Array<Int>;         // start index in bDrawables per batch
    var bLen:Array<Int>;           // number of drawables per batch
    var bMinOrder:Array<Int>;      // minimum renderOrder in batch (for sorting)
    var bSpriteRef:Array<Sprite>;  // which Sprite this batch uses
    var activeBatchCount:Int = 0;

    // Static
    static var frameworkInitialized:Bool = false;
    static var defaultColorTransform:ColorTransform = new ColorTransform();

    // State
    var destroyed:Bool = false;
    var ownsTextures:Bool = true;
    var firstFrame:Bool = true;

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

        if (!frameworkInitialized)
        {
            trace('[L2D] Initializing framework...');
            L2D.frameworkStartUp();
            frameworkInitialized = true;
            trace('[L2D] Framework initialized');
        }

        model = L2D.loadModel(dir, fileName);
        if (model.isNull())
        {
            trace('[L2D] ERROR: Model is null after load!');
            return;
        }

        // Load textures
        var texCount = L2D.getTextureCount(model);
        trace('[L2D] Texture count: $texCount');
        for (i in 0...texCount)
        {
            var texPath = L2D.getTexturePath(model, i);
            var fullPath = dir + texPath;
            var graphic = loadTexture(fullPath);
            if (graphic != null)
                textures.push(graphic);
            else
                trace('[L2D] ERROR: Failed to load texture: $fullPath');
        }

        // Initialize per-drawable buffers and compute model bounds
        var drawableCount = L2D.getDrawableCount(model);
        trace('[L2D] Drawable count: $drawableCount');

        vertexBuffers = [];
        uvBuffers = [];
        indexBuffers = [];
        colorBuf = Bytes.alloc(4 * 4);

        var bMinX = 999999.0, bMaxX = -999999.0;
        var bMinY = 999999.0, bMaxY = -999999.0;

        for (i in 0...drawableCount)
        {
            var vertCount = L2D.getDrawableVertexCount(model, i);
            var idxCount = L2D.getDrawableIndexCount(model, i);

            vertexBuffers.push(Bytes.alloc(vertCount * 2 * 4));
            uvBuffers.push(Bytes.alloc(vertCount * 2 * 4));
            indexBuffers.push(Bytes.alloc(idxCount * 2));

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
        }

        modelCenterX = (bMinX + bMaxX) / 2;
        modelCenterY = (bMinY + bMaxY) / 2;
        modelWidth = bMaxX - bMinX;
        modelHeight = bMaxY - bMinY;
        trace('[L2D] Model center: ($modelCenterX, $modelCenterY), size: $modelWidth x $modelHeight');

        // Pre-compute mask groups
        precomputeMaskGroups(drawableCount);

        // Create container and Sprite pools
        containerSprite = new Sprite();

        batchSprites = [];
        for (i in 0...BATCH_POOL_SIZE)
        {
            var s = new Sprite();
            s.visible = false;
            containerSprite.addChild(s);
            batchSprites.push(s);
        }

        batchMaskSprites = [];
        for (i in 0...MASK_POOL_SIZE)
        {
            var ms = new Sprite();
            ms.visible = false;
            containerSprite.addChild(ms);
            batchMaskSprites.push(ms);
        }

        // Individual Sprites: lazy-created, initially all null
        drawableSprites = [for (i in 0...drawableCount) null];

        // Pre-allocate batch description arrays
        bTexIdx = [for (i in 0...BATCH_POOL_SIZE + drawableCount) 0];
        bBlendVal = [for (i in 0...BATCH_POOL_SIZE + drawableCount) 0];
        bMaskGroup = [for (i in 0...BATCH_POOL_SIZE + drawableCount) -1];
        bIsBatchable = [for (i in 0...BATCH_POOL_SIZE + drawableCount) false];
        bDrawables = [for (i in 0...drawableCount * 2) 0];
        bStart = [for (i in 0...BATCH_POOL_SIZE + drawableCount) 0];
        bLen = [for (i in 0...BATCH_POOL_SIZE + drawableCount) 0];
        bMinOrder = [for (i in 0...BATCH_POOL_SIZE + drawableCount) 0];
        bSpriteRef = [for (i in 0...BATCH_POOL_SIZE + drawableCount) null];

        trace('[L2D] Component initialized successfully (batched mode)');
    }

    function precomputeMaskGroups(drawableCount:Int):Void
    {
        drawableMaskGroupId = [for (i in 0...drawableCount) -1];
        maskGroupMaskIndices = [];

        var signatureToGroup:Map<String, Int> = new Map();
        var nextGroupId = 0;

        for (i in 0...drawableCount)
        {
            var maskCount = L2D.getDrawableMaskCount(model, i);
            if (maskCount == 0) continue;

            var maskBuf = Bytes.alloc(maskCount * 4);
            L2D.getDrawableMasks(model, i, maskBuf);
            var indices = [for (m in 0...maskCount) maskBuf.getInt32(m * 4)];
            indices.sort(function(a, b) return a - b);

            var sig = indices.join(',');
            var groupId;
            if (signatureToGroup.exists(sig))
            {
                groupId = signatureToGroup.get(sig);
            }
            else
            {
                groupId = nextGroupId++;
                signatureToGroup.set(sig, groupId);
                maskGroupMaskIndices.push(indices);
            }
            drawableMaskGroupId[i] = groupId;
        }

        trace('[L2D] Mask groups: $nextGroupId (from $drawableCount drawables)');
    }

    // ===== Update =====

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

    // ===== Batch Building =====

    function buildBatches():Void
    {
        var count = L2D.getDrawableCount(model);
        activeBatchCount = 0;
        var totalDrawables = 0;

        // Collect visible drawables sorted by renderOrder
        var visibleList:Array<{idx:Int, order:Int}> = [];
        for (i in 0...count)
        {
            if (L2D.isDrawableVisible(model, i))
            {
                visibleList.push({idx: i, order: L2D.getDrawableRenderOrder(model, i)});
            }
        }
        visibleList.sort(function(a, b) return a.order - b.order);

        // Scan sorted list, group consecutive drawables with same batch key
        var prevTexIdx = -999;
        var prevBlendVal = -999;
        var prevMaskGroup = -999;
        var prevIsBatchable = false;

        for (item in visibleList)
        {
            var idx = item.idx;

            // Skip nearly invisible
            var opacity = L2D.getDrawableOpacity(model, idx) * alpha;
            if (opacity < 0.01) continue;

            var texIdx = L2D.getDrawableTextureIndex(model, idx);
            var blendVal = L2D.getDrawableBlendMode(model, idx);
            var maskGroup = drawableMaskGroupId[idx];

            // Check default color
            L2D.getDrawableMultiplyColor(model, idx, colorBuf);
            var mulR = colorBuf.getFloat(0), mulG = colorBuf.getFloat(4), mulB = colorBuf.getFloat(8);
            L2D.getDrawableScreenColor(model, idx, colorBuf);
            var scrR = colorBuf.getFloat(0), scrG = colorBuf.getFloat(4), scrB = colorBuf.getFloat(8);
            var isDefaultColor = (mulR >= 0.999 && mulR <= 1.001)
                && (mulG >= 0.999 && mulG <= 1.001)
                && (mulB >= 0.999 && mulB <= 1.001)
                && (scrR >= -0.001 && scrR <= 0.001)
                && (scrG >= -0.001 && scrG <= 0.001)
                && (scrB >= -0.001 && scrB <= 0.001);

            var isFullOpacity = (opacity >= 0.99);
            var isBatchable = isDefaultColor && isFullOpacity;

            // Can extend current batch?
            var canExtend = (activeBatchCount > 0)
                && (texIdx == prevTexIdx)
                && (blendVal == prevBlendVal)
                && (maskGroup == prevMaskGroup)
                && (isBatchable == prevIsBatchable)
                && isBatchable; // only batchable drawables can merge

            if (canExtend)
            {
                bLen[activeBatchCount - 1]++;
                bDrawables[totalDrawables] = idx;
                totalDrawables++;
                if (item.order < bMinOrder[activeBatchCount - 1])
                    bMinOrder[activeBatchCount - 1] = item.order;
            }
            else
            {
                // Start new batch
                var bi = activeBatchCount;
                bTexIdx[bi] = texIdx;
                bBlendVal[bi] = blendVal;
                bMaskGroup[bi] = maskGroup;
                bIsBatchable[bi] = isBatchable;
                bStart[bi] = totalDrawables;
                bLen[bi] = 1;
                bMinOrder[bi] = item.order;
                bSpriteRef[bi] = null;
                bDrawables[totalDrawables] = idx;
                totalDrawables++;
                activeBatchCount++;
            }

            prevTexIdx = texIdx;
            prevBlendVal = blendVal;
            prevMaskGroup = maskGroup;
            prevIsBatchable = isBatchable;
        }

        if (firstFrame)
        {
            var batchedCount = 0;
            var individualCount = 0;
            for (b in 0...activeBatchCount)
            {
                if (bIsBatchable[b]) batchedCount += bLen[b];
                else individualCount += bLen[b];
            }
            trace('[L2D] Batches: $activeBatchCount (batched: $batchedCount, individual: $individualCount)');
        }
    }

    // ===== Rendering =====

    function blendModeFromValue(val:Int):BlendMode
    {
        return switch (val)
        {
            case 0: BlendMode.NORMAL;
            case 1: BlendMode.ADD;
            case 2: BlendMode.MULTIPLY;
            case 3: BlendMode.ADD;
            case 6: BlendMode.MULTIPLY;
            case 10: BlendMode.SCREEN;
            default: BlendMode.NORMAL;
        }
    }

    function renderBatchToSprite(sprite:Sprite, batchIdx:Int):Void
    {
        var start = bStart[batchIdx];
        var len = bLen[batchIdx];
        var texIdx = bTexIdx[batchIdx];

        // First pass: count total verts/indices
        var totalVerts = 0;
        var totalIndices = 0;
        for (i in 0...len)
        {
            var dIdx = bDrawables[start + i];
            totalVerts += L2D.getDrawableVertexCount(model, dIdx);
            totalIndices += L2D.getDrawableIndexCount(model, dIdx);
        }
        if (totalVerts == 0 || totalIndices == 0) return;

        // Create per-batch Vectors (OpenFL drawTriangles stores references, not copies)
        var vertices = new Vector<Float>(totalVerts * 2);
        var uvtData = new Vector<Float>(totalVerts * 2);
        var indices = new Vector<Int>(totalIndices);

        // Fill merged buffers
        var vertexOffset = 0;
        var idxWritePos = 0;

        for (i in 0...len)
        {
            var dIdx = bDrawables[start + i];
            var vertCount = L2D.getDrawableVertexCount(model, dIdx);
            var idxCount = L2D.getDrawableIndexCount(model, dIdx);

            if (vertCount == 0 || idxCount == 0) continue;

            // Resize per-drawable buffers if needed
            var needVertBytes = vertCount * 2 * 4;
            var needIdxBytes = idxCount * 2;
            if (vertexBuffers[dIdx].length < needVertBytes)
                vertexBuffers[dIdx] = Bytes.alloc(needVertBytes);
            if (uvBuffers[dIdx].length < needVertBytes)
                uvBuffers[dIdx] = Bytes.alloc(needVertBytes);
            if (indexBuffers[dIdx].length < needIdxBytes)
                indexBuffers[dIdx] = Bytes.alloc(needIdxBytes);

            L2D.getDrawableVertexPositions(model, dIdx, vertexBuffers[dIdx]);
            L2D.getDrawableVertexUvs(model, dIdx, uvBuffers[dIdx]);
            L2D.getDrawableIndices(model, dIdx, indexBuffers[dIdx]);

            var vertBuf = vertexBuffers[dIdx];
            var uvBuf = uvBuffers[dIdx];
            var idxBuf = indexBuffers[dIdx];

            for (v in 0...vertCount)
            {
                var vx = vertBuf.getFloat(v * 8);
                var vy = vertBuf.getFloat(v * 8 + 4);
                var u = uvBuf.getFloat(v * 8);
                var vt = uvBuf.getFloat(v * 8 + 4);

                vertices[(vertexOffset + v) * 2] = (vx - modelCenterX) * scale + x;
                vertices[(vertexOffset + v) * 2 + 1] = -(vy - modelCenterY) * scale + y;
                uvtData[(vertexOffset + v) * 2] = u;
                uvtData[(vertexOffset + v) * 2 + 1] = 1.0 - vt;
            }

            for (n in 0...idxCount)
            {
                indices[idxWritePos + n] = idxBuf.getUInt16(n * 2) + vertexOffset;
            }

            vertexOffset += vertCount;
            idxWritePos += idxCount;
        }

        // Draw merged triangles
        var texture:FlxGraphic = null;
        if (texIdx >= 0 && texIdx < textures.length)
            texture = textures[texIdx];

        var g = sprite.graphics;
        if (texture != null)
            g.beginBitmapFill(texture.bitmap, null, false, true);
        else
            g.beginFill(0xFFFFFF, 1.0);

        g.drawTriangles(vertices, indices, uvtData, NONE);
        g.endFill();
    }

    function drawDrawableToSprite(sprite:Sprite, drawableIndex:Int):Void
    {
        if (drawableIndex >= vertexBuffers.length) return;

        var vertCount = L2D.getDrawableVertexCount(model, drawableIndex);
        var idxCount = L2D.getDrawableIndexCount(model, drawableIndex);
        if (vertCount == 0 || idxCount == 0) return;

        var opacity = L2D.getDrawableOpacity(model, drawableIndex) * alpha;
        if (opacity < 0.01) return;

        var needVertBytes = vertCount * 2 * 4;
        var needIdxBytes = idxCount * 2;
        if (vertexBuffers[drawableIndex].length < needVertBytes)
            vertexBuffers[drawableIndex] = Bytes.alloc(needVertBytes);
        if (uvBuffers[drawableIndex].length < needVertBytes)
            uvBuffers[drawableIndex] = Bytes.alloc(needVertBytes);
        if (indexBuffers[drawableIndex].length < needIdxBytes)
            indexBuffers[drawableIndex] = Bytes.alloc(needIdxBytes);

        L2D.getDrawableVertexPositions(model, drawableIndex, vertexBuffers[drawableIndex]);
        L2D.getDrawableVertexUvs(model, drawableIndex, uvBuffers[drawableIndex]);
        L2D.getDrawableIndices(model, drawableIndex, indexBuffers[drawableIndex]);

        var texIdx = L2D.getDrawableTextureIndex(model, drawableIndex);

        sprite.alpha = opacity;

        // ColorTransform
        L2D.getDrawableMultiplyColor(model, drawableIndex, colorBuf);
        var mulR = colorBuf.getFloat(0), mulG = colorBuf.getFloat(4), mulB = colorBuf.getFloat(8);
        L2D.getDrawableScreenColor(model, drawableIndex, colorBuf);
        var scrR = colorBuf.getFloat(0), scrG = colorBuf.getFloat(4), scrB = colorBuf.getFloat(8);
        var isDefaultColor = (mulR >= 0.999 && mulR <= 1.001)
            && (mulG >= 0.999 && mulG <= 1.001)
            && (mulB >= 0.999 && mulB <= 1.001)
            && (scrR >= -0.001 && scrR <= 0.001)
            && (scrG >= -0.001 && scrG <= 0.001)
            && (scrB >= -0.001 && scrB <= 0.001);

        if (isDefaultColor)
            sprite.transform.colorTransform = defaultColorTransform;
        else
            sprite.transform.colorTransform = new ColorTransform(
                mulR - scrR, mulG - scrG, mulB - scrB, 1.0,
                scrR * 255.0, scrG * 255.0, scrB * 255.0, 0.0
            );

        sprite.blendMode = blendModeFromValue(L2D.getDrawableBlendMode(model, drawableIndex));

        var graphics = sprite.graphics;
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
            vertices[v * 2] = (vx - modelCenterX) * scale + x;
            vertices[v * 2 + 1] = -(vy - modelCenterY) * scale + y;

            var u = uvBuf.getFloat(v * 8);
            var vt = uvBuf.getFloat(v * 8 + 4);
            uvtData[v * 2] = u;
            uvtData[v * 2 + 1] = 1.0 - vt;
        }
        for (n in 0...idxCount)
        {
            indices[n] = idxBuf.getUInt16(n * 2);
        }

        var texture:FlxGraphic = null;
        if (texIdx >= 0 && texIdx < textures.length)
            texture = textures[texIdx];

        if (texture != null)
            graphics.beginBitmapFill(texture.bitmap, null, false, true);
        else
            graphics.beginFill(0xFFFFFF, 1.0);

        graphics.drawTriangles(vertices, indices, uvtData);
        graphics.endFill();
    }

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

    // ===== Main Render =====

    public function render():Void
    {
        if (model.isNull() || destroyed) return;

        // 1. Build batches
        buildBatches();

        // 2. Hide and reset all pool Sprites
        for (s in batchSprites)
        {
            s.visible = false;
            s.graphics.clear();
            s.alpha = 1.0;
            s.blendMode = BlendMode.NORMAL;
            s.transform.colorTransform = defaultColorTransform;
            s.mask = null;
        }
        for (s in batchMaskSprites)
        {
            s.visible = false;
            s.graphics.clear();
        }

        // Hide individual drawable Sprites
        for (s in drawableSprites)
        {
            if (s != null)
            {
                s.visible = false;
                s.graphics.clear();
                s.blendMode = BlendMode.NORMAL;
                s.transform.colorTransform = defaultColorTransform;
                s.mask = null;
            }
        }

        // 3. Render each batch
        var batchSpriteUsed = 0;
        for (b in 0...activeBatchCount)
        {
            if (bIsBatchable[b])
            {
                // Batched: use pool Sprite
                var sprite = (batchSpriteUsed < BATCH_POOL_SIZE)
                    ? batchSprites[batchSpriteUsed]
                    : null;

                if (sprite != null)
                {
                    sprite.visible = true;
                    sprite.alpha = 1.0;
                    sprite.blendMode = blendModeFromValue(bBlendVal[b]);
                    sprite.transform.colorTransform = defaultColorTransform;
                    renderBatchToSprite(sprite, b);
                    bSpriteRef[b] = sprite;
                    batchSpriteUsed++;
                }
                else
                {
                    // Pool exhausted: fall back to individual rendering
                    bIsBatchable[b] = false;
                    renderIndividualBatch(b);
                }
            }
            else
            {
                renderIndividualBatch(b);
            }
        }

        // 4. Apply masks
        renderMasks(batchSpriteUsed);

        // 5. Reorder children
        reorderChildren(batchSpriteUsed);

        firstFrame = false;
    }

    function renderIndividualBatch(batchIdx:Int):Void
    {
        var start = bStart[batchIdx];
        var len = bLen[batchIdx];

        for (i in 0...len)
        {
            var dIdx = bDrawables[start + i];

            // Lazy-create individual Sprite
            if (drawableSprites[dIdx] == null)
            {
                var s = new Sprite();
                containerSprite.addChild(s);
                drawableSprites[dIdx] = s;
            }

            var sprite = drawableSprites[dIdx];
            sprite.visible = true;
            sprite.graphics.clear();
            drawDrawableToSprite(sprite, dIdx);
            bSpriteRef[batchIdx] = sprite; // points to last individual sprite for this batch
        }
    }

    function renderMasks(batchSpriteUsed:Int):Void
    {
        // For batched Sprites with mask groups, set shared maskSprite
        var maskSpriteUsed = 0;
        var maskGroupToPoolIdx:Map<Int, Int> = new Map();

        for (b in 0...activeBatchCount)
        {
            var mg = bMaskGroup[b];
            if (mg < 0) continue; // no mask

            var sprite = bSpriteRef[b];
            if (sprite == null) continue;

            // Get or allocate a mask Sprite for this mask group
            var poolIdx;
            if (maskGroupToPoolIdx.exists(mg))
            {
                poolIdx = maskGroupToPoolIdx.get(mg);
            }
            else
            {
                if (maskSpriteUsed >= MASK_POOL_SIZE)
                {
                    // Pool exhausted, skip masking for remaining
                    sprite.mask = null;
                    continue;
                }
                poolIdx = maskSpriteUsed;
                maskGroupToPoolIdx.set(mg, poolIdx);
                maskSpriteUsed++;

                // Draw mask shapes for this group
                var maskSprite = batchMaskSprites[poolIdx];
                maskSprite.visible = true;
                maskSprite.graphics.clear();
                for (maskDIdx in maskGroupMaskIndices[mg])
                {
                    drawMaskShape(maskSprite, maskDIdx);
                }
            }

            sprite.mask = batchMaskSprites[poolIdx];
        }

        // For individual (non-batched) drawables with masks
        for (b in 0...activeBatchCount)
        {
            if (bIsBatchable[b]) continue; // already handled above
            var mg = bMaskGroup[b];
            if (mg < 0) continue;

            var start = bStart[b];
            var len = bLen[b];
            for (i in 0...len)
            {
                var dIdx = bDrawables[start + i];
                var sprite = drawableSprites[dIdx];
                if (sprite == null) continue;

                // Reuse the same mask Sprite for this mask group
                var poolIdx = maskGroupToPoolIdx.exists(mg) ? maskGroupToPoolIdx.get(mg) : -1;
                if (poolIdx >= 0)
                    sprite.mask = batchMaskSprites[poolIdx];
            }
        }
    }

    function reorderChildren(batchSpriteUsed:Int):Void
    {
        var targetIndex = 0;

        // Visible Sprites in renderOrder
        for (b in 0...activeBatchCount)
        {
            if (bIsBatchable[b])
            {
                var sprite = bSpriteRef[b];
                if (sprite != null && sprite.visible)
                    containerSprite.setChildIndex(sprite, targetIndex++);
            }
            else
            {
                var start = bStart[b];
                var len = bLen[b];
                for (i in 0...len)
                {
                    var dIdx = bDrawables[start + i];
                    var s = drawableSprites[dIdx];
                    if (s != null && s.visible)
                        containerSprite.setChildIndex(s, targetIndex++);
                }
            }
        }

        // Hidden batch Sprites
        for (i in 0...BATCH_POOL_SIZE)
        {
            if (!batchSprites[i].visible)
                containerSprite.setChildIndex(batchSprites[i], targetIndex++);
        }

        // Individual Sprites (hidden ones)
        for (s in drawableSprites)
        {
            if (s != null && !s.visible)
                containerSprite.setChildIndex(s, targetIndex++);
        }

        // Mask Sprites at the end
        for (s in batchMaskSprites)
        {
            containerSprite.setChildIndex(s, targetIndex++);
        }
    }

    // ===== Destroy =====

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
                    if (t != null) t.destroy();
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

        batchSprites = null;
        batchMaskSprites = null;
        drawableSprites = null;
        vertexBuffers = null;
        uvBuffers = null;
        indexBuffers = null;
        colorBuf = null;
        drawableMaskGroupId = null;
        maskGroupMaskIndices = null;

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

    public function setDragging(screenX:Float, screenY:Float):Void
    {
        if (model.isNull()) return;
        var modelX = (screenX - x) / scale + modelCenterX;
        var modelY = -((screenY - y) / scale) + modelCenterY;
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
