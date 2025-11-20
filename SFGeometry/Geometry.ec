public import IMPORT_STATIC "ecrt"
public import IMPORT_STATIC "GeoExtents"

private:

#include <math.h>
#include <float.h>

// REVIEW: We way want to use Pointd and a multiplier instead of GeoPoint in this module...

define radEpsilon = Radians { 10 * DBL_EPSILON };

/*private */static inline Radians fromLine(const GeoPoint p, const GeoPoint a, const GeoPoint b)
{
   return ((Radians)b.lon - (Radians)a.lon) * ((Radians)p.lat - (Radians)a.lat) - ((Radians)p.lon - (Radians)a.lon) * ((Radians)b.lat - (Radians)a.lat);
}

public void extentUnionNoDL(GeoExtent a, const GeoExtent e)
{
   a.ll.lat = Min(a.ll.lat, e.ll.lat);
   a.ll.lon = Min(a.ll.lon, e.ll.lon);
   a.ur.lat = Max(a.ur.lat, e.ur.lat);
   a.ur.lon = Max(a.ur.lon, e.ur.lon);
}

/*
double doublePointsArea(int count, Pointd * p)
{
   double area = 0;
   int i;
   for(i = 0; i < count; i++)
   {
      int j = (i == count - 1) ? 0 : i + 1;
      area += (p[i].x - p->x) * (p[j].y - p->y) - (p[j].x - p->x) * (p[i].y - p->y);
   }
   return area;
}
*/

public double computeEuclideanArea(int count, const Pointd * p)
{
   // TODO: Use depths when available

   // TODO: Implement Kahan / Neumaier summation -- https://en.wikipedia.org/wiki/Kahan_summation_algorithm
#if !defined(__EMSCRIPTEN__) && !defined(__ANDROID__) && !defined(__UWP__) && !defined(__APPLE__)
#if defined(__AARCH64EB__) || defined(__AARCH64EL__) || defined(__ARMEB__) || defined(__ARMEL__)
   #define AREA_DBLTYPE double // _Float128 TODO: eC compiler does not yet recognize _Float128
#else
   #define AREA_DBLTYPE __float128
#endif
#else
   #define AREA_DBLTYPE double
#endif
   AREA_DBLTYPE area = 0.0;
   if(count >= 3)
   {
      int i;
      Pointd o = p[0];
      int last = count-1;
      for(i = 1; i < last; i++)
      {
         area += ((AREA_DBLTYPE)p[i].y-o.y) * (AREA_DBLTYPE)(p[i+1].x-o.x) - ((AREA_DBLTYPE)p[i+1].y-o.y) * ((AREA_DBLTYPE)p[i].x-o.x);
      }
      area += (AREA_DBLTYPE)(p[i].y-o.y) * ((AREA_DBLTYPE)p[0].x-o.x) - ((AREA_DBLTYPE)p[0].y-o.y) * ((AREA_DBLTYPE)p[i].x-o.x);
   }
   return (double)area / 2;
}

public void addExtentPoint(GeoExtent e, const GeoPoint p)
{
   if(e.ll.lon == MAXDOUBLE)
   {
      e.ll = p, e.ur = p;
      e.ur.lon = e.ll.lon = wrapLon(e.ll.lon);
   }
   else
   {
      bool crossingDL = e.ur.lon < e.ll.lon;
      Radians midLon = ((Radians)e.ll.lon + (Radians)e.ur.lon) / 2;
      bool pole = p.lat <= -Pi/2 + radEpsilon || p.lat >= Pi/2 - radEpsilon;
      Radians lon = wrapLon(p.lon);

      if(p.lat < e.ll.lat) e.ll.lat = p.lat;
      if(p.lat > e.ur.lat) e.ur.lat = p.lat;

      if(!pole)
      {
             if(midLon > 0 && lon <= -Pi + radEpsilon) lon = Pi;
         else if(midLon < 0 && lon >= Pi - radEpsilon) lon = -Pi;
      }

      if(crossingDL ? (lon < e.ll.lon && lon > e.ur.lon) : (lon < e.ll.lon || lon > e.ur.lon))
      {
         bool emptyLon = (e.ur.lon - e.ll.lon) <= radEpsilon;
         bool flipL = false, flipR = false;
         Radians dLLon = fabs(lon - (Radians)e.ll.lon);
         Radians dRLon = fabs(lon - (Radians)e.ur.lon);
         if(dLLon > Pi) dLLon = fabs(dLLon - 2*Pi), flipL = emptyLon && dLLon > radEpsilon;
         if(dRLon > Pi) dRLon = fabs(dRLon - 2*Pi), flipR = emptyLon && dRLon > radEpsilon;

         if(!crossingDL && !pole)
         {
            if(lon <= -Pi + radEpsilon && dRLon < dLLon) lon = Pi;
            else if(lon >= Pi - radEpsilon && dLLon < dRLon) lon = -Pi;
         }
         if(lon < e.ll.lon)
         {
            if(emptyLon ? flipL : (dRLon < dLLon && lon > e.ur.lon))
               e.ur.lon = lon;
            else if(lon < e.ll.lon)
               e.ll.lon = lon;
         }
         else
         {
            if(emptyLon ? flipR : (dLLon < dRLon && lon < e.ll.lon))
               e.ll.lon = lon;
            else if(lon > e.ur.lon)
               e.ur.lon = lon;
         }
         if(!emptyLon && fabs((Radians)e.ur.lon - (Radians)e.ll.lon) <= radEpsilon)
         {
            e.ll.lon = -180, e.ur.lon = 180;
            if(e.ll.lat < 0) e.ll.lat = -90;
            if(e.ur.lat > 0) e.ur.lat =  90;
         }
      }
   }
}

