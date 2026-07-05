package live2d.cubism;

import haxe.io.Bytes;
import live2d.cubism.backend.IL2DRenderer;
import live2d.cubism.backend.L2DDisplayHandle;
import live2d.cubism.backend.L2DTextureHandle;
import live2d.cubism.core.CubismAPI;
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

    // Internal: cached static data (UVs and indices never change)
    var drawableCount:Int = 0;
    var cachedVertCounts:Array<Int>;
    var cachedIdxCounts:Array<Int>;
    var cachedUVs:Array<Array<Float>>;
    var cachedIndices:Array<Array<Int>>;
    var vertexDirty:Array<Bool>;
    var cachedPositions:Array<Array<Float>>;  // Cached vertex positions as Float arrays (avoids getFloat)

    // Reusable Maps (avoid new Map() every frame)
    var reusableMaskGroupMap:Map<Int, Int>;
    var reusableVisibleDrawableSet:Map<Int, Bool>;

    // Internal: batch metadata buffer (1 FFI call for all drawables)
    var metadataBuf:Bytes;
    static inline var METADATA_STRIDE = 48;

    // Internal: fillVertexData accumulators (avoid anonymous object allocation)
    var fvVertexOffset:Int = 0;
    var fvIdxWritePos:Int = 0;

    // Internal: model bounds
    var modelCenterX:Float = 0;
    var modelCenterY:Float = 0;

    // Internal: mask group pre-computation
    var drawableMaskGroupId:Array<Int>;
    var maskGroupMaskIndices:Array<Array<Int>>;

    // Internal: shader mask state
    var maskGroupChannelFlag:Array<Array<Float>>;
    var maskGroupIsInverted:Array<Bool>;
    var maskTextureDirty:Bool;
    var maskTextureHandle:L2DTextureHandle;
    var maskBitmapWidth:Int;
    var maskBitmapHeight:Int;
    var maskScreenOffsetX:Float;
    var maskScreenOffsetY:Float;
    var useShaderMask:Bool;

    // Internal: display object pools
    var batchDisplayObjs:Array<L2DDisplayHandle>;
    var maskDisplayObjs:Array<L2DDisplayHandle>;
    var drawableDisplayObjs:Array<L2DDisplayHandle>;
    static inline var BATCH_POOL_SIZE = 32;
    static inline var MASK_POOL_SIZE = 16;
    static inline var SHADER_MASK_MAX_GROUPS = 3;

    // Internal: batch description (SoA)
    var bTexIdx:Array<Int>;
    var bBlendVal:Array<Int>;
    var bMaskGroup:Array<Int>;
    var bIsBatchable:Array<Bool>;
    var bMulColor:Array<Array<Float>>;   // [R, G, B] per batch
    var bScrColor:Array<Array<Float>>;   // [R, G, B] per batch
    var bOpacity:Array<Float>;           // per batch
    var bDrawables:Array<Int>;
    var bStart:Array<Int>;
    var bLen:Array<Int>;
    var bMinOrder:Array<Int>;
    var bDisplayObjRef:Array<L2DDisplayHandle>;
    var activeBatchCount:Int = 0;

    // Dirty tracking for optimization
    var usedDisplayObjs:Map<Int, Bool>;
    var lastChildOrder:Array<Int>;

    // Reusable buffers for buildBatches (avoid GC pressure)
    var visibleList:Array<{idx:Int, order:Int}>;
    var reusableVerts:Array<Float>;
    var reusableUVs:Array<Float>;
    var reusableIndices:Array<Int>;

    // Internal: state
    var destroyed:Bool = false;
    var firstFrame:Bool = true;

    static var frameworkInitialized:Bool = false;

    // Static sort comparator (avoid closure allocation per frame)
    static var visibleListSorter = function(a:{idx:Int, order:Int}, b:{idx:Int, order:Int}):Int {
        return a.order - b.order;
    };

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
        drawableCount = bridge.getDrawableCount(model);
        trace('[L2D] Drawable count: $drawableCount');

        vertexBuffers = [];
        uvBuffers = [];
        indexBuffers = [];
        cachedVertCounts = [];
        cachedIdxCounts = [];
        cachedUVs = [];
        cachedIndices = [];
        vertexDirty = [];
        cachedPositions = [];

        reusableMaskGroupMap = new Map<Int, Int>();
        reusableVisibleDrawableSet = new Map<Int, Bool>();

        var bMinX = 999999.0, bMaxX = -999999.0;
        var bMinY = 999999.0, bMaxY = -999999.0;

        for (i in 0...drawableCount)
        {
            var vertCount = bridge.getDrawableVertexCount(model, i);
            var idxCount = bridge.getDrawableIndexCount(model, i);

            cachedVertCounts.push(vertCount);
            cachedIdxCounts.push(idxCount);
            vertexBuffers.push(Bytes.alloc(vertCount * 2 * 4));
            uvBuffers.push(Bytes.alloc(vertCount * 2 * 4));
            indexBuffers.push(Bytes.alloc(idxCount * 2));
            vertexDirty.push(true);

            // Cache positions (dynamic data, refreshed when dirty)
            var posArr = new Array<Float>();
            if (vertCount > 0)
            {
                var posBuf = Bytes.alloc(vertCount * 2 * 4);
                bridge.getDrawableVertexPositions(model, i, posBuf);
                for (v in 0...vertCount)
                {
                    posArr.push(posBuf.getFloat(v * 8));
                    posArr.push(posBuf.getFloat(v * 8 + 4));
                }
            }
            cachedPositions.push(posArr);

            // Cache UVs (static data)
            var uvArr = new Array<Float>();
            if (vertCount > 0)
            {
                var uvBuf = Bytes.alloc(vertCount * 2 * 4);
                bridge.getDrawableVertexUvs(model, i, uvBuf);
                for (v in 0...vertCount)
                {
                    uvArr.push(uvBuf.getFloat(v * 8));
                    uvArr.push(uvBuf.getFloat(v * 8 + 4));
                }
            }
            cachedUVs.push(uvArr);

            // Cache indices (static data)
            var idxArr = new Array<Int>();
            if (idxCount > 0)
            {
                var idxBuf = Bytes.alloc(idxCount * 2);
                bridge.getDrawableIndices(model, i, idxBuf);
                for (n in 0...idxCount)
                    idxArr.push(idxBuf.getUInt16(n * 2));
            }
            cachedIndices.push(idxArr);

            // Compute bounds from vertex positions
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

        // Pre-allocate batch metadata buffer
        metadataBuf = Bytes.alloc(drawableCount * METADATA_STRIDE);

        modelCenterX = (bMinX + bMaxX) / 2;
        modelCenterY = (bMinY + bMaxY) / 2;
        modelWidth = bMaxX - bMinX;
        modelHeight = bMaxY - bMinY;
        trace('[L2D] Model center: ($modelCenterX, $modelCenterY), size: $modelWidth x $modelHeight');

        // Pre-compute mask groups
        precomputeMaskGroups(drawableCount);

        // Determine mask rendering path
        useShaderMask = renderer.supportsShaderMask();
        maskTextureDirty = true;
        maskTextureHandle = null;
        maskBitmapWidth = 0;
        maskBitmapHeight = 0;
        maskScreenOffsetX = 0;
        maskScreenOffsetY = 0;
        trace('[L2D] Shader mask: $useShaderMask');

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
        var maxBatches = BATCH_POOL_SIZE + drawableCount;
        bTexIdx = [for (i in 0...maxBatches) 0];
        bBlendVal = [for (i in 0...maxBatches) 0];
        bMaskGroup = [for (i in 0...maxBatches) -1];
        bIsBatchable = [for (i in 0...maxBatches) false];
        bMulColor = [for (i in 0...maxBatches) [1.0, 1.0, 1.0]];
        bScrColor = [for (i in 0...maxBatches) [0.0, 0.0, 0.0]];
        bOpacity = [for (i in 0...maxBatches) 1.0];
        bDrawables = [for (i in 0...drawableCount * 2) 0];
        bStart = [for (i in 0...maxBatches) 0];
        bLen = [for (i in 0...maxBatches) 0];
        bMinOrder = [for (i in 0...maxBatches) 0];
        bDisplayObjRef = [for (i in 0...maxBatches) null];

        usedDisplayObjs = new Map();
        lastChildOrder = [];
        visibleList = [];
        reusableVerts = [];
        reusableUVs = [];
        reusableIndices = [];

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

        var channelFlags = [
            [1.0, 0.0, 0.0, 0.0],
            [0.0, 1.0, 0.0, 0.0],
            [0.0, 0.0, 1.0, 0.0]
        ];

        maskGroupChannelFlag = [];
        maskGroupIsInverted = [];

        for (g in 0...maskGroupMaskIndices.length)
        {
            if (g < SHADER_MASK_MAX_GROUPS)
                maskGroupChannelFlag.push(channelFlags[g]);
            else
                maskGroupChannelFlag.push(null);

            var isInverted = false;
            for (dIdx in 0...drawableMaskGroupId.length)
            {
                if (drawableMaskGroupId[dIdx] == g)
                {
                    isInverted = bridge.getDrawableInvertedMask(model, dIdx);
                    break;
                }
            }
            maskGroupIsInverted.push(isInverted);
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
        // 1 FFI call to get ALL drawable metadata (instead of ~1400 individual calls)
        CubismAPI.getDrawableBatchMetadata(model, drawableCount, metadataBuf);

        activeBatchCount = 0;
        var totalDrawables = 0;

        // Parse metadata and mark visible drawables as vertex-dirty
        var vlLen = 0;
        for (i in 0...drawableCount)
        {
            var offset = i * METADATA_STRIDE;
            var visible = metadataBuf.getInt32(offset);

            if (visible != 0)
            {
                vertexDirty[i] = true;
                var order = metadataBuf.getInt32(offset + 4);
                if (vlLen < visibleList.length)
                {
                    visibleList[vlLen].idx = i;
                    visibleList[vlLen].order = order;
                }
                else
                {
                    visibleList.push({idx: i, order: order});
                }
                vlLen++;
            }
        }
        while (visibleList.length > vlLen)
            visibleList.pop();
        visibleList.sort(visibleListSorter);

        // Previous batch key for extension check
        var prevTexIdx = -999;
        var prevBlendVal = -999;
        var prevMaskGroup = -999;
        var prevIsBatchable = false;
        var prevMulR:Float = 0, prevMulG:Float = 0, prevMulB:Float = 0;
        var prevScrR:Float = 0, prevScrG:Float = 0, prevScrB:Float = 0;
        var prevOpacity:Float = -1.0;

        for (item in visibleList)
        {
            var idx = item.idx;
            var metaOff = idx * METADATA_STRIDE;

            // Read all metadata from pre-fetched buffer (0 FFI)
            var opacity = metadataBuf.getFloat(metaOff + 8) * alpha;
            if (opacity < 0.01) continue;

            var texIdx = metadataBuf.getInt32(metaOff + 12);
            var blendVal = metadataBuf.getInt32(metaOff + 16);
            var maskGroup = drawableMaskGroupId[idx];

            var mulR = metadataBuf.getFloat(metaOff + 20);
            var mulG = metadataBuf.getFloat(metaOff + 24);
            var mulB = metadataBuf.getFloat(metaOff + 28);
            var scrR = metadataBuf.getFloat(metaOff + 32);
            var scrG = metadataBuf.getFloat(metaOff + 36);
            var scrB = metadataBuf.getFloat(metaOff + 40);

            if (useShaderMask)
            {
                var isBatchable = true;

                var canExtend = (activeBatchCount > 0)
                    && (texIdx == prevTexIdx)
                    && (blendVal == prevBlendVal)
                    && (maskGroup == prevMaskGroup)
                    && Math.abs(mulR - prevMulR) < 0.001
                    && Math.abs(mulG - prevMulG) < 0.001
                    && Math.abs(mulB - prevMulB) < 0.001
                    && Math.abs(scrR - prevScrR) < 0.001
                    && Math.abs(scrG - prevScrG) < 0.001
                    && Math.abs(scrB - prevScrB) < 0.001
                    && Math.abs(opacity - prevOpacity) < 0.01;

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
                    var bi = activeBatchCount;
                    bTexIdx[bi] = texIdx;
                    bBlendVal[bi] = blendVal;
                    bMaskGroup[bi] = maskGroup;
                    bIsBatchable[bi] = true;
                    bMulColor[bi][0] = mulR; bMulColor[bi][1] = mulG; bMulColor[bi][2] = mulB;
                    bScrColor[bi][0] = scrR; bScrColor[bi][1] = scrG; bScrColor[bi][2] = scrB;
                    bOpacity[bi] = opacity;
                    bStart[bi] = totalDrawables;
                    bLen[bi] = 1;
                    bMinOrder[bi] = item.order;
                    bDisplayObjRef[bi] = null;
                    bDrawables[totalDrawables] = idx;
                    totalDrawables++;
                    activeBatchCount++;
                }

                prevMulR = mulR; prevMulG = mulG; prevMulB = mulB;
                prevScrR = scrR; prevScrG = scrG; prevScrB = scrB;
                prevOpacity = opacity;
            }
            else
            {
                var isDefaultColor = (mulR >= 0.999 && mulR <= 1.001)
                    && (mulG >= 0.999 && mulG <= 1.001)
                    && (mulB >= 0.999 && mulB <= 1.001)
                    && (scrR >= -0.001 && scrR <= 0.001)
                    && (scrG >= -0.001 && scrG <= 0.001)
                    && (scrB >= -0.001 && scrB <= 0.001);

                var isFullOpacity = (opacity >= 0.99);
                var isBatchable = isDefaultColor && isFullOpacity;

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
                    var bi = activeBatchCount;
                    bTexIdx[bi] = texIdx;
                    bBlendVal[bi] = blendVal;
                    bMaskGroup[bi] = maskGroup;
                    bIsBatchable[bi] = isBatchable;
                    bMulColor[bi][0] = mulR; bMulColor[bi][1] = mulG; bMulColor[bi][2] = mulB;
                    bScrColor[bi][0] = scrR; bScrColor[bi][1] = scrG; bScrColor[bi][2] = scrB;
                    bOpacity[bi] = opacity;
                    bStart[bi] = totalDrawables;
                    bLen[bi] = 1;
                    bMinOrder[bi] = item.order;
                    bDisplayObjRef[bi] = null;
                    bDrawables[totalDrawables] = idx;
                    totalDrawables++;
                    activeBatchCount++;
                }
            }

            prevTexIdx = texIdx;
            prevBlendVal = blendVal;
            prevMaskGroup = maskGroup;
            prevIsBatchable = bIsBatchable[activeBatchCount - 1];
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
            trace('[L2D] Batches: $activeBatchCount (batched: $batchedCount, individual: $individualCount, shader: $useShaderMask)');
        }
    }

    static inline function ensureArraySizeFloat(arr:Array<Float>, size:Int):Void
    {
        if (arr.length > size)
            arr.splice(size, arr.length - size);
        while (arr.length < size) arr.push(0.0);
    }

    static inline function ensureArraySizeInt(arr:Array<Int>, size:Int):Void
    {
        if (arr.length > size)
            arr.splice(size, arr.length - size);
        while (arr.length < size) arr.push(0);
    }

    // ===== Rendering =====

    function fillVertexData(drawableIndex:Int, vertices:Array<Float>, uvs:Array<Float>, indices:Array<Int>):Void
    {
        var vertCount = cachedVertCounts[drawableIndex];
        var idxCount = cachedIdxCounts[drawableIndex];

        if (vertCount == 0 || idxCount == 0)
            return;

        // Refresh cached positions when dirty
        if (vertexDirty[drawableIndex])
        {
            var needVertBytes = vertCount * 2 * 4;
            if (vertexBuffers[drawableIndex].length < needVertBytes)
                vertexBuffers[drawableIndex] = Bytes.alloc(needVertBytes);
            bridge.getDrawableVertexPositions(model, drawableIndex, vertexBuffers[drawableIndex]);

            // Update cached Float array from Bytes buffer
            var vertBuf = vertexBuffers[drawableIndex];
            var posArr = cachedPositions[drawableIndex];
            for (v in 0...vertCount)
            {
                posArr[v * 2] = vertBuf.getFloat(v * 8);
                posArr[v * 2 + 1] = vertBuf.getFloat(v * 8 + 4);
            }
            vertexDirty[drawableIndex] = false;
        }

        var cachedPos = cachedPositions[drawableIndex];
        var cachedUV = cachedUVs[drawableIndex];
        var cachedIdx = cachedIndices[drawableIndex];

        var vo = fvVertexOffset;
        for (v in 0...vertCount)
        {
            var vi2 = v * 2;
            vertices[(vo + v) * 2] = (cachedPos[vi2] - modelCenterX) * scale + x;
            vertices[(vo + v) * 2 + 1] = -(cachedPos[vi2 + 1] - modelCenterY) * scale + y;
            uvs[(vo + v) * 2] = cachedUV[vi2];
            uvs[(vo + v) * 2 + 1] = 1.0 - cachedUV[vi2 + 1];
        }

        for (n in 0...idxCount)
        {
            indices[fvIdxWritePos + n] = cachedIdx[n] + vo;
        }

        fvVertexOffset = vo + vertCount;
        fvIdxWritePos = fvIdxWritePos + idxCount;
    }

    function renderBatchWithShader(obj:L2DDisplayHandle, batchIdx:Int):Void
    {
        var start = bStart[batchIdx];
        var len = bLen[batchIdx];
        var texIdx = bTexIdx[batchIdx];
        var mg = bMaskGroup[batchIdx];
        var blendVal = bBlendVal[batchIdx];

        // Count total verts/indices using cached counts
        var totalVerts = 0;
        var totalIndices = 0;
        for (i in 0...len)
        {
            var dIdx = bDrawables[start + i];
            totalVerts += cachedVertCounts[dIdx];
            totalIndices += cachedIdxCounts[dIdx];
        }
        if (totalVerts == 0 || totalIndices == 0) return;

        // Reuse arrays to reduce GC pressure
        ensureArraySizeFloat(reusableVerts, totalVerts * 2);
        ensureArraySizeFloat(reusableUVs, totalVerts * 2);
        ensureArraySizeInt(reusableIndices, totalIndices);

        fvVertexOffset = 0;
        fvIdxWritePos = 0;

        for (i in 0...len)
        {
            fillVertexData(bDrawables[start + i], reusableVerts, reusableUVs, reusableIndices);
        }

        var texture:L2DTextureHandle = null;
        if (texIdx >= 0 && texIdx < textures.length)
            texture = textures[texIdx];

        var hasMask = (mg >= 0 && mg < SHADER_MASK_MAX_GROUPS && maskGroupChannelFlag[mg] != null);

        var isMultiplyBlend = (blendVal == 2 || blendVal == 6);
        var isScreenBlend = (blendVal == 10);

        var mulColor:Array<Float> = null;
        var scrColor:Array<Float> = null;
        var useColor = false;

        var bm = bMulColor[batchIdx];
        var bs = bScrColor[batchIdx];
        if (isMultiplyBlend && !(bm[0] >= 0.999 && bm[1] >= 0.999 && bm[2] >= 0.999))
        {
            mulColor = bm;
            scrColor = [0.0, 0.0, 0.0];
            useColor = true;
        }
        else if (isScreenBlend && !(bs[0] <= 0.001 && bs[1] <= 0.001 && bs[2] <= 0.001))
        {
            mulColor = [1.0, 1.0, 1.0];
            scrColor = bs;
            useColor = true;
        }

        var isFullOpacity = (bOpacity[batchIdx] >= 0.99);
        var needsShader = hasMask || useColor || !isFullOpacity;

        if (needsShader)
        {
            renderer.drawShaderTexturedTriangles(
                obj, texture, reusableVerts, reusableUVs, reusableIndices,
                hasMask ? maskTextureHandle : null,
                hasMask ? maskGroupChannelFlag[mg] : null,
                hasMask ? [maskScreenOffsetX, maskScreenOffsetY] : null,
                hasMask ? [maskBitmapWidth * 1.0, maskBitmapHeight * 1.0] : null,
                hasMask ? maskGroupIsInverted[mg] : null,
                useColor ? mulColor : null,
                useColor ? scrColor : null,
                !isFullOpacity ? bOpacity[batchIdx] : null
            );
        }
        else
        {
            renderer.drawTexturedTriangles(obj, texture, reusableVerts, reusableUVs, reusableIndices);
        }
    }

    function renderBatchToDisplayObj(obj:L2DDisplayHandle, batchIdx:Int):Void
    {
        var start = bStart[batchIdx];
        var len = bLen[batchIdx];
        var texIdx = bTexIdx[batchIdx];

        var totalVerts = 0;
        var totalIndices = 0;
        for (i in 0...len)
        {
            var dIdx = bDrawables[start + i];
            totalVerts += cachedVertCounts[dIdx];
            totalIndices += cachedIdxCounts[dIdx];
        }
        if (totalVerts == 0 || totalIndices == 0) return;

        ensureArraySizeFloat(reusableVerts, totalVerts * 2);
        ensureArraySizeFloat(reusableUVs, totalVerts * 2);
        ensureArraySizeInt(reusableIndices, totalIndices);

        fvVertexOffset = 0;
        fvIdxWritePos = 0;

        for (i in 0...len)
        {
            fillVertexData(bDrawables[start + i], reusableVerts, reusableUVs, reusableIndices);
        }

        var texture:L2DTextureHandle = null;
        if (texIdx >= 0 && texIdx < textures.length)
            texture = textures[texIdx];

        renderer.drawTexturedTriangles(obj, texture, reusableVerts, reusableUVs, reusableIndices);
    }

    function drawDrawableWithShader(obj:L2DDisplayHandle, drawableIndex:Int):Void
    {
        if (drawableIndex >= vertexBuffers.length) return;

        var vertCount = cachedVertCounts[drawableIndex];
        var idxCount = cachedIdxCounts[drawableIndex];
        if (vertCount == 0 || idxCount == 0) return;

        // Read metadata from pre-fetched buffer (0 FFI)
        var metaOff = drawableIndex * METADATA_STRIDE;
        var opacity = metadataBuf.getFloat(metaOff + 8) * alpha;
        if (opacity < 0.01) return;

        var texIdx = metadataBuf.getInt32(metaOff + 12);
        var blendVal = metadataBuf.getInt32(metaOff + 16);
        var mg = drawableMaskGroupId[drawableIndex];

        var mulR = metadataBuf.getFloat(metaOff + 20);
        var mulG = metadataBuf.getFloat(metaOff + 24);
        var mulB = metadataBuf.getFloat(metaOff + 28);
        var scrR = metadataBuf.getFloat(metaOff + 32);
        var scrG = metadataBuf.getFloat(metaOff + 36);
        var scrB = metadataBuf.getFloat(metaOff + 40);

        var isMultiplyBlend = (blendVal == 2 || blendVal == 6);
        var isScreenBlend = (blendVal == 10);

        var useColor = false;
        var finalMulColorIdx = -1;
        var finalScrColorIdx = -1;

        if (isMultiplyBlend && !(mulR >= 0.999 && mulG >= 0.999 && mulB >= 0.999))
        {
            finalMulColorIdx = drawableIndex;
            finalScrColorIdx = -2; // sentinel for [0,0,0]
            useColor = true;
        }
        else if (isScreenBlend && !(scrR <= 0.001 && scrG <= 0.001 && scrB <= 0.001))
        {
            finalMulColorIdx = -3; // sentinel for [1,1,1]
            finalScrColorIdx = drawableIndex;
            useColor = true;
        }

        var isFullOpacity = (opacity >= 0.99);

        ensureArraySizeFloat(reusableVerts, vertCount * 2);
        ensureArraySizeFloat(reusableUVs, vertCount * 2);
        ensureArraySizeInt(reusableIndices, idxCount);

        fvVertexOffset = 0;
        fvIdxWritePos = 0;
        fillVertexData(drawableIndex, reusableVerts, reusableUVs, reusableIndices);

        var texture:L2DTextureHandle = null;
        if (texIdx >= 0 && texIdx < textures.length)
            texture = textures[texIdx];

        var hasMask = (mg >= 0 && mg < SHADER_MASK_MAX_GROUPS && maskGroupChannelFlag[mg] != null);

        var needsShader = hasMask || useColor || !isFullOpacity;

        if (needsShader)
        {
            // Resolve color arrays from pre-allocated batch arrays or sentinels
            var mulColorArr:Array<Float> = null;
            var scrColorArr:Array<Float> = null;
            if (useColor)
            {
                if (finalMulColorIdx >= 0)
                {
                    mulColorArr = [metadataBuf.getFloat(finalMulColorIdx * METADATA_STRIDE + 20),
                                   metadataBuf.getFloat(finalMulColorIdx * METADATA_STRIDE + 24),
                                   metadataBuf.getFloat(finalMulColorIdx * METADATA_STRIDE + 28)];
                }
                else if (finalMulColorIdx == -2)
                    mulColorArr = [0.0, 0.0, 0.0];
                else if (finalMulColorIdx == -3)
                    mulColorArr = [1.0, 1.0, 1.0];

                if (finalScrColorIdx >= 0)
                {
                    scrColorArr = [metadataBuf.getFloat(finalScrColorIdx * METADATA_STRIDE + 32),
                                   metadataBuf.getFloat(finalScrColorIdx * METADATA_STRIDE + 36),
                                   metadataBuf.getFloat(finalScrColorIdx * METADATA_STRIDE + 40)];
                }
                else if (finalScrColorIdx == -2)
                    scrColorArr = [0.0, 0.0, 0.0];
                else if (finalScrColorIdx == -3)
                    scrColorArr = [1.0, 1.0, 1.0];
            }

            renderer.drawShaderTexturedTriangles(
                obj, texture, reusableVerts, reusableUVs, reusableIndices,
                hasMask ? maskTextureHandle : null,
                hasMask ? maskGroupChannelFlag[mg] : null,
                hasMask ? [maskScreenOffsetX, maskScreenOffsetY] : null,
                hasMask ? [maskBitmapWidth * 1.0, maskBitmapHeight * 1.0] : null,
                hasMask ? maskGroupIsInverted[mg] : null,
                useColor ? mulColorArr : null,
                useColor ? scrColorArr : null,
                !isFullOpacity ? opacity : null
            );
        }
        else
        {
            renderer.drawTexturedTriangles(obj, texture, reusableVerts, reusableUVs, reusableIndices);
        }
    }

    function drawDrawableToDisplayObj(obj:L2DDisplayHandle, drawableIndex:Int):Void
    {
        if (drawableIndex >= vertexBuffers.length) return;

        var vertCount = cachedVertCounts[drawableIndex];
        var idxCount = cachedIdxCounts[drawableIndex];
        if (vertCount == 0 || idxCount == 0) return;

        // Read metadata from pre-fetched buffer (0 FFI)
        var metaOff = drawableIndex * METADATA_STRIDE;
        var opacity = metadataBuf.getFloat(metaOff + 8) * alpha;
        if (opacity < 0.01) return;

        var texIdx = metadataBuf.getInt32(metaOff + 12);
        var blendVal = metadataBuf.getInt32(metaOff + 16);
        var mulR = metadataBuf.getFloat(metaOff + 20);
        var mulG = metadataBuf.getFloat(metaOff + 24);
        var mulB = metadataBuf.getFloat(metaOff + 28);
        var scrR = metadataBuf.getFloat(metaOff + 32);
        var scrG = metadataBuf.getFloat(metaOff + 36);
        var scrB = metadataBuf.getFloat(metaOff + 40);

        ensureArraySizeFloat(reusableVerts, vertCount * 2);
        ensureArraySizeFloat(reusableUVs, vertCount * 2);
        ensureArraySizeInt(reusableIndices, idxCount);

        fvVertexOffset = 0;
        fvIdxWritePos = 0;
        fillVertexData(drawableIndex, reusableVerts, reusableUVs, reusableIndices);

        renderer.setAlpha(obj, opacity);

        var isMultiplyBlend = (blendVal == 2 || blendVal == 6);
        var isScreenBlend = (blendVal == 10);
        var isDefaultMulColor = (mulR >= 0.999 && mulR <= 1.001)
            && (mulG >= 0.999 && mulG <= 1.001)
            && (mulB >= 0.999 && mulB <= 1.001);
        var isDefaultScrColor = (scrR >= -0.001 && scrR <= 0.001)
            && (scrG >= -0.001 && scrG <= 0.001)
            && (scrB >= -0.001 && scrB <= 0.001);

        var shouldApplyColor = false;
        var applyMulR = 1.0, applyMulG = 1.0, applyMulB = 1.0;
        var applyScrR = 0.0, applyScrG = 0.0, applyScrB = 0.0;

        if (isMultiplyBlend && !isDefaultMulColor)
        {
            applyMulR = mulR; applyMulG = mulG; applyMulB = mulB;
            shouldApplyColor = true;
        }
        else if (isScreenBlend && !isDefaultScrColor)
        {
            applyMulR = 1.0; applyMulG = 1.0; applyMulB = 1.0;
            applyScrR = scrR; applyScrG = scrG; applyScrB = scrB;
            shouldApplyColor = true;
        }

        if (shouldApplyColor)
            renderer.setColorTransform(obj,
                applyMulR - applyScrR, applyMulG - applyScrG, applyMulB - applyScrB, 1.0,
                applyScrR * 255.0, applyScrG * 255.0, applyScrB * 255.0, 0.0
            );
        else
            renderer.resetColorTransform(obj);

        renderer.setBlendMode(obj, blendVal);

        var texture:L2DTextureHandle = null;
        if (texIdx >= 0 && texIdx < textures.length)
            texture = textures[texIdx];

        renderer.drawTexturedTriangles(obj, texture, reusableVerts, reusableUVs, reusableIndices);
    }

    function drawMaskShape(obj:L2DDisplayHandle, maskDrawableIndex:Int):Void
    {
        var vertCount = cachedVertCounts[maskDrawableIndex];
        var idxCount = cachedIdxCounts[maskDrawableIndex];
        if (vertCount == 0 || idxCount == 0) return;

        // Fetch vertex positions if dirty (masks may need fresh positions)
        // Note: do NOT set vertexDirty=false here; fillVertexData manages it
        if (vertexDirty[maskDrawableIndex])
        {
            var needVertBytes = vertCount * 2 * 4;
            if (vertexBuffers[maskDrawableIndex].length < needVertBytes)
                vertexBuffers[maskDrawableIndex] = Bytes.alloc(needVertBytes);
            bridge.getDrawableVertexPositions(model, maskDrawableIndex, vertexBuffers[maskDrawableIndex]);
        }

        var vertBuf = vertexBuffers[maskDrawableIndex];
        var cachedIdx = cachedIndices[maskDrawableIndex];

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
            indices[n] = cachedIdx[n];
        }

        renderer.drawSolidTriangles(obj, vertices, indices);
    }

    // ===== Mask Texture Update =====

    function updateMaskTexture():Void
    {
        if (!maskTextureDirty && maskTextureHandle != null) return;

        var texWidth = Math.ceil(modelWidth * scale);
        var texHeight = Math.ceil(modelHeight * scale);
        if (texWidth <= 0 || texHeight <= 0) return;

        var offsetX = x - (modelWidth / 2) * scale;
        var offsetY = y - (modelHeight / 2) * scale;

        maskBitmapWidth = texWidth;
        maskBitmapHeight = texHeight;
        maskScreenOffsetX = offsetX;
        maskScreenOffsetY = offsetY;

        var maskShapes = new Array<{groupIndex:Int, channelFlag:Array<Float>, vertices:Array<Array<Float>>, indices:Array<Array<Int>>}>();

        var groupCount = maskGroupMaskIndices.length;
        var maxGroup = (groupCount < SHADER_MASK_MAX_GROUPS) ? groupCount : SHADER_MASK_MAX_GROUPS;

        for (g in 0...maxGroup)
        {
            var groupVerts = new Array<Array<Float>>();
            var groupIdxs = new Array<Array<Int>>();

            for (maskDIdx in maskGroupMaskIndices[g])
            {
                var vertCount = cachedVertCounts[maskDIdx];
                var idxCount = cachedIdxCounts[maskDIdx];
                if (vertCount == 0 || idxCount == 0) continue;

                // Ensure vertex positions are fresh
                // Note: do NOT set vertexDirty=false; fillVertexData manages it
                if (vertexDirty[maskDIdx])
                {
                    var needVertBytes = vertCount * 2 * 4;
                    if (vertexBuffers[maskDIdx].length < needVertBytes)
                        vertexBuffers[maskDIdx] = Bytes.alloc(needVertBytes);
                    bridge.getDrawableVertexPositions(model, maskDIdx, vertexBuffers[maskDIdx]);
                }

                var vertBuf = vertexBuffers[maskDIdx];
                var cachedIdx = cachedIndices[maskDIdx];

                var verts = new Array<Float>();
                var idxs = new Array<Int>();
                for (v in 0...vertCount)
                {
                    var vx = vertBuf.getFloat(v * 8);
                    var vy = vertBuf.getFloat(v * 8 + 4);
                    verts.push((vx - modelCenterX) * scale + x);
                    verts.push(-(vy - modelCenterY) * scale + y);
                }
                for (n in 0...idxCount)
                    idxs.push(cachedIdx[n]);

                groupVerts.push(verts);
                groupIdxs.push(idxs);
            }

            maskShapes.push({
                groupIndex: g,
                channelFlag: maskGroupChannelFlag[g],
                vertices: groupVerts,
                indices: groupIdxs
            });
        }

        maskTextureHandle = renderer.renderMaskToBitmapData(
            maskShapes, texWidth, texHeight, offsetX, offsetY
        );

        maskTextureDirty = false;
    }

    // ===== Main Render =====

    public function render():Void
    {
        if (model.isNull() || destroyed) return;

        // 1. Build batches
        buildBatches();

        // 2. Check mask texture dirty (using pre-fetched metadata, 0 additional FFI)
        if (useShaderMask)
        {
            maskTextureDirty = firstFrame;
            if (!maskTextureDirty)
            {
                for (g in 0...maskGroupMaskIndices.length)
                {
                    if (g >= SHADER_MASK_MAX_GROUPS) break;
                    for (maskDIdx in maskGroupMaskIndices[g])
                    {
                        var metaOff = maskDIdx * METADATA_STRIDE;
                        if (metadataBuf.getInt32(metaOff + 44) != 0)
                        {
                            maskTextureDirty = true;
                            break;
                        }
                    }
                    if (maskTextureDirty) break;
                }
            }

            if (maskTextureDirty)
                updateMaskTexture();
        }

        // 3. Reset only display objects that were used last frame
        for (key in usedDisplayObjs.keys())
        {
            var obj:L2DDisplayHandle = null;
            if (key < 0)
            {
                // Negative key = mask pool object at index -(key+1)
                var poolIdx = -(key + 1);
                if (poolIdx < MASK_POOL_SIZE)
                    obj = maskDisplayObjs[poolIdx];
            }
            else if (key < BATCH_POOL_SIZE)
            {
                obj = batchDisplayObjs[key];
            }
            else
            {
                var dIdx = key - BATCH_POOL_SIZE;
                if (dIdx < drawableDisplayObjs.length)
                    obj = drawableDisplayObjs[dIdx];
            }
            if (obj != null)
                renderer.resetDisplayObject(obj);
        }
        usedDisplayObjs.clear();

        // 4. Render each batch
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
                    usedDisplayObjs.set(batchObjUsed, true); // track usage

                    if (useShaderMask)
                    {
                        renderer.setAlpha(obj, 1.0);
                        renderer.setBlendMode(obj, bBlendVal[b]);
                        renderBatchWithShader(obj, b);
                    }
                    else
                    {
                        renderer.setAlpha(obj, 1.0);
                        renderer.setBlendMode(obj, bBlendVal[b]);
                        renderer.resetColorTransform(obj);
                        renderBatchToDisplayObj(obj, b);
                    }

                    bDisplayObjRef[b] = obj;
                    batchObjUsed++;
                }
                else
                {
                    bIsBatchable[b] = false;
                    renderIndividualBatch(b);
                }
            }
            else
            {
                renderIndividualBatch(b);
            }
        }

        // 5. Apply masks (fallback Sprite.mask path)
        if (!useShaderMask)
        {
            renderMasks(batchObjUsed);
        }
        else
        {
            renderMasksForFallbackGroups(batchObjUsed);
        }

        // 6. Reorder display list
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
            usedDisplayObjs.set(BATCH_POOL_SIZE + dIdx, true); // track usage

            if (useShaderMask)
            {
                // Shader path: opacity handled by shader, alpha=1.0 on Sprite
                renderer.setAlpha(obj, 1.0);
                var metaOff = dIdx * METADATA_STRIDE;
                renderer.setBlendMode(obj, metadataBuf.getInt32(metaOff + 16));
                drawDrawableWithShader(obj, dIdx);
            }
            else
            {
                // Fallback path: uses setAlpha + ColorTransform + drawTexturedTriangles
                drawDrawableToDisplayObj(obj, dIdx);
            }

            bDisplayObjRef[batchIdx] = obj;
        }
    }

    function renderMasks(batchObjUsed:Int):Void
    {
        var maskObjUsed = 0;
        reusableMaskGroupMap.clear();

        // For batched display objects with mask groups
        for (b in 0...activeBatchCount)
        {
            var mg = bMaskGroup[b];
            if (mg < 0) continue;

            var obj = bDisplayObjRef[b];
            if (obj == null) continue;

            var poolIdx;
            if (reusableMaskGroupMap.exists(mg))
            {
                poolIdx = reusableMaskGroupMap.get(mg);
            }
            else
            {
                if (maskObjUsed >= MASK_POOL_SIZE)
                {
                    renderer.clearMask(obj);
                    continue;
                }
                poolIdx = maskObjUsed;
                reusableMaskGroupMap.set(mg, poolIdx);
                maskObjUsed++;

                var maskObj = maskDisplayObjs[poolIdx];
                renderer.setVisible(maskObj, true);
                usedDisplayObjs.set(-(poolIdx + 1), true);
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

                var poolIdx = reusableMaskGroupMap.exists(mg) ? reusableMaskGroupMap.get(mg) : -1;
                if (poolIdx >= 0)
                    renderer.setMask(obj, maskDisplayObjs[poolIdx]);
            }
        }
    }

    function renderMasksForFallbackGroups(batchObjUsed:Int):Void
    {
        if (maskGroupMaskIndices.length <= SHADER_MASK_MAX_GROUPS) return;

        var maskObjUsed = 0;
        reusableMaskGroupMap.clear();

        for (b in 0...activeBatchCount)
        {
            var mg = bMaskGroup[b];
            if (mg < SHADER_MASK_MAX_GROUPS) continue;

            var obj = bDisplayObjRef[b];
            if (obj == null) continue;

            var poolIdx;
            if (reusableMaskGroupMap.exists(mg))
            {
                poolIdx = reusableMaskGroupMap.get(mg);
            }
            else
            {
                if (maskObjUsed >= MASK_POOL_SIZE)
                {
                    renderer.clearMask(obj);
                    continue;
                }
                poolIdx = maskObjUsed;
                reusableMaskGroupMap.set(mg, poolIdx);
                maskObjUsed++;

                var maskObj = maskDisplayObjs[poolIdx];
                renderer.setVisible(maskObj, true);
                usedDisplayObjs.set(-(poolIdx + 1), true);
                for (maskDIdx in maskGroupMaskIndices[mg])
                {
                    drawMaskShape(maskObj, maskDIdx);
                }
            }

            renderer.setMask(obj, maskDisplayObjs[poolIdx]);
        }

        for (b in 0...activeBatchCount)
        {
            if (bIsBatchable[b]) continue;
            var mg = bMaskGroup[b];
            if (mg < SHADER_MASK_MAX_GROUPS) continue;

            var start = bStart[b];
            var len = bLen[b];
            for (i in 0...len)
            {
                var dIdx = bDrawables[start + i];
                var obj = drawableDisplayObjs[dIdx];
                if (obj == null) continue;

                var poolIdx = reusableMaskGroupMap.exists(mg) ? reusableMaskGroupMap.get(mg) : -1;
                if (poolIdx >= 0)
                    renderer.setMask(obj, maskDisplayObjs[poolIdx]);
            }
        }
    }

    function reorderDisplayObjs(batchObjUsed:Int):Void
    {
        var targetIndex = 0;

        // Build set of drawable indices that are visible this frame
        reusableVisibleDrawableSet.clear();
        for (b in 0...activeBatchCount)
        {
            if (!bIsBatchable[b])
            {
                var start = bStart[b];
                var len = bLen[b];
                for (i in 0...len)
                    reusableVisibleDrawableSet.set(bDrawables[start + i], true);
            }
        }

        // Visible display objects in renderOrder — skip setChildIndex if order unchanged
        for (b in 0...activeBatchCount)
        {
            if (bIsBatchable[b])
            {
                var obj = bDisplayObjRef[b];
                if (obj != null)
                {
                    if (lastChildOrder[renderer.getObjectId(obj)] != targetIndex)
                    {
                        renderer.setChildIndex(obj, targetIndex);
                        lastChildOrder[renderer.getObjectId(obj)] = targetIndex;
                    }
                    targetIndex++;
                }
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
                    {
                        if (lastChildOrder[renderer.getObjectId(obj)] != targetIndex)
                        {
                            renderer.setChildIndex(obj, targetIndex);
                            lastChildOrder[renderer.getObjectId(obj)] = targetIndex;
                        }
                        targetIndex++;
                    }
                }
            }
        }

        // Hidden batch display objects (only unused pool objects)
        for (i in batchObjUsed...BATCH_POOL_SIZE)
        {
            var obj = batchDisplayObjs[i];
            if (lastChildOrder[renderer.getObjectId(obj)] != targetIndex)
            {
                renderer.setChildIndex(obj, targetIndex);
                lastChildOrder[renderer.getObjectId(obj)] = targetIndex;
            }
            targetIndex++;
        }

        // Hidden individual display objects (not visible this frame)
        for (dIdx in 0...drawableDisplayObjs.length)
        {
            if (drawableDisplayObjs[dIdx] != null && !reusableVisibleDrawableSet.exists(dIdx))
            {
                var obj = drawableDisplayObjs[dIdx];
                if (lastChildOrder[renderer.getObjectId(obj)] != targetIndex)
                {
                    renderer.setChildIndex(obj, targetIndex);
                    lastChildOrder[renderer.getObjectId(obj)] = targetIndex;
                }
                targetIndex++;
            }
        }

        // Mask display objects at the end (only needed for Sprite.mask fallback)
        if (!useShaderMask || maskGroupMaskIndices.length > SHADER_MASK_MAX_GROUPS)
        {
            for (obj in maskDisplayObjs)
            {
                if (lastChildOrder[renderer.getObjectId(obj)] != targetIndex)
                {
                    renderer.setChildIndex(obj, targetIndex);
                    lastChildOrder[renderer.getObjectId(obj)] = targetIndex;
                }
                targetIndex++;
            }
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

        maskTextureHandle = null;

        renderer.destroyContainer();

        batchDisplayObjs = null;
        maskDisplayObjs = null;
        drawableDisplayObjs = null;
        vertexBuffers = null;
        uvBuffers = null;
        indexBuffers = null;
        cachedVertCounts = null;
        cachedIdxCounts = null;
        cachedUVs = null;
        cachedIndices = null;
        vertexDirty = null;
        metadataBuf = null;
        drawableMaskGroupId = null;
        maskGroupMaskIndices = null;
        maskGroupChannelFlag = null;
        maskGroupIsInverted = null;
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