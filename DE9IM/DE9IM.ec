public import IMPORT_STATIC "ecrt"
public import IMPORT_STATIC "GeoExtents"
public import IMPORT_STATIC "SFGeometry"

private:

#include <float.h>

define radEpsilon = Radians { 10 * DBL_EPSILON };

#define DE9IM_HI(a, b) (((a) == '2' || (b) == '2') ? '2' : ((a) == '1' || (b) == '1') ? '1' : ((a) == '0' || (b) == '0') ? '0' : 'F')
#define DE9IM_LO(a, b) (((a) == 'F' || (b) == 'F') ? 'F' : ((a) == '0' || (b) == '0') ? '0' : ((a) == '1' || (b) == '1') ? '1' : ((a) == '2' || (b) == '2') ? '2' : '*')

// Work around to declare Array on stack...
struct ArrayOnStack
{
   // From base Instance
   void ** _vTbl;
   Class _class;
   int _refCount;

   // From Array
   void * array;
   uint count;
   uint minAllocSize;
};

public struct DE9IM
{
   char m[10]; // Includes an extra null terminating character

   property const String
   {
      get { return m; }
      set { strncpy(m, value, 9); m[9] = 0;}
   }

   bool OnGetDataFromString(const char * string)
   {
      strncpy(m, string, 9);
      m[9] = 0;
      return true;
   }

   const char * OnGetString(char * tempString, void * fieldData, ObjectNotationType * onType)
   {
      return m;
   }

   void zero()
   {
      strcpy(m, "FFFFFFFF2");
   }

   void wild()
   {
      strcpy(m, "*********");
   }

   void flip(const DE9IM rel)
   {
      m[0] = rel.m[0], m[1] = rel.m[3], m[2] = rel.m[6];
      m[3] = rel.m[1], m[4] = rel.m[4], m[5] = rel.m[7];
      m[6] = rel.m[2], m[7] = rel.m[5], m[8] = rel.m[8];
      m[9] = 0;
   }
/*
   void combine(const DE9IM a, const DE9IM b)
   {
      // Interior and Boundary are combined as an OR
      m[0] = DE9IM_HI(a.m[0], b.m[0]);
      m[1] = DE9IM_HI(a.m[1], b.m[1]);
      m[3] = DE9IM_HI(a.m[3], b.m[3]);
      m[4] = DE9IM_HI(a.m[4], b.m[4]);

      // This combines Exterior as an AND
      m[2] = DE9IM_LO(a.m[2], b.m[2]);
      m[5] = DE9IM_LO(a.m[5], b.m[5]);
      m[6] = DE9IM_LO(a.m[6], b.m[6]);
      m[7] = DE9IM_LO(a.m[7], b.m[7]);
      m[8] = DE9IM_LO(a.m[8], b.m[8]);
      m[9] = 0;
   }
*/
   void combineAExtOR(const DE9IM a, const DE9IM b)
   {
      // Interior and Boundary are combined as an OR
      m[0] = DE9IM_HI(a.m[0], b.m[0]);
      m[1] = DE9IM_HI(a.m[1], b.m[1]);
      m[3] = DE9IM_HI(a.m[3], b.m[3]);
      m[4] = DE9IM_HI(a.m[4], b.m[4]);

      m[2] = DE9IM_LO(a.m[2], b.m[2]);
      m[5] = DE9IM_LO(a.m[5], b.m[5]);

      // This combines A Exterior as an OR
      m[6] = DE9IM_HI(a.m[6], b.m[6]);
      m[7] = DE9IM_HI(a.m[7], b.m[7]);
      m[8] = DE9IM_HI(a.m[8], b.m[8]);
      m[9] = 0;
   }

   void combineBExtOR(const DE9IM a, const DE9IM b)
   {
      // Interior and Boundary are combined as an OR
      m[0] = DE9IM_HI(a.m[0], b.m[0]);
      m[1] = DE9IM_HI(a.m[1], b.m[1]);
      m[3] = DE9IM_HI(a.m[3], b.m[3]);
      m[4] = DE9IM_HI(a.m[4], b.m[4]);

      // This combines B Exterior as an OR
      m[2] = DE9IM_HI(a.m[2], b.m[2]);
      m[5] = DE9IM_HI(a.m[5], b.m[5]);

      m[6] = DE9IM_LO(a.m[6], b.m[6]);
      m[7] = DE9IM_LO(a.m[7], b.m[7]);
      m[8] = DE9IM_LO(a.m[8], b.m[8]);
      m[9] = 0;
   }

/*
   void combineABExtOR(const DE9IM a, const DE9IM b)
   {
      // Interior and Boundary are combined as an OR
      m[0] = DE9IM_HI(a.m[0], b.m[0]);
      m[1] = DE9IM_HI(a.m[1], b.m[1]);
      m[3] = DE9IM_HI(a.m[3], b.m[3]);
      m[4] = DE9IM_HI(a.m[4], b.m[4]);

      // This combines A and B Exterior as an OR
      m[2] = DE9IM_HI(a.m[2], b.m[2]);
      m[5] = DE9IM_HI(a.m[5], b.m[5]);
      m[6] = DE9IM_HI(a.m[6], b.m[6]);
      m[7] = DE9IM_HI(a.m[7], b.m[7]);
      m[8] = DE9IM_HI(a.m[8], b.m[8]);
      m[9] = 0;
   }
*/
   bool match(const DE9IM mask)
   {
      bool result = false;
      int i = 0;
      for(i=0; i < 9; i++)
      {
         if(mask.m[i] == '*' || m[i] == mask.m[i] || (mask.m[i] == 'T' && m[i] != 'F'))
            result = true;
         else
         {
            result = false;
            break;
         }
      }
      return result;
   }

   bool disjoint()
   {
      return match("FF*FF****");
   }

   bool equals()
   {
      return match("T*F**FFF*");
   }

   bool contains()
   {
      return match("T*****FF*");
   }

   bool within()
   {
      return match("T*F**F***");
   }

   bool touches()
   {
      return match("FT*******") || match("F**T*****") || match("F***T****");
   }

   bool covers()
   {
      return match("T*****FF*") || match("*T****FF*") || match("***T**FF*") || match("****T*FF*");
   }

   bool crosses(int dimA, int dimB)
   {
      bool result = false;
      if(dimA != dimB || dimA == 1 || dimB == 1) // different dimensions
         result = match(dimA < dimB ? "T*T******" : dimA > dimB ? "T*****T**" : "0********");
      return result;
   }

   bool overlaps(int dimA, int dimB)
   {
      bool result = false;
      if(dimA == dimB)
         result = match(dimA == 1 ? "1*T***T**" : "T*T***T**");
      return result;
   }

   bool intersects()
   {
      return !disjoint();
   }

   bool coveredBy()
   {
      DE9IM flipped;
      flipped.flip(this);
      return flipped.covers();
   }
};

public enum InsideReturn
{
   outside, inside, onTheEdge
};

// Point relations
private bool pointIsSameEpsilon(const GeoPoint a, const GeoPoint b, double e)
{
   return fabs((Radians)a.lat - (Radians)b.lat) < e && fabs((Radians)a.lon - (Radians)b.lon) < e;
}

bool isPointContainedInExtent(const GeoPoint a, const GeoExtent extent)
{
   return (Radians)a.lat >= (Radians)extent.ll.lat - radEpsilon && (Radians)a.lat <= (Radians)extent.ur.lat + radEpsilon &&
          (Radians)a.lon >= (Radians)extent.ll.lon - radEpsilon && (Radians)a.lon <= (Radians)extent.ur.lon + radEpsilon;
}

bool isPointContainedInExtentEpsilon(const GeoPoint a, const GeoExtent extent, double e)
{
   return (Radians)a.lat >= (Radians)extent.ll.lat - (Radians)e && (Radians)a.lat <= (Radians)extent.ur.lat + (Radians)e &&
          (Radians)a.lon >= (Radians)extent.ll.lon - (Radians)e && (Radians)a.lon <= (Radians)extent.ur.lon + (Radians)e;
}

private void pointRelatePoint(const GeoPoint a, const GeoPoint b, double e, DE9IM relation)
{
   if(pointIsSameEpsilon(a, b, e))
   {
      /*
         Equal points
         (0FF FFF FF2)
                b
              I B E
              -----
            I|0 F F
         a  B|F F F
            E|F F 2
      */
      relation = "0FFFFFFF2";
   }
   else
   {
      /*
         Disjoint points
         (FF0 FFF 0F2)
                b
              I B E
              -----
            I|F F 0
         a  B|F F F
            E|0 F 2
      */
      relation = "FF0FFF0F2";
   }
}

private void pointRelateLineString(const GeoPoint a, const LineString b, double e, DE9IM relation)
{
   InsideReturn ptInside = pointInsideLineString(b, a, e);
   if(ptInside == onTheEdge)
   {
      /*
      point on line string boundary (end points)
         (F0F FFF 102)
    line string b
              I B E
              -----
            I|F 0 F
   point a  B|F F F
            E|1 0 2
      */
      relation = "F0FFFF102";
   }
   else if(ptInside == inside)
   {
      /*
      point inside line string
         (0FF FFF 102)
    line string b
              I B E
              -----
            I|0 F F
   point a  B|F F F
            E|1 0 2
      */
      relation = "0FFFFF102";
   }
   else
   {
      /*
      point outside line string
         (FF0 FFF 102)
    line string b
              I B E
              -----
            I|F F 0
   point a  B|F F F
            E|1 0 2
      */
      relation = "FF0FFF102";
   }
}

private void pointRelateBbox(const GeoPoint a, const GeoExtent b, double e, DE9IM relation)
{
   InsideReturn r = outside;

   if(isPointContainedInExtentEpsilon(a, b, e))
      r = isPointContainedInExtentEpsilon(a, b, -e) ? inside : onTheEdge;

   if(r == onTheEdge)
   {
      /*
         Point on bbox boundary
         (F0F FFF 212)
        polygon b
              I B E
              -----
            I|F 0 F
   point a  B|F F F
            E|2 1 2
      */
      relation = "F0FFFF212";
   }
   else if(r == inside)
   {
      /*
         Point inside bbox
         (0FF FFF 212)
        polygon b
              I B E
              -----
            I|0 F F
   point a  B|F F F
            E|2 1 2
      */
      relation = "0FFFFF212";
   }
   else
   {
      /*
         Point outside bbox
         (FF0 FFF 212)
        polygon b
              I B E
              -----
            I|F F 0
   point a  B|F F F
            E|2 1 2
      */
      relation = "FF0FFF212";
   }
}

private void pointRelatePolygon(const GeoPoint a, const Polygon b, double e, DE9IM relation)
{
   InsideReturn r = pointInsidePolygon(b, a, e);

   if(r == onTheEdge)
   {
      /*
         Point on polygon boundary
         (F0F FFF 212)
        polygon b
              I B E
              -----
            I|F 0 F
   point a  B|F F F
            E|2 1 2
      */
      relation = "F0FFFF212";
   }
   else if(r == inside)
   {
      /*
         Point inside polygon
         (0FF FFF 212)
        polygon b
              I B E
              -----
            I|0 F F
   point a  B|F F F
            E|2 1 2
      */
      relation = "0FFFFF212";
   }
   else
   {
      /*
         Point outside polygon
         (FF0 FFF 212)
        polygon b
              I B E
              -----
            I|F F 0
   point a  B|F F F
            E|2 1 2
      */
      relation = "FF0FFF212";
   }
}

// Bounding Box relations

//TODO: maybe combine all these 3 intersects with some internal method?

void bboxRelateBbox(const GeoExtent a, const GeoExtent b, double e, DE9IM relation)
{
   // REVIEW:
   if(a.ll.lon < MAXDOUBLE && a.ll.lon > a.ur.lon)
   {
      GeoExtent aa { { a.ll.lat, a.ll.lon }, { a.ur.lat, 180 } };
      GeoExtent c { { a.ll.lat, -180 }, { a.ur.lat, a.ur.lon } };
      bboxRelateBbox(aa, b, e, relation);
      if(!strcmp(relation, "FF2FF1212"))
      {
         bboxRelateBbox(c, b, e, relation);
      }
   }
   else if(b.ll.lon < MAXDOUBLE && b.ll.lon > b.ur.lon)
   {
      GeoExtent aa { { b.ll.lat, b.ll.lon }, { b.ur.lat, 180 } };
      GeoExtent c { { b.ll.lat, -180 }, { b.ur.lat, b.ur.lon } };
      bboxRelateBbox(a, aa, e, relation);
      if(!strcmp(relation, "FF2FF1212"))
         bboxRelateBbox(a, c, e, relation);
   }
   else if(isBBoxContained(a, b))
      relation = "212101FF2";
   else if((Radians)a.ll.lat < (Radians)b.ur.lat - radEpsilon &&
          (Radians)b.ll.lat < (Radians)a.ur.lat - radEpsilon &&
          (Radians)a.ll.lon < (Radians)b.ur.lon - radEpsilon &&
          (Radians)b.ll.lon < (Radians)a.ur.lon - radEpsilon)
   {
      //TODO: touches-only? we only know if overlaps
      relation = "212101212";
   }
   else
      relation = "FF2FF1212";
}

