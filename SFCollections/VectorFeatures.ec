public import IMPORT_STATIC "ecrt"
public import IMPORT_STATIC "GeoExtents"
public import IMPORT_STATIC "SFGeometry"

#include <math.h>
#include <float.h>

////////////////////
public enum VectorType {
   none, points, lines, polygons, areas = polygons;

   public VectorType ::fromDimension(int dimension)
   {
      switch(dimension)
      {
         case 0: return points;
         case 1: return lines;
         case 2: return polygons;
         // case 3: return polyhedrons;
      }
      return none;
   }

   public VectorType ::fromString(const String geometryType)
   {
      if(!geometryType)
         return none;
      else if(!strcmpi(geometryType, "MULTIPOINT") || !strcmpi(geometryType, "POINT"))
         return points;
      else if(!strcmpi(geometryType, "MULTILINESTRING") || !strcmpi(geometryType, "LINESTRING"))
         return lines;
      else if(!strcmpi(geometryType, "MULTIPOLYGON") || !strcmpi(geometryType, "POLYGON"))
         return polygons;
      return none;
   }
};


public struct VectorFeature
{
private:
   int64 id;

   int OnCompare(VectorFeature b)
   {
      if(id < b.id) return -1;
      if(id > b.id) return  1;
      return 0;
   }
public:
   void getGeometry(VectorType vectorType, Geometry geometry, bool steal)
   {
      geometry = { };
      switch(vectorType)
      {
         case polygons:
         {
            PolygonFeature * pf = (PolygonFeature *)this;
            Array<Polygon> polygons = (Array<Polygon>)*&pf->geometry;
            if(polygons && polygons.count > 1)
            {
               geometry.multiPolygon = polygons;
               geometry.type = multiPolygon;
               geometry.subElementsNotFreed = true;
               if(steal) *&pf->geometry = null; // Stealing Array
            }
            else if(polygons && polygons.count == 1)
            {
               geometry.polygon = polygons[0];
               geometry.type = polygon;
               if(steal) polygons[0] = { }; // Stealing Polygon
            }
            break;
         }
         case lines:
         {
            LineFeature * lf = (LineFeature *)this;
            Array<LineString> lines = (Array<LineString>)*&lf->geometry;
            if(lines && lines.count > 1)
            {
               geometry.multiLineString = lines;
               geometry.type = multiLineString;
               geometry.subElementsNotFreed = true;
               if(steal) *&lf->geometry = null; // Stealing array
            }
            else if(lines && lines.count == 1)
            {
               geometry.type = lineString;
               geometry.lineString = lines[0];
               if(steal) lines[0] = { }; // Stealing LineString
            }
            break;
         }
         case points:
         {
            PointFeature * pf = (PointFeature *)this;
            Array<GeoPoint> points = (Array<GeoPoint>)*&pf->geometry;
            if(points && points.count > 1)
            {
               geometry.multiPoint = points;
               geometry.type = multiPoint;
               geometry.subElementsNotFreed = true;
               if(steal) *&pf->geometry = null; // Stealing array
            }
            else if(points && points.count == 1)
            {
               geometry.type = point;
               geometry.point = points[0];
            }
            break;
         }
      }
   }
};

public struct PolygonFeature : /*private */VectorFeature
{
   property Container<Polygon> geometry
   {
      set
      {
         if(geometry)
         {
            if(geometry._refCount <= 1)
               geometry.Free();
            delete geometry;
         }

         if(value)
         {
            if(!eClass_IsDerived(value._class, class(Array)))
               geometry = { value };
            else
            {
               geometry = (Array<Polygon>)value;
               incref value;
            }
         }
      }
      get { return geometry; }
   }
   property int64 id { set { VectorFeature::id = value; } get { return VectorFeature::id; } }

