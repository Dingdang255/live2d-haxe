package live2d.cubism.backend.heaps;

#if heaps

import hxsl.Shader;

/**
 * Unified Heaps shader for Live2D rendering.
 *
 * Supports three features that can be independently enabled:
 *   1. Multiply/Screen color blending (u_useColor > 0.5)
 *   2. Mask texture sampling (u_useMask > 0.5)
 *   3. Per-drawable opacity (u_opacity < 1.0)
 *
 * Uses hxsl SRC syntax. Priority is set to 200 so this shader's fragment()
 * runs BEFORE Base2d.fragment() (priority=100). This way we can modify
 * `pixelColor` and Base2d will write `output.color = pixelColor` with the
 * modified value.
 *
 * Vertex stage:
 *   1. Base2d.__init__ sets absolutePosition, pixelColor (texture * color)
 *   2. CubismHeapsShader.vertex: compute v_maskUV from absolutePosition
 *   3. Base2d.vertex: transform absolutePosition to clip space
 * Fragment stage (by priority desc):
 *   1. CubismHeapsShader.fragment: apply color/mask/opacity to pixelColor
 *   2. Base2d.fragment: output.color = pixelColor
 */
class CubismHeapsShader extends Shader
{
    static var SRC = {
        @param var u_maskTexture : Sampler2D;
        @param var u_channelFlag : Vec4;
        @param var u_maskOffset : Vec2;
        @param var u_maskScale : Vec2;
        @param var u_isInverted : Float;
        @param var u_useMask : Float;
        @param var u_mulColor : Vec3;
        @param var u_scrColor : Vec3;
        @param var u_useColor : Float;
        @param var u_opacity : Float;

        // Shared variables from Base2d (read-only here)
        var absolutePosition : Vec4;
        var pixelColor : Vec4;

        // Explicit varying for mask UV — computed in vertex stage, interpolated in fragment.
        // Using vertex() instead of __init__() because vertex() is guaranteed to run in the
        // vertex stage, and absolutePosition is definitely available there (Base2d.vertex
        // reads it). In __init__, the stage assignment depends on Linker dependency analysis.
        @var var v_maskUV : Vec2;

        function vertex() {
            v_maskUV = (absolutePosition.xy - u_maskOffset) / u_maskScale;
        }

        function fragment() {
            // Multiply/Screen color blending (only when u_useColor > 0.5)
            if (u_useColor > 0.5) {
                pixelColor.rgb = pixelColor.rgb * u_mulColor + u_scrColor * (1.0 - pixelColor.rgb);
            }

            // Mask texture sampling
            // Heaps BlendMode.Alpha = SrcAlpha * Src + (1-SrcA) * Dst (non-premultiplied)
            // Only scale alpha; RGB scaling would cause double-darkening during blend.
            if (u_useMask > 0.5) {
                var clipMask = u_maskTexture.get(v_maskUV);
                var maskVal = dot(clipMask, u_channelFlag);
                maskVal = mix(maskVal, 1.0 - maskVal, u_isInverted);
                pixelColor.a *= maskVal;
            }

            // Per-drawable opacity: only scale alpha (non-premultiplied blend mode)
            pixelColor.a *= u_opacity;
        }
    };

    public function new()
    {
        super();
        // Run before Base2d (priority=100) so we can modify pixelColor
        setPriority(200);
        // Default uniform values
        u_channelFlag.set(1, 0, 0, 0);
        u_maskOffset.set(0, 0);
        u_maskScale.set(1, 1);
        u_isInverted = 0;
        u_useMask = 0;
        u_mulColor.set(1, 1, 1);
        u_scrColor.set(0, 0, 0);
        u_useColor = 0;
        u_opacity = 1;
    }
}

#end