public void addExtentPointNoDL(GeoExtent e, const GeoPoint p)
{
   if(e.ll.lon == MAXDOUBLE)
      e.ll = p, e.ur = p;
   else
   {
      if(p.lat < e.ll.lat) e.ll.lat = p.lat;
      if(p.lat > e.ur.lat) e.ur.lat = p.lat;
      if(p.lon < e.ll.lon) e.ll.lon = p.lon;
      if(p.lon > e.ur.lon) e.ur.lon = p.lon;
   }
}

////////////////////

public struct LineString
{
   property Container<LineString>
   {
      get { return Array<LineString> { [ this ] }; }
      set
      {
         LineString *firstString = value && value.GetCount() == 1 ? (LineString *)value.GetAtPosition(0, false, null) : null;
         this = firstString ? *firstString : { };
      }
   }

   property Container<GeoPoint> points
   {
      set
      {
         delete _points;
         if(value)
         {
            if(!eClass_IsDerived(value._class, class(Array)))
               _points = { value };
            else
            {
               _points = (Array<GeoPoint>)value;
               incref value;
            }
         }
      }
      get
      {
         return _points;
      }
   }

private:
   Array<GeoPoint> _points;
   public Meters * depths;
   public double * measures;

   void OnFree()
   {
      delete _points;
      delete depths;
      delete measures;
   }

   void OnCopy(const LineString src)
   {
      OnFree();
      if(src._points)
      {
         uint count = src._points.count;
         _points = { src._points };
         if(src.depths)
         {
            depths = new Meters[count];
            memcpy(depths, src.depths, sizeof(Meters) * count);
         }
         if(src.measures)
         {
            measures = new double[count];
            memcpy(measures, src.measures, sizeof(double) * count);
         }
      }
   }

   public void calculateExtent(GeoExtent extent)
   {
      int i, count = _points.count;
      GeoPoint ll { MAXDOUBLE, MAXDOUBLE };
      GeoPoint ur { -MAXDOUBLE, -MAXDOUBLE };
      GeoPoint * p = _points.array;

      for(i = 0; i < count; i++, p++)
      {
         if(p->lat < ll.lat) ll.lat = p->lat;
         if(p->lat > ur.lat) ur.lat = p->lat;
         if(p->lon < ll.lon) ll.lon = p->lon;
         if(p->lon > ur.lon) ur.lon = p->lon;
      }
      extent = { ll, ur };
   }
};


public struct StartEndPair
{
   int start, end;
};

// TODO: Should processing code be moved in separate module?
public class PolygonContour : struct
{
   Array<GeoPoint> _points { };
   Array<StartEndPair> hiddenSegments; // Edges between each 'start' and 'end' indices pair should not be drawn

public:
   property Container<PolygonContour>
   {
      get { return Array<PolygonContour> { [ this ] }; }
      set { return value && value.GetCount() == 1 ? value[0] : null; }
   }

   property Container<GeoPoint> points
   {
      set
      {
         if(value)
         {
            if(!eClass_IsDerived(value._class, class(Array)))
               _points.copySrc = (void *)value;
            else
            {
               delete _points;
               _points = (Array<GeoPoint>)value;
               incref value;
            }
         }
         else
            _points.Free();
      }
      get { return _points; }
   }

