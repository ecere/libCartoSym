public import IMPORT_STATIC "ecrt"
public import IMPORT_STATIC "GeoExtents"
public import IMPORT_STATIC "SFGeometry"

import "FeatureCollection"

public bool writeWKBCollection(FeatureCollection fc, File f)
{
   bool result = true;
   VectorType vType = fc.type.vectorType;
   WKBGeometryType type = (WKBGeometryType)vType;  // point, lineString, polygons match up
   int i;

   if(fc.type.hasMeasure) type.m = true;
   if(fc.type.is3D)       type.z = true;

   f.Putc(0);        // Big endian
   f.Put(type);      // Collection feature type
   f.Put((uint32)fc.count);  // Number of features
   for(i = 0; i < fc.count; i++)
   {
      Geometry geometry;
      const VectorFeature * feature = null;
      const double * measures = null;
      const Meters * depths = null;

      switch(vType)
      {
         case points:
            if(fc.type.is3D)
            {
               const Point3DFeature * p3DFeature = &((FeatureCollection<Point3DFeature>)fc)[i];
               feature = (VectorFeature *)p3DFeature;
               depths = p3DFeature->depths;
               measures = p3DFeature->measures;
            }
            else
            {
               const PointFeature * pFeature = &((FeatureCollection<PointFeature>)fc)[i];
               feature = (VectorFeature *)pFeature;
               measures = pFeature->measures;
            }
            break;
         case lines: feature = (VectorFeature *)&((FeatureCollection<LineFeature   >)fc)[i]; break;
         case polygons: feature = (VectorFeature *)&((FeatureCollection<PolygonFeature>)fc)[i]; break;
      }
      ((VectorFeature *)feature)->getGeometry(vType, geometry, false);
      f.Put(feature->id);  // Feature ID
      writeGeometryWKB(f, geometry, measures, depths);   // WKB Geometry
   }
   return result;
}

public FeatureCollection readWKBCollection(File f)
{
   FeatureCollection result = null;
   char byteOrder = 0;
   if(f && f.Getc(&byteOrder))
   {
      WKBGeometryType cType = 0;
      uint featuresCount = 0;
      int i;
      FeatureCollection fc = null;

      f.Get(cType);
      f.Get(featuresCount);

      switch(cType.type)
      {
         case point:
            if(cType.z)
            {
               fc = FeatureCollection<Point3DFeature> { };
            }
            else
            {
               fc = FeatureCollection<PointFeature> { };
            }
            break;
         case lineString:
            fc = FeatureCollection<LineFeature> { };
            break;
         case polygon:
            fc = FeatureCollection<PolygonFeature> { };
            break;
      }
      fc.size = featuresCount;

      for(i = 0; i < featuresCount; i++)
      {
         VectorFeature * feature = null;
         int64 id = 0;
         Geometry geometry { };

         f.Get(id);

         // TODO: This doesn't read measures or depths yet
         readGeometryWKB(f, geometry);
         switch(cType.type)
         {
            case point:
               if(cType.z)
               {
                  Point3DFeature * p3DFeature = &((FeatureCollection<Point3DFeature>)fc)[i];
                  feature = (VectorFeature *)p3DFeature;
                  if(geometry.type == point)
                     p3DFeature->geometry = Array<GeoPoint> { [ geometry.point ] };
                  else if(geometry.type == multiPoint)
                     p3DFeature->geometry = geometry.multiPoint;
               }
               else
               {
                  PointFeature * pFeature = &((FeatureCollection<PointFeature  >)fc)[i];
                  feature = (VectorFeature *)pFeature;
                  if(geometry.type == point)
                     pFeature->geometry = Array<GeoPoint> { [ geometry.point ] };
                  else if(geometry.type == multiPoint)
                     pFeature->geometry = geometry.multiPoint;
               }
               break;
            case lineString:
            {
               LineFeature * lFeature = &((FeatureCollection<LineFeature   >)fc)[i];
               feature = (VectorFeature *)lFeature;
               if(geometry.type == lineString)
                  lFeature->geometry = Array<LineString> { [ geometry.lineString ] };
               else if(geometry.type == multiLineString)
                  lFeature->geometry = geometry.multiLineString;
               break;
            }
            case polygon:
            {
               PolygonFeature * pFeature = &((FeatureCollection<PolygonFeature>)fc)[i];
               feature = (VectorFeature *)pFeature;
               if(geometry.type == polygon)
                  pFeature->geometry = Array<Polygon> { [ geometry.polygon ] };
               else if(geometry.type == multiPolygon)
                  pFeature->geometry = geometry.multiPolygon;
               break;
            }
         }
         feature->id = id;
      }

      result = fc;
   }
   return result;
}
