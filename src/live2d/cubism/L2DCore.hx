package live2d.cubism;

import haxe.io.Bytes;
import live2d.cubism.backend.IL2DRenderer;
import live2d.cubism.backend.L2DDisplayHandle;
import live2d.cubism.backend.L2DTextureHandle;
import live2d.cubism.core.ICubismBridge;
import live2d.cubism.core.L2DModel;

/**
 * Platform-independent core logic for Live2D model rendering.
 *
 * Manages model lifecycle, texture loading, vertex buffers,
 * batch building, mask grouping, and render orchestration.
 * All platform-specific rendering is delegated to IL2DRenderer.
 */
class L2DCore
{
    // Public state
    public var model:L2DModel = L2DModel.NULL;
    public var modelDir(default, null):String;
    public var modelFileName(default, null):String;
    public var x:Float = 0;
    public var y:Float = 0;
    public var scale:Float = 1.0;
    public var alpha:Float = 1.0;
    public var modelWidth:Float = 1;
    public var modelHeight:Float = 1;

    // Internal: dependencies
    var bridge:ICubismBridge;
    var renderer:IL2DRenderer;

    // Internal: textures
    var textures:Array<L2DTextureHandle> = [];
    public var ownsTextures:Bool = true;

    // Internal: vertex data buffers
    var vertexBuffers:Array<Bytes> = [];
    var uvBuffers:Array<Bytes> = [];
    var indexBuffers:Array<Bytes> = [];
    var colorBuf:Bytes;

    // Internal: model bounds
    var modelCenterX:Float = 0;
    var modelCenterY:Float = 0;

    // Internal: mask group pre-computation
    var drawableMaskGroupId:Array<Int>;
    var maskGroupMaskIndices:Array<Array<Int>>;

    // Internal: display object pools
    var batchDisplayObjs:Array<L2DDisplayHandle>;
    var maskDisplayObjs:Array<L2DDisplayHandle>;
    var drawableDisplayObjs:Array<L2DDisplayHandle>;
    static inline var BATCH_POOL_SIZE = 32;
    static inline var MASK_POOL_SIZE = 16;

    // Internal: batch description (SoA)
    var bTexIdx:Array<Int>;
    var bBlendVal:Array<Int>;
    var bMaskGroup:Array<Int>;
    var bIsBatchable:Array<Bool>;
    var bDrawables:Array<Int>;
    var bStart:Array<Int>;
    var bLen:Array<Int>;
    var bMinOrder:Array<Int>;
    var bDisplayObjRef:Array<L2DDisplayHandle>;
    var activeBatchCount:Int = 0;

    // Internal: state
    var destroyed:Bool = false;
    var firstFrame:Bool = true;

    static var frameworkInitialized:Bool = false;