private void bboxRelatePoint(const GeoExtent a, const GeoPoint b, double e, DE9IM relation)
{
   InsideReturn r = outside;

   if(isPointContainedInExtentEpsilon(b, a, e))
      r = isPointContainedInExtentEpsilon(b, a, -e) ? inside : onTheEdge;

   if(r == onTheEdge)
   {
      /*
         Point on bbox boundary
         (FF2 0F1 FF2)
          point b
              I B E
              -----
            I|F F 2
    bbox a  B|0 F 1
            E|F F 2
      */
      relation = "FF20F1FF2";
   }
   else if(r == inside)
   {
      /*
         Point inside bbox
         (0F2 FF1 FF2)
          point b
              I B E
              -----
            I|0 F 2
    bbox a  B|F F 1
            E|F F 2
      */
      relation = "0F2FF1FF2";
   }
   else
   {
      /*
         Point outside bbox
         (FF2 FF1 0F2)
          point b
              I B E
              -----
            I|F F 2
    bbox a  B|F F 1
            E|0 F 2
      */
      relation = "FF2FF10F2";
   }
}

void bboxRelatePolygon(const GeoExtent a, const Polygon b, double e, DE9IM relation)
{
   if(a.ur.lon < a.ll.lon)
   {
      DE9IM ma, mb;
      bboxRelatePolygon(GeoExtent { { a.ll.lat, a.ll.lon }, { a.ur.lat, 180 } }, b, e, ma);
      bboxRelatePolygon(GeoExtent { { a.ll.lat, -180 }, { a.ur.lat, a.ur.lon } }, b, e, mb);
      relation.combineBExtOR(ma, mb);
   }
   else if(a.ur.lon == a.ll.lon && a.ur.lat == a.ll.lat)
   {
      GeoPoint p = a.ll;
      pointRelatePolygon(p, b, e, relation);
   }
   else
   {
      /* REVIEW: Wrapping issues with non lat/lon?
      GeoExtent polyExtent;
      b.calculateExtent(polyExtent);

      if(!intersectsOrTouchesEpsilon(polyExtent, e))
         relation = "FF2FF1212";
      else */
      {
         // Optimized to be on the stack and avoid dynamic memory allocation
         GeoPoint points[4] = { a.ll, GeoPoint { a.ll.lat, a.ur.lon }, a.ur, GeoPoint { a.ur.lat, a.ll.lon } };
         struct PolygonContour cStruct; PolygonContour c = (PolygonContour)&cStruct;
         ArrayOnStack pointsArray { class(Array)._vTbl, class(Array<GeoPoint>), 0, array = points, 4 };
         ArrayOnStack contoursArray { class(Array)._vTbl, class(Array<PolygonContour>), 0, array = &c, 1 };
         Polygon bboxPoly { };
         bboxPoly.setContours((Array<PolygonContour>)&contoursArray);
         memset(c, 0, sizeof(struct PolygonContour));
         c.points = (Array<GeoPoint>)&pointsArray;
         polygonRelatePolygon(bboxPoly, b, e, relation, true);
      }
   }
}

void bboxRelateLineString(const GeoExtent a, const LineString b, double e, DE9IM relation)
{
   if(a.ur.lon < a.ll.lon)
   {
      DE9IM ma, mb;
      bboxRelateLineString(GeoExtent { { a.ll.lat, a.ll.lon }, { a.ur.lat, 180 } }, b, e, ma);
      bboxRelateLineString(GeoExtent { { a.ll.lat, -180 }, { a.ur.lat, a.ur.lon } }, b, e, mb);
      relation.combineBExtOR(ma, mb);
   }
   else
   {
      // Optimized to be on the stack and avoid dynamic memory allocation
      GeoPoint points[4] = { a.ll, GeoPoint { a.ll.lat, a.ur.lon }, a.ur, GeoPoint { a.ur.lat, a.ll.lon } };
      struct PolygonContour cStruct; PolygonContour c = (PolygonContour)&cStruct;
      ArrayOnStack pointsArray { class(Array)._vTbl, class(Array<GeoPoint>), 0, array = points, 4 };
      ArrayOnStack contoursArray { class(Array)._vTbl, class(Array<PolygonContour>), 0, array = &c, 1 };
      Polygon bboxPoly { };
      bboxPoly.setContours((Array<PolygonContour>)&contoursArray);
      memset(c, 0, sizeof(struct PolygonContour));
      c.points = (Array<GeoPoint>)&pointsArray;
      polygonRelateLineString(bboxPoly, b, e, relation);
   }
}

bool bboxIntersectsOrTouches(const GeoExtent a, const GeoExtent b)
{
   if(a.ll.lon < MAXDOUBLE && a.ll.lon > a.ur.lon)
   {
      GeoExtent aa { { a.ll.lat, a.ll.lon }, { a.ur.lat, 180 } };
      GeoExtent c { { a.ll.lat, -180 }, { a.ur.lat, a.ur.lon } };
      return bboxIntersectsOrTouches(aa, b) || bboxIntersectsOrTouches(c, b);
   }
   else if(b.ll.lon < MAXDOUBLE && b.ll.lon > b.ur.lon)
   {
      GeoExtent aa { { b.ll.lat, b.ll.lon }, { b.ur.lat, 180 } };
      GeoExtent c { { b.ll.lat, -180 }, { b.ur.lat, b.ur.lon } };
      return bboxIntersectsOrTouches(a, aa) || bboxIntersectsOrTouches(a, c);
   }
   else
   return (Radians)a.ll.lat < (Radians)b.ur.lat + radEpsilon &&
          (Radians)b.ll.lat < (Radians)a.ur.lat + radEpsilon &&
          (Radians)a.ll.lon < (Radians)b.ur.lon + radEpsilon &&
          (Radians)b.ll.lon < (Radians)a.ur.lon + radEpsilon;
}

bool bboxIntersectsOrTouchesApprox(const GeoExtent a, const GeoExtent b)
{
   if(a.ll.lon < MAXDOUBLE && a.ll.lon > a.ur.lon)
   {
      GeoExtent aa { { a.ll.lat, a.ll.lon }, { a.ur.lat, 180 } };
      GeoExtent c { { a.ll.lat, -180 }, { a.ur.lat, a.ur.lon } };
      return bboxIntersectsOrTouchesApprox(aa, b) || bboxIntersectsOrTouchesApprox(c, b);
   }
   else if(b.ll.lon < MAXDOUBLE && b.ll.lon > b.ur.lon)
   {
      GeoExtent aa { { b.ll.lat, b.ll.lon }, { b.ur.lat, 180 } };
      GeoExtent c { { b.ll.lat, -180 }, { b.ur.lat, b.ur.lon } };
      return bboxIntersectsOrTouchesApprox(a, aa) || bboxIntersectsOrTouchesApprox(a, c);
   }
   else
   return (Radians)a.ll.lat < (Radians)b.ur.lat + radEpsilon &&
          (Radians)b.ll.lat < (Radians)a.ur.lat + radEpsilon &&
          (Radians)a.ll.lon < (Radians)b.ur.lon + radEpsilon &&
          (Radians)b.ll.lon < (Radians)a.ur.lon + radEpsilon;
}

bool bboxIntersectsOrTouchesEpsilon(const GeoExtent a, const GeoExtent b, Radians epsilon)
{
   if(a.ll.lon < MAXDOUBLE && a.ll.lon > a.ur.lon)
   {
      GeoExtent aa { { a.ll.lat, a.ll.lon }, { a.ur.lat, 180 } };
      GeoExtent c { { a.ll.lat, -180 }, { a.ur.lat, a.ur.lon } };
      return bboxIntersectsOrTouchesEpsilon(aa, b, epsilon) || bboxIntersectsOrTouchesEpsilon(c, b, epsilon);
   }
   else if(b.ll.lon < MAXDOUBLE && b.ll.lon > b.ur.lon)
   {
      GeoExtent aa { { b.ll.lat, b.ll.lon }, { b.ur.lat, 180 } };
      GeoExtent c { { b.ll.lat, -180 }, { b.ur.lat, b.ur.lon } };
      return bboxIntersectsOrTouchesEpsilon(a, aa, epsilon) || bboxIntersectsOrTouchesEpsilon(a, c, epsilon);
   }
   else
   return (Radians)a.ll.lat < (Radians)b.ur.lat + epsilon &&
          (Radians)b.ll.lat < (Radians)a.ur.lat + epsilon &&
          (Radians)a.ll.lon < (Radians)b.ur.lon + epsilon &&
          (Radians)b.ll.lon < (Radians)a.ur.lon + epsilon;
}

bool isBBoxContained(const GeoExtent a, const GeoExtent container)
{
   return isBBoxContainedEpsilon(a, container, radEpsilon);
   /*return (Radians)ll.lat >= (Radians)container.ll.lat - radEpsilon &&
          (Radians)ur.lat <= (Radians)container.ur.lat + radEpsilon &&
          (Radians)ll.lon >= (Radians)container.ll.lon - radEpsilon &&
          (Radians)ur.lon <= (Radians)container.ur.lon + radEpsilon;*/
}

bool isBBoxContainedEpsilon(const GeoExtent a, const GeoExtent container, double e)
{
   return (Radians)a.ll.lat >= (Radians)container.ll.lat - (Radians)e &&
          (Radians)a.ur.lat <= (Radians)container.ur.lat + (Radians)e &&
          (Radians)a.ll.lon >= (Radians)container.ll.lon - (Radians)e &&
          (Radians)a.ur.lon <= (Radians)container.ur.lon + (Radians)e;
}

// LineString relations

InsideReturn pointInsideLineString(const LineString ls, const GeoPoint b, double e)
{
   InsideReturn result = outside;
   Array<GeoPoint> points = (Array<GeoPoint>)ls.points;
   int count = points ? points.count : 0;
   const GeoPoint * p = points ? points.array : null;
   if(count &&
      (pointIsSameEpsilon(b, p, e) ||
       pointIsSameEpsilon(b, points[count-1], e)))
      result = onTheEdge;
   else
   {
      int i;
      for(i = 0; i < count-1; i++, p++)
      {
         const GeoPoint * np = p+1;
         Radians minLat, maxLat, minLon, maxLon;
         if(p->lat < np->lat) minLat = p->lat, maxLat = np->lat; else minLat = np->lat, maxLat = p->lat;
         if(p->lon < np->lon) minLon = p->lon, maxLon = np->lon; else minLon = np->lon, maxLon = p->lon;
         if((Radians)b.lat >= minLat - Radians { e } && (Radians)b.lat <= maxLat + Radians { e } &&
            (Radians)b.lon >= minLon - Radians { e } && (Radians)b.lon <= maxLon + Radians { e })
         {
            double d = fromLine(b, p, np);
            if(fabs(d) < e)
            {
               result = inside;
               break;
            }
         }
      }
   }
   return result;
}

InsideReturn segmentInsideLineString(const GeoPoint a1, const GeoPoint a2, const GeoPoint b1, const GeoPoint b2,
   double e, InsideReturn rAInB[2], InsideReturn rBInA[2])
{
   InsideReturn result = outside;
   InsideReturn aInB[2] = { outside, outside }, bInA[2] = { outside, outside };
   Radians aMinLat, aMaxLat, aMinLon, aMaxLon;
   Radians bMinLat, bMaxLat, bMinLon, bMaxLon;

   if(a1.lat < a2.lat) aMinLat = a1.lat, aMaxLat = a2.lat; else aMinLat = a2.lat, aMaxLat = a1.lat;
   if(a1.lon < a2.lon) aMinLon = a1.lon, aMaxLon = a2.lon; else aMinLon = a2.lon, aMaxLon = a1.lon;
   if(b1.lat < b2.lat) bMinLat = b1.lat, bMaxLat = b2.lat; else bMinLat = b2.lat, bMaxLat = b1.lat;
   if(b1.lon < b2.lon) bMinLon = b1.lon, bMaxLon = b2.lon; else bMinLon = b2.lon, bMaxLon = b1.lon;

   if(aMaxLat >= bMinLat - Radians { e } && aMinLat <= bMaxLat + Radians { e } &&
      aMaxLon >= bMinLon - Radians { e } && aMinLon <= bMaxLon + Radians { e })
   {
      Radians daLat = (Radians)a2.lat - (Radians)a1.lat, daLon = (Radians)a2.lon - (Radians)a1.lon;
      Radians dbLat = (Radians)b2.lat - (Radians)b1.lat, dbLon = (Radians)b2.lon - (Radians)b1.lon;
      Radians da1b1Lat = (Radians)a1.lat - (Radians)b1.lat, da1b1Lon = (Radians)a1.lon - (Radians)b1.lon;
      bool parallel = fabs(daLon * dbLat - dbLon * daLat) <= e;
      bool a1b1 = (fabs(da1b1Lat) < e && fabs(da1b1Lon) < e);
      bool a1b2 = (fabs((Radians)a1.lat - (Radians)b2.lat) < e && fabs((Radians)a1.lon - (Radians)b2.lon) < e);
      bool a2b1 = (fabs((Radians)a2.lat - (Radians)b1.lat) < e && fabs((Radians)a2.lon - (Radians)b1.lon) < e);
      bool a2b2 = (fabs((Radians)a2.lat - (Radians)b2.lat) < e && fabs((Radians)a2.lon - (Radians)b2.lon) < e);
      // Identical (Test Case #7) if both aInB and bInA are all onTheEdge
      if(a1b1 || a1b2)
         aInB[0] = onTheEdge;
      else if(a1.lat >= bMinLat - Radians { e } && a1.lat <= bMaxLat + Radians { e } &&
              a1.lon >= bMinLon - Radians { e } && a1.lon <= bMaxLon + Radians { e } &&
              fabs(fromLine(a1, b1, b2)) < e)
         aInB[0] = inside;

      if(a2b1 || a2b2)
         aInB[1] = onTheEdge;
      else if(a2.lat >= bMinLat - Radians { e } && a2.lat <= bMaxLat + Radians { e } &&
              a2.lon >= bMinLon - Radians { e } && a2.lon <= bMaxLon + Radians { e } &&
              fabs(fromLine(a2, b1, b2)) < e)
         aInB[1] = inside;

      if(a1b1 || a2b1)
         bInA[0] = onTheEdge;
      else if(b1.lat >= aMinLat - Radians { e } && b1.lat <= aMaxLat + Radians { e } &&
              b1.lon >= aMinLon - Radians { e } && b1.lon <= aMaxLon + Radians { e } &&
              fabs(fromLine(b1, a1, a2)) < e)
         bInA[0] = inside;

      if(a1b2 || a2b2)
         bInA[1] = onTheEdge;
      else if(b2.lat >= aMinLat - Radians { e } && b2.lat <= aMaxLat + Radians { e } &&
              b2.lon >= aMinLon - Radians { e } && b2.lon <= aMaxLon + Radians { e } &&
              fabs(fromLine(b2, a1, a2)) < e)
         bInA[1] = inside;

      if(a1b1 || a1b2 || a2b1 || a2b2) // At least one segment extremity is shared
      {
         if(parallel && (
            (aMaxLat > bMinLat + Radians { e } && aMinLat < bMaxLat - Radians { e }) ||
            (aMaxLon > bMinLon + Radians { e } && aMinLon < bMaxLon - Radians { e })))
            result = inside;  // Overlapping (Test Case #7 or #9)
         else
            result = onTheEdge; // Sharing only segment extremity (Test Case #12)
      }
      else if(aInB[0] == inside || aInB[1] == inside || bInA[0] == inside || bInA[1] == inside)
         result = parallel ? inside /* Test Case #8 or #11 */ : onTheEdge /* Test case #10 */;
      else if(!parallel &&
         segIntersect(daLat, daLon, da1b1Lat, da1b1Lon, dbLat, dbLon, e))
         result = onTheEdge;  // Test case #13 (intersection)
      // Otherwise Test case #6 (overlapping envelope)
   }
   // Otherwise Test cases #6 (non-overlapping envelope)
   if(rAInB) rAInB[0] = aInB[0], rAInB[1] = aInB[1];
   if(rBInA) rBInA[0] = bInA[0], rBInA[1] = bInA[1];
   return result;
}

