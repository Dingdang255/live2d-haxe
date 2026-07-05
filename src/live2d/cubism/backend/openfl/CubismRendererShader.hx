package live2d.cubism.backend.openfl;

#if openfl

import openfl.display.GraphicsShader;

/**
 * Unified GraphicsShader for Live2D rendering.
 *
 * Supports three features that can be independently enabled:
 *   1. Multiply/Screen color blending (useColor)
 *   2. Mask texture sampling (useMask)
 *   3. Per-drawable opacity (opacity < 1.0)
 *
 * Uses @:glFragmentBody to insert custom processing after OpenFL's texture sampling.
 * GLSL ES 2.0 compatible (WebGL1 / OpenGL ES2).
 */
class CubismRendererShader extends GraphicsShader
{
    @:glVertexHeader("
        varying vec2 v_maskUV;
        uniform vec2 u_maskOffset;
        uniform vec2 u_maskScale;
    ")
    @:glVertexBody("
        v_maskUV = (openfl_Position.xy - u_maskOffset) / u_maskScale;
    ")
    @:glFragmentHeader("
        varying vec2 v_maskUV;
        uniform sampler2D u_maskTexture;
        uniform vec4 u_channelFlag;
        uniform float u_isInverted;
        uniform float u_useMask;
        uniform vec3 u_mulColor;
        uniform vec3 u_scrColor;
        uniform float u_useColor;
        uniform float u_opacity;
    ")
    @:glFragmentBody("
        // Multiply/Screen color blending (only when u_useColor > 0)
        if (u_useColor > 0.5) {
            gl_FragColor.rgb = gl_FragColor.rgb * u_mulColor + u_scrColor * (1.0 - gl_FragColor.rgb);
        }

        // Mask texture sampling
        if (u_useMask > 0.5) {
            vec4 clipMask = texture2D(u_maskTexture, v_maskUV);
            float maskVal = dot(clipMask, u_channelFlag);
            maskVal = mix(maskVal, 1.0 - maskVal, u_isInverted);
            gl_FragColor.a *= maskVal;
            gl_FragColor.rgb *= maskVal;
        }

        // Per-drawable opacity (premultiplied alpha: must scale RGB too)
        gl_FragColor *= u_opacity;
    ")
    public function new()
    {
        super();
        // Set default values
        data.u_maskOffset.value = [0.0, 0.0];
        data.u_maskScale.value = [1.0, 1.0];
        data.u_channelFlag.value = [1.0, 0.0, 0.0, 0.0];
        data.u_isInverted.value = [0.0];
        data.u_useMask.value = [0.0];
        data.u_mulColor.value = [1.0, 1.0, 1.0];
        data.u_scrColor.value = [0.0, 0.0, 0.0];
        data.u_useColor.value = [0.0];
        data.u_opacity.value = [1.0];
    }
}

#end