   Meters * depths;
   double * measures;

private:
   GeoExtent extent;

   struct
   {
      bool isClockwise:1;
      bool isInner:1;
   };

public:
   property Container<StartEndPair> hidden
   {
      set
      {
         if(value)
         {
            if(!hiddenSegments) hiddenSegments = { };

            if(!eClass_IsDerived(value._class, class(Array)))
               hiddenSegments.copySrc = (void *)value;
            else
            {
               delete hiddenSegments;
               hiddenSegments = (Array<StartEndPair>)value;
               incref value;
            }
         }
         else
            delete hiddenSegments;
      }
      get { return hiddenSegments; }
      isset { return hiddenSegments != null; }
   }

   property bool inner
   {
      set { isInner = value; }
      get { return isInner; }
   }

   property bool clockwise
   {
      set { isClockwise = value; }
      get { return isClockwise; }
   }

   bool updateClockwise()
   {
      return (isClockwise = (computeEuclideanArea() < 0));
   }

   property bool selfIntersects
   {
      get
      {
         int i, j;
         uint64 * masks = null; // 1/64th of the bbox touched by each segment
         uint count = _points.count;
         const GeoPoint * points = _points.array;
         if(count > 100)
         {
            Radians minLat = MAXDOUBLE, maxLat = -MAXDOUBLE;
            Radians minLon = MAXDOUBLE, maxLon = -MAXDOUBLE;
            Radians dLat, dLon;
            masks = new0 uint64[count];
            for(i = 0; i < count; i++)
            {
               const GeoPoint * p = &points[i];
               if(p->lat < minLat) minLat = p->lat;
               if(p->lon < minLon) minLon = p->lon;
               if(p->lat > minLat) maxLat = p->lat;
               if(p->lon > minLon) maxLon = p->lon;
            }
            dLat = maxLat - minLat;
            dLon = maxLon - minLon;
            for(i = 0; i < count; i++)
            {
               const GeoPoint * ap = &points[i], * aq = &points[(i < count-1) ? i + 1 : 0];
               Radians pMinLat = ap->lat < aq->lat ? ap->lat : aq->lat;
               Radians pMinLon = ap->lon < aq->lon ? ap->lon : aq->lon;
               Radians pMaxLat = ap->lat > aq->lat ? ap->lat : aq->lat;
               Radians pMaxLon = ap->lon > aq->lon ? ap->lon : aq->lon;
               int iMinLat = Min(7, Max(0, 8 * ((Radians)pMinLat - minLat) / dLat));
               int iMinLon = Min(7, Max(0, 8 * ((Radians)pMinLon - minLon) / dLon));
               int iMaxLat = Min(7, Max(0, 8 * ((Radians)pMaxLat - minLat) / dLat));
               int iMaxLon = Min(7, Max(0, 8 * ((Radians)pMaxLon - minLon) / dLon));
               int k;
               uint64 mask = 0;

               for(j = iMinLat; j <= iMaxLat; j++)
                  for(k = iMinLon; k <= iMaxLon; k++)
                     mask |= 1LL << (j * 8 + k);
               masks[i] = mask;
            }
         }

         for(i = 0; i < count; i++)
         {
            const GeoPoint * ap = &points[i], * aq = &points[(i < count-1) ? i + 1 : 0];
            Radians minLat = ap->lat < aq->lat ? ap->lat : aq->lat;
            Radians minLon = ap->lon < aq->lon ? ap->lon : aq->lon;
            Radians maxLat = ap->lat > aq->lat ? ap->lat : aq->lat;
            Radians maxLon = ap->lon > aq->lon ? ap->lon : aq->lon;
            for(j = i+2 /*0*/; j < count; j++)
            {
               const GeoPoint * bp = &points[j], * bq = &points[(j < count-1) ? j + 1 : 0];
               // if(ap != bp && ap != bq && aq != bp && aq != bq)
               if((!masks || (masks[i] & masks[j])) &&
                  ((Radians)bp->lat > minLat || (Radians)bq->lat > minLat) &&
                  ((Radians)bp->lon > minLon || (Radians)bq->lon > minLon) &&
                  ((Radians)bp->lat < maxLat || (Radians)bq->lat < maxLat) &&
                  ((Radians)bp->lon < maxLon || (Radians)bq->lon < maxLon))
               {
                  #define SELF_INTERSECT_EPSILON 1E-11
                  #define ccw(p1, p2, p3) fromLine(p3, p1, p2)

                  double a = ccw(ap, aq, bp);
                  double b = ccw(ap, aq, bq);
                  double c = ccw(bp, bq, ap);
                  double d = ccw(bp, bq, aq);

                  if(Abs(a) < SELF_INTERSECT_EPSILON) a = 0;
                  if(Abs(b) < SELF_INTERSECT_EPSILON) b = 0;
                  if(Abs(c) < SELF_INTERSECT_EPSILON) c = 0;
                  if(Abs(d) < SELF_INTERSECT_EPSILON) d = 0;

                  if(Sgn(a) * Sgn(b) < 0 && Sgn(c) * Sgn(d) < 0)
                  {
                     delete masks;
                     return true;
                  }
               }
            }
         }
         delete masks;
         return false;
      }
   }

private:
   int OnCompare(PolygonContour b)
   {
      if(b && !b) return 1;
      if(!b && b) return -1;
      if(isInner && !b.isInner) return 1;
      if(!isInner && b.isInner) return -1;
      if(this < b) return -1;
      if(this > b) return 1;
      return 0;
   }

