#ifndef HG_GEOMETRY_H
#define HG_GEOMETRY_H
#include <math.h>
typedef struct { double x, y, width, height; } HGRect;
static inline double HGClampTabHeight(double height) {
    return isfinite(height) ? fmax(44.0, fmin(80.0, height)) : 54.0;
}
static inline HGRect HGGlassRectWithHeight(double width, double height, double safeBottom, double barHeight) {
    double inset = width < 340.0 ? 16.0 : 24.0;
    barHeight = HGClampTabHeight(barHeight);
    HGRect rect = { inset, fmax(0.0, height - safeBottom - barHeight - 8.0),
                    fmax(1.0, width - inset * 2.0), barHeight };
    return rect;
}
static inline HGRect HGGlassRect(double width, double height, double safeBottom) {
    return HGGlassRectWithHeight(width, height, safeBottom, 54.0);
}
static inline HGRect HGTabButtonRect(double width, double height, unsigned long index, unsigned long count) {
    double padding = 6.0, itemWidth = fmax(1.0, (width - padding * 2.0) / fmax(1.0, (double)count));
    HGRect rect = { padding + index * itemWidth, 0.0, itemWidth, height };
    return rect;
}
static inline HGRect HGVideoRect(double width, double height, double sourceWidth,
                                double sourceHeight, int fillPortrait) {
    if (width <= 0 || height <= 0 || sourceWidth <= 0 || sourceHeight <= 0) {
        HGRect empty = { 0, 0, 0, 0 }; return empty;
    }
    double scale = fmin(width / sourceWidth, height / sourceHeight);
    if (fillPortrait && sourceHeight / sourceWidth >= 1.60) scale = fmax(width / sourceWidth, height / sourceHeight);
    double w = sourceWidth * scale, h = sourceHeight * scale;
    HGRect rect = { (width - w) / 2.0, (height - h) / 2.0, w, h };
    return rect;
}
static inline double HGInteractionPitch(double sourceHeight, double scale) {
    return fmax(44.0, sourceHeight * scale);
}
static inline double HGPageOffset(double oldOffset, double oldHeight, double newHeight, unsigned long count) {
    if (count == 0 || oldHeight <= 0 || newHeight <= 0) return 0;
    double page = fmax(0.0, fmin((double)count - 1.0, round(oldOffset / oldHeight)));
    return page * newHeight;
}
#endif
