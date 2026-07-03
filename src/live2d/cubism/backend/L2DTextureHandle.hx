package live2d.cubism.backend;

/**
 * Opaque handle for a loaded texture.
 * Backend implementations cast this to their internal texture type.
 */
abstract L2DTextureHandle(Dynamic) from Dynamic to Dynamic {}
