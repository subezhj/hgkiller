#include "../src/HGGeometry.h"
#include <assert.h>
#include <stdio.h>
static int near(double a, double b) { return fabs(a - b) < 0.001; }
int main(void) {
    HGRect tab = HGGlassRect(402, 874, 34);
    assert(near(tab.x, 24) && near(tab.y, 778));
    assert(near(tab.width, 354) && near(tab.height, 54));
    assert(tab.y + tab.height <= 874 - 34);
    HGRect compact = HGGlassRect(320, 568, 0);
    assert(near(compact.width, 288) && compact.y >= 0);
    HGRect landscape = HGVideoRect(402, 874, 1920, 1080, 1);
    assert(near(landscape.width, 402));
    assert(near(landscape.height, 226.125));
    assert(near(landscape.y, (874 - 226.125) / 2));
    HGRect portraitFit = HGVideoRect(402, 874, 1080, 1920, 0);
    assert(portraitFit.width <= 402 && portraitFit.height <= 874);
    assert(near(portraitFit.width / portraitFit.height, 1080.0 / 1920.0));
    HGRect portraitFill = HGVideoRect(402, 874, 1080, 1920, 1);
    assert(portraitFill.width >= 402 && portraitFill.height >= 874);
    assert(near(portraitFill.height, 874) && portraitFill.x < 0);
    HGRect lowPortrait = HGVideoRect(402, 874, 1080, 1440, 1);
    assert(near(lowPortrait.width, 402) && lowPortrait.height < 874);
    HGRect invalid = HGVideoRect(402, 874, 0, 0, 1);
    assert(invalid.width == 0 && invalid.height == 0);
    assert(near(HGInteractionPitch(46, .55), 44));
    assert(near(HGInteractionPitch(62, .8), 49.6));
    assert(near(HGPageOffset(784 * 3, 784, 874, 10), 874 * 3));
    assert(near(HGPageOffset(10000, 784, 874, 3), 874 * 2));
    assert(HGPageOffset(-100, 784, 874, 3) == 0);
    assert(HGPageOffset(100, 784, 874, 0) == 0);
    puts("Geometry tests passed: safe area, aspect ratio, hit target and page alignment.");
    return 0;
}
