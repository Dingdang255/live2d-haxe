package live2d.cubism.backend.heaps;

#if heaps

import hxsl.Shader;

/**
 * Solid-color fill shader for mask RT rendering.
 *
 * Ignores texture sampling and outputs a flat `u_color` per fragment.
 * Priority 200 ensures fragment() runs before Base2d.fragment() (priority 100),
 * so `pixelColor` is set to `u_color` and Base2d writes `output.color = pixelColor`.
 *
 * Used by HeapsRenderer.renderMaskToBitmapData to draw mask shapes into the
 * mask render-target texture (one color per mask group: R/G/B channels).
 */
class CubismMaskShader extends Shader
{
    static var SRC = {
        @param var u_color : Vec4;

        var pixelColor : Vec4;

        function fragment() {
            pixelColor = u_color;
        }
    };

    public function new()
    {
        super();
        setPriority(200);
        u_color.set(1, 1, 1, 1);
    }
}

#end
