public import IMPORT_STATIC "ecrt"

import "Geometry"

public enum WKBGeometryBaseType : uint32
{
   geometry           = 0x0000,
   point              = 0x0001,
   lineString         = 0x0002,
   polygon            = 0x0003,
   multiPoint         = 0x0004,
   multiLineString    = 0x0005,
   multiPolygon       = 0x0006,
   geometryCollection = 0x0007,
   circularString     = 0x0008,
   compoundCurve      = 0x0009,
   curvePolygon       = 0x0010,
   multiCurve         = 0x0011,
   multiSurface       = 0x0012,
   curve              = 0x0013,
   surface            = 0x0014,
   polyhedralSurface  = 0x0015,
   tin                = 0x0016,
   triangle           = 0x0017,
   circle             = 0x0018,
   geodesicString     = 0x0019,
   ellipticalCurve    = 0x0020,
   nurbsCurve         = 0x0021,
   clothoid           = 0x0022,
   spiralCurve        = 0x0023,
   compoundSurface    = 0x0024,
   brepSolid          = 0x0025,
   affinePlacement    = 0x0102,
};

public class WKBGeometryType : uint32
{
public:
   WKBGeometryBaseType type:8: 0;
   bool                   z:1:12;
   bool                   m:1:13;
};

static bool readPointWKB(File f, GeoPoint point, double * measure, double * depth)
{
   double x, y;

   f.Get(x);
   f.Get(y);
   if(depth)   { double z; f.Get(z); *depth = z; }
   if(measure) { double m; f.Get(m); *measure = m; }

   point = { x, y };
   return true;
}

static bool readLineStringWKB(File f, LineString line)
{
   uint32 count;
   Array<GeoPoint> points = null;

   f.Get(count);

   if(count)
   {
      int i;

      points = { size = count };

      for(i = 0; i < count; i++)
      {
         char byteOrder = 0;
         if(f.Getc(&byteOrder))
         {
            WKBGeometryType pType = 0;
            f.Get(pType);
            if(pType.type == WKBGeometryBaseType::point)
               readPointWKB(f, points[i], null, null);
         }
      }
   }

   line.points = points;
   return true;
}

static bool readPolygonWKB(File f, Polygon poly)
{
   uint32 cCount = 0;
   Array<PolygonContour> contours = null;

   f.Get(cCount);

   if(cCount)
   {
      int i;

      contours = { size = cCount };

      for(i = 0; i < cCount; i++)
      {
         uint32 count;
         Array<GeoPoint> points = null;
         double * depths = null;
         double * measures = null;

         f.Get(count);

         if(count)
         {
            int j;

            points = { size = count };

            for(j = 0; j < count; j++)
            {
               char byteOrder = 0;
               if(f.Getc(&byteOrder))
               {
                  WKBGeometryType pType = 0;
                  f.Get(pType);
                  if(pType.z && !depths)
                     depths = new0 double[count];
                  if(pType.m && !measures)
                     depths = new0 double[count];
                  if(pType.type == WKBGeometryBaseType::point)
                     readPointWKB(f, points[j], measures ? measures + j : null, depths ? depths + j : null);
               }
            }
         }

         // TODO: Verify clockwiseness? (Tricky in 3D for a single polygon!...)
         contours[i] = PolygonContour { points = points, depths = (Meters *)depths, measures = measures, isInner = i > 1, isClockwise = i > 1 };
      }
   }

   poly.contours = contours;
   return true;
}

public void readGeometryWKB(File f, Geometry geometry)
{
   char byteOrder = 0;
   if(f && f.Getc(&byteOrder))
   {
      WKBGeometryType gType = 0;

      f.Get(gType);
      switch(gType.type)
      {
         case point:
         case multiPoint:
         {
            GeoPoint * points;
            uint32 nPoints = 1, i;

            if(gType.type == multiPoint)
            {
               f.Get(nPoints);
               geometry.multiPoint = Array<GeoPoint> { size = nPoints };
               points = ((Array<GeoPoint>)geometry.multiPoint).array;
            }
            else
               points = &geometry.point;
            geometry.type = gType.type == point ? point : multiPoint;

            for(i = 0; i < nPoints; i++)
            {
               if(gType.type == multiPoint)
               {
                  char byteOrder = 0;
                  if(f.Getc(&byteOrder))
                  {
                     WKBGeometryType pType = 0;
                     f.Get(pType);
                     if(pType.type == WKBGeometryBaseType::point)
                        ;
                  }
               }
               readPointWKB(f, points[i], null, null);
            }
            break;
         }
         case lineString:
         case multiLineString:
         {
            LineString * lines;
            uint32 nLines = 1, i;

            if(gType.type == multiLineString)
            {
               f.Get(nLines);
               geometry.multiLineString = Array<LineString> { size = nLines };
               lines = ((Array<LineString>)geometry.multiLineString).array;
            }
            else
               lines = &geometry.lineString;

            geometry.type = gType.type == lineString ? lineString : multiLineString;

            for(i = 0; i < nLines; i++)
            {
               if(gType.type == multiLineString)
               {
                  char byteOrder = 0;

                  if(f && f.Getc(&byteOrder))
                  {
                     WKBGeometryType gType = 0;

                     f.Get(gType);
                     if(gType.type == lineString)
                        ;
                  }
               }
               readLineStringWKB(f, lines[i]);
            }
            break;
         }
         case polygon:
         case multiPolygon:
         {
            Polygon * polygons;
            uint32 nPolygons = 1, i;

            if(gType.type == multiPolygon)
            {
               f.Get(nPolygons);
               geometry.multiPolygon = Array<Polygon> { size = nPolygons };
               polygons = ((Array<Polygon>)geometry.multiPolygon).array;
            }
            else
               polygons = &geometry.polygon;

            geometry.type = gType.type == polygon ? polygon : multiPolygon;

            for(i = 0; i < nPolygons; i++)
            {
               if(gType.type == multiPolygon)
               {
                  char byteOrder = 0;

                  if(f && f.Getc(&byteOrder))
                  {
                     WKBGeometryType gType = 0;

                     f.Get(gType);
                     if(gType.type == polygon)
                        ;
                  }
               }

               readPolygonWKB(f, polygons[i]);
            }
            break;
         }
      }
   }
}