   void calculateExtent(GeoExtent extent)
   {
      Array<Polygon> polygons = (Array<Polygon>)geometry;
      extent.clear();

      if(polygons)
      {
         int i, count = polygons.count;
         for(i = 0; i < count; i++)
         {
            GeoExtent e;
            polygons[i].calculateExtent(e);
            extentUnionNoDL(extent, e);   // REVIEW: Should this use DL?
         }
      }
   }

   public void OnFree()
   {
      if(geometry)
      {
         geometry.Free();
         delete geometry;
      }
   }

private:
   Array<Polygon> geometry;
};
public struct LineFeature : /*private */VectorFeature
{
   property Container<LineString> geometry
   {
      set
      {
         if(geometry && geometry._refCount == 1)
            geometry.Free();
         delete geometry;

         if(value)
         {
            if(!eClass_IsDerived(value._class, class(Array)))
               geometry = { value };
            else
            {
               geometry = (Array<LineString>)value;
               incref value;
            }
         }
      }
      get { return geometry; }
   }
   property int64 id { set { VectorFeature::id = value; } get { return VectorFeature::id; } }

   void OnFree()
   {
      if(geometry)
      {
         geometry.Free();
         delete geometry;
      }
   }

   public void calculateExtent(GeoExtent extent)
   {
      LineFeature * lf = this;
      Array<LineString> lineStrings = (Array<LineString>)lf->geometry;

      extent.clear();
      if(lineStrings)
      {
         int j;

         for(j = 0; j < lineStrings.count; j++)
         {
            LineString * l = &lineStrings[j];
            GeoExtent e;
            l->calculateExtent(extent);
            extentUnionNoDL(extent, e);
         }
      }
   }

private:
   Array<LineString> geometry;
};

public struct PointFeature : /*private */VectorFeature
{
   property Container<GeoPoint> geometry
   {
      set
      {
         delete geometry;

         if(value)
         {
            if(!eClass_IsDerived(value._class, class(Array)))
               geometry = { value };
            else
            {
               geometry = (Array<GeoPoint>)value;
               incref value;
            }
         }
      }
      get { return geometry; }
   }
   property int64 id { set { VectorFeature::id = value; } get { return VectorFeature::id; } }
   public property int64 * ids
   {
      set { ids = value; }
      get { return ids;  }
   }

   void OnFree()
   {
      if(geometry)
      {
         geometry.Free();
         delete geometry;
      }
      delete measures;
      delete colors;
      delete ids;
   }
private:
   Array<GeoPoint> geometry;
   double * measures;
   uint32 /*ColorRGBA*/ * colors;
   int64 * ids;   // If set, these are per point IDs within multi-points

   public void calculateExtent(GeoExtent extent)
   {
      PointFeature * pf = this;
      Array<GeoPoint> points = (Array<GeoPoint>)pf->geometry;

      extent.clear();
      if(points)
      {
         int j;

         for(j = 0; j < points.count; j++)
         {
            GeoPoint * p = &points[j];
            addExtentPoint(extent, p);
         }
      }
   }
};

public struct Line3DFeature : LineFeature
{
   Meters * depths;

   void OnFree()
   {
      delete depths;
      LineFeature::OnFree();
   }
};

public struct Point3DFeature : PointFeature
{
   Meters * depths;

   void OnFree()
   {
      delete depths;
      PointFeature::OnFree();
   }
};

public class ModelID : uint32
{
public:
   int model:27;
   int level:5;
}

public struct Models3DFeature : Point3DFeature
{
   ModelID * modelIDs;
   Degrees /*Euler*/ * orientations;
   float /*Vector3Df*/ * scales;

   void OnFree()
   {
      delete modelIDs;
      delete orientations;
      delete scales;
      Point3DFeature::OnFree();
   }
};

public class PCScanInfo : uint16
{
public:
   uint returnNumber:3;
   uint numberOfReturns:3;
   uint scanDirection:1;
   bool edgeOfFlight:1;
   byte angle:8;
};

public struct PointCloudFeature : Point3DFeature
{
   PCScanInfo * scanInfo;

   void OnFree()
   {
      delete scanInfo;
      Point3DFeature::OnFree();
   }
};