bool segmentFullyInsideLineString(const LineString ls, const GeoPoint a, const GeoPoint b, double e)
{
   bool anyInside = false, aInside = false, bInside = false;
   Array<GeoPoint> points = (Array<GeoPoint>)ls.points;
   int count = points ? points.count : 0, i;
   const GeoPoint * p0;

   for(i = 0, p0 = &points[0]; i < count - 1; i++, p0++)
   {
      const GeoPoint * np0 = p0 + 1;
      InsideReturn abInSeg[2], r = segmentInsideLineString(p0, np0, a, b, e, null, abInSeg);
      if(r == inside)
         anyInside = true;
      if(abInSeg[0] != outside)
         aInside = true;
      if(abInSeg[1] != outside)
         bInside = true;

      if(anyInside && aInside && bInside) return true;
   }
   return false;
}

void lineStringRelatePoint(const LineString ls, const GeoPoint b, double e, DE9IM relation)
{
   InsideReturn ptInside = pointInsideLineString(ls, b, e);
   if(ptInside == onTheEdge)
   {
      /*
      point on line string boundary (end points)
         (FF1 0F0 FF2)
          point b
              I B E
              -----
            I|F F 1
line string a  B|0 F 0
            E|F F 2
      */
      relation = "FF10F0FF2";
   }
   else if(ptInside == inside)
   {
      /*
      point inside line string
         (0F1 FF0 FF2)
          point b
              I B E
              -----
            I|0 F 1
line string a  B|F F 0
            E|F F 2
      */
      relation = "0F1FF0FF2";
   }
   else
   {
      /*
      point outside line string
         (FF1 FF0 0F2)
          point b
              I B E
              -----
            I|F F 1
line string a  B|F F 0
            E|0 F 2
      */
      relation = "FF1FF00F2";
   }
}

bool checkForSplitSegments(double e,
   int i, int j, int count, int bCount,
   const GeoPoint * p0, const GeoPoint * np0, const GeoPoint * p1, const GeoPoint * np1,
   const InsideReturn aInB[2], const InsideReturn bInA[2])
{
   bool result = false;

   // Simple case (crossing segments)
   if(aInB[0] == outside && aInB[1] == outside &&
      bInA[0] == outside && bInA[1] == outside)
      result = true;
   // Complicated cases for LineString split exactly at but continuing beyond the crossing point:
   else if(aInB[0] == outside && aInB[1] == outside &&
           bInA[0] == outside && bInA[1] == inside && j < bCount-2)
   {
      // LineString B crossing p0..np0 segment of LineString A at np1
      const GeoPoint * nnp1 = np1+1;
      double d1 = fromLine(nnp1, p0, np0);
      double d2 = fromLine(p1, p0, np0);
      if(Sgn(d1) != Sgn(d2) && (e > 0 || (fabs(d1) > -e && fabs(d2) > -e)))
         result = true;
   }
   else if(aInB[0] == outside && aInB[1] == outside &&
           bInA[0] == inside  && bInA[1] == outside && j > 0)
   {
      // LineString B crossing p0..np0 segment of LineString A at p1
      const GeoPoint * pp1 = p1-1;
      double d1 = fromLine(pp1, p0, np0);
      double d2 = fromLine(np1, p0, np0);
      if(Sgn(d1) != Sgn(d2) && (e > 0 || (fabs(d1) > -e && fabs(d2) > -e)))
         result = true;
   }
   else if(bInA[0] == outside && bInA[1] == outside &&
           aInB[0] == outside && aInB[1] == inside && i < count-2)
   {
      // LineString A crossing p1..np1 segment of LineString B at np0
      const GeoPoint * nnp0 = np0+1;
      double d1 = fromLine(nnp0, p1, np1);
      double d2 = fromLine(p0, p1, np1);
      if(Sgn(d1) != Sgn(d2) && (e > 0 || (fabs(d1) > -e && fabs(d2) > -e)))
         result = true;
   }
   else if(bInA[0] == outside && bInA[1] == outside &&
           aInB[0] == inside  && aInB[1] == outside && i > 0)
   {
      // LineString A crossing p1..np1 segment of LineString B at p0
      const GeoPoint * pp0 = p0-1;
      double d1 = fromLine(pp0, p1, np1);
      double d2 = fromLine(np0, p1, np1);
      if(Sgn(d1) != Sgn(d2) && (e > 0 || (fabs(d1) > -e && fabs(d2) > -e)))
         result = true;
   }
   // Even more complicated cases where both LineStrings are split exactly at crossing point
   else if(aInB[0] == outside && aInB[1] == onTheEdge &&
           bInA[0] == outside && bInA[1] == onTheEdge && i < count-2 && j < bCount-2)
   {
      // Doubly-split cross at np0 / np1
      const GeoPoint * nnp0 = np0+1, * nnp1 = np1+1;
      double d1 = fromLine(nnp0, p1, np1);
      double d2 = fromLine(p0,   p1, np1);
      double d3 = fromLine(nnp1, p0, np0);
      double d4 = fromLine(p1,   p0, np0);
      if(Sgn(d1) != Sgn(d2) && Sgn(d3) != Sgn(d4) && (e > 0 || (fabs(d1) > -e && fabs(d2) > -e && fabs(d3) > -e && fabs(d4) > -e)))
         result = true;
   }
   else if(aInB[0] == onTheEdge && aInB[1] == outside &&
           bInA[0] == outside && bInA[1] == onTheEdge && i > 0 && j < bCount-2)
   {
      // Doubly-split cross at p0 / np1
      const GeoPoint * pp0 = p0-1, * nnp1 = np1+1;
      double d1 = fromLine(pp0,  p1, np1);
      double d2 = fromLine(p0,   p1, np1);
      double d3 = fromLine(nnp1, p0, np0);
      double d4 = fromLine(p1,   p0, np0);
      if(Sgn(d1) != Sgn(d2) && Sgn(d3) != Sgn(d4) && (e > 0 || (fabs(d1) > -e && fabs(d2) > -e && fabs(d3) > -e && fabs(d4) > -e)))
         result = true;
   }
   else if(aInB[0] == outside && aInB[1] == onTheEdge &&
           bInA[0] == onTheEdge && bInA[1] == outside && i < count-2 && j > 0)
   {
      // Doubly-split cross at np0 / p1
      const GeoPoint * nnp0 = np0+1, * pp1 = p1-1;
      double d1 = fromLine(nnp0, p1, np1);
      double d2 = fromLine(p0,   p1, np1);
      double d3 = fromLine(pp1,  p0, np0);
      double d4 = fromLine(p1,   p0, np0);
      if(Sgn(d1) != Sgn(d2) && Sgn(d3) != Sgn(d4) && (e > 0 || (fabs(d1) > -e && fabs(d2) > -e && fabs(d3) > -e && fabs(d4) > -e)))
         result = true;
   }
   else if(aInB[0] == onTheEdge && aInB[1] == outside &&
           bInA[0] == outside && bInA[1] == onTheEdge && i > 0 && j > 0)
   {
      // Doubly-split cross at p0 / p1
      const GeoPoint * pp0 = p0-1, * pp1 = p1-1;
      double d1 = fromLine(pp0, p1, np1);
      double d2 = fromLine(p0,  p1, np1);
      double d3 = fromLine(pp1, p0, np0);
      double d4 = fromLine(p1,  p0, np0);
      if(Sgn(d1) != Sgn(d2) && Sgn(d3) != Sgn(d4) && (e > 0 || (fabs(d1) > -e && fabs(d2) > -e && fabs(d3) > -e && fabs(d4) > -e)))
         result = true;
   }
   return result;
}

void lineStringRelateLineString(const LineString a, const LineString b, double e, DE9IM relation)
{
   Array<GeoPoint> aPoints = (Array<GeoPoint>)a.points, bPoints = (Array<GeoPoint>)b.points;
   int count = aPoints ? aPoints.count : 0, bCount = bPoints ? bPoints.count : 0, i, j;
   const GeoPoint * p0, * p1;

   relation.zero();

   if(bCount < 2 || count < 2) return;

   // Exterior / Interior intersection
   for(j = 0, p1 = bPoints.array; relation.m[6] != '1' && j < bCount-1; j++, p1++)
      if(!segmentFullyInsideLineString(a, p1, p1 + 1, e))
         relation.m[6] = '1';

   for(i = 0, p0 = aPoints.array; i < count-1; i++, p0++)
   {
      const GeoPoint * np0 = p0+1;

      // Interior / Exterior intersection
      if(relation.m[2] != '1' && !segmentFullyInsideLineString(b, p0, np0, e))
         relation.m[2] = '1';

      for(j = 0, p1 = bPoints.array; j < bCount-1; j++, p1++)
      {
         const GeoPoint * np1 = p1+1;
         InsideReturn aInB[2], bInA[2], r = segmentInsideLineString(p0, np0, p1, np1, e, aInB, bInA);

         // Interior / Interior intersections
         if(r == inside)
            relation.m[0] = '1'; // Interior / Interior segment intersection
         else if(r == onTheEdge && relation.m[0] == 'F' &&
            checkForSplitSegments(e, i, j, count, bCount, p0, np0, p1, np1, aInB, bInA))
            // Interior / Interior point intersection (crossing)
            relation.m[0] = '0';

         // Boundary intersections

         // Boundary / IBE
         if(i == 0)
         {
            if(aInB[0] == outside)
            {
               if(relation.m[5] != '0' && pointInsideLineString(b, p0, e) == outside)
                  relation.m[5] = '0'; // Boundary / Exterior
            }
            else if(aInB[0] == onTheEdge &&
               ((j == 0 && bInA[0] == onTheEdge) || (j == bCount-2 && bInA[1] == onTheEdge)))
               relation.m[4] = '0'; // Boundary / Boundary
            else
               relation.m[3] = '0'; // Boundary / Interior
         }
         if(i == count - 2)
         {
            if(aInB[1] == outside)
            {
               if(relation.m[5] != '0' && pointInsideLineString(b, np0, e) == outside)
                  relation.m[5] = '0'; // Boundary / Exterior
            }
            else if(aInB[1] == onTheEdge &&
               ((j == 0 && bInA[0] == onTheEdge) || (j == bCount-2 && bInA[1] == onTheEdge)))
               relation.m[4] = '0'; // Boundary / Boundary
            else
               relation.m[3] = '0'; // Boundary / Interior
         }

         // IBE / Boundary
         if(j == 0)
         {
            if(bInA[0] == outside)
            {
               if(relation.m[7] != '0' && pointInsideLineString(a, p1, e) == outside)
                  relation.m[7] = '0'; // Exterior / Boundary
            }
            else if(bInA[0] == onTheEdge &&
               ((i == 0 && aInB[0] == onTheEdge) || (i == count-2 && aInB[1] == onTheEdge)))
               relation.m[4] = '0'; // Boundary / Boundary
            else
               relation.m[1] = '0'; // Interior / Boundary
         }
         if(j == bCount - 2)
         {
            if(bInA[1] == outside)
            {
               if(relation.m[7] != '0' && pointInsideLineString(a,  np1, e) == outside)
                  relation.m[7] = '0'; // Exterior / Boundary
            }
            else if(bInA[1] == onTheEdge &&
               ((i == 0 && aInB[0] == onTheEdge) || (i == count-2 && aInB[1] == onTheEdge)))
               relation.m[4] = '0'; // Boundary / Boundary
            else
               relation.m[1] = '0'; // Interior / Boundary
         }
      }
   }
}