static inline void writePointWKB(File f, const GeoPoint point, const Meters * depth, const double * measure)
{
   WKBGeometryType type { WKBGeometryBaseType::point, z = depth != null, m = measure != null };
   f.Putc(0);
   f.Put(type);
   f.Put((double)point.lat);
   f.Put((double)point.lon);
   if(depth)   f.Put(*depth);
   if(measure) f.Put(*measure);
}

static inline void writeLineStringWKB(File f, const LineString ls)
{
   WKBGeometryType type { WKBGeometryBaseType::lineString, z = ls.depths != null, m = ls.measures != null };
   Array<GeoPoint> points = (Array<GeoPoint>)((LineString *)ls)->points;
   uint32 count = points ? points.count : 0, i;

   f.Putc(0);
   f.Put(type);
   f.Put(count);
   for(i = 0; i < count; i++)
      writePointWKB(f, points[i], ls.depths ? &ls.depths[i] : null, ls.measures ? &ls.measures[i] : null);
}

static inline void writePolygonWKB(File f, const Polygon poly)
{
   WKBGeometryType type { WKBGeometryBaseType::polygon, z = poly.contours[0].depths != null, m = poly.contours[0].measures != null };
   uint32 count = poly.contours ? poly.contours.count : 0, i;

   f.Putc(0);
   f.Put(type);
   f.Put(count);
   for(i = 0; i < count; i++)
   {
      PolygonContour contour = poly.contours[i];
      Array<GeoPoint> points = contour ? (Array<GeoPoint>)contour.points : null;
      uint32 pCount = points ? points.count : 0, j;

      f.Put(pCount);
      for(j = 0; j < pCount; j++)
         writePointWKB(f, points[j], contour.depths ? &contour.depths[j] : null, contour.measures ? &contour.measures[j] : null);
   }
}

public void writeGeometryWKB(File f, const Geometry geometry, const double * measures, const Meters * depths)
{
   if(geometry != null)
   {
      GeometryType gt = geometry.type;
      WKBGeometryType type =
         gt == point ? { point } : gt == multiPoint ? { multiPoint } :
         gt == lineString ? { lineString } : gt == multiLineString ? { multiLineString } :
         gt == polygon ? { polygon } : gt == multiPolygon ? { multiPolygon } : 0;
      uint multiCount = 0;
      int i;

      if(measures) type.m = true;
      if(depths)   type.z = true;

      if(geometry.type == multiPoint || geometry.type == multiLineString || geometry.type == multiPolygon)
      {
         multiCount = geometry != null && geometry.multiPolygon ? geometry.multiPolygon.GetCount() : 0;

         f.Putc(0);        // Big endian
         f.Put(type);
         f.Put(multiCount);
      }

      switch(gt)
      {
         case point: writePointWKB(f, geometry.point, depths, measures); break;
         case multiPoint:
         {
            Array<GeoPoint> g = (Array<GeoPoint>)geometry.multiPoint;
            for(i = 0; i < g.count; i++)
               writePointWKB(f, g[i], depths ? &depths[i] : null, measures ? &measures[i] : null);
            break;
         }
         case lineString: writeLineStringWKB(f, geometry.lineString); break;
         case multiLineString:
         {
            Array<LineString> g = (Array<LineString>)geometry.multiLineString;
            for(i = 0; i < g.count; i++)
               writeLineStringWKB(f, g[i]);
            break;
         }
         case polygon: writePolygonWKB(f, geometry.polygon); break;
         case multiPolygon:
         {
            Array<Polygon> g = (Array<Polygon>)geometry.multiPolygon;
            for(i = 0; i < g.count; i++)
               writePolygonWKB(f, g[i]);
            break;
         }
      }
   }
}