    public function new(dir:String, fileName:String, bridge:ICubismBridge, renderer:IL2DRenderer)
    {
        this.bridge = bridge;
        this.renderer = renderer;

        modelDir = dir;
        modelFileName = fileName;

        trace('[L2D] Loading model from: $dir$fileName');

        if (!frameworkInitialized)
        {
            trace('[L2D] Initializing framework...');
            bridge.frameworkStartUp();
            frameworkInitialized = true;
            trace('[L2D] Framework initialized');
        }

        model = bridge.loadModel(dir, fileName);
        if (model.isNull())
        {
            trace('[L2D] ERROR: Model is null after load!');
            return;
        }

        // Load textures
        var texCount = bridge.getTextureCount(model);
        trace('[L2D] Texture count: $texCount');
        for (i in 0...texCount)
        {
            var texPath = bridge.getTexturePath(model, i);
            var fullPath = dir + texPath;
            var tex = renderer.loadTexture(fullPath);
            if (tex != null)
                textures.push(tex);
            else
                trace('[L2D] ERROR: Failed to load texture: $fullPath');
        }

        // Initialize per-drawable buffers and compute model bounds
        var drawableCount = bridge.getDrawableCount(model);
        trace('[L2D] Drawable count: $drawableCount');

        vertexBuffers = [];
        uvBuffers = [];
        indexBuffers = [];
        colorBuf = Bytes.alloc(4 * 4);

        var bMinX = 999999.0, bMaxX = -999999.0;
        var bMinY = 999999.0, bMaxY = -999999.0;

        for (i in 0...drawableCount)
        {
            var vertCount = bridge.getDrawableVertexCount(model, i);
            var idxCount = bridge.getDrawableIndexCount(model, i);

            vertexBuffers.push(Bytes.alloc(vertCount * 2 * 4));
            uvBuffers.push(Bytes.alloc(vertCount * 2 * 4));
            indexBuffers.push(Bytes.alloc(idxCount * 2));

            if (vertCount > 0)
            {
                var testBuf = Bytes.alloc(vertCount * 2 * 4);
                bridge.getDrawableVertexPositions(model, i, testBuf);
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

        // Create container and display object pools via renderer
        renderer.createContainer();

        batchDisplayObjs = [];
        for (i in 0...BATCH_POOL_SIZE)
        {
            batchDisplayObjs.push(renderer.createDisplayObject());
        }

        maskDisplayObjs = [];
        for (i in 0...MASK_POOL_SIZE)
        {
            maskDisplayObjs.push(renderer.createDisplayObject());
        }

        // Individual display objects: lazy-created, initially all null
        drawableDisplayObjs = [for (i in 0...drawableCount) null];

        // Pre-allocate batch description arrays
        bTexIdx = [for (i in 0...BATCH_POOL_SIZE + drawableCount) 0];
        bBlendVal = [for (i in 0...BATCH_POOL_SIZE + drawableCount) 0];
        bMaskGroup = [for (i in 0...BATCH_POOL_SIZE + drawableCount) -1];
        bIsBatchable = [for (i in 0...BATCH_POOL_SIZE + drawableCount) false];
        bDrawables = [for (i in 0...drawableCount * 2) 0];
        bStart = [for (i in 0...BATCH_POOL_SIZE + drawableCount) 0];
        bLen = [for (i in 0...BATCH_POOL_SIZE + drawableCount) 0];
        bMinOrder = [for (i in 0...BATCH_POOL_SIZE + drawableCount) 0];
        bDisplayObjRef = [for (i in 0...BATCH_POOL_SIZE + drawableCount) null];

        trace('[L2D] Core initialized successfully (batched mode)');
    }

    function precomputeMaskGroups(drawableCount:Int):Void
    {
        drawableMaskGroupId = [for (i in 0...drawableCount) -1];
        maskGroupMaskIndices = [];

        var signatureToGroup:Map<String, Int> = new Map();
        var nextGroupId = 0;

        for (i in 0...drawableCount)
        {
            var maskCount = bridge.getDrawableMaskCount(model, i);
            if (maskCount == 0) continue;

            var maskBuf = Bytes.alloc(maskCount * 4);
            bridge.getDrawableMasks(model, i, maskBuf);
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

    public function update(elapsed:Float):Void
    {
        if (model.isNull()) return;
        bridge.setDeltaTime(elapsed);
        bridge.update(model);
    }

    public function getContainer():L2DDisplayHandle
    {
        return renderer.getContainer();
    }

    // ===== Batch Building =====

    function buildBatches():Void
    {
        var count = bridge.getDrawableCount(model);
        activeBatchCount = 0;
        var totalDrawables = 0;

        // Collect visible drawables sorted by renderOrder
        var visibleList:Array<{idx:Int, order:Int}> = [];
        for (i in 0...count)
        {
            if (bridge.isDrawableVisible(model, i))
            {
                visibleList.push({idx: i, order: bridge.getDrawableRenderOrder(model, i)});
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
            var opacity = bridge.getDrawableOpacity(model, idx) * alpha;
            if (opacity < 0.01) continue;

            var texIdx = bridge.getDrawableTextureIndex(model, idx);
            var blendVal = bridge.getDrawableBlendMode(model, idx);
            var maskGroup = drawableMaskGroupId[idx];

            // Check default color
            bridge.getDrawableMultiplyColor(model, idx, colorBuf);
            var mulR = colorBuf.getFloat(0), mulG = colorBuf.getFloat(4), mulB = colorBuf.getFloat(8);
            bridge.getDrawableScreenColor(model, idx, colorBuf);
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
                && isBatchable;

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
                bDisplayObjRef[bi] = null;
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

    function renderBatchToDisplayObj(obj:L2DDisplayHandle, batchIdx:Int):Void
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
            totalVerts += bridge.getDrawableVertexCount(model, dIdx);
            totalIndices += bridge.getDrawableIndexCount(model, dIdx);
        }
        if (totalVerts == 0 || totalIndices == 0) return;

        // Fill merged arrays
        var vertices = new Array<Float>();
        vertices[totalVerts * 2 - 1] = 0;
        var uvs = new Array<Float>();
        uvs[totalVerts * 2 - 1] = 0;
        var indices = new Array<Int>();
        indices[totalIndices - 1] = 0;

        var vertexOffset = 0;
        var idxWritePos = 0;

        for (i in 0...len)
        {
            var dIdx = bDrawables[start + i];
            var vertCount = bridge.getDrawableVertexCount(model, dIdx);
            var idxCount = bridge.getDrawableIndexCount(model, dIdx);

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

            bridge.getDrawableVertexPositions(model, dIdx, vertexBuffers[dIdx]);
            bridge.getDrawableVertexUvs(model, dIdx, uvBuffers[dIdx]);
            bridge.getDrawableIndices(model, dIdx, indexBuffers[dIdx]);

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
                uvs[(vertexOffset + v) * 2] = u;
                uvs[(vertexOffset + v) * 2 + 1] = 1.0 - vt;
            }

            for (n in 0...idxCount)
            {
                indices[idxWritePos + n] = idxBuf.getUInt16(n * 2) + vertexOffset;
            }

            vertexOffset += vertCount;
            idxWritePos += idxCount;
        }

        // Draw merged triangles
        var texture:L2DTextureHandle = null;
        if (texIdx >= 0 && texIdx < textures.length)
            texture = textures[texIdx];

        renderer.drawTexturedTriangles(obj, texture, vertices, uvs, indices);
    }

    function drawDrawableToDisplayObj(obj:L2DDisplayHandle, drawableIndex:Int):Void
    {
        if (drawableIndex >= vertexBuffers.length) return;

        var vertCount = bridge.getDrawableVertexCount(model, drawableIndex);
        var idxCount = bridge.getDrawableIndexCount(model, drawableIndex);
        if (vertCount == 0 || idxCount == 0) return;

        var opacity = bridge.getDrawableOpacity(model, drawableIndex) * alpha;
        if (opacity < 0.01) return;

        var needVertBytes = vertCount * 2 * 4;
        var needIdxBytes = idxCount * 2;
        if (vertexBuffers[drawableIndex].length < needVertBytes)
            vertexBuffers[drawableIndex] = Bytes.alloc(needVertBytes);
        if (uvBuffers[drawableIndex].length < needVertBytes)
            uvBuffers[drawableIndex] = Bytes.alloc(needVertBytes);
        if (indexBuffers[drawableIndex].length < needIdxBytes)
            indexBuffers[drawableIndex] = Bytes.alloc(needIdxBytes);

        bridge.getDrawableVertexPositions(model, drawableIndex, vertexBuffers[drawableIndex]);
        bridge.getDrawableVertexUvs(model, drawableIndex, uvBuffers[drawableIndex]);
        bridge.getDrawableIndices(model, drawableIndex, indexBuffers[drawableIndex]);

        var texIdx = bridge.getDrawableTextureIndex(model, drawableIndex);

        renderer.setAlpha(obj, opacity);

        // ColorTransform
        bridge.getDrawableMultiplyColor(model, drawableIndex, colorBuf);
        var mulR = colorBuf.getFloat(0), mulG = colorBuf.getFloat(4), mulB = colorBuf.getFloat(8);
        bridge.getDrawableScreenColor(model, drawableIndex, colorBuf);
        var scrR = colorBuf.getFloat(0), scrG = colorBuf.getFloat(4), scrB = colorBuf.getFloat(8);
        var isDefaultColor = (mulR >= 0.999 && mulR <= 1.001)
            && (mulG >= 0.999 && mulG <= 1.001)
            && (mulB >= 0.999 && mulB <= 1.001)
            && (scrR >= -0.001 && scrR <= 0.001)
            && (scrG >= -0.001 && scrG <= 0.001)
            && (scrB >= -0.001 && scrB <= 0.001);

        if (isDefaultColor)
            renderer.resetColorTransform(obj);
        else
            renderer.setColorTransform(obj,
                mulR - scrR, mulG - scrG, mulB - scrB, 1.0,
                scrR * 255.0, scrG * 255.0, scrB * 255.0, 0.0
            );

        renderer.setBlendMode(obj, bridge.getDrawableBlendMode(model, drawableIndex));

        var vertices = new Array<Float>();
        vertices[vertCount * 2 - 1] = 0;
        var uvArr = new Array<Float>();
        uvArr[vertCount * 2 - 1] = 0;
        var idxArr = new Array<Int>();
        idxArr[idxCount - 1] = 0;

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
            uvArr[v * 2] = u;
            uvArr[v * 2 + 1] = 1.0 - vt;
        }
        for (n in 0...idxCount)
        {
            idxArr[n] = idxBuf.getUInt16(n * 2);
        }

        var texture:L2DTextureHandle = null;
        if (texIdx >= 0 && texIdx < textures.length)
            texture = textures[texIdx];

        renderer.drawTexturedTriangles(obj, texture, vertices, uvArr, idxArr);
    }

    function drawMaskShape(obj:L2DDisplayHandle, maskDrawableIndex:Int):Void
    {
        var vertCount = bridge.getDrawableVertexCount(model, maskDrawableIndex);
        var idxCount = bridge.getDrawableIndexCount(model, maskDrawableIndex);
        if (vertCount == 0 || idxCount == 0) return;

        var vertBuf = Bytes.alloc(vertCount * 2 * 4);
        var idxBuf = Bytes.alloc(idxCount * 2);
        bridge.getDrawableVertexPositions(model, maskDrawableIndex, vertBuf);
        bridge.getDrawableIndices(model, maskDrawableIndex, idxBuf);

        var vertices = new Array<Float>();
        vertices[vertCount * 2 - 1] = 0;
        var indices = new Array<Int>();
        indices[idxCount - 1] = 0;

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

        renderer.drawSolidTriangles(obj, vertices, indices);
    }

    // ===== Main Render =====

    public function render():Void
    {
        if (model.isNull() || destroyed) return;

        // 1. Build batches
        buildBatches();

        // 2. Reset all display objects
        for (obj in batchDisplayObjs)
            renderer.resetDisplayObject(obj);
        for (obj in maskDisplayObjs)
            renderer.resetDisplayObject(obj);

        for (obj in drawableDisplayObjs)
        {
            if (obj != null)
                renderer.resetDisplayObject(obj);
        }

        // 3. Render each batch
        var batchObjUsed = 0;
        for (b in 0...activeBatchCount)
        {
            if (bIsBatchable[b])
            {
                var obj:L2DDisplayHandle = (batchObjUsed < BATCH_POOL_SIZE)
                    ? batchDisplayObjs[batchObjUsed]
                    : null;

                if (obj != null)
                {
                    renderer.setVisible(obj, true);
                    renderer.setAlpha(obj, 1.0);
                    renderer.setBlendMode(obj, bBlendVal[b]);
                    renderer.resetColorTransform(obj);
                    renderBatchToDisplayObj(obj, b);
                    bDisplayObjRef[b] = obj;
                    batchObjUsed++;
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
        renderMasks(batchObjUsed);

        // 5. Reorder display list
        reorderDisplayObjs(batchObjUsed);

        firstFrame = false;
    }

    function renderIndividualBatch(batchIdx:Int):Void
    {
        var start = bStart[batchIdx];
        var len = bLen[batchIdx];

        for (i in 0...len)
        {
            var dIdx = bDrawables[start + i];

            // Lazy-create individual display object
            if (drawableDisplayObjs[dIdx] == null)
            {
                drawableDisplayObjs[dIdx] = renderer.createDisplayObject();
            }

            var obj = drawableDisplayObjs[dIdx];
            renderer.setVisible(obj, true);
            drawDrawableToDisplayObj(obj, dIdx);
            bDisplayObjRef[batchIdx] = obj;
        }
    }

    function renderMasks(batchObjUsed:Int):Void
    {
        var maskObjUsed = 0;
        var maskGroupToPoolIdx:Map<Int, Int> = new Map();

        // For batched display objects with mask groups
        for (b in 0...activeBatchCount)
        {
            var mg = bMaskGroup[b];
            if (mg < 0) continue;

            var obj = bDisplayObjRef[b];
            if (obj == null) continue;

            var poolIdx;
            if (maskGroupToPoolIdx.exists(mg))
            {
                poolIdx = maskGroupToPoolIdx.get(mg);
            }
            else
            {
                if (maskObjUsed >= MASK_POOL_SIZE)
                {
                    renderer.clearMask(obj);
                    continue;
                }
                poolIdx = maskObjUsed;
                maskGroupToPoolIdx.set(mg, poolIdx);
                maskObjUsed++;

                // Draw mask shapes for this group
                var maskObj = maskDisplayObjs[poolIdx];
                renderer.setVisible(maskObj, true);
                for (maskDIdx in maskGroupMaskIndices[mg])
                {
                    drawMaskShape(maskObj, maskDIdx);
                }
            }

            renderer.setMask(obj, maskDisplayObjs[poolIdx]);
        }

        // For individual (non-batched) drawables with masks
        for (b in 0...activeBatchCount)
        {
            if (bIsBatchable[b]) continue;
            var mg = bMaskGroup[b];
            if (mg < 0) continue;

            var start = bStart[b];
            var len = bLen[b];
            for (i in 0...len)
            {
                var dIdx = bDrawables[start + i];
                var obj = drawableDisplayObjs[dIdx];
                if (obj == null) continue;

                var poolIdx = maskGroupToPoolIdx.exists(mg) ? maskGroupToPoolIdx.get(mg) : -1;
                if (poolIdx >= 0)
                    renderer.setMask(obj, maskDisplayObjs[poolIdx]);
            }
        }
    }

    function reorderDisplayObjs(batchObjUsed:Int):Void
    {
        var targetIndex = 0;

        // Build set of drawable indices that are visible this frame
        var visibleDrawableSet:Map<Int, Bool> = new Map();
        for (b in 0...activeBatchCount)
        {
            if (!bIsBatchable[b])
            {
                var start = bStart[b];
                var len = bLen[b];
                for (i in 0...len)
                    visibleDrawableSet.set(bDrawables[start + i], true);
            }
        }

        // Visible display objects in renderOrder
        for (b in 0...activeBatchCount)
        {
            if (bIsBatchable[b])
            {
                var obj = bDisplayObjRef[b];
                if (obj != null)
                    renderer.setChildIndex(obj, targetIndex++);
            }
            else
            {
                var start = bStart[b];
                var len = bLen[b];
                for (i in 0...len)
                {
                    var dIdx = bDrawables[start + i];
                    var obj = drawableDisplayObjs[dIdx];
                    if (obj != null)
                        renderer.setChildIndex(obj, targetIndex++);
                }
            }
        }

        // Hidden batch display objects (only unused pool objects)
        for (i in batchObjUsed...BATCH_POOL_SIZE)
        {
            renderer.setChildIndex(batchDisplayObjs[i], targetIndex++);
        }

        // Hidden individual display objects (not visible this frame)
        for (dIdx in 0...drawableDisplayObjs.length)
        {
            if (drawableDisplayObjs[dIdx] != null && !visibleDrawableSet.exists(dIdx))
                renderer.setChildIndex(drawableDisplayObjs[dIdx], targetIndex++);
        }

        // Mask display objects at the end
        for (obj in maskDisplayObjs)
        {
            renderer.setChildIndex(obj, targetIndex++);
        }
    }

    // ===== Destroy =====

    public function destroy():Void
    {
        if (destroyed) return;
        destroyed = true;

        if (model.notNull())
        {
            bridge.releaseModel(model);
            model = L2DModel.NULL;
        }

        if (textures != null)
        {
            if (ownsTextures)
            {
                for (t in textures)
                    if (t != null) renderer.destroyTexture(t);
            }
            textures = null;
        }

        renderer.destroyContainer();

        batchDisplayObjs = null;
        maskDisplayObjs = null;
        drawableDisplayObjs = null;
        vertexBuffers = null;
        uvBuffers = null;
        indexBuffers = null;
        colorBuf = null;
        drawableMaskGroupId = null;
        maskGroupMaskIndices = null;
    }

    // ===== Convenience API =====

    public function startMotion(group:String, no:Int = 0, priority:Int = 2):Int
    {
        if (model.isNull()) return -1;
        return bridge.startMotion(model, group, no, priority);
    }

    public function startIdleMotion():Int
    {
        if (model.isNull()) return -1;
        return bridge.startRandomMotion(model, 'Idle', 1);
    }

    public function setExpression(id:String):Void
    {
        if (model.isNull()) return;
        bridge.setExpression(model, id);
    }

    public function setRandomExpression():Void
    {
        if (model.isNull()) return;
        bridge.setRandomExpression(model);
    }

    public function hitTest(areaName:String, px:Float, py:Float):Bool
    {
        if (model.isNull()) return false;
        return bridge.hitTest(model, areaName, px - x, py - y);
    }

    public function setDragging(screenX:Float, screenY:Float):Void
    {
        if (model.isNull()) return;
        var modelX = (screenX - x) / scale + modelCenterX;
        var modelY = -((screenY - y) / scale) + modelCenterY;
        var normX = (modelX - modelCenterX) / (modelWidth / 2);
        var normY = (modelY - modelCenterY) / (modelHeight / 2);
        bridge.setDragging(model, normX, normY);
    }

    public function getCanvasWidth():Float
    {
        if (model.isNull()) return 0;
        return bridge.getCanvasWidth(model);
    }

    public function getCanvasHeight():Float
    {
        if (model.isNull()) return 0;
        return bridge.getCanvasHeight(model);
    }
}