// This flavor only sets [6] and [7]
void lineStringRelateLineString67(const LineString a, const LineString b, double e, DE9IM relation)
{
   Array<GeoPoint> aPoints = (Array<GeoPoint>)a.points, bPoints = (Array<GeoPoint>)b.points;
   int count = aPoints ? aPoints.count : 0, bCount = bPoints ? bPoints.count : 0, i, j;
   const GeoPoint * p0, * p1;

   relation.zero();

   if(bCount < 2 || count < 2) return;

   // Exterior / Interior intersection
   for(j = 0, p1 = bPoints.array; relation.m[6] != '1' && j < bCount-1; j++, p1++)
      if(!segmentFullyInsideLineString(a, p1, p1 + 1, e))
         relation.m[6] = '1';

   for(i = 0, p0 = aPoints.array; i < count-1; i++, p0++)
   {
      const GeoPoint * np0 = p0+1;
      for(j = 0, p1 = bPoints.array; j < bCount-1; j+=bCount-2, p1+=bCount-2)
      {
         const GeoPoint * np1 = p1+1;
         InsideReturn aInB[2], bInA[2];

         segmentInsideLineString(p0, np0, p1, np1, e, aInB, bInA);

         // Boundary intersections

         // IBE / Boundary
         if(j == 0)
         {
            if(bInA[0] == outside)
            {
               if(relation.m[7] != '0' && pointInsideLineString(a, p1, e) == outside)
                  relation.m[7] = '0'; // Exterior / Boundary
            }
         }
         if(j == bCount - 2)
         {
            if(bInA[1] == outside)
            {
               if(relation.m[7] != '0' && pointInsideLineString(a, np1, e) == outside)
                  relation.m[7] = '0'; // Exterior / Boundary
            }
         }
         if(bCount ==2)
            break;
      }
   }
}

void lineStringRelatePolygon(const LineString a, const Polygon b, double e, DE9IM relation) // NOTE: flip matrix for Polygon-LineString case
{
   Array<PolygonContour> contours = b.getContours();
   Array<GeoPoint> aPoints = (Array<GeoPoint>)a.points;
   int count = aPoints ? aPoints.count : 0, i;
   const GeoPoint * p0 = aPoints ? aPoints.array : null;

   relation.zero();
   relation.m[6] = '2'; // A LineString's exterior shares a 2D intersection with any polygon's infinite exterior plane

   if(count < 2) return;

   for(i = 0; i < count-1; i++, p0++)
   {
      const GeoPoint * np0 = p0+1;
      InsideReturn r1 = pointInsidePolygon(b, p0, e);
      InsideReturn r2 = pointInsidePolygon(b, np0, e);

      if(r1 == inside || r2 == inside)
      {
         relation.m[0] = '1'; // LineString Interior / Polygon Interior intersection is a 1D curve
         if((r1 == inside && i == 0) || (r2 == inside && i == count - 2))
            relation.m[3] = '0'; // Boundary/Inside intersection
      }
      if(r1 == outside || r2 == outside)
      {
         relation.m[2] = '1'; // LineString Interior / Polygon Exterior intersection is a 1D curve
         if((r1 == outside && i == 0) || (r2 == outside && i == count - 2))
            relation.m[5] = '0'; // LineString Boundary / Polygon Exterior intersection is a point
      }

      for(c : contours)
      {
         PolygonContour contour = c;
         Array<GeoPoint> cPoints = (Array<GeoPoint>)contour.points;
         int cCount = cPoints.count, j;
         GeoPoint * p1 = cPoints.array;

         if(cCount > 2 &&
            fabs((Radians)cPoints[cCount - 1].lat - (Radians)cPoints[0].lat) < 10*DBL_EPSILON &&
            fabs((Radians)cPoints[cCount - 1].lon - (Radians)cPoints[0].lon) < 10*DBL_EPSILON)
            cCount--;
         if(cCount < 3) continue;

         for(j = 0; j < cCount; j++, p1++)
         {
            const GeoPoint * np1 = j == cCount - 1 ? cPoints.array : p1+1;
            InsideReturn aInB[2], bInA[2], lsSegInCtrSeg = segmentInsideLineString(p0, np0, p1, np1, e, aInB, bInA);
            if(lsSegInCtrSeg == onTheEdge)
            {
               // line segment crosses inside polygon
               if(aInB[0] == outside && aInB[1] == outside && bInA[0] == outside && bInA[1] == outside)
                  relation.m[0] = '1'; // LineString Interior / Polygon Interior intersection is a 1D curve

               // LineString Interior / Polygon Boundary
               if(relation.m[1] != '1')
               {
                  if(i == 0 && aInB[0] != outside);
                  else if(i == count-2 && aInB[1] != outside);
                  else
                     relation.m[1] = '0'; // intersection is a point
               }
            }
            else if(lsSegInCtrSeg == inside) // LineString Interior / Polygon Boundary
               relation.m[1] = '1'; // intersection is an overlapping segment

            // LineString Boundary / Polygon Boundary
            if(i == 0)
            {
               if(aInB[0] != outside)
                  relation.m[4] = '0';
               else if(r1 == outside)
                  relation.m[5] = '0';
            }
            if(i == count - 2)
            {
               if(aInB[1] != outside)
                  relation.m[4] = '0';
               else if(r2 == outside)
                  relation.m[5] = '0';
            }
         }
      }
   }

   // LineString Exterior / Polygon Boundary Intersection
   for(c : contours)
   {
      PolygonContour contour = c;
      Array<GeoPoint> cPoints = (Array<GeoPoint>)contour.points;
      int cCount = cPoints.count, j;
      GeoPoint * p1 = cPoints.array;

      if(cCount > 2 &&
         fabs((Radians)cPoints[cCount - 1].lat - (Radians)cPoints[0].lat) < 10*DBL_EPSILON &&
         fabs((Radians)cPoints[cCount - 1].lon - (Radians)cPoints[0].lon) < 10*DBL_EPSILON)
         cCount--;
      if(cCount < 3) continue;

      for(j = 0; j < cCount; j++, p1++)
      {
         const GeoPoint * np1 = j < cCount - 1 ? p1 + 1 : &cPoints[0];
         if(!segmentFullyInsideLineString(a, p1, np1, e))
         {
            relation.m[7] = '1';
            break;
         }
      }
      if(relation.m[7] == '1')
         break;
   }
}

void lineStringRelateBbox(const LineString a, const GeoExtent b, double e, DE9IM relation)
{
   // TODO: Try to avoid allocations
   if(b.ur.lon < b.ll.lon)
   {
      DE9IM ma, mb;
      ma.wild();
      mb.wild();

      lineStringRelateBbox(a, { { b.ll.lat, b.ll.lon }, { b.ur.lat, 180 } }, e, ma);
      lineStringRelateBbox(a, { { b.ll.lat, -180 }, { b.ur.lat, b.ur.lon } }, e, mb);
      relation.combineBExtOR(ma, mb);
   }
   else
   {
      // Optimized to be on the stack and avoid dynamic memory allocation
      GeoPoint points[4] = { b.ll, GeoPoint { b.ll.lat, b.ur.lon }, b.ur, GeoPoint { b.ur.lat, b.ll.lon } };
      struct PolygonContour cStruct; PolygonContour c = (PolygonContour)&cStruct;
      ArrayOnStack pointsArray { class(Array)._vTbl, class(Array<GeoPoint>), 0, array = points, 4 };
      ArrayOnStack contoursArray { class(Array)._vTbl, class(Array<PolygonContour>), 0, array = &c, 1 };
      Polygon bboxPoly { };
      bboxPoly.setContours((Array<PolygonContour>)&contoursArray);
      memset(c, 0, sizeof(struct PolygonContour));
      c.points = (Array<GeoPoint>)&pointsArray;
      lineStringRelatePolygon(a, bboxPoly, e, relation);
   }
}

#define USE_DUVANENKO   0

private bool lineStringIntersectsBbox(const LineString a, const GeoExtent b)
{
   bool result = false;
   Array<GeoPoint> aPoints = (Array<GeoPoint>)a.points;
   int count = aPoints ? aPoints.count : 0, i;
   const GeoPoint * p = aPoints ? aPoints.array : null;
#if !USE_DUVANENKO
   double e = 1E-11;
   Radians dLat = b.ur.lat - b.ll.lat;
   Radians dLon = b.ur.lon - b.ll.lon;
   bool outside[4] =
   {
      p->lat < b.ll.lat - e,
      p->lon < b.ll.lon - e,
      p->lat > b.ur.lat + e,
      p->lon > b.ur.lon + e
   };
   if(!outside[0] && !outside[1] && !outside[2] && !outside[3])
      return true;
#endif
   for(i = 1; i < count; i++, p++)
   {
      const GeoPoint * np = p + 1;
#if USE_DUVANENKO
      if(clipLine_Duvanenko(p, np, b, null, null))
         return true;
#else
      bool nextOutside[4] =
      {
         np->lat < b.ll.lat - e,
         np->lon < b.ll.lon - e,
         np->lat > b.ur.lat + e,
         np->lon > b.ur.lon + e
      };
      if(!(outside[0] && nextOutside[0]) &&
         !(outside[1] && nextOutside[1]) &&
         !(outside[2] && nextOutside[2]) &&
         !(outside[3] && nextOutside[3]))
      {
         GeoPoint s1 { np->lat - p->lat, np->lon - p->lon };
         Radians dLatLL = p->lat - b.ll.lat;
         Radians dLonLL = p->lon - b.ll.lon;
         Radians dLatUR = p->lat - b.ur.lat;
         Radians dLonUR = p->lon - b.ur.lon;
         if(((fabs(dLatLL) < fabs(e) || fabs(dLatUR) < fabs(e)) && !outside[1] && !outside[3]) ||
            ((fabs(dLonLL) < fabs(e) || fabs(dLonUR) < fabs(e)) && !outside[0] && !outside[1]))
         {
            if(e >= 0)
               return true;
         }
         else if(
                 /*
                 PolygonContour::edgeOverlapSeg(s1, { dLatLL, dLonLL }, dLat, 0) ||
                 PolygonContour::edgeOverlapSeg(s1, { dLatLL, dLonLL }, 0, dLon) ||
                 PolygonContour::edgeOverlapSeg(s1, { dLatLL, dLonUR }, dLat, 0) ||
                 PolygonContour::edgeOverlapSeg(s1, { dLatUR, dLonLL }, 0, dLon)
                 */
                 segIntersect(s1.lat, s1.lon, dLatLL, dLonLL, dLat, 0, e) ||
                 segIntersect(s1.lat, s1.lon, dLatLL, dLonLL, 0, dLon, e) ||
                 segIntersect(s1.lat, s1.lon, dLatLL, dLonUR, dLat, 0, e) ||
                 segIntersect(s1.lat, s1.lon, dLatUR, dLonLL, 0, dLon, e)
                 )
            return true;
      }
      memcpy(outside, nextOutside, 4 * sizeof(bool));
      if(!outside[0] && !outside[1] && !outside[2] && !outside[3])
         return true;
#endif
   }
   return result;
}

// Polygon Contours
private static inline bool segIntersect(Radians s1Lat, Radians s1Lon, Radians dLat, Radians dLon, Radians s2Lat, Radians s2Lon, Radians e)
{
   double d = (s1Lon * s2Lat - s2Lon * s1Lat);
   if(fabs(d) > 1E-13) // Return false for parallel segments
   {
      double factor = 1.0 / d;
      Radians s = (s1Lon * dLat - s1Lat * dLon) * factor;
      if(s + e >= 0 && s - e <= 1)
      {
         Radians t = ( s2Lon * dLat - s2Lat * dLon) * factor;
         if(t + e >= 0 && t - e <= 1)
         {
            // intersection = { a1.lat + t * s1.lat, a1.lon + t * s1.lon };
            return true;
         }
      }
   }
   return false;
}

#define SEG_COLINEAR_EPSILON  1E-22

private static inline bool edgeOverlapSeg(const GeoPoint s1, const GeoPoint d, Radians s2Lat, Radians s2Lon)
{
   double denom = (Radians)s1.lon * (Radians)s2Lon - (Radians)s2Lat * (Radians)s1.lat;
   if(fabs(denom) > SEG_COLINEAR_EPSILON) // Co-linear otherwise
   {
      int sDenom = Sgn(denom);
      double s = (Radians)s1.lon * (Radians)d.lat - (Radians)s1.lat * (Radians)d.lon, as = fabs(s);
      if(as > 0 && Sgn(s) == sDenom)
      {
         double t = (Radians)s2Lat * (Radians)d.lat - (Radians)s2Lon * (Radians)d.lat, at = fabs(t);
         if(at > 0 && Sgn(t) == sDenom)
         {
            double d1 = s - denom, ad1 = fabs(d1);
            double d2 = t - denom, ad2 = fabs(d2);
            if(ad1 > 0 && Sgn(d1) != sDenom &&
               ad2 > 0 && Sgn(d2) != sDenom)
            {
               if(as < 0.01 || at < 0.01 || d1 < 0.01 || d2 < 0.01)
               {
                  double dt = t / denom;
                  return dt >= 0 && dt <= 1;
               }
               return true;
            }
         }
      }
   }
   return false;
}

