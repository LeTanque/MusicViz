#include "projectm_shim.h"
#include <OpenGL/gl3.h>

void projectm_read_pixels(unsigned char *pixels, int width, int height) {
    glReadPixels(0, 0, width, height, GL_RGBA, GL_UNSIGNED_BYTE, pixels);
}