   void OnCopy(PolygonContour b)
   {
      this = b.copy(false);
   }

   ~PolygonContour()
   {
      delete hiddenSegments;
      delete depths;
      delete measures;
   }

   public PolygonContour copy(bool flip) // WARNING: This does not change isInner
   {
      uint count = _points.count;
      PolygonContour ring { _points.size = count };
      int d;

      for(d = 0; d < count; d++)
         ring._points[flip ? (count-1-d) : d] = _points[d];
      ring.isClockwise = flip ? !isClockwise : isClockwise;
      ring.isInner = isInner;
      ring.extent = extent;
      if(hiddenSegments)
         ring.hiddenSegments = { hiddenSegments };

      if(flip && hiddenSegments && hiddenSegments.count)
         for(d = 0; d < hiddenSegments.count; d++)
         {
            if(hiddenSegments[d].end != 0)
            {
               hiddenSegments[d].start = count-1-hiddenSegments[d].end;
               hiddenSegments[d].end = count-1-hiddenSegments[d].start;
            }
         }
      return ring;
   }

   public void getExtent(GeoExtent e) { calculateExtent(); e = extent; }
   public const GeoExtent * getExtentPtr() { return &extent; }

   public void calculateExtent()
   {
      // NOTE: This should probably take into account the interval between current and last point
      int i, count = _points.count;
      GeoPoint * p = _points.array;
      extent.clear();
      for(i = 0; i < count; i++, p++)
         addExtentPoint(extent, p);
      addExtentPoint(extent, _points.array);

      /*
      GeoPoint ll { MAXDOUBLE, MAXDOUBLE };
      GeoPoint ur { -MAXDOUBLE, -MAXDOUBLE };

      for(i = 0; i < count; i++, p++)
      {
         if(p->lat < ll.lat) ll.lat = p->lat;
         if(p->lat > ur.lat) ur.lat = p->lat;
         if(p->lon < ll.lon) ll.lon = p->lon;
         if(p->lon > ur.lon) ur.lon = p->lon;
      }
      extent = { ll, ur };
      */
   }

   public void flip(bool toggleCWFlag)
   {
      int numPoints = _points.count;
      GeoPoint * tmp = new GeoPoint[numPoints];
      Meters * tmpDepths = depths ? new Meters[numPoints] : null;
      int i;

      for(i = 0; i < numPoints; i++)
         tmp[i] = _points[numPoints-1-i];
      if(tmpDepths)
      {
         for(i = 0; i < numPoints; i++)
            tmpDepths[i] = depths[numPoints-1-i];
      }

      if(hiddenSegments && hiddenSegments.count)
         for(i = 0; i < hiddenSegments.count; i++)
         {
            if(hiddenSegments[i].end != 0)
            {
               hiddenSegments[i].start = numPoints-1-hiddenSegments[i].end;
               hiddenSegments[i].end = numPoints-1-hiddenSegments[i].start;
            }
         }

      memcpy(_points.array, tmp, numPoints * sizeof(GeoPoint));
      delete tmp;
      if(tmpDepths)
      {
         memcpy(depths, tmpDepths, numPoints * sizeof(Meters));
         delete tmpDepths;
      }

      if(toggleCWFlag)
         isClockwise ^= true;
   }