private InsideReturn contourEdgesOverlap2(const PolygonContour a, const PolygonContour b, Radians e)
{
   // NOTE: This new function is used by PolygonContour::contourContainsOrTouches2and contourOverlapsEx()
   //       for the new DE-9IM relations and may be doing something quite different from previous contourEdgesOverlap()
   Array<GeoPoint> aPoints = (Array<GeoPoint>)a.points, bPoints = (Array<GeoPoint>)b.points;
   int count = aPoints ? aPoints.count : 0, bCount = bPoints ? bPoints.count : 0, i, j;
   const GeoPoint * p0, * p1;

   // Handle repeated first points
   if(count > 2 &&
      fabs((Radians)aPoints[count - 1].lat - (Radians)aPoints[0].lat) < 10*DBL_EPSILON &&
      fabs((Radians)aPoints[count - 1].lon - (Radians)aPoints[0].lon) < 10*DBL_EPSILON)
      count--;
   if(bCount > 2 &&
      fabs((Radians)bPoints[bCount - 1].lat - (Radians)bPoints[0].lat) < 10*DBL_EPSILON &&
      fabs((Radians)bPoints[bCount - 1].lon - (Radians)bPoints[0].lon) < 10*DBL_EPSILON)
      bCount--;
   if(bCount < 3 || count < 3) return outside;

   for(i = 0, p0 = aPoints.array; i < count; i++, p0++)
   {
      const GeoPoint * np0 = i < count - 1 ? p0+1 : &aPoints[0];
      for(j = 0, p1 = bPoints.array; j < bCount; j++, p1++)
      {
         const GeoPoint * np1 = j < bCount - 1 ? p1+1 : &bPoints[0];
         InsideReturn aInB[2], bInA[2], r = segmentInsideLineString(p0, np0, p1, np1, e, aInB, bInA);

         if(r == inside)
            return inside;
         // REVIEW: Explain this logic...
         else if((r == onTheEdge || (e < 0 && segmentInsideLineString(p0, np0, p1, np1, -e, aInB, bInA) == onTheEdge)) &&
            checkForSplitSegments(e, i, j, count, bCount, p0, np0, p1, np1, aInB, bInA))
            return r == onTheEdge ? onTheEdge : inside;
      }
   }
   return outside;
}

private bool contourEdgesOverlap(const PolygonContour a, const PolygonContour b, Radians e)
{
   Array<GeoPoint> aPoints = (Array<GeoPoint>)a.points, bPoints = (Array<GeoPoint>)b.points;
   GeoPoint * p0 = aPoints.array;
   int count = aPoints.count, bCount = bPoints.count, i, j;
   // Handle repeated first points
   if(count > 2 &&
      fabs((Radians)aPoints[count - 1].lat - (Radians)aPoints[0].lat) < 10*DBL_EPSILON &&
      fabs((Radians)aPoints[count - 1].lon - (Radians)aPoints[0].lon) < 10*DBL_EPSILON)
      count--;
   if(bCount > 2 &&
      fabs((Radians)bPoints[bCount - 1].lat - (Radians)bPoints[0].lat) < 10*DBL_EPSILON &&
      fabs((Radians)bPoints[bCount - 1].lon - (Radians)bPoints[0].lon) < 10*DBL_EPSILON)
      bCount--;
   if(bCount < 3 || count < 3) return false;

   for(i = 0; i < count; i++, p0++)
   {
      GeoPoint * np0 = i == count - 1 ? aPoints.array : p0+1;
      GeoPoint * p1 = bPoints.array;
      Radians s1Lat = np0->lat - p0->lat, s1Lon = np0->lon - p0->lon;
      Radians minLat, minLon, maxLat, maxLon;
      if(p0->lat < np0->lat) minLat = p0->lat, maxLat = np0->lat; else minLat = np0->lat, maxLat = p0->lat;
      if(p0->lon < np0->lon) minLon = p0->lon, maxLon = np0->lon; else minLon = np0->lon, maxLon = p0->lon;

      for(j = 0; j < bCount; j++, p1++)
      {
         GeoPoint * np1 = j == bCount - 1 ? bPoints.array : p1+1;
         if(
            ((Radians)p1->lat > minLat - Abs(e) || (Radians)np1->lat > minLat - Abs(e)) &&
            ((Radians)p1->lon > minLon - Abs(e) || (Radians)np1->lon > minLon - Abs(e)) &&
            ((Radians)p1->lat < maxLat + Abs(e) || (Radians)np1->lat < maxLat + Abs(e)) &&
            ((Radians)p1->lon < maxLon + Abs(e) || (Radians)np1->lon < maxLon + Abs(e)))
         {
            Radians s2Lat = np1->lat - p1->lat, s2Lon = np1->lon - p1->lon;
            Radians dLat = p0->lat - p1->lat, dLon = p0->lon - p1->lon;
            if(fabs(dLon) < fabs(e) && fabs(dLat) < fabs(e))   // TOCHECK: Should this be an && ?
            {
               if(e < 0) continue;
               return true;
            }
            else if(segIntersect(s1Lat, s1Lon, dLat, dLon, s2Lat, s2Lon, e))
            {
               return true;
            }
         }
      }
   }
   return false;
}

private bool contourEdgesOverlapExtent(const PolygonContour a, const GeoExtent b, Radians e)
{
   Array<GeoPoint> aPoints = (Array<GeoPoint>)a.points;
   const GeoPoint * p = aPoints.array;
   int count = aPoints.count, i;
#if !USE_DUVANENKO
   Radians dLat = b.ur.lat - b.ll.lat;
   Radians dLon = b.ur.lon - b.ll.lon;
   bool outside[4] =
   {
      p->lat < b.ll.lat,
      p->lon < b.ll.lon,
      p->lat > b.ur.lat,
      p->lon > b.ur.lon
   };
#endif
   for(i = 0; i < count; i++, p++)
   {
      const GeoPoint * np = i == count - 1 ? aPoints.array : p + 1;
#if USE_DUVANENKO
      if(clipLine_Duvanenko(p, np, b, null, null))
         return true;
#else
      bool nextOutside[4] =
      {
         np->lat < b.ll.lat,
         np->lon < b.ll.lon,
         np->lat > b.ur.lat,
         np->lon > b.ur.lon
      };
      if(!(outside[0] && nextOutside[0]) &&
         !(outside[1] && nextOutside[1]) &&
         !(outside[2] && nextOutside[2]) &&
         !(outside[3] && nextOutside[3]))
      {
         GeoPoint s1 { np->lat - p->lat, np->lon - p->lon };
         Radians dLatLL = p->lat - b.ll.lat;
         Radians dLonLL = p->lon - b.ll.lon;
         /*
         if(edgeOverlapSeg(s1, { dLatLL, dLonLL }, dLat, 0) ||
            edgeOverlapSeg(s1, { dLatLL, dLonLL }, 0, dLon) ||
            edgeOverlapSeg(s1, { dLatLL, p->lon - b.ur.lon }, dLat, 0) ||
            edgeOverlapSeg(s1, { p->lat - b.ur.lat, dLonLL }, 0, dLon))
            return true;
         */
         if(segIntersect(s1.lat, s1.lon, dLatLL, dLonLL, dLat, 0, e) ||
            segIntersect(s1.lat, s1.lon, dLatLL, dLonLL, 0, dLon, e) ||
            segIntersect(s1.lat, s1.lon, dLatLL, p->lon - b.ur.lon, dLat, 0, e) ||
            segIntersect(s1.lat, s1.lon, p->lat - b.ur.lat, dLonLL, 0, dLon, e))
            return true;
      }
      memcpy(outside, nextOutside, 4 * sizeof(bool));
#endif
   }
   return false;
}

// TODO: Re-use generic Ecere 2D graphics code?
private static inline Radians fromLine(const GeoPoint p, const GeoPoint a, const GeoPoint b)
{
   return ((Radians)b.lon - (Radians)a.lon) * ((Radians)p.lat - (Radians)a.lat) - ((Radians)p.lon - (Radians)a.lon) * ((Radians)b.lat - (Radians)a.lat);
}

#if 0 // This is only used from within pointInsideInt(), and __int128 is not supported on 32-bit platforms
private static inlinint ::fromLineInt(int64 px, int64 py, int64 ax, int64 ay, int64 bx, int64 by)
{
   __int128 d = (__int128)(bx - ax) * (py - ay) - (__int128)(px - ax) * (by - ay);
   return d < 0 ? -1 : d > 0 ? 1 : 0;
}
#endif

InsideReturn pointInsideContour(const PolygonContour contour, const GeoPoint point, double e)
{
   return pointInsideContour2(contour, point, null, e);
}

InsideReturn pointInsideContour2(const PolygonContour a, const GeoPoint point, int * pointIndex, double e)
{
   // This implements Dan Sunday's winding number algorithm
   // See https://web.archive.org/web/20130126163405/http://geomalgorithms.com/a03-_inclusion.html
   Array<GeoPoint> aPoints = (Array<GeoPoint>)a.points;
   const GeoPoint * p = aPoints.array;
   int count = aPoints.count, winding = 0, i;
   const GeoExtent * aExtent = a.getExtentPtr();

   // REVIEW: Dateline crossing
   if(aExtent->ur.lat || aExtent->ur.lon || aExtent->ll.lat || aExtent->ll.lon)
   {
      if((Radians)point.lat < (Radians)aExtent->ll.lat - Abs(e) ||
         (Radians)point.lon < (Radians)aExtent->ll.lon - Abs(e) ||
         (Radians)point.lat > (Radians)aExtent->ur.lat + Abs(e) ||
         (Radians)point.lon > (Radians)aExtent->ur.lon + Abs(e))
         return outside;
   }

   // Handle repeated first points
   if(count > 2 &&
      fabs((Radians)aPoints[count - 1].lat - (Radians)aPoints[0].lat) < (Radians)10*DBL_EPSILON &&
      fabs((Radians)aPoints[count - 1].lon - (Radians)aPoints[0].lon) < (Radians)10*DBL_EPSILON)
      count--;

   for(i = 0; i < count; i++, p++)
   {
      const GeoPoint * np = i == count - 1 ? aPoints.array : p+1;
      double d = MAXDOUBLE;

      if((Radians)p->lat <= (Radians)point.lat)
      {
         if((Radians)np->lat > (Radians)point.lat)
         {
            d = fromLine(point, p, np);
            if(d > 0)
               winding++;
         }
      }
      else if((Radians)np->lat <= (Radians)point.lat)
      {
         d = fromLine(point, p, np);
         if(d < 0)
            winding--;
      }
      if(d == MAXDOUBLE || fabs(d) < e)
      {
         Radians minLat, maxLat, minLon, maxLon;
         if(p->lat < np->lat) minLat = p->lat, maxLat = np->lat; else minLat = np->lat, maxLat = p->lat;
         if(p->lon < np->lon) minLon = p->lon, maxLon = np->lon; else minLon = np->lon, maxLon = p->lon;
         if((Radians)point.lat >= minLat - Radians { e } && (Radians)point.lat <= maxLat + Radians { e } &&
            (Radians)point.lon >= minLon - Radians { e } && (Radians)point.lon <= maxLon + Radians { e })
         {
            if(d == MAXDOUBLE)
            {
               d = fromLine(point, p, np);
               if(fabs(d) > /*=*/ e) continue;
            }
            if(pointIndex) *pointIndex = i;
            return onTheEdge;
         }
      }
   }
   return winding ? inside : outside;
}

// NOTE: This returns true if A contains all of B's inside, and A's inside and border contain B's border
bool contourContainsOrTouches2(const PolygonContour a, const PolygonContour b, double e)
{
   Array<GeoPoint> aPoints = (Array<GeoPoint>)a.points, bPoints = b != null ? (Array<GeoPoint>)b.points : null;
   if(aPoints && aPoints.count && bPoints && bPoints.count)
   {
      InsideReturn insideReturn = pointInsideContour2(a, bPoints[0], null, e);
      if(insideReturn == inside || insideReturn == onTheEdge)
      {
         const GeoExtent * aExtent = a.getExtentPtr(), * bExtent = b.getExtentPtr();

         if(isBBoxContainedEpsilon(bExtent, aExtent, -e))
            return true;
         if(insideReturn == onTheEdge || !contourEdgesOverlap2(a, b, -e))
         {
            int i;
            for(i = 0; i < bPoints.count; i++)
            {
               InsideReturn r = pointInsideContour2(a, bPoints[i], null, e);
               if(r == outside)
                  return false;
            }
            return true;
         }
      }
   }
   return false;
}

bool contourTouches(const PolygonContour a, const PolygonContour b/*, int * index*/)
{
   Array<GeoPoint> aPoints = (Array<GeoPoint>)a.points, bPoints = b != null ? (Array<GeoPoint>)b.points : null;
   if(aPoints && aPoints.count && bPoints && bPoints.count)
   {
      //InsideReturn insideReturn = pointInside(b._points[0], 1E-12);
      //if(insideReturn == onTheEdge)
         if(!contourEdgesOverlap(a, b, -1E-12))
         {
            int i;
            for(i = 0; i < bPoints.count; i++)
            {
               if(pointInsideContour(a, bPoints[i], 1E-12) == onTheEdge)
                  return true;
            }
            return false;
         }
   }
   return false;
}

bool contourContains(const PolygonContour a, const PolygonContour b)
{
   Array<GeoPoint> aPoints = (Array<GeoPoint>)a.points, bPoints = b != null ? (Array<GeoPoint>)b.points : null;
   if(aPoints && aPoints.count && bPoints && bPoints.count)
   {
      if(pointInsideContour2(a, bPoints[0], null, 1E-12) == inside)
         if(!contourEdgesOverlap(a, b, 1E-12))
            return true;
   }
   return false;
}

bool contourOverlaps(const PolygonContour a, const PolygonContour b)
{
   bool result = false;
   Array<GeoPoint> aPoints = (Array<GeoPoint>)a.points, bPoints = (Array<GeoPoint>)b.points;

   for(p : aPoints; pointInsideContour2(b, p, null, 0) != outside) return true;
   for(p : bPoints; pointInsideContour2(a, p, null, 0) != outside) return true;
   result = contourEdgesOverlap(a, b, 0);
   return result;
}

