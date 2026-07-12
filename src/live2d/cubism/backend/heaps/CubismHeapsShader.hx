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
 * Blend-mode-specific handling:
 *
 *   Multiply (convertPremul=0): GPU blend is dst * src.rgb (GL_DST_COLOR, GL_ZERO,
 *     alpha ignored). Premultiplied→non-premultiplied conversion always happens
 *     FIRST (even without mask), so transparent areas become white (= no multiply
 *     effect). Mask then lerps RGB toward white. Alpha set to 1.
 *
 *   Alpha/Add (convertPremul=1): GPU blends use src.a to scale RGB. Mask scales
 *     alpha only; premul→non-premul conversion happens at the end so the GPU
 *     receives non-premultiplied RGB with correctly-scaled alpha.
 *
 *   Screen (convertPremul=0): GPU blend is src + (1-src.rgb)*dst. Same as
 *     Multiply path for premul conversion and mask.
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
        @param var u_convertPremul : Float;

        var absolutePosition : Vec4;
        var pixelColor : Vec4;

        @var var v_maskUV : Vec2;

        function vertex() {
            v_maskUV = (absolutePosition.xy - u_maskOffset) / u_maskScale;
        }

        function fragment() {
            // Multiply/Screen color blending (expects premultiplied values)
            if (u_useColor > 0.5) {
                pixelColor.rgb = pixelColor.rgb * u_mulColor + u_scrColor * (1.0 - pixelColor.rgb);
            }

            // Multiply/Screen: always convert premul -> non-premul.
            // Multiply blend (GL_DST_COLOR,GL_ZERO) ignores alpha, so we MUST
            // convert or transparent premul pixels (rgb≈0) would multiply dst to black.
            // Transparent areas output white = no multiply effect.
            if (u_convertPremul < 0.5) {
                if (pixelColor.a > 0.001) {
                    pixelColor.rgb /= pixelColor.a;
                } else {
                    pixelColor.rgb = vec3(1.0, 1.0, 1.0);
                }
                pixelColor.a = 1.0;
            }

            // Mask texture sampling.
            if (u_useMask > 0.5) {
                var clipMask = u_maskTexture.get(v_maskUV);
                var maskVal = dot(clipMask, u_channelFlag);
                maskVal = mix(maskVal, 1.0 - maskVal, u_isInverted);

                if (u_convertPremul < 0.5) {
                    // Multiply/Screen: mask lerps non-premul RGB toward white
                    // (mask=0 -> white -> no multiply/screen effect)
                    pixelColor.rgb = mix(vec3(1.0, 1.0, 1.0), pixelColor.rgb, maskVal);
                } else {
                    // Alpha/Add: mask scales alpha only.
                    // GPU blend uses src.a to scale RGB, so mask=0 -> alpha=0 -> no contribution.
                    pixelColor.a *= maskVal;
                }
            }

            // Per-drawable opacity.
            // For Multiply/Screen: alpha was set to 1 above, so opaque non-premul pixels
            //   scale uniformly — opacity just fades alpha toward 0. Correct.
            // For Alpha/Add: pixelColor is still premultiplied, so we must scale
            //   RGB along with alpha to keep the premul ratio consistent. Otherwise
            //   the premul→non-premul division below would amplify RGB (white bug).
            if (u_opacity < 0.999) {
                pixelColor.a *= u_opacity;
                if (u_convertPremul > 0.5) {
                    pixelColor.rgb *= u_opacity;
                }
            }

            // Convert premultiplied -> non-premultiplied for Alpha/Add.
            // Multiply already converted above.
            if (u_convertPremul > 0.5 && pixelColor.a > 0.0) {
                pixelColor.rgb /= pixelColor.a;
            }

        }
    };

    public function new()
    {
        super();
        setPriority(200);
        u_channelFlag.set(1, 0, 0, 0);
        u_maskOffset.set(0, 0);
        u_maskScale.set(1, 1);
        u_isInverted = 0;
        u_useMask = 0;
        u_mulColor.set(1, 1, 1);
        u_scrColor.set(0, 0, 0);
        u_useColor = 0;
        u_opacity = 1;
        u_convertPremul = 1; // Alpha/Add by default
    }
}

#end