   // NOTE: This returns Radians square
   public double computeEuclideanArea()
   {
      return ::computeEuclideanArea(_points.count, (const Pointd *)_points.array);
   }
}

public struct Polygon
{
   property Container<Polygon>
   {
      get { return Array<Polygon> { [ this ] }; }
      set
      {
         Polygon * firstPoly = value && value.GetCount() == 1 ? (Polygon *)value.GetAtPosition(0, false, null) : null;
         this = firstPoly ? *firstPoly : { };
      }
   }

   property PolygonContour outer
   {
      set
      {
         if(!contours) contours = { }, incref contours;
         if(value)
         {
            PolygonContour o = value;
            o.isClockwise = o.computeEuclideanArea() < 0; // Clockwise computes negative area for (lat, lon)
            contours.Add(o);
         }
      }
      get
      {
         if(contours)
            for(i : contours; i && !i.isInner)
               return i;
         return null;
      }
   }

   property Container<PolygonContour> inner
   {
      set
      {
         if(!contours) contours = { }, incref contours;
         if(value)
         {
            for(i : value; i)
            {
               PolygonContour c = i.copy(false);
               contours.Add(c);
               c.isInner = true;
               c.isClockwise = c.computeEuclideanArea() < 0; // Clockwise computes negative area for (lat, lon)
            }
            /*if(eClass_IsDerived(value._class, class(Array)))
            {
               value.RemoveAll();
               if(!value._refCount)
                  delete value;
            }*/
         }
      }
      get
      {
         Array<PolygonContour> inner = null;
         if(contours)
         {
            for(i : contours; i && i.isInner)
            {
               if(!inner) inner = { };
               inner.Add(i);
            }
         }
         return inner;
      }
      isset
      {
         if(contours)
            for(i : contours; i && i.isInner)
               return true;
         return false;
      }
   }
   //TODO: 'rings' or 'contours' property
   //TODO: Container<GeoPoint> into a PolygonContour

   Array<PolygonContour> getContours()
   {
      return contours;
   }

   void setContours(Container<PolygonContour> value)
   {
      if(contours) contours.Free(), delete contours;
      if(value)
      {
         if(!eClass_IsDerived(value._class, class(Array)))
            contours = { value };
         else
         {
            contours = (Array<PolygonContour>)value;
            incref value;
         }
      }
   }

   void calculateExtent(GeoExtent extent)
   {
      extent.clear();
      if(contours)
         for(r : contours; r)
         {
            PolygonContour ring = r;
            if(!ring.extent.ll.lat && !ring.extent.ll.lon && !ring.extent.ur.lat && !ring.extent.ur.lon)
            {
               ring.extent.clear();
               if(ring._points)
                  for(p : ring._points)
                     addExtentPoint(ring.extent, p);
            }
            if(ring._points && !ring.isInner)
               extent.doUnionDL(ring.extent);
         }
   }

   void calculateExtentNoDL(GeoExtent extent)
   {
      extent.clear();
      if(contours)
         for(r : contours; r)
         {
            PolygonContour ring = r;
            if(!ring.extent.ll.lat && !ring.extent.ll.lon && !ring.extent.ur.lat && !ring.extent.ur.lon)
            {
               ring.extent.clear();
               if(ring._points)
                  for(p : ring._points)
                     addExtentPointNoDL(ring.extent, p);
            }
            if(ring._points && !ring.isInner)
               extentUnionNoDL(extent, ring.extent);
         }
   }

   void OnCopy(Polygon src)
   {
      if(src.contours)
      {
         int i;

         contours = { size = src.contours.size };
         for(i = 0; i < contours.count; i++)
            contours[i].OnCopy(src.contours[i]);
      }
      else
         contours = null;
   }

   void OnFree()
   {
      if(contours)
      {
         //TOFIX: a better way to avoid freeing the already freed contours?
         //if(contours._refCount)
            contours.Free();
         delete contours;
      }
   }

   bool fixContours()
   {
      bool changed = false;
      int c;
      bool isInner = false;
      for(c = 0; c < contours.count; c++)
      {
         PolygonContour ct = contours[c];
         bool isClockwise;

         if(ct.isInner != isInner)
            changed = true, ct.isInner = isInner;

         isClockwise = ct.computeEuclideanArea() < 0;
         if(ct.isClockwise != isClockwise)
            changed = true, ct.isClockwise = isClockwise;
         if(ct.isInner != ct.isClockwise && !ct.depths)
            changed = true, ct.flip(true);

         isInner = true;
      }
      return changed;
   }

private:
   Array<PolygonContour> contours;
};