InsideReturn contourOverlapsEx(const PolygonContour a, const PolygonContour b, bool * sharedSegment, bool * sharedPoint, double e)
{
   InsideReturn result = outside;
   int pIndex = 0;
   Array<GeoPoint> aPoints = (Array<GeoPoint>)a.points, bPoints = (Array<GeoPoint>)b.points;
   int count = aPoints.count, bCount = bPoints.count, i;
   const GeoPoint * p0 = aPoints.array;

   // Handle repeated first points
   if(count > 2 &&
      fabs((Radians)aPoints[count - 1].lat - (Radians)aPoints[0].lat) < 10*DBL_EPSILON &&
      fabs((Radians)aPoints[count - 1].lon - (Radians)aPoints[0].lon) < 10*DBL_EPSILON)
      count--;
   if(bCount > 2 &&
      fabs((Radians)bPoints[bCount - 1].lat - (Radians)bPoints[0].lat) < 10*DBL_EPSILON &&
      fabs((Radians)bPoints[bCount - 1].lon - (Radians)bPoints[0].lon) < 10*DBL_EPSILON)
      bCount--;
   if(bCount < 3 || count < 3) return outside;

   for(i = 0; i < count; i++, p0++)
   {
      InsideReturn r = pointInsideContour2 /*Int*/(b, p0, &pIndex, e);
      if(r == inside)
         result = inside;
      else if(r == onTheEdge)
      {
         const GeoPoint * pp0 = i == 0 ? aPoints.array + count - 1 : p0-1;
         const GeoPoint * np0 = i == count - 1 ? aPoints.array : p0+1;
         const GeoPoint * p1 = &bPoints[pIndex];
         const GeoPoint * np1 = pIndex == bCount - 1 ? bPoints.array : p1+1;
         // Point p0 is on Segment p1..np1
         if(sharedSegment)
            if(segmentInsideLineString(pp0, p0, p1, np1, e, null, null) == inside ||
               segmentInsideLineString(p0, np0, p1, np1, e, null, null) == inside)
               *sharedSegment = true;
         if(sharedPoint) *sharedPoint = true;

         if(result != inside)
            result = onTheEdge;
      }
   }

   p0 = bPoints.array;
   for(i = 0; i < bCount; i++, p0++)
   {
      InsideReturn r = pointInsideContour2 /*Int*/(a, p0, &pIndex, e);
      if(r == inside)
         result = inside;
#if 1  // REVIEW: Shouldn't cases on the edges be caught in first pass? CSV 6, 10, 14 tests failures without this
      else if(r == onTheEdge)
      {
         const GeoPoint * pp0 = i == 0 ? bPoints.array + bCount - 1 : p0-1;
         const GeoPoint * np0 = i == bCount - 1 ? bPoints.array : p0+1;
         const GeoPoint * p1 = &aPoints[pIndex];
         const GeoPoint * np1 = pIndex == count - 1 ? aPoints.array : p1+1;
         // Point p0 is on Segment p1..np1
         if(sharedSegment)
            if(segmentInsideLineString(pp0, p0, p1, np1, e, null, null) == inside ||
               segmentInsideLineString(p0, np0, p1, np1, e, null, null) == inside)
            *sharedSegment = true;
         if(sharedPoint)
            *sharedPoint = true;

         if(result != inside)
            result = onTheEdge;
      }
#endif
   }

   if(result == outside)
      result = contourEdgesOverlap2(a, b, e);
   return result;
}

bool contourContainsExtent(const PolygonContour a, const GeoExtent b)
{
   Array<GeoPoint> aPoints = (Array<GeoPoint>)a.points;
   if(aPoints && aPoints.count)
   {
      // true if a point of the extent is within the contour...
      if(pointInsideContour2(a, b.ll, null, 1E-12) == inside)
         // ...and if no bounding segment of the extent intersects the contour edges
         if(!contourEdgesOverlapExtent(a, b, -1E-12))
            return true;
   }
   return false;
}

bool contourOverlapsExtent(const PolygonContour a, const GeoExtent b)
{
   bool result = false;

   if((Radians)b.ur.lon < (Radians)b.ll.lon)
   {
      result = contourOverlapsExtent(a, GeoExtent { { b.ll.lat, b.ll.lon }, { b.ur.lat, Pi } });
      if(!result)
         result = contourOverlapsExtent(a, GeoExtent { { b.ll.lat, -Pi }, { b.ur.lat, b.ur.lon } });
   }
   else
   {
      int i;
      Array<GeoPoint> aPoints = (Array<GeoPoint>)a.points;
      const GeoPoint * p = aPoints.array;
      uint count = aPoints.count;

      // true if any point of this contour is within the box
      for(i = 0; i < count; i++, p++)
      {
         if((Radians)p->lat >= (Radians)b.ll.lat && (Radians)p->lat <= (Radians)b.ur.lat &&
            (Radians)p->lon >= (Radians)b.ll.lon && (Radians)p->lon <= (Radians)b.ur.lon)
            return true;
      }
      // true if any point of the extent is within the contour
      if(pointInsideContour2(a, b.ll, null, 0) != outside) return true;
      if(pointInsideContour2(a, b.ur, null, 0) != outside) return true;
      if(pointInsideContour2(a, { b.ll.lat, b.ur.lon }, null, 0) != outside) return true;
      if(pointInsideContour2(a, { b.ur.lat, b.ll.lon }, null, 0) != outside) return true;
      // true if any bounding segment of the extent intersects the contour edges
      result = contourEdgesOverlapExtent(a, b, 0);
   }
   return result;
}


// Polygons

bool polygonIntersectsBbox(const Polygon a, const GeoExtent extent)
{
   bool result = false;
   Array<PolygonContour> aContours = a.getContours();

   if(aContours.count)
   {
      // Test whether outer contour overlaps with extent
      PolygonContour outer = aContours[0];
      const GeoExtent * outerExtent = outer.getExtentPtr();
      if((!outerExtent->ll.lat && !outerExtent->ur.lat) || outerExtent->intersects(extent))
         result = contourOverlapsExtent(outer, extent);
      if(result)
      {
         int i;

         // Check if extent falls in a hole
         for(i = 1; i < aContours.count; i++)
         {
            PolygonContour c = aContours[i];
            const GeoExtent * cExtent = c->getExtentPtr();
            if((cExtent->ll.lat || cExtent->ur.lat) && !isBBoxContained(extent, cExtent))
               continue;

            if(contourContainsExtent(c, extent))
            {
               result = false;
               break;
            }
         }
      }
   }
   return result;
}

bool polygonIntersectsPolygon(const Polygon a, const Polygon b)
{
   bool result = false;
   GeoExtent ext1, ext2;
   a.calculateExtent(ext1);
   b.calculateExtent(ext2);

   if(bboxIntersectsOrTouches(ext1, ext2))
   {
      Array<PolygonContour> aContours = a.getContours(), bContours = b.getContours();
      for(c : aContours; !c.inner)
      {
         const GeoExtent * cExtent = c.getExtentPtr();
         for(c2 : bContours; !result && !c2.inner)
         {
            const GeoExtent * c2Extent = c2.getExtentPtr();
            result = bboxIntersectsOrTouchesApprox(cExtent, c2Extent) && contourOverlaps(c, c2);
            if(result) break;
         }
         if(result) break;
      }
   }
   return result;
}

bool polygonContainsPoint(const Polygon a, const GeoPoint p, double e)
{
   bool result = false;
   Array<PolygonContour> contours = a.getContours();

   if(contours && contours.count)
   {
      PolygonContour outer = contours[0];
      if(pointInsideContour2(outer, p, null, e))
      {
         int i;

         result = true;
         for(i = 1; result && i < contours.count; i++)
         {
            PolygonContour inner = contours[i];
            if(pointInsideContour2(inner, p, null, e))
               result = false;
         }
      }
   }
   return result;
}

// NOTE: This is same as containsPoint() but indicates whether on edge
InsideReturn pointInsidePolygon(const Polygon a, const GeoPoint p, double e)
{
   InsideReturn result = outside;
   PolygonContour outer = a.outer;
   if(outer)
   {
      result = pointInsideContour2(outer, p, null, e);
      if(result == inside)
      {
         Array<PolygonContour> aContours = (Array<PolygonContour>)a.getContours();
         for(c : aContours; c.inner)
         {
            InsideReturn r = pointInsideContour2(c, p, null, e);
            if(r == onTheEdge)
            {
               result = onTheEdge;
               break;
            }
            else if(r == inside)
            {
               result = outside;
               break;
            }
         }
      }
   }
   return result;
}

void polygonRelatePolygon(const Polygon a, const Polygon b, double e, DE9IM relation, bool thisIsBBOX)
{
   bool sharedSegment = false, sharedPoint = false;
   PolygonContour outerA = a.outer, outerB = b.outer;
   InsideReturn overlapping;

   GeoExtent ext1, ext2;
   a.calculateExtentNoDL(ext1);
   b.calculateExtentNoDL(ext2);
   if(!bboxIntersectsOrTouchesEpsilon(ext1, ext2, e))
   {
      relation = "FF2FF1212";
      return;
   }

   if(thisIsBBOX && isBBoxContainedEpsilon(ext2, ext1, -e)) // REVIEW: Initial optimization for BBOX
      overlapping = inside;
   else
      overlapping = contourOverlapsEx(outerA, outerB, &sharedSegment, &sharedPoint, e);

   if(overlapping == inside)
   {
      // NOTE: not yet handling inner contours
      if(contourContainsOrTouches2(outerA, outerB, e))
      {
         // NOTE: not yet handling identical polygons
         if(sharedSegment)
         {
            /*
            a contains b (sharing segment)
               (212 FF1 FF2)
                      b
                    I B E
                    -----
                  I|2 1 2
               a  B|F 1 1
                  E|F F 2
            */
            // verify if inside or touching inner contours
            if(!a.inner)
               relation = "212F11FF2";
            else
               polygonRelateInnerToOuter(a, relation, outerB,  e, true, false, null);
         }
         else if(sharedPoint)
         {
            /*
            a contains b (sharing point)
               (212 FF1 FF2)
                      b
                    I B E
                    -----
                  I|2 1 2
               a  B|F 0 1
                  E|F F 2
            */
            // verify if inside or touching inner contours
            if(!a.inner)
               relation = "212F01FF2";
            else
               polygonRelateInnerToOuter(a, relation, outerB, e, false, true, null);
         }
         else
         {
            /*
            a contains b (inside the boundaries)
               (212 FF1 FF2)
                      b
                    I B E
                    -----
                  I|2 1 2
               a  B|F F 1
                  E|F F 2
            */
            if(!a.inner)
               relation = "212FF1FF2";
            else
               polygonRelateInnerToOuter(a, relation, outerB, e, false, false, null);
         }
      }
      else if(contourContainsOrTouches2(outerB, outerA, e))
      {
         // NOTE: not yet handling identical polygons
         if(sharedSegment)
         {
            /*
            b contains a (sharing segment)
               (2FF 1FF 212)
                      b
                    I B E
                    -----
                  I|2 F F
               a  B|1 2 F
                  E|2 1 2
            */
            if(!b.inner)
               relation = "2FF11F212";
            else
               polygonRelateInnerToOuter(a, relation, outerA, e, true, false, (Array<PolygonContour>)b.inner);
         }
         else if(sharedPoint)
         {
            /*
            b contains a (sharing point)
               (2FF 1FF 212)
                      b
                    I B E
                    -----
                  I|2 F F
               a  B|1 1 F
                  E|2 1 2
            */

            if(!b.inner)
               relation = "2FF10F212";
            else
               polygonRelateInnerToOuter(a, relation, outerA, e, false, true, (Array<PolygonContour>)b.inner);
         }
         else
         {
            /*
            b contains a (inside the boundaries)
               (2FF 1FF 212)
                      b
                    I B E
                    -----
                  I|2 F F
               a  B|1 F F
                  E|2 1 2
            */
            if(!b.inner)
               relation = "2FF1FF212";
            else
               polygonRelateInnerToOuter(a, relation, outerA, e, false, false, (Array<PolygonContour>)b.inner);
         }
      }
      else
      {
         if(sharedSegment)
         {
            /*
            a and b overlap
               (212 101 212)
                      b
                    I B E
                    -----
                  I|2 1 2
               a  B|1 1 1
                  E|2 1 2
            */
            relation =  "212111212";
         }
         else
         {
            /*
            a and b overlap
               (212 101 212)
                      b
                    I B E
                    -----
                  I|2 1 2
               a  B|1 0 1
                  E|2 1 2
            */
            relation = "212101212";
         }
      }
   }
   else if(overlapping == onTheEdge)
   {
      // TODO: Reduce number of tests
      if(sharedSegment && contourContainsOrTouches2(outerA, outerB, e) && contourContainsOrTouches2(outerB, outerA, e))
      {
         Array<PolygonContour> innerA = (Array<PolygonContour>)a.inner, innerB = (Array<PolygonContour>)b.inner;
         if(!(innerA || innerB))
            relation = "2FFF1FFF2"; // equivalent
         else if((innerA && !innerB) || (!innerA && innerB) || (innerA.GetCount() != innerB.GetCount()))
            relation = "2121F1212"; //outer contours identical but only one has inner, so overlap?
         else
         {
            relation.zero();
            relation.m[0] = '2';
            relation.m[8] = '2';
            polygonCompareInnerContours(a, innerB, e, relation);
         }

         /*
         a and b are equivalent
            (FF2 F11 212)
                   b
                 I B E
                 -----
               I|2 F F
            a  B|F 1 F
               E|F F 2
         */
         //relation = "2FFF1FFF2";
      }
      else if(sharedSegment)
      {
         /*
         a and b are touching (sharing segments)
            (FF2 F11 212)
                   b
                 I B E
                 -----
               I|F F 2
            a  B|F 1 1
               E|2 1 2
         */
         relation = "FF2F11212";
      }
      else
      {
         /*
         a and b are touching (sharing a point)
            (FF2 F11 212)
                   b
                 I B E
                 -----
               I|F F 2
            a  B|F 0 1
               E|2 1 2
         */
         relation = "FF2F01212";
      }
   }
   else
   {
      /*
         Completely disjoint:
         (FF2 FF1 212)
                b
              I B E
              -----
            I|F F 2
         a  B|F F 1
            E|2 1 2
      */
      relation = "FF2FF1212";
   }
}

