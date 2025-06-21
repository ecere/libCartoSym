public import IMPORT_STATIC "ecrt"

private:

public define wgs84InvFlattening = 298.257223563;
public define wgs84Major = 6378137.0;  // Meters
define wgs84Minor = wgs84Major - (wgs84Major / wgs84InvFlattening); // 6356752.3142451792955399
public define paperRes = Meters { 0.00028 };       // 0.28 mm/pixels -- following standard WMS 1.3.0 [OGC 06-042], SE and WMTS

// These methods and definitions currently imply the GNOSIS Global Grid:
define firstZoomLevelTileDistance = (Meters)(wgs84Major * firstZoomLevelRadians);
define firstZoomLevelRadians = Pi/2;
define firstZoomLevelDegrees = 90;
define tilePixels = 256.0;
public double scaleDenominatorFromLevel(int level)
{
   return firstZoomLevelTileDistance / ((1 << level) * tilePixels * paperRes);
}

public int levelFromScaleDenominator(double denominator)
{
   return log2i((uint)ceil(firstZoomLevelTileDistance / (denominator * tilePixels * paperRes) - 1E-7));
}

public double metersPerPixelFromLevel(int level)
{
   return firstZoomLevelTileDistance / (tilePixels * (1 << level));
}

public int levelFromMetersPerPixel(double metersPerPixel)
{
   return log2i((uint)ceil(firstZoomLevelTileDistance / (metersPerPixel * tilePixels) - 1E-7));
}
