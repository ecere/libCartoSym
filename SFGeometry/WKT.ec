public import IMPORT_STATIC "ecrt"
public import IMPORT_STATIC "GeoExtents"

private:

import "Geometry"

String geometryToWKT(const Geometry geom)
{
   // FIXME: Only handling MultiPolygon right now, other geometries handled in libCQL2 with CQL2Normalization
   String result;
   ZString z { allocType = heap };
   switch(geom.type)
   {
      case GeometryType::multiPolygon:
      {
         Array<Polygon> mp = (Array<Polygon>)geom.multiPolygon;
         if(mp)
         {
            int i;
            z.concat("MULTIPOLYGON(");
            for(i = 0; i < mp.count; i++)
            {
               Polygon * p = &mp[i];
               int j;

               z.concat("(");
               for(j = 0; j < (p->contours ? p->contours.count : 0); j++)
               {
                  PolygonContour c = p->contours[j];
                  if(c && c._points.count)
                  {
                     int k;
                     z.concat("(");
                     for(k = 0; k < c._points.count; k++)
                        z.concatx(k ? ", " : "", c._points[k].lon, " ", c._points[k].lat);
                     // FIXME: Repeat first point if not same
                     z.concat(")");
                  }
               }
               z.concat(")");
            }
            z.concat(")");
         }
         break;
      }
   }
   result = z._string;
   z._string = null;
   delete z;
   return result;
}