void polygonRelateInnerToOuter(const Polygon a, DE9IM relation, const PolygonContour b, double e, bool isSharedSeg, bool isSharedPoint, Array<PolygonContour> innerB)
{
   Array<PolygonContour> contours = innerB ? (Array<PolygonContour>)innerB : (Array<PolygonContour>)a.inner;
   InsideReturn overlap;
   bool isB = innerB != null;
   relation.zero();
   relation.m[8] = '2';
   for(a : contours)
   {
      bool sharedSegment = false, sharedPoint = false;
      overlap = contourOverlapsEx(a, b, &sharedSegment, &sharedPoint, e);
      if(overlap != outside)
      {
         bool aContains = contourContainsOrTouches2(a, b, e);
         bool bContains = contourContainsOrTouches2(b, a, e);
         // NOTE avoiding use of some conditionals since we don't want to overrite an existing # with F
         if(overlap == inside)
         {
            relation.m[2] = '2';
            if(aContains)
               relation.m[5] = '1', relation.m[6] = '2', relation.m[7] = '1';//"FF2FF1212"; // b inside inner
            else
            {
               relation.m[0] = '2', relation.m[1] = '1', relation.m[3] = '1', relation.m[6] = '2';
               if(bContains)// b contains a.inner
               {
                  if(isSharedSeg || sharedSegment)
                     relation.m[4] = '1', relation.m[5] = '1', relation.m[7] = '1';
                  else if(isSharedPoint || sharedPoint)
                     relation.m[4] = '0', relation.m[5] = '1', relation.m[7] = '1';
                  if(!isB)
                     relation.m[5] = '1';
                  else
                     relation.m[7] = '1';
               }
               else
               {
                  relation.m[4] = (isSharedSeg || sharedSegment) ? '1' : '0';
                  relation.m[5] = '1', relation.m[7] = '1';
               }
            }
         }
         else
         {
            if(!isB)
            {
               relation.m[2] = '2';
               if(sharedSegment && aContains && bContains)
                  relation.m[4] = '1', relation.m[5] = '1', relation.m[6] = '2', relation.m[7] = '1';//"FF2F11212"; // verify this
               else
               {
                  relation.m[0] = '2', relation.m[1] = '1', relation.m[5] = '1';
                  if(isSharedSeg || sharedSegment)
                     relation.m[4] = '1';
                  else if(isSharedPoint || sharedPoint)
                     relation.m[4] = '0';
                  if(overlap == onTheEdge)
                     relation.m[3] = '1', relation.m[6] = '2', relation.m[7] = '1';//"212111212"
               }
            }
            else
            {
               //relation.m[0] = '2';
               if(sharedSegment && aContains && bContains)//"FF2F11212
                  relation.m[2] = '2', relation.m[4] = '1', relation.m[5] = '1', relation.m[6] = '2', relation.m[7] = '1';//"FF2F11212"; // verify this
               else
               {
                  relation.m[0] = '2', relation.m[3] = '1', relation.m[6] = '2', relation.m[7] = '1';
                  if(isSharedSeg || sharedSegment)
                     relation.m[4] = '1';
                  else if(isSharedPoint || sharedPoint)
                     relation.m[4] = '0';
                  if(overlap == onTheEdge)
                     relation.m[1] = '1', relation.m[2] = '2', relation.m[3] = '1', relation.m[5] = '1', relation.m[6] = '2', relation.m[7] = '1';//"212111212"
               }
            }
         }
      }
      else
         relation.m[0] = '2', relation.m[3] = '1', relation.m[6] = '2', relation.m[7] = '1';//"2FF1FF212";
   }
}

void polygonCompareInnerContours(const Polygon a, Array<PolygonContour> innerB, double e, DE9IM relation)
{
   InsideReturn overlap = outside;
   Array<PolygonContour> innerA = (Array<PolygonContour>)a.inner;
   bool sharedSegment = false, sharedPoint = false;

   for(a : innerA)
   {
      for(b : innerB)
      {
         overlap = contourOverlapsEx(a, b, &sharedSegment, &sharedPoint, e);
         if(overlap == onTheEdge)
         {
            relation.m[4] = sharedSegment ? '1' : '0';
            // identical
            if(!(sharedSegment && contourContainsOrTouches2(a, b, e) && contourContainsOrTouches2(b, a, e)))
               relation.m[1] = '1', relation.m[2] = '2', relation.m[3] = '1', relation.m[5] = '1';
         }
         else
         {
            relation.m[1] = '1', relation.m[3] = '1';//, relation.m[6] = '2';
            if(overlap == inside)
            {
               bool aContains = contourContainsOrTouches2(a, b, e), bContains = contourContainsOrTouches2(b, a, e);

               if(sharedSegment || sharedPoint || !aContains)//!(bContains || aContains))
                  relation.m[2] = '2';
               relation.m[4] = (sharedPoint || !(aContains || bContains)) ? '0' : '1';
               if(sharedSegment || sharedPoint || !aContains)//!(bContains || aContains))
                  relation.m[5] = '1';
               if(!bContains || (sharedPoint || sharedSegment))
                  relation.m[7] = '1', relation.m[6] = '2';// flipped 212111FF2"
            }
            else
               relation.m[2] = '2', relation.m[6] = '2';
         }
      }
   }
}

void polygonRelateLineString(const Polygon a, const LineString b, double e, DE9IM relation)
{
   DE9IM relLSPoly;
   lineStringRelatePolygon(b, a, e, relLSPoly);
   relation.flip(relLSPoly);
}

void polygonRelateBbox(const Polygon a, const GeoExtent b, double e, DE9IM relation)
{
   // TODO: Try to avoid allocations
   if(b.ur.lon < b.ll.lon)
   {
      DE9IM ma, mb;

      polygonRelateBbox(a, { { b.ll.lat, b.ll.lon }, { b.ur.lat, 180 } }, e, ma);
      polygonRelateBbox(a, { { b.ll.lat, -180 }, { b.ur.lat, b.ur.lon } }, e, mb);
      relation.combineBExtOR(ma, mb);
   }
   else
   {
      /* REVIEW: GeoExtent polyExtent;
      calculateExtent(polyExtent);

      if(!polyExtent.intersectsOrTouchesEpsilon(b, e))
         relation = "FF2FF1212";
      else*/
      {
         // Optimized to be on the stack and avoid dynamic memory allocation
         GeoPoint points[4] = { b.ll, GeoPoint { b.ll.lat, b.ur.lon }, b.ur, GeoPoint { b.ur.lat, b.ll.lon } };
         struct PolygonContour cStruct; PolygonContour c = (PolygonContour)&cStruct;
         ArrayOnStack pointsArray { class(Array)._vTbl, class(Array<GeoPoint>), 0, array = points, 4 };
         ArrayOnStack contoursArray { class(Array)._vTbl, class(Array<PolygonContour>), 0, array = &c, 1 };
         Polygon bboxPoly { };
         bboxPoly.setContours((Array<PolygonContour>)&contoursArray);
         memset(c, 0, sizeof(struct PolygonContour));
         c.points = (Array<GeoPoint>)&pointsArray;
         polygonRelatePolygon(a, bboxPoly, e, relation, false);
      }
   }
}

void polygonRelatePoint(const Polygon a, const GeoPoint p, double e, DE9IM relation)
{
   InsideReturn ptInside = pointInsidePolygon(a, p, e);
   if(ptInside == onTheEdge)
   {
      /*
         Point on polygon boundary
         (FF2 0F1 FF2)
          point b
              I B E
              -----
            I|F F 2
 polygon a  B|0 F 1
            E|F F 2
      */
      relation = "FF20F1FF2";
   }
   else if(ptInside == inside)
   {
      /*
         Point inside polygon
         (0F2 FF1 FF2)
          point b
              I B E
              -----
            I|0 F 2
 polygon a  B|F F 1
            E|F F 2
      */
      relation = "0F2FF1FF2";
   }
   else
   {
      /*
         Point outside polygon
         (FF2 FF1 0F2)
          point b
              I B E
              -----
            I|F F 2
 polygon a  B|F F 1
            E|0 F 2
      */
      relation = "FF2FF10F2";
   }
}


// Geometry
public void geometryRelate(const Geometry a, const Geometry b, DE9IM result)
{
   double e = Max(a.epsilon, b.epsilon);
   if(!e) e = 1E-11;
   result.wild();

   switch(b.type)
   {
      case bbox:               geometryRelateBbox(a, b.bbox, e, result); break;
      case point:              geometryRelatePoint(a, b.point, e, result); break;
      case lineString:         geometryRelateLineString(a, b.lineString, e, result); break;
      case polygon:            geometryRelatePolygon(a, b.polygon, e, result); break;
      case multiPoint:         geometryRelateMultiPoint(a, b.multiPoint, e, result); break;
      case multiLineString:    geometryRelateMultiLineString(a, b.multiLineString, e, result); break;
      case multiPolygon:       geometryRelateMultiPolygon(a, b.multiPolygon, e, result); break;
      case geometryCollection: geometryRelateGeometryCollection(a, b.geometryCollection, e, result);  break;
   }
}

public bool geometryDisjoint(const Geometry a, const Geometry b)
{
   DE9IM relation;
   geometryRelate(a, b, relation);
   return relation.match("FF*FF****");
}

public bool geometryEquals(const Geometry a, const Geometry b)
{
   DE9IM relation;
   geometryRelate(a, b, relation);
   return relation.match("T*F**FFF*");
}

public bool geometryContains(const Geometry a, const Geometry b)
{
   DE9IM relation;
   geometryRelate(a, b, relation);
   return relation.match("T*****FF*");
}

public bool geometryWithin(const Geometry a, const Geometry b)
{
   DE9IM relation;
   geometryRelate(a, b, relation);
   return relation.match("T*F**F***");
   // or simply: return b.contains(this);
}

public bool geometryTouches(const Geometry a, const Geometry b)
{
   DE9IM relation;
   geometryRelate(a, b, relation);
   return relation.match("FT*******") || relation.match("F**T*****") || relation.match("F***T****");
}

public bool geometryCovers(const Geometry a, const Geometry b)
{
   DE9IM relation;

   geometryRelate(a, b, relation);
   return relation.match("T*****FF*") || relation.match("*T****FF*") ||
          relation.match("***T**FF*") || relation.match("****T*FF*");
}

public bool geometryCrosses(const Geometry a, const Geometry b)
{
   bool result = false;
   int dimA = a.dimension, dimB = b.dimension;
   if(dimA != dimB || dimA == 1 || dimB == 1) // different dimensions
   {
      DE9IM relation;
      geometryRelate(a, b, relation);
      result = relation.match(dimA < dimB ? "T*T******" : dimA > dimB ? "T*****T**" : "0********");
   }
   return result;
}

public bool geometryOverlaps(const Geometry a, const Geometry b)
{
   bool result = false;
   int dimA = a.dimension, dimB = b.dimension;
   if(dimA == dimB)
   {
      DE9IM relation;
      geometryRelate(a, b, relation);
      result = relation.match(dimA == 1 ? "1*T***T**" : "T*T***T**");
   }
   return result;
}

public bool geometryIntersects(const Geometry a, const Geometry b)
{
   return !geometryDisjoint(a, b);
}

bool geometryCoveredBy(const Geometry a, const Geometry b)
{
   return geometryCovers(b, a);
}

static void geometryRelatePolygon(const Geometry a, const Polygon b, double e, DE9IM result)
{
   result.wild();
   switch(a.type)
   {
      case bbox:              bboxRelatePolygon(a.bbox, b, e, result); break;
      case point:             pointRelatePolygon(a.point, b, e, result); break;
      case lineString:        lineStringRelatePolygon(a.lineString, b, e, result); break;
      case polygon:           polygonRelatePolygon(a.polygon, b, e, result, false); break;
      case multiPoint:
         for(p : a.multiPoint)
         {
            DE9IM r;
            pointRelatePolygon(p, b, e, r);
            result.combineBExtOR(result, r);
         }
         break;
      case multiLineString:
         for(l : a.multiLineString)
         {
            DE9IM r;
            lineStringRelatePolygon(l, b, e, r);
            result.combineBExtOR(result, r);
         }
         break;
      case multiPolygon:
         for(p : a.multiPolygon)
         {
            DE9IM r;
            polygonRelatePolygon(p, b, e, r, false);
            result.combineBExtOR(result, r);
         }
         break;
      case geometryCollection:
         for(c : a.geometryCollection)
         {
            DE9IM r;
            geometryRelatePolygon(c, b, e, r);
            result.combineBExtOR(result, r);
         }
         break;
   }
}

static void geometryRelateBbox(const Geometry a, const GeoExtent b, double e, DE9IM result)
{
   result.wild();
   switch(a.type)
   {
      case bbox:              bboxRelateBbox(a.bbox, b, e, result); break;
      case point:             pointRelateBbox(a.point, b, e, result); break;
      case lineString:        lineStringRelateBbox(a.lineString, b, e, result); break;
      case polygon:           polygonRelateBbox(a.polygon, b, e, result); break;
      case multiPoint:
         for(p : a.multiPoint)
         {
            DE9IM r;
            pointRelateBbox(p, b, e, r);
            result.combineBExtOR(result, r);
         }
         break;
      case multiLineString:
         for(l : a.multiLineString)
         {
            DE9IM r;
            lineStringRelateBbox(l, b, e, r);
            result.combineBExtOR(result, r);
         }
         break;
      case multiPolygon:
         for(p : a.multiPolygon)
         {
            DE9IM r;
            polygonRelateBbox(p, b, e, r);
            result.combineBExtOR(result, r);
         }
         break;
      case geometryCollection:
         for(c : a.geometryCollection)
         {
            DE9IM r;
            geometryRelateBbox(c, b, e, r);
            result.combineBExtOR(result, r);
         }
         break;
   }
}

