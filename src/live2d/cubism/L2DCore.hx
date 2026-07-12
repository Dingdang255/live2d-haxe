package live2d.cubism;

import haxe.io.Bytes;
import live2d.cubism.backend.IL2DRenderer;
import live2d.cubism.backend.L2DDisplayHandle;
import live2d.cubism.backend.L2DTextureHandle;
import live2d.cubism.core.CubismAPI;
import live2d.cubism.core.L2DModel;
#if sys
import sys.io.File;
import haxe.Json;
#end

using StringTools;

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
    var renderer:IL2DRenderer;

    // Internal: textures
    var textures:Array<L2DTextureHandle> = [];
    public var ownsTextures:Bool = true;

    // Internal: vertex data buffers
    var vertexBuffers:Array<Bytes> = [];
    var uvBuffers:Array<Bytes> = [];
    var indexBuffers:Array<Bytes> = [];

    // Internal: cached static data (UVs and indices never change)
    var _drawableCount:Int = 0;
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

    // Fallback mask RT dimensions (computed from actual vertex AABB)
    var fbOffsetX:Float = 0;
    var fbOffsetY:Float = 0;
    var fbWidth:Float = 0;
    var fbHeight:Float = 0;
    var useShaderMask:Bool;

    // Internal: track model transform changes for mask texture dirty
    var maskLastX:Float = 0;
    var maskLastY:Float = 0;
    var maskLastScale:Float = -1;

    // Internal: display object pools
    var batchDisplayObjs:Array<L2DDisplayHandle>;
    var maskDisplayObjs:Array<L2DDisplayHandle>;
    var drawableDisplayObjs:Array<L2DDisplayHandle>;
    var maskPoolSize:Int = 16;
    static inline var BATCH_POOL_SIZE = 256;
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

    // Internal: VTuber expression file support
    var vtubeExpressionCache:Map<String, Array<{paramIndex:Int, value:Float, blend:String}>>;
    var activeVTubeExpressions:Array<String>;

    // Framework behavior enabled state (mirrors C++ side)
    public var breathEnabled(default, null):Bool = true;
    public var eyeBlinkEnabled(default, null):Bool = true;
    public var expressionEnabled(default, null):Bool = true;
    public var lookEnabled(default, null):Bool = true;
    public var physicsEnabled(default, null):Bool = true;
    public var lipSyncEnabled(default, null):Bool = true;
    public var poseEnabled(default, null):Bool = true;

    // Rendering stats (exposed for performance panels)
    /** Number of drawables in the model. */
    public var drawableCount(get, null):Int;
    /** Number of active batches in the current frame (after buildBatches). */
    public var batchCount(get, null):Int;
    /** Mask render-texture width in pixels (0 if no mask/shader mask not used). */
    public var maskRTWidth(get, null):Int;
    /** Mask render-texture height in pixels (0 if no mask/shader mask not used). */
    public var maskRTHeight(get, null):Int;

    function get_drawableCount():Int return _drawableCount;
    function get_batchCount():Int return activeBatchCount;
    function get_maskRTWidth():Int return useShaderMask ? maskBitmapWidth : 0;
    function get_maskRTHeight():Int return useShaderMask ? maskBitmapHeight : 0;

    static var frameworkInitialized:Bool = false;

    // Static sort comparator (avoid closure allocation per frame)
    static var visibleListSorter = function(a:{idx:Int, order:Int}, b:{idx:Int, order:Int}):Int {
        return a.order - b.order;
    };

    public function new(dir:String, fileName:String, renderer:IL2DRenderer)
    {
        this.renderer = renderer;

        modelDir = dir;
        modelFileName = fileName;

        trace('[L2D] Loading model from: $dir$fileName');

        if (!frameworkInitialized)
        {
            trace('[L2D] Initializing framework...');
            CubismAPI.frameworkStartUp();
            frameworkInitialized = true;

            var coreVer = CubismAPI.getCoreVersion();
            var latestMoc = CubismAPI.getLatestMocVersion();
            trace('[L2D] Cubism Core version: ${coreVer}');
            trace('[L2D] Supported moc version: ≤${latestMoc}');
        }

        // Pre-load moc3 version check
        var mocPath = dir + fileName.replace('.model3.json', '.moc3');
        var consistent = CubismAPI.hasMocConsistency(mocPath);
        if (!consistent)
        {
            var latestMoc = CubismAPI.getLatestMocVersion();
            var coreVer = CubismAPI.getCoreVersion();
            trace('[L2D] ERROR: moc3 file incompatible with current Core!');
            trace('[L2D]   File: $mocPath');
            trace('[L2D]   Core version: $coreVer, supported moc version: ≤$latestMoc');
            trace('[L2D]   Possible causes:');
            trace('[L2D]     1. moc3 was exported with a newer Cubism Editor than the Core supports');
            trace('[L2D]     2. The moc3 file is corrupted or missing');
            trace('[L2D]   Possible fix: re-export from Cubism Editor with lower target version');
            model = L2DModel.NULL;
            return;
        }
        trace('[L2D] moc3 consistency check passed: $mocPath');

        model = CubismAPI.loadModel(dir, fileName);
        if (model.isNull())
        {
            trace('[L2D] ERROR: Model is null after load!');
            return;
        }

        // Load textures
        var texCount = CubismAPI.getTextureCount(model);
        trace('[L2D] Texture count: $texCount');
        for (i in 0...texCount)
        {
            var texPath = CubismAPI.getTexturePath(model, i);
            var fullPath = dir + texPath;
            var tex = renderer.loadTexture(fullPath);
            textures.push(tex);
            if (tex == null)
                trace('[L2D] ERROR: Failed to load texture: $fullPath');
        }
        // Diagnostic: report texture array state
        for (ti in 0...textures.length)
        {
            var t = textures[ti];
            trace('[L2D TEX] texIdx=$ti tex=${t != null} path=$dir${CubismAPI.getTexturePath(model, ti)}');
        }

        // Initialize per-drawable buffers and compute model bounds
        _drawableCount = CubismAPI.getDrawableCount(model);
        trace('[L2D] Drawable count: $_drawableCount');

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

        for (i in 0..._drawableCount)
        {
            var vertCount = CubismAPI.getDrawableVertexCount(model, i);
            var idxCount = CubismAPI.getDrawableIndexCount(model, i);

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
                CubismAPI.getDrawableVertexPositions(model, i, posBuf);
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
                CubismAPI.getDrawableVertexUvs(model, i, uvBuf);
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
                CubismAPI.getDrawableIndices(model, i, idxBuf);
                for (n in 0...idxCount)
                    idxArr.push(idxBuf.getUInt16(n * 2));
            }
            cachedIndices.push(idxArr);

            // Compute bounds from vertex positions
            if (vertCount > 0)
            {
                var testBuf = Bytes.alloc(vertCount * 2 * 4);
                CubismAPI.getDrawableVertexPositions(model, i, testBuf);
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
        metadataBuf = Bytes.alloc(_drawableCount * METADATA_STRIDE);

        modelCenterX = (bMinX + bMaxX) / 2;
        modelCenterY = (bMinY + bMaxY) / 2;
        modelWidth = bMaxX - bMinX;
        modelHeight = bMaxY - bMinY;
        trace('[L2D] Model center: ($modelCenterX, $modelCenterY), size: $modelWidth x $modelHeight');

        // Pre-compute mask groups
        precomputeMaskGroups(_drawableCount);

        // Ensure mask pool is large enough for all mask groups
        maskPoolSize = Std.int(Math.max(16, maskGroupMaskIndices.length));

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
        for (i in 0...maskPoolSize)
        {
            maskDisplayObjs.push(renderer.createDisplayObject());
        }

        // Individual display objects: lazy-created, initially all null
        drawableDisplayObjs = [for (i in 0..._drawableCount) null];

        // Pre-allocate batch description arrays
        var maxBatches = BATCH_POOL_SIZE + _drawableCount;
        bTexIdx = [for (i in 0...maxBatches) 0];
        bBlendVal = [for (i in 0...maxBatches) 0];
        bMaskGroup = [for (i in 0...maxBatches) -1];
        bIsBatchable = [for (i in 0...maxBatches) false];
        bMulColor = [for (i in 0...maxBatches) [1.0, 1.0, 1.0]];
        bScrColor = [for (i in 0...maxBatches) [0.0, 0.0, 0.0]];
        bOpacity = [for (i in 0...maxBatches) 1.0];
        bDrawables = [for (i in 0..._drawableCount * 2) 0];
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

        vtubeExpressionCache = new Map();
        activeVTubeExpressions = [];

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
            var maskCount = CubismAPI.getDrawableMaskCount(model, i);
            if (maskCount == 0) continue;

            var maskBuf = Bytes.alloc(maskCount * 4);
            CubismAPI.getDrawableMasks(model, i, maskBuf);
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
                    isInverted = CubismAPI.getDrawableInvertedMask(model, dIdx);
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
        CubismAPI.setDeltaTime(elapsed);
        CubismAPI.update(model);
    }

    public function getContainer():L2DDisplayHandle
    {
        return renderer.getContainer();
    }

    // ===== Batch Building =====

    function buildBatches():Void
    {
        // 1 FFI call to get ALL drawable metadata (instead of ~1400 individual calls)
        CubismAPI.getDrawableBatchMetadata(model, _drawableCount, metadataBuf);

        activeBatchCount = 0;
        var totalDrawables = 0;

        // Parse metadata and mark visible drawables as vertex-dirty
        var vlLen = 0;
        for (i in 0..._drawableCount)
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
            CubismAPI.getDrawableVertexPositions(model, drawableIndex, vertexBuffers[drawableIndex]);

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
        if (texture == null) trace('[L2D WHITE] renderBatchWithShader: null texture | texIdx=$texIdx texturesLen=${textures.length} mg=$mg blend=$blendVal');

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

		// Fallback mask: look up RT first, only force shader path if RT is available
		var hasFallbackMask = (mg >= SHADER_MASK_MAX_GROUPS);
		var fmTex:L2DTextureHandle = null;
		var fmInv:Bool = false;
		if (hasFallbackMask)
		{
			var poolIdx = reusableMaskGroupMap.get(mg);
			var maskObj = (poolIdx != null && poolIdx >= 0) ? maskDisplayObjs[poolIdx] : null;
			fmTex = (maskObj != null) ? renderer.getFallbackMaskTexture(maskObj) : null;
			fmInv = maskGroupIsInverted[mg];
		}

		var needsShader = hasMask || useColor || !isFullOpacity || isMultiplyBlend || isScreenBlend || (hasFallbackMask && fmTex != null);

        if (needsShader)
        {
            renderer.drawShaderTexturedTriangles(
                obj, texture, reusableVerts, reusableUVs, reusableIndices,
                hasFallbackMask ? fmTex : (hasMask ? maskTextureHandle : null),
                hasFallbackMask ? [1.0, 0, 0, 0] : (hasMask ? maskGroupChannelFlag[mg] : null),
                hasFallbackMask ? [fbOffsetX, fbOffsetY] : (hasMask ? [maskScreenOffsetX, maskScreenOffsetY] : null),
                hasFallbackMask ? [fbWidth, fbHeight] : (hasMask ? [maskBitmapWidth * 1.0, maskBitmapHeight * 1.0] : null),
                hasFallbackMask ? fmInv : (hasMask ? maskGroupIsInverted[mg] : null),
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
        if (texture == null) trace('[L2D WHITE] drawDrawableWithShader: null texture | drawIdx=$drawableIndex texIdx=$texIdx texturesLen=${textures.length} mg=$mg blend=$blendVal');

        var hasMask = (mg >= 0 && mg < SHADER_MASK_MAX_GROUPS && maskGroupChannelFlag[mg] != null);

		// Fallback mask: look up RT first, only force shader path if RT is available
		var hasFallbackMask = (mg >= SHADER_MASK_MAX_GROUPS);
		var fmTex:L2DTextureHandle = null;
		var fmInv:Bool = false;
		if (hasFallbackMask)
		{
			var poolIdx = reusableMaskGroupMap.get(mg);
			var maskObj = (poolIdx != null && poolIdx >= 0) ? maskDisplayObjs[poolIdx] : null;
			fmTex = (maskObj != null) ? renderer.getFallbackMaskTexture(maskObj) : null;
			fmInv = maskGroupIsInverted[mg];
		}

		var needsShader = hasMask || useColor || !isFullOpacity || isMultiplyBlend || isScreenBlend || (hasFallbackMask && fmTex != null);

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
                hasFallbackMask ? fmTex : (hasMask ? maskTextureHandle : null),
                hasFallbackMask ? [1.0, 0, 0, 0] : (hasMask ? maskGroupChannelFlag[mg] : null),
                hasFallbackMask ? [fbOffsetX, fbOffsetY] : (hasMask ? [maskScreenOffsetX, maskScreenOffsetY] : null),
                hasFallbackMask ? [fbWidth, fbHeight] : (hasMask ? [maskBitmapWidth * 1.0, maskBitmapHeight * 1.0] : null),
                hasFallbackMask ? fmInv : (hasMask ? maskGroupIsInverted[mg] : null),
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
            CubismAPI.getDrawableVertexPositions(model, maskDrawableIndex, vertexBuffers[maskDrawableIndex]);
        }

        var vertBuf = vertexBuffers[maskDrawableIndex];
        var cachedIdx = cachedIndices[maskDrawableIndex];

        var vertices = new Array<Float>();
        vertices[vertCount * 2 - 1] = 0;
        var indices = new Array<Int>();
        indices[idxCount - 1] = 0;

        var minX:Float = 1e10, maxX:Float = -1e10;
        var minY:Float = 1e10, maxY:Float = -1e10;
        for (v in 0...vertCount)
        {
            var vx = vertBuf.getFloat(v * 8);
            var vy = vertBuf.getFloat(v * 8 + 4);
            var sx = (vx - modelCenterX) * scale + x;
            var sy = -(vy - modelCenterY) * scale + y;
            vertices[v * 2] = sx;
            vertices[v * 2 + 1] = sy;
            if (sx < minX) minX = sx;
            if (sx > maxX) maxX = sx;
            if (sy < minY) minY = sy;
            if (sy > maxY) maxY = sy;
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

                // Force-refresh: mask drawables are usually invisible, so buildBatches
                // never sets vertexDirty for them and fillVertexData never resets it,
                // leaving vertexBuffers with stale/zero data after the first frame.
                var needVertBytes = vertCount * 2 * 4;
                if (vertexBuffers[maskDIdx].length < needVertBytes)
                    vertexBuffers[maskDIdx] = Bytes.alloc(needVertBytes);
                CubismAPI.getDrawableVertexPositions(model, maskDIdx, vertexBuffers[maskDIdx]);

                var vertBuf = vertexBuffers[maskDIdx];
                var cachedIdx = cachedIndices[maskDIdx];

                var verts = new Array<Float>();
                var idxs = new Array<Int>();
                for (v in 0...vertCount)
                {
                    var vx = vertBuf.getFloat(v * 8);
                    var vy = vertBuf.getFloat(v * 8 + 4);
                    var sx = (vx - modelCenterX) * scale + x;
                    var sy = -(vy - modelCenterY) * scale + y;
                    verts.push(sx);
                    verts.push(sy);
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
            // Detect model transform changes (x/y/scale) — mask RT must be re-rendered
            if (!maskTextureDirty)
            {
                if (x != maskLastX || y != maskLastY || scale != maskLastScale)
                    maskTextureDirty = true;
            }
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
            {
                updateMaskTexture();
                maskLastX = x;
                maskLastY = y;
                maskLastScale = scale;
            }
        }

        // 3. Reset only display objects that were used last frame
        for (key in usedDisplayObjs.keys())
        {
            var obj:L2DDisplayHandle = null;
            if (key < 0)
            {
                // Negative key = mask pool object at index -(key+1)
                var poolIdx = -(key + 1);
                if (poolIdx < maskPoolSize)
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

        // 3.5 Pre-render fallback mask groups to RTs (so mask textures are available
        //     for shader sampling during batch rendering below).
        if (useShaderMask)
            preRenderFallbackMasks();

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

        // First-frame batch diagnostic
        if (firstFrame)
        {
            trace('[L2D RENDER] First frame: $activeBatchCount batches, useShaderMask=$useShaderMask texturesLen=${textures.length} texNulls=${textures.filter(t -> t == null).length}');
            for (b in 0...activeBatchCount)
            {
                var ti = bTexIdx[b];
                var hasTex = (ti >= 0 && ti < textures.length && textures[ti] != null);
                trace('[L2D RENDER]   batch#$b texIdx=$ti texValid=$hasTex mg=${bMaskGroup[b]} blend=${bBlendVal[b]} drawables=${bLen[b]} batchable=${bIsBatchable[b]} opacity=${bOpacity[b]} mulRGB=[${bMulColor[b][0]},${bMulColor[b][1]},${bMulColor[b][2]}] scrRGB=[${bScrColor[b][0]},${bScrColor[b][1]},${bScrColor[b][2]}]');
            }
        }

        // 5. Apply masks
        //    Shader path: Groups 0-2 handled by main mask RT sampled in shader.
        //    Fallback mask objects (populated by preRenderFallbackMasks with solid
        //    white shapes for Heaps RT capture) are hidden here so they don't
        //    appear as visible white overlays on top of the model.
        //    Non-shader path: use renderMasks for Sprite.mask fallback for all groups.
        if (!useShaderMask)
        {
            renderMasks(batchObjUsed);
        }
        else
        {
            // Hide fallback mask objects to prevent white overlay.
            // Mask shapes were already drawn (by preRenderFallbackMasks)
            // for Heaps RT capture; OpenFL ignores fallback RT anyway.
            for (mi in 0...maskPoolSize)
            {
                renderer.setVisible(maskDisplayObjs[mi], false);
            }
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

    function preRenderFallbackMasks():Void
    {
        if (maskGroupMaskIndices.length <= SHADER_MASK_MAX_GROUPS)
        {
            // Reset fallback mask dimensions to prevent cross-model contamination
            // when the renderer is shared across multiple L2DCore instances.
            renderer.setFallbackMaskDimensions(0, 0, 0, 0);
            fbOffsetX = 0; fbOffsetY = 0;
            fbWidth = 0; fbHeight = 0;
            return;
        }

        var maskObjUsed = 0;
        reusableMaskGroupMap.clear();

        // === Pass 1: compute AABB of all fallback mask shapes ===
        var fbMinX:Float = 1e10, fbMaxX:Float = -1e10;
        var fbMinY:Float = 1e10, fbMaxY:Float = -1e10;

        for (b in 0...activeBatchCount)
        {
            var mg = bMaskGroup[b];
            if (mg < SHADER_MASK_MAX_GROUPS) continue;
            if (reusableMaskGroupMap.exists(mg)) continue;

            reusableMaskGroupMap.set(mg, maskObjUsed);
            maskObjUsed++;

            for (maskDIdx in maskGroupMaskIndices[mg])
            {
                var vertCount = cachedVertCounts[maskDIdx];
                if (vertCount == 0) continue;

                // Fetch current vertex positions
                if (vertexDirty[maskDIdx])
                {
                    var needVertBytes = vertCount * 2 * 4;
                    if (vertexBuffers[maskDIdx].length < needVertBytes)
                        vertexBuffers[maskDIdx] = Bytes.alloc(needVertBytes);
                    CubismAPI.getDrawableVertexPositions(model, maskDIdx, vertexBuffers[maskDIdx]);
                }

                var vertBuf = vertexBuffers[maskDIdx];
                for (v in 0...vertCount)
                {
                    var vx = vertBuf.getFloat(v * 8);
                    var vy = vertBuf.getFloat(v * 8 + 4);
                    var sx = (vx - modelCenterX) * scale + x;
                    var sy = -(vy - modelCenterY) * scale + y;
                    if (sx < fbMinX) fbMinX = sx;
                    if (sx > fbMaxX) fbMaxX = sx;
                    if (sy < fbMinY) fbMinY = sy;
                    if (sy > fbMaxY) fbMaxY = sy;
                }
            }
        }

        // Set fallback mask dimensions on renderer (enlarged to cover all mask shapes)
        var fbW = fbMaxX - fbMinX;
        var fbH = fbMaxY - fbMinY;
        if (fbW <= 0 || fbH <= 0) return;
        // Use ceil'd dimensions so u_maskScale matches the actual RT physical size
        // (drawSolidTriangles uses Math.ceil(fbMaskWidth) * SSAA).
        // Without this, UV computation is off by ceil(fbW)/fbW ≈ 0.7%.
        var fbCeilW = Math.ceil(fbW);
        var fbCeilH = Math.ceil(fbH);
        renderer.setFallbackMaskDimensions(fbMinX, fbMinY, fbCeilW, fbCeilH);
        fbOffsetX = fbMinX;
        fbOffsetY = fbMinY;
        fbWidth = fbCeilW;
        fbHeight = fbCeilH;

        // === Pass 2: render fallback mask shapes with corrected offset/dimensions ===
        maskObjUsed = 0;
        reusableMaskGroupMap.clear();

        for (b in 0...activeBatchCount)
        {
            var mg = bMaskGroup[b];
            if (mg < SHADER_MASK_MAX_GROUPS) continue;

            if (reusableMaskGroupMap.exists(mg)) continue;

            if (maskObjUsed >= maskPoolSize)
            {
                trace('[L2D FALLBACK] MASK_POOL_SIZE ($maskPoolSize) exceeded at group $mg in preRender');
                continue;
            }

            var poolIdx = maskObjUsed;
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
                if (maskObjUsed >= maskPoolSize)
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

            renderer.setMask(obj, maskDisplayObjs[poolIdx], maskGroupIsInverted[mg]);
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
                    renderer.setMask(obj, maskDisplayObjs[poolIdx], maskGroupIsInverted[mg]);
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
            CubismAPI.releaseModel(model);
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
        return CubismAPI.startMotion(model, group, no, priority);
    }

    public function startIdleMotion():Int
    {
        if (model.isNull()) return -1;
        return CubismAPI.startRandomMotion(model, 'Idle', 1);
    }

    public function setExpression(id:String):Void
    {
        if (model.isNull()) return;
        CubismAPI.setExpression(model, id);
    }

    public function setRandomExpression():Void
    {
        if (model.isNull()) return;
        CubismAPI.setRandomExpression(model);
    }

    // ===== File-path Expression Support (VTuber-style models) =====

    /**
     * Load a .exp3.json file by path and cache its parameter overrides.
     * Call this once per expression file before using applyExpressionFile/toggleExpressionFile.
     * Returns the number of parameters loaded, or -1 if the file couldn't be parsed.
     */
    public function loadExpressionFile(filePath:String):Int
    {
        #if sys
        if (vtubeExpressionCache.exists(filePath))
            return vtubeExpressionCache.get(filePath).length;

        try
        {
            var content = File.getContent(filePath);
            var json:Dynamic = Json.parse(content);
            var params:Array<Dynamic> = json.Parameters;
            var parsed:Array<{paramIndex:Int, value:Float, blend:String}> = [];

            for (p in cast(params, Array<Dynamic>))
            {
                var id:String = p.Id;
                var val:Float = p.Value;
                var blend:String = (p.Blend != null) ? p.Blend : "Add";
                var idx = CubismAPI.findParameterIndex(model, id);
                if (idx >= 0)
                {
                    parsed.push({paramIndex: idx, value: val, blend: blend});
                }
                else
                {
                    trace('[L2DCore] Expression param not found: $id (from $filePath)');
                }
            }
            vtubeExpressionCache.set(filePath, parsed);
            return parsed.length;
        }
        catch (e:Dynamic)
        {
            trace('[L2DCore] Failed to load expression file: $filePath ($e)');
            return -1;
        }
        #else
        return -1;
        #end
    }

    /**
     * Apply a previously loaded expression file's parameters to the model.
     * Blend modes are respected: "Add", "Multiply", "Overwrite".
     * Call removeExpressionFile() or toggleExpressionFile() to deactivate.
     */
    public function applyExpressionFile(filePath:String):Void
    {
        if (model.isNull()) return;

        if (!vtubeExpressionCache.exists(filePath))
        {
            var count = loadExpressionFile(filePath);
            if (count <= 0) return;
        }

        var params = vtubeExpressionCache.get(filePath);
        if (params == null || params.length == 0) return;

        for (p in params)
        {
            var cur = CubismAPI.getParameterValue(model, p.paramIndex);
            var newVal:Float;
            switch (p.blend)
            {
                case "Add":       newVal = cur + p.value;
                case "Multiply":  newVal = cur * p.value;
                case "Overwrite": newVal = p.value;
                default:          newVal = cur + p.value;
            }
            CubismAPI.setParameterValue(model, p.paramIndex, newVal, 1.0);
        }

        if (activeVTubeExpressions.indexOf(filePath) < 0)
            activeVTubeExpressions.push(filePath);
    }

    /**
     * Remove a previously applied expression file from the active list.
     * The parameter values will be recalculated by the next update() cycle.
     */
    function removeExpressionFile(filePath:String):Void
    {
        activeVTubeExpressions.remove(filePath);
    }

    /**
     * Toggle an expression file on/off. If active, removes it; otherwise applies it.
     */
    public function toggleExpressionFile(filePath:String):Void
    {
        if (activeVTubeExpressions.indexOf(filePath) >= 0)
            removeExpressionFile(filePath);
        else
            applyExpressionFile(filePath);
    }

    /** Check if a file-path expression is currently active. */
    public function isExpressionFileActive(filePath:String):Bool
    {
        return activeVTubeExpressions.indexOf(filePath) >= 0;
    }

    /** Remove all active file-path expressions. */
    public function clearFileExpressions():Void
    {
        while (activeVTubeExpressions.length > 0)
            removeExpressionFile(activeVTubeExpressions[0]);
    }

    // ===== File-path Motion Support (VTuber-style models) =====

    /**
     * Start a motion from a file path (.motion3.json).
     *
     * Loads and plays a standalone motion file that is NOT registered
     * in model3.json's FileReferences.Motions. Used for VTuber-style
     * models where motions are standalone files referenced from
     * .vtube.json Hotkeys (Action: "TriggerAnimation").
     *
     * @param filePath Absolute or relative path to .motion3.json.
     * @param priority Motion priority (0=idle, 1=normal, 2=force). Default 2.
     * @return Motion handle (>0 on success), or -1 if model is null or the file can't be loaded.
     */
    public function startMotionFile(filePath:String, priority:Int = 2):Int
    {
        if (model.isNull()) return -1;
        return CubismAPI.startMotionFile(model, filePath, priority);
    }

    /**
     * Stop all motions on the native motion queue immediately (no fadeout).
     * Used before force-switching to idle to prevent stale parameter values
     * from old motions leaking into the next parameter save cycle.
     */
    public function stopAllMotions():Void
    {
        if (model.notNull()) CubismAPI.stopAllMotions(model);
    }

    public function hitTest(areaName:String, px:Float, py:Float):Bool
    {
        if (model.isNull()) return false;
        return CubismAPI.hitTest(model, areaName, px - x, py - y);
    }

    public function setDragging(screenX:Float, screenY:Float):Void
    {
        if (model.isNull()) return;
        var modelX = (screenX - x) / scale + modelCenterX;
        var modelY = -((screenY - y) / scale) + modelCenterY;
        var normX = (modelX - modelCenterX) / (modelWidth / 2);
        var normY = (modelY - modelCenterY) / (modelHeight / 2);
        CubismAPI.setDragging(model, normX, normY);
    }

    public function getCanvasWidth():Float
    {
        if (model.isNull()) return 0;
        return CubismAPI.getCanvasWidth(model);
    }

    public function getCanvasHeight():Float
    {
        if (model.isNull()) return 0;
        return CubismAPI.getCanvasHeight(model);
    }

    // ===== Framework Behavior Control =====

    public function setBreathEnabled(enabled:Bool):Void
    {
        breathEnabled = enabled;
        if (model.notNull()) CubismAPI.setBreathEnabled(model, enabled);
    }

    public function setEyeBlinkEnabled(enabled:Bool):Void
    {
        eyeBlinkEnabled = enabled;
        if (model.notNull()) CubismAPI.setEyeBlinkEnabled(model, enabled);
    }

    public function setExpressionEnabled(enabled:Bool):Void
    {
        expressionEnabled = enabled;
        if (model.notNull()) CubismAPI.setExpressionEnabled(model, enabled);
    }

    public function setLookEnabled(enabled:Bool):Void
    {
        lookEnabled = enabled;
        if (model.notNull()) CubismAPI.setLookEnabled(model, enabled);
    }

    public function setPhysicsEnabled(enabled:Bool):Void
    {
        physicsEnabled = enabled;
        if (model.notNull()) CubismAPI.setPhysicsEnabled(model, enabled);
    }

    public function setLipSyncEnabled(enabled:Bool):Void
    {
        lipSyncEnabled = enabled;
        if (model.notNull()) CubismAPI.setLipSyncEnabled(model, enabled);
    }

    public function setPoseEnabled(enabled:Bool):Void
    {
        poseEnabled = enabled;
        if (model.notNull()) CubismAPI.setPoseEnabled(model, enabled);
    }

    /**
     * Set external lip sync value (0.0~1.0 for mouth open amount).
     * Pass a negative value to revert to wav file handler mode.
     */
    public function setLipSyncValue(value:Float):Void
    {
        if (model.notNull()) CubismAPI.setLipSyncValue(model, value);
    }

    // ===== Parts API =====

    public function getPartCount():Int
    {
        if (model.isNull()) return 0;
        return CubismAPI.getPartCount(model);
    }

    public function findPartIndex(name:String):Int
    {
        if (model.isNull()) return -1;
        return CubismAPI.findPartIndex(model, name);
    }

    public function getPartId(partIndex:Int):String
    {
        if (model.isNull()) return "";
        return CubismAPI.getPartId(model, partIndex);
    }

    public function getPartOpacity(partIndex:Int):Float
    {
        if (model.isNull()) return 0;
        return CubismAPI.getPartOpacity(model, partIndex);
    }

    public function setPartOpacity(partIndex:Int, opacity:Float):Void
    {
        if (model.notNull()) CubismAPI.setPartOpacity(model, partIndex, opacity);
    }

    public function setPartOpacityByName(name:String, opacity:Float):Void
    {
        var idx = findPartIndex(name);
        if (idx >= 0) setPartOpacity(idx, opacity);
    }

    public function resetPose():Void
    {
        if (model.notNull()) CubismAPI.resetPose(model);
    }

    // ===== Physics Runtime Tuning =====
    // Wraps CubismPhysics SDK APIs (SetOptions/GetOptions/Reset/Stabilization)
    // so the Haxe layer can adjust gravity/wind at runtime and reset/stabilize
    // the pendulum simulation without reloading the model.

    /**
     * Set runtime gravity/wind vectors used by the physics pendulum simulation.
     * These override the EffectiveForces values parsed from physics3.json.
     * Default gravity is (0, -1); default wind is (0, 0).
     **/
    public function setPhysicsOptions(gravityX:Float, gravityY:Float, windX:Float, windY:Float):Void
    {
        if (model.notNull()) CubismAPI.setPhysicsOptions(model, gravityX, gravityY, windX, windY);
    }

    /**
     * Read the currently applied gravity/wind from the native physics engine.
     * Returns `{gx, gy, wx, wy}`; returns defaults `{0, -1, 0, 0}` if no model.
     **/
    public function getPhysicsOptions():{gx:Float, gy:Float, wx:Float, wy:Float}
    {
        if (model.isNull()) return {gx: 0.0, gy: -1.0, wx: 0.0, wy: 0.0};
        var buf = Bytes.alloc(16);
        CubismAPI.getPhysicsOptions(model, buf);
        return {
            gx: buf.getFloat(0),
            gy: buf.getFloat(4),
            wx: buf.getFloat(8),
            wy: buf.getFloat(12)
        };
    }

    /**
     * Reset physics pendulum state and restore default gravity/wind options.
     * Useful after large parameter jumps to avoid residual oscillation.
     * Note: this also resets gravity/wind to defaults (0,-1,0,0); re-apply
     * custom options afterwards if needed.
     **/
    public function resetPhysics():Void
    {
        if (model.notNull()) CubismAPI.resetPhysics(model);
    }

    /**
     * Stabilize physics with current parameter values (single-shot settle).
     * Computes a steady-state for the pendulum so the model does not swing
     * from initial conditions. Useful right after model load.
     **/
    public function stabilizePhysics():Void
    {
        if (model.notNull()) CubismAPI.stabilizePhysics(model);
    }

    // ===== Motion Event Polling =====

    public function pollMotionEvents(outBuf:Bytes, bufLen:Int):Int
    {
        if (model.isNull()) return 0;
        return CubismAPI.pollMotionEvents(model, outBuf, bufLen);
    }

    public function clearMotionEvents():Void
    {
        if (model.notNull()) CubismAPI.clearMotionEvents(model);
    }

    // ===== Moc Version Checking =====

    public static function getCoreVersion():Int
        return CubismAPI.getCoreVersion();

    public static function getLatestMocVersion():Int
        return CubismAPI.getLatestMocVersion();

    public static function hasMocConsistency(mocFilePath:String):Bool
        return CubismAPI.hasMocConsistency(mocFilePath);
}