public enum GeometryType { none, point, multiPoint, polygon, multiPolygon, lineString, multiLineString, geometryCollection, bbox };
public struct Geometry
{
   GeometryType type;
   double epsilon;   // FIXME: There seems to be an eC issue with having this double epsilon _after_ the union
   CRS crs;
   bool subElementsOwned;  // REVIEW: Avoid the need for this flag?
   union
   {
      GeoPoint point;
      Container<GeoPoint> multiPoint;
      Polygon polygon;
      Container<Polygon> multiPolygon;
      LineString lineString;
      Container<LineString> multiLineString;
      Container<Geometry> geometryCollection;
      GeoExtent bbox;
   };

   void OnCopy(Geometry src)
   {
      type = src.type;
      crs = src.crs;
      epsilon = src.epsilon;
      subElementsOwned = src.subElementsOwned;
      switch(type)
      {
         case GeometryType::bbox:               bbox.OnCopy(src.bbox); break;
         case GeometryType::point:              point.OnCopy(src.point); break;
         case GeometryType::lineString:         lineString.OnCopy(src.lineString); break;
         case GeometryType::polygon:            polygon.OnCopy(src.polygon); break;
         case GeometryType::multiPoint:
            if(subElementsOwned)
               multiPoint.OnCopy(src.multiPoint);
            else
               multiPoint = src.multiPoint;
            break;
         case GeometryType::multiPolygon:
            if(subElementsOwned)
            {
               if(src.multiPolygon)
               {
                  Array<Polygon> mp = (Array<Polygon>)src.multiPolygon;
                  Array<Polygon> amp { size = mp.count };
                  int i;

                  multiPolygon = amp;
                  for(i = 0; i < mp.count; i++)
                     multiPolygon[i].OnCopy(mp[i]);
               }
               else
                  multiPolygon = null;
            }
            else
               multiPolygon = src.multiPolygon;
            break;
         case GeometryType::multiLineString:
            if(subElementsOwned)
            {
               if(src.multiLineString)
               {
                  Array<LineString> ml = (Array<LineString>)src.multiLineString;
                  Array<LineString> aml { size = ml.count };
                  int i;

                  multiLineString = aml;
                  for(i = 0; i < ml.count; i++)
                     multiLineString[i].OnCopy(ml[i]);
               }
               else
                  multiLineString = null;
            }
            else
               multiLineString = src.multiLineString;
            break;
         case GeometryType::geometryCollection:
            if(subElementsOwned)
            {
               if(src.geometryCollection)
               {
                  Array<Geometry> gc = (Array<Geometry>)src.geometryCollection;
                  Array<Geometry> agc { size = gc.count };
                  int i;

                  geometryCollection = agc;
                  for(i = 0; i < gc.count; i++)
                     geometryCollection[i].OnCopy(gc[i]);
               }
               else
                  geometryCollection = null;
            }
            else
               geometryCollection = src.geometryCollection;
            break;
      }
   }

   void OnFree()
   {
      switch(type)
      {
         case GeometryType::lineString:         lineString.OnFree(); break;
         case GeometryType::polygon:            polygon.OnFree(); break;
         case GeometryType::multiPoint:
         {
            if(subElementsOwned)
               multiPoint.Free();
            delete multiPoint; break;
         }
         case GeometryType::multiPolygon:
         {
            if(subElementsOwned)
               multiPolygon.Free();
            delete multiPolygon; break;
         }
         case GeometryType::multiLineString:
         {
            if(subElementsOwned)
               multiLineString.Free();
            delete multiLineString; break;
         }
         case GeometryType::geometryCollection:
         {
            if(subElementsOwned)
               geometryCollection.Free();
            delete geometryCollection; break;
         }
      }
   }

   property int dimension
   {
      get
      {
         switch(type)
         {
            case point:       case multiPoint:              return 0;
            case lineString:  case multiLineString:         return 1;
            case polygon:     case multiPolygon: case bbox: return 2;
            case geometryCollection:
               if(geometryCollection)
               {
                  int d = -1;
                  for(g : geometryCollection)
                  {
                     d = Max(d, g.dimension);
                     if(d == 2) return d;
                  }
                  return d;
               }
            default: return -1;
         }
      }
   }
};
