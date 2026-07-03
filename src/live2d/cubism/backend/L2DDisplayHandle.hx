package live2d.cubism.backend;

/**
 * Opaque handle for a display object (sprite, graphics context, etc).
 * Backend implementations cast this to their internal display type.
 */
abstract L2DDisplayHandle(Dynamic) from Dynamic to Dynamic {}