static void geometryRelatePoint(const Geometry a, const GeoPoint b, double e, DE9IM result)
{
   result.wild();
   switch(a.type)
   {
      case bbox:              bboxRelatePoint(a.bbox, b, e, result); break;
      case point:             pointRelatePoint(a.point, b, e, result); break;
      case lineString:        lineStringRelatePoint(a.lineString, b, e, result); break;
      case polygon:           polygonRelatePoint(a.polygon, b, e, result); break;
      case multiPoint:
         for(p : a.multiPoint)
         {
            DE9IM r;
            pointRelatePoint(p, b, e, r);
            result.combineBExtOR(result, r);
         }
         break;
      case multiLineString:
         for(l : a.multiLineString)
         {
            DE9IM r;
            lineStringRelatePoint(l, b, e, r);
            result.combineBExtOR(result, r);
         }
         break;
      case multiPolygon:
         for(p : a.multiPolygon)
         {
            DE9IM r;
            polygonRelatePoint(p, b, e, r);
            result.combineBExtOR(result, r);
         }
         break;
      case geometryCollection:
         for(c : a.geometryCollection)
         {
            DE9IM r;
            geometryRelatePoint(c, b, e, r);
            result.combineBExtOR(result, r);
         }
         break;
   }
}

static void geometryRelateLineString(const Geometry a, const LineString b, double e, DE9IM result)
{
   result.wild();
   switch(a.type)
   {
      case bbox:              bboxRelateLineString(a.bbox, b, e, result); break;
      case point:             pointRelateLineString(a.point, b, e, result); break;
      case lineString:        lineStringRelateLineString(a.lineString, b, e, result); break;
      case polygon:           polygonRelateLineString(a.polygon, b, e, result); break;
      case multiPolygon:
         for(p : a.multiPolygon)
         {
            DE9IM r;
            polygonRelateLineString(p, b, e, r);
            result.combineBExtOR(result, r);
         }
         break;
      case multiPoint:
         for(p : a.multiPoint)
         {
            DE9IM r;
            pointRelateLineString(p, b, e, r);
            result.combineBExtOR(result, r);
         }
         break;
      case multiLineString:
         for(l : a.multiLineString)
         {
            DE9IM r;
            lineStringRelateLineString(l, b, e, r);
            result.combineBExtOR(result, r);
         }
         break;
      case geometryCollection:
         for(c : a.geometryCollection)
         {
            DE9IM r;
            geometryRelateLineString(c, b, e, r);
            result.combineBExtOR(result, r);
         }
         break;
   }
}

static void geometryRelateMultiPolygon(const Geometry a, Container<Polygon> b, double e, DE9IM result)
{
   result.wild();
   for(bPoly : b)
   {
      DE9IM r;
      r.wild();
      switch(a.type)
      {
         case bbox:              bboxRelatePolygon(a.bbox, bPoly, e, r); break;
         case point:             pointRelatePolygon(a.point, bPoly, e, r); break;
         case lineString:        lineStringRelatePolygon(a.lineString, bPoly, e, r); break;
         case polygon:           polygonRelatePolygon(a.polygon, bPoly, e, r, false); break;
         case multiPoint:
            for(p : a.multiPoint)
            {
               DE9IM r2;
               pointRelatePolygon(p, bPoly, e, r2);
               r.combineBExtOR(r, r2);
            }
            break;
         case multiLineString:
            for(l : a.multiLineString)
            {
               DE9IM r2;
               lineStringRelatePolygon(l, bPoly, e, r2);
               r.combineBExtOR(r, r2);
            }
            break;
         case multiPolygon:
            for(p : a.multiPolygon)
            {
               DE9IM r2;
               polygonRelatePolygon(p, bPoly, e, r2, false);
               r.combineBExtOR(r, r2);
            }
            break;
         case geometryCollection:
            for(c : a.geometryCollection)
            {
               DE9IM r2;
               geometryRelatePolygon(c, bPoly, e, r2);
               result.combineBExtOR(r, r2);
            }
         break;
      }
      result.combineAExtOR(result, r);
   }

   if(a.type == multiPolygon)
   {
      // We need a reverse check to fix exterior [2] and [5] for identical scenarios
      char irm6 = '*', irm7 = '*';

      for(aPoly : a.multiPolygon)
      {
         char rm6 = '*', rm7 = '*';
         for(p : b)
         {
            DE9IM r2;
            polygonRelatePolygon(p, aPoly, e, r2, false);
            rm6 = DE9IM_LO(rm6, r2.m[6]);
            rm7 = DE9IM_LO(rm7, r2.m[7]);
            if(rm6 == 'F' && rm7 == 'F') break;
         }
         irm6 = DE9IM_HI(irm6, rm6);
         irm7 = DE9IM_HI(irm7, rm7);
         if(irm6 == '2' && irm7 == '1') break;
      }
      result.m[2] = DE9IM_LO(result.m[2], irm6);
      result.m[5] = DE9IM_LO(result.m[5], irm7);
   }
}

static void geometryRelateMultiLineString(const Geometry a, Container<LineString> b, double e, DE9IM result)
{
   result.wild();
   for(bl : b)
   {
      DE9IM r;

      switch(a.type)
      {
         case bbox:              bboxRelateLineString(a.bbox, bl, e, r); break;
         case point:             pointRelateLineString(a.point, bl, e, r); break;
         case lineString:        lineStringRelateLineString(a.lineString, bl, e, r); break;
         case polygon:           polygonRelateLineString(a.polygon, bl, e, r); break;
         case multiPolygon:
            r.wild();
            for(p : a.multiPolygon)
            {
               DE9IM r2;
               polygonRelateLineString(p, bl, e, r2);
               r.combineBExtOR(r, r2);
            }
            break;
         case multiPoint:
            r.wild();
            for(p : a.multiPoint)
            {
               DE9IM r2;
               pointRelateLineString(p, bl, e, r2);
               r.combineBExtOR(r, r2);
            }
            break;
         case multiLineString:
            r.wild();
            for(l : a.multiLineString)
            {
               DE9IM r2;
               lineStringRelateLineString(l, bl, e, r2);
               r.combineBExtOR(r, r2);
            }
            break;
         case geometryCollection:
            r.wild();
            for(c : a.geometryCollection)
            {
               DE9IM r2;
               geometryRelateLineString(c, bl, e, r2);
               r.combineBExtOR(r, r2);
            }
            break;
      }
      result.combineAExtOR(result, r);
   }

   if(a.type == multiLineString)
   {
      // We need a reverse check to fix exterior [2] and [5] for identical scenarios
      char irm6 = '*', irm7 = '*';

      for(al : a.multiLineString)
      {
         char rm6 = '*', rm7 = '*';
         for(l : b)
         {
            DE9IM r2;
            lineStringRelateLineString67(l, al, e, r2);
            rm6 = DE9IM_LO(rm6, r2.m[6]);
            rm7 = DE9IM_LO(rm7, r2.m[7]);
            if(rm6 == 'F' && rm7 == 'F') break;
         }
         irm6 = DE9IM_HI(irm6, rm6);
         irm7 = DE9IM_HI(irm7, rm7);
         if(irm6 == '1' && irm7 == '0') break;
      }
      result.m[2] = DE9IM_LO(result.m[2], irm6);
      result.m[5] = DE9IM_LO(result.m[5], irm7);
   }
}

static void geometryRelateMultiPoint(const Geometry a, Container<GeoPoint> b, double e, DE9IM result)
{
   result.wild();
   for(bPoint : b)
   {
      DE9IM r;

      switch(a.type)
      {
         case bbox:              bboxRelatePoint(a.bbox, bPoint, e, r); break;
         case point:             pointRelatePoint(a.point, bPoint, e, r); break;
         case lineString:        lineStringRelatePoint(a.lineString, bPoint, e, r); break;
         case polygon:           polygonRelatePoint(a.polygon, bPoint, e, r); break;
         case multiPolygon:
            r.wild();
            for(p : a.multiPolygon)
            {
               DE9IM r2;
               polygonRelatePoint(p, bPoint, e, r2);
               r.combineBExtOR(r, r2);
            }
            break;
         case multiPoint:
            r.wild();
            for(p : a.multiPoint)
            {
               DE9IM r2;
               pointRelatePoint(p, bPoint, e, r2);
               r.combineBExtOR(r, r2);
            }
            break;
         case multiLineString:
            r.wild();
            for(l : a.multiLineString)
            {
               DE9IM r2;
               lineStringRelatePoint(l, bPoint, e, r2);
               r.combineBExtOR(r, r2);
            }
            break;
         case geometryCollection:
            r.wild();
            for(c : a.geometryCollection)
            {
               DE9IM r2;
               geometryRelatePoint(c, bPoint, e, r2);
               r.combineBExtOR(r, r2);
            }
            break;
      }
      result.combineAExtOR(result, r);
   }

   if(a.type == multiPoint)
   {
      // We need a reverse check to fix exterior [2] for identical scenarios
      char irm6 = '*';

      for(aPoint : a.multiPoint)
      {
         char rm6 = '*';
         for(p : b)
         {
            char r2m6 = pointIsSameEpsilon(p, aPoint, e) ? 'F' : '0';
            rm6 = DE9IM_LO(rm6, r2m6);
            if(rm6 == 'F') break;
         }
         irm6 = DE9IM_HI(irm6, rm6);
         if(irm6 == '0') break;
      }
      result.m[2] = DE9IM_LO(result.m[2], irm6);
   }
}

static void geometryRelateGeometryCollection(const Geometry a, Container<Geometry> b, double e, DE9IM result)
{
   result.wild();
   for(bGeom : b)
   {
      DE9IM r;
      geometryRelate(a, bGeom, r);
      result.combineAExtOR(result, r);
   }
   // NOTE: reverse checks inside?
}

// Organize an arbitrary list of contours as Polygons with one outer and inner contours
Array<Polygon> normalizeContours(Array<PolygonContour> contours)
{
   Array<Polygon> polygons = null;
   int count = 0; // Count of polygons (outer contours)
   if(contours && contours.count)
   {
      int i = 0;
      for(r : contours)
      {
         if(r)
         {
            if(!r.inner)
               count++;
            i++;
         }
      }
   }

   if(count)
   {
      int i, iInner;

      polygons = { size = count };

      count = 0;
      for(r : contours)
      {
         PolygonContour contour = r;
         if(contour)
         {
            contour.calculateExtent();
            if(!contour.inner)
               polygons[count++].setContours(Array<PolygonContour> { [ contour.copy(false) ] });   // NOTE: Consider not copying?
         }
      }
      for(iInner = 0; iInner < contours.count; iInner++)
      {
         PolygonContour innerContour = contours[iInner];
         if(innerContour && innerContour.inner)
         {
            bool skipExtentCheck = false;
            const GeoExtent * innerExtent = innerContour.getExtentPtr();

            for(i = 0; i < count; i++)
            {
               Polygon * d = &polygons[i];
               Array<PolygonContour> dContours = d->getContours();
               // if(d->rings[0].extent.intersects(innerContour.extent) && d->rings[0].overlaps(innerContour) && !innerContour.contains(d->rings[0]))
               // if(d->rings[0].extent.intersects(innerContour.extent) && d->rings[0].overlapsAndIsNotContained(innerContour))
               // TODO: Figure out why overlapsAndIsNotContained() is not as good -- e.g. Sakhalin dissapearing with relAngle = 3-...

               // If the destination polygon outer ring contains or touches this ring...
               const GeoExtent * dExtent = skipExtentCheck ? null : dContours[0].getExtentPtr();
               if(!dExtent ||
                  (dExtent->intersects(innerExtent) &&
                   contourContainsOrTouches2(dContours[0], innerContour, 1E-12)))
               {
                  int j;
                  bool otherRingContainsThis = false;
                  for(j = i+1; j < count; j++) // We might want to find the smallest ring that contains this instead?
                  {
                     Polygon * e = &polygons[j];
                     Array<PolygonContour> eContours = e->getContours();
                     const GeoExtent * eExtent = eContours[0].getExtentPtr();

                     // If this other polygon also contains this ring, and that other polygon does not contain our destination polygon
                     if(eExtent->intersects(innerExtent) &&
                        contourContains(eContours[0], innerContour) &&
                        !contourContains(eContours[0], dContours[0]))
                     {
                        otherRingContainsThis = true;
                        // Resume search at the outer ring identified as containing this
                        skipExtentCheck = true;
                        i = j-1;
                        break;
                     }
                  }
                  if(!otherRingContainsThis)
                  {
                     // This is where this goes!
                     int ix = dContours.size;
                     uint mas = dContours.minAllocSize;
                     if(mas < ix + 1)
                        dContours.minAllocSize = mas ? mas * 3 / 2 : 2;
                     dContours.size = ix+1;
                     dContours[ix] = innerContour.copy(false);
                     break; // We've placed this inner ring and can move on to the next...
                  }
               }
            }
         }
      }
      for(i = 0; i < count; i++)
      {
         Array<PolygonContour> contours = polygons[i].getContours();
         contours.minAllocSize = 0;
      }
   }
   return polygons;
}
