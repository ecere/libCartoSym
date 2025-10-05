// GeoJSON Support

public import IMPORT_STATIC "ecrt"
public import IMPORT_STATIC "GeoExtents"

private:

import "FeatureCollection"
import "TimeIntervals"
import "MinimalProjection"

// Only used for printing request parameters in links
// TODO: Pass an array or map of links instead
import "iso8601"

#undef GetObject

static void printIndent(int indent, File out)
{
   int i;
   for(i = 0; i < indent; i++)
      out.Print("   ");
}

// Currently here for lack of another better low dependency place...
public int printDoubleDec(double value, int numDec, char * s, int size)
{
   int l = printDouble(s, size, numDec, value);
   if(strchr(s, '.'))
   {
      while(l > 1 && (s[l-1] == '0' || s[l-1] == '.') && (s[l-2] == '.' || isdigit(s[l-2])))
      {
         l--;
         if(s[l] == '.') break;
      }
      s[l] = 0;
   }
   return l;
}

public int printDoubleDecFile(File f, double value, int numDec)
{
   char buf[1024];
   int len = printDoubleDec(value, numDec, buf, sizeof(buf));
   f.Write(buf, 1, len);
   return len;
}

// REVIEW: To avoid parsing warnings...
public class OGCAPILink
{
public:
   String rel;
   String type;
   String title;
   String hreflang;
   String href;

   ~OGCAPILink()
   {
      delete rel;
      delete type;
      delete title;
      delete hreflang;
      delete href;
   }
}

public class GeoJSONFeatureCollection
{
private:
   String coordRefSys;
   int geometryDimension;
   geometryDimension = -1;
   ~GeoJSONFeatureCollection()
   {
      delete crs;
      delete type;
      delete timeStamp;
      delete coordRefSys;
      delete description;
      delete code;
      if(features)
      {
         features.Free();
         delete features;
      }
      if(links) links.Free(), delete links;
      delete name;
      delete bbox;
      delete status;
      delete featureType;
      delete geometry_name;
      delete totalFeatures;
   }
public:
   String type;
   Array<GeoJSONFeature> features;
   GeoJSONCRS crs;
   int numberReturned;
   int numberMatched;
   Array<OGCAPILink> links;
   String timeStamp;
   String name;
   String status;
   Array<double> bbox;
   String code;
   String description;
   String featureType;

   // Avoid warnings on these:
   String geometry_name;
   String totalFeatures;

   property String coordrefsys
   {
      set { delete coordRefSys; if(value) coordRefSys = CopyString(value); }
      get { return this ? coordRefSys : null; }
      isset { return false; }
   };

   property String coordRefSys
   {
      set { delete coordRefSys; if(value) coordRefSys = CopyString(value); }
      get { return this ? coordRefSys : null; }
      isset { return coordRefSys != null; } // false?
   };

   property int geometryDimension
   {
      set { geometryDimension = value; }
      get { return geometryDimension; }
      isset { return geometryDimension != -1; }
   };
}


public class GeoJSONFGTime
{
public:
   String instant;
   Array<String> interval;

   ~GeoJSONFGTime()
   {
      delete instant;
      if(interval) interval.Free(), delete interval;
   }
}


public class GeoJSONCRS
{
public:
   String type;
   Map<String, FieldValue> properties;

   ~GeoJSONCRS()
   {
      delete type;
      if(properties) properties.Free(), delete properties;
   }
}

public class GeoJSONFeature
{
private:
   String coordRefSys;
   GeoJSONGeometry place;
   GeoJSONFGTime time;
   String featureType;
   ~GeoJSONFeature()
   {
      delete type;
      delete geometry;
      if(properties) properties.Free(), delete properties;

      delete featureType;
      delete coordRefSys;
      delete place;
      delete time;
      if(links) links.Free(), delete links;

      delete stac_version;
      if(assets) assets.Free(), delete assets;
      delete bbox;
      delete collection;
      if(stac_extensions) stac_extensions.Free(), delete stac_extensions;
      delete geometry_name;
   }
public:
   String type;
   GeoJSONGeometry geometry;
   FieldValue id;
   Map<String, FieldValue> properties;
   Array<OGCAPILink> links;
   String stac_version;
   Map<String, FieldValue> assets;
   Array<double> bbox;
   String collection;
   Array<String> stac_extensions;
   // Avoid warnings on these:
   String geometry_name;

   property String coordrefsys
   {
      set { delete coordRefSys; if(value) coordRefSys = CopyString(value); }
      get { return this ? coordRefSys : null; }
      isset { return false; }
   };
   property String coordRefSys
   {
      set { delete coordRefSys; if(value) coordRefSys = CopyString(value); }
      get { return this ? coordRefSys : null; }
      isset { return coordRefSys != null; } // false?
   };
   property GeoJSONGeometry where
   {
      set { place = value; }
      get { return place; }
      isset { return false; }
   };
   property GeoJSONFGTime when
   {
      set { time = value; }
      get { return time; }
      isset { return false; }
   };
   property GeoJSONGeometry place
   {
      set { place = value; }
      get { return place; }
      isset { return place != null; }
   };
   property GeoJSONFGTime time
   {
      set { time = value; }
      get { return time; }
      isset { return time != null; }
   };
   property String featureType
   {
      set { delete featureType; if(value) featureType = CopyString(value); }
      get { return this ? featureType : null; }
      isset { return featureType != null; }
   };
}

public class GeoJSONGeometry
{
   String type;
   bool isMulti;
   VectorType vType;
public:
   property String type
   {
      set
      {
         type = CopyString(value);
         if(!strcmpi(value, "MultiPolygon"))
         {
            vType = polygons, isMulti = true;
            if(!coordinates)
               coordinates = Array<Array<Array<Array<double>>>> { };
         }
         else if(!strcmpi(value, "Polygon"))
         {
            vType = polygons;
            if(!coordinates)
               coordinates = Array<Array<Array<double>>> { };
         }
         else if(!strcmpi(value, "MultiLineString"))
         {
            vType = lines, isMulti = true;
            if(!coordinates)
               coordinates = Array<Array<Array<double>>> { };
         }
         else if(!strcmpi(value, "LineString"))
         {
            vType = lines;
            if(!coordinates)
               coordinates = Array<Array<double>> { };
         }
         else if(!strcmpi(value, "MultiPoint"))
         {
            vType = points, isMulti = true;
            if(!coordinates)
               coordinates = Array<Array<double>> { };
         }
         else if(!strcmpi(value, "Point"))
         {
            vType = points;
            if(!coordinates)
               coordinates = Array<double> { };
         }
         // TODO: Polyhedron and MultiPolyhedron
         // A polyhedron is an non-empty array of multi-polygon arrays.
         // A multi-polyhedron is an array of polyhedron arrays. The order of the polyhedra is not significant.
         // https://github.com/opengeospatial/ogc-feat-geo-json/blob/main/proposals/spatial-geometry.adoc
      }
      get
      {
         switch(vType)
         {
            case points:   return (char*)(isMulti ? "MultiPoint"      : "Point");      break;
            case lines:    return (char*)(isMulti ? "MultiLineString" : "LineString"); break;
            case polygons: return (char*)(isMulti ? "MultiPolygon"    : "Polygon");    break;
         }
         return (char*)"";
      }
   }
   GeoJSONCRS crs;
   Array coordinates;

   ~GeoJSONGeometry()
   {
      delete crs;
      delete type;
      if(coordinates)
      {
         // TO REVIEW: Deep freeing 2 or 3 levels...
         coordinates.Free();
         delete coordinates;
      }
   }
}

// FIXME: We need to pass the CRS to deprojectPoint() point to handle axis order flipping for EPSG:4326
static void inline deprojectPoint(const double * points, GeoPoint pos, MinimalProjection pj)
{
   Pointd v { x = points[0] / wgs84Major, y = points[1] / wgs84Major };
   GeoPoint geo;
   pj.cartesianToGeo(v, geo);
   pos = { geo.lat, geo.lon };
}

/*static */int64 textToID(const String s)
{
   String endPtr;
   int64 id = strtoll(s, &endPtr, 16);
   if(s && (!id || *endPtr))
   {
      int64 numPart = id;

      if(!numPart)
      {
         int i;
         char ch;

         for(i = 0; (ch = s[i]); i++)
         {
            if(strchr("0123456789", ch))
            {
               numPart = strtoll(s + i, null, 16);
               break;
            }
         }
      }

      id = ((int64)hash32Data((char *)s, strlen(s)) << 30) ^ numPart;
   }
   return id;
}

public FeatureCollection loadGeoJSON(File f, HashMap<int64, Map<String, FieldValue>> attribs, bool skipAttribCache)
{
   return loadGeoJSONEx(f, attribs, skipAttribCache, 0, false, none, false, null);
}

public FeatureCollection loadGeoJSONEx(File f, HashMap<int64, Map<String, FieldValue>> attribs, bool skipAttribCache,
   CRS pCRS, bool fgJSON, VectorType restrictedType, bool individualFeature, Array<OGCAPILink> * retLinks)
{
   FeatureCollection result = null;
   JSONParser parser { f = f, debug = false };
   GeoJSONFeatureCollection geoJSON = null;
   GeoJSONFeature geoJSONFeature = null;
   JSONResult r = parser.GetObject(
      individualFeature ? class(GeoJSONFeature) : class(GeoJSONFeatureCollection),
      individualFeature ? &geoJSONFeature : &geoJSON);
   CRS crs = pCRS;
   MinimalProjection pj = crs ? MinimalProjection::fromCRS(crs) : null;
   bool demoMode = false; // force use of 'place'

   // Handle mismatched Feature / Feature Collection (JSON parsing warnings will show up)
   if(r == success)
   {
      if(individualFeature && geoJSONFeature && geoJSONFeature.type && !strcmpi(geoJSONFeature.type, "FeatureCollection"))
      {
         // Expecting a single feature, but parsing a collection instead
         delete geoJSONFeature;
         f.Seek(0, start);
         r = parser.GetObject(class(GeoJSONFeatureCollection), &geoJSON);
      }
      else
      {
         if(!individualFeature && geoJSON && geoJSON.type && !strcmpi(geoJSON.type, "Feature"))
         {
            // Expecting a feature collection, but parsing a single feature instead
            delete geoJSON;
            f.Seek(0, start);
            r = parser.GetObject(class(GeoJSONFeature), &geoJSONFeature);
         }
         if(geoJSONFeature)
         {
            // Automatically set up a single feature collection
            geoJSON = { type = CopyString("FeatureCollection"), features = { [ geoJSONFeature ] } };
            geoJSONFeature = null;
         }
      }
   }

   if(r == success && geoJSON)
   {
      // FIXME: We need to pass the CRS to deprojectPoint() point to handle axis order flipping for EPSG:4326
      if(!crs && geoJSON.coordrefsys) // jsonFG
      {
         crs = crsFromID(geoJSON.coordrefsys);
         pj = MinimalProjection::fromCRS(crs);
      }
      else if(!crs && (geoJSON.crs && geoJSON.crs.properties))
      {
         FieldValue fv = geoJSON.crs.properties["name"];
         if(fv.s)
         {
            crs = crsFromID(fv.s);
            pj = MinimalProjection::fromCRS(crs);
         }
      }
      if(geoJSON.type && geoJSON.features && geoJSON.features.count && !strcmpi(geoJSON.type, "FeatureCollection"))
      {
         Array<GeoJSONFeature> features = geoJSON.features;
         bool ignorePJ = false;
         if(features[0].type && !strcmpi(features[0].type, "Feature") && features[0]) // && features[0].geometry)
         {
            // With restricted type, *only* that geometry type will be returned
            VectorType vType = restrictedType ? restrictedType : ((features[0].place && pj) ? features[0].place.vType : features[0].geometry ? features[0].geometry.vType : none);
            int count = features.count, i, j, k; //, l;
            uint64 id = 1;
            bool is3D = false;//, hasMeasure = false;

            // vType = polygons;

            if(restrictedType == polygons || (vType == polygons && restrictedType == none))
            {
               FeatureCollection<PolygonFeature> polygonFeatures { size = count, type = { type = vector, vectorType = vType } };
               for(i = 0; i < count; i++)
               {
                  GeoJSONFeature jsonFeature = features[i];
                  PolygonFeature * feature = &polygonFeatures[i];
                  if(jsonFeature)
                  {
                     GeoJSONGeometry geometry = (jsonFeature.geometry && !(demoMode && jsonFeature.place)) ? jsonFeature.geometry : jsonFeature.place ? jsonFeature.place : null;
                     ignorePJ = (jsonFeature.place && geometry == jsonFeature.geometry);
                     // NOTE: since PJ is meant for 'place' when included, ignore it if opting for geometry instead.. but we still want it when only geometry exists
                     if(geometry && geometry.vType == polygons)
                     {
                        Array<Polygon> polys { };
                        if(geometry.isMulti)
                        {
                           Array<Array<Array<Array<double>>>> polygons = (Array<Array<Array<Array<double>>>>)geometry.coordinates;
                           // function out begin
                           polys.size = polygons.count;
                           for(j = 0; j < polygons.count; j++)
                           {
                              Array<Array<Array<double>>> polygon = polygons[j];
                              Polygon * poly = &polys[j];
                              generatePolygonFromCoordinates(poly, polygon, ignorePJ, pj, crs, &is3D);
                              delete polygon;
                           }
                           delete polygons;
                        }
                        else
                        {
                           Polygon * poly;
                           Array<Array<Array<double>>> polygon = (Array<Array<Array<double>>>)geometry.coordinates;
                           polys.size = 1;
                           poly = &polys[0];
                           generatePolygonFromCoordinates(poly, polygon, ignorePJ, pj, crs, &is3D);
                           delete polygon;
                        }
                        geometry.coordinates = null;
                        if(jsonFeature.properties)
                        {
                           MapIterator<String, FieldValue> it { map = jsonFeature.properties };
                           FieldValue * dv;
                           if(it.Index("feature::id", false) || it.Index("id", false) || it.Index("Feature ID", false))
                           {
                              dv = (FieldValue *)it.GetData();
                              if(dv->type.type == integer)
                                 id = dv->i;
                              else if(dv->type.type == text)
                              {
                                 id = textToID(dv->s);
                                 delete dv->s;
                              }
                           }
                           if(it.Index("line::hidden", false))
                           {
                              dv = (FieldValue *)it.GetData();
                              if(dv->type.type == array && dv->a)
                              {
                                 Array<FieldValue> a = dv->a;
                                 int i;

                                 for(i = 0; i < a.count; i++)
                                 {
                                    FieldValue * h = &a[i];
                                    if(h->type.type == map && h->m)
                                    {
                                       Map<String, FieldValue> m = h->m;
                                       int polygonIx = -1;
                                       int contourIx = -1;
                                       Array<FieldValue> s = null;

                                       for(v : m)
                                       {
                                          const String key = &v;
                                          FieldValue vv = v;
                                          if(!strcmpi(key, "polygon"))
                                          {
                                             if(vv.type.type == integer)
                                                polygonIx = (int)vv.i;
                                          }
                                          else if(!strcmpi(key, "contour"))
                                          {
                                             if(vv.type.type == integer)
                                                contourIx = (int)vv.i;
                                          }
                                          else if(!strcmpi(key, "segments"))
                                          {
                                             if(vv.type.type == array && vv.a)
                                                s = vv.a;
                                          }
                                       }

                                       if(s && polygonIx >= 0 && polygonIx < polys.count)
                                       {
                                          Polygon * polygon = &polys[polygonIx];
                                          Array<PolygonContour> contours = polygon->getContours();
                                          if(contourIx >= 0 && contourIx < contours.count)
                                          {
                                             PolygonContour contour = contours[contourIx];
                                             int j;
                                             Array<StartEndPair> segments { size = s.count };
                                             Array<GeoPoint> points = (Array<GeoPoint>)contour.points;

                                             contour.hidden = segments;
                                             for(j = 0; j < s.count; j++)
                                             {
                                                const FieldValue * seg = &s[j];
                                                StartEndPair * se = &segments[j];
                                                if(seg->type.type == map)
                                                {
                                                   for(v : seg->m)
                                                   {
                                                      const String key = &v;
                                                      FieldValue vv = v;
                                                      if(!strcmpi(key, "from") && vv.type.type == integer)
                                                         se->start = (int)vv.i;
                                                      else if(!strcmpi(key, "to") && vv.type.type == integer)
                                                      {
                                                         se->end = (int)vv.i;
                                                         if(se->end == points.count)
                                                            se->end = 0;
                                                      }
                                                   }
                                                }
                                             }
                                          }
                                       }
                                    }
                                 }
                              }
                           }
                        }
                        for(j = 0; j < polys.count; j++)
                        {
                           Polygon * poly = &polys[j];
                           Array<PolygonContour> contours = poly->getContours();

                           for(k = 0; k < contours.count; k++)
                           {
                              PolygonContour contour = contours[k];
                              if(contour.inner != contour.clockwise && !contour.depths)
                                 contour.flip(true);
                           }
                        }
                        feature->geometry = polys;
                     }
                     if(jsonFeature.id.type.type == integer)
                        id = jsonFeature.id.i;
                     else if(jsonFeature.id.type.type == text)
                     {
                        id = textToID(jsonFeature.id.s);
                        // delete jsonFeature.id.s;
                     }

                     feature->id = id++;
                  }
               }
               if(polygonFeatures && is3D)
                  polygonFeatures.type |= { is3D = true };
               result = polygonFeatures;
            }
            else if(restrictedType == lines || (vType == lines && restrictedType == none))
            {
               FeatureCollection<LineFeature> lineFeatures { size = count, type = { type = vector, vectorType = vType } };
               for(i = 0; i < count; i++)
               {
                  GeoJSONFeature jsonFeature = features[i];
                  LineFeature * feature = &lineFeatures[i];
                  if(jsonFeature)
                  {
                     GeoJSONGeometry geometry = (jsonFeature.geometry && !(demoMode && jsonFeature.place)) ? jsonFeature.geometry : jsonFeature.place ? jsonFeature.place : null;
                     ignorePJ = (jsonFeature.place && geometry == jsonFeature.geometry);
                     if(geometry && geometry.vType == lines)
                     {
                        Array<LineString> lines { };
                        if(geometry.isMulti)
                        {
                           Array<Array<Array<double>>> lineStrings = (Array<Array<Array<double>>>)geometry.coordinates;
                           lines.size = lineStrings.count;
                           for(j = 0; j < lineStrings.count; j++)
                           {
                              Array<Array<double>> lineString = lineStrings[j];
                              LineString * line = &lines[j];
                              generateLineStringFromCoordinates(line, lineString, ignorePJ, pj, crs, &is3D);
                              delete lineString;
                           }
                           delete lineStrings;
                        }
                        else
                        {
                           LineString * line;
                           Array<Array<double>> lineString = (Array<Array<double>>)geometry.coordinates;
                           lines.size = 1;
                           line = &lines[0];
                           generateLineStringFromCoordinates(line, lineString, ignorePJ, pj, crs, &is3D);
                           delete lineString;
                        }
                        feature->geometry = lines;
                        geometry.coordinates = null;
                     }
                     if(jsonFeature.properties)
                     {
                        MapIterator<String, FieldValue> it { map = jsonFeature.properties };
                        FieldValue * dv;
                        if(it.Index("feature::id", false) || it.Index("id", false) || it.Index("Feature ID", false))
                        {
                           dv = (FieldValue *)it.GetData();
                           if(dv->type.type == integer)
                              id = dv->i;
                           else if(dv->type.type == text)
                           {
                              id = textToID(dv->s);
                              delete dv->s;
                           }
                        }
                     }
                     setJSONFeatureID(&id, jsonFeature);
                     feature->id = id++;
                  }
               }
               result = lineFeatures;
            }
            else if(restrictedType == points || (vType == points && restrictedType == none))
            {
               FeatureCollection<Models3DFeature> mfc = null;
               FeatureCollection<PointFeature> pointFeatures = null;
               FeatureCollection<Point3DFeature> p3dfc = null;
               GeoJSONFeature * firstFeature = count ? &features[0] : null;
               bool isModel = false;

               if(firstFeature && firstFeature->properties)
               {
                  MapIterator<String, FieldValue> it { map = firstFeature->properties };
                  if(it.Index("model::id", false))
                     isModel = true;
               }

               // Check if the geometry is 3D
               if(!isModel)
               {
                  for(i = 0; i < count; i++)
                  {
                     GeoJSONFeature jsonFeature = features[i];
                     if(jsonFeature)
                     {
                        GeoJSONGeometry geometry = (jsonFeature.geometry && !(demoMode && jsonFeature.place)) ? jsonFeature.geometry : jsonFeature.place ? jsonFeature.place : null;
                        if(geometry && geometry.vType == points)
                        {
                           if(geometry.isMulti)
                           {
                              Array<Array<double>> multiPoints = (Array<Array<double>>)geometry.coordinates;
                              if(multiPoints)
                              {
                                 for(j = 0; j < multiPoints.count; j++)
                                 {
                                    Array<double> point = multiPoints[j];
                                    if(point && point.count == 3)
                                    {
                                       is3D = true;
                                       break;
                                    }
                                 }
                              }
                           }
                           else
                           {
                              Array<double> point = (Array<double>)geometry.coordinates;
                              if(point && point.count == 3)
                                 is3D = true;
                           }
                        }
                     }
                     if(is3D) break;
                  }
               }

               if(isModel)
                  mfc = { size = count, type = { type = vector, vectorType = vType, isModel = true, is3D = true } };
               else if(is3D)
                  p3dfc = { size = count, type = { type = vector, vectorType = vType, is3D = true } };
               else
                  pointFeatures = { size = count, type = { type = vector, vectorType = vType } };

               for(i = 0; i < count; i++)
               {
                  GeoJSONFeature jsonFeature = features[i];
                  Point3DFeature * p3dFeature = p3dfc ? &p3dfc[i] : null;
                  Models3DFeature * mFeature = mfc ? &mfc[i] : null;
                  PointFeature * feature = pointFeatures ? &pointFeatures[i] : p3dFeature ? (PointFeature *)p3dFeature :
                     mFeature ? (PointFeature *)mFeature : null;
                  if(jsonFeature)
                  {
                     GeoJSONGeometry geometry = (jsonFeature.geometry && !(demoMode && jsonFeature.place)) ? jsonFeature.geometry : jsonFeature.place ? jsonFeature.place : null;
                     MapIterator<String, FieldValue> it { map = jsonFeature.properties };
                     ignorePJ = (jsonFeature.place && geometry == jsonFeature.geometry);
                     if(geometry && geometry.vType == points)
                     {
                        Array<GeoPoint> points { };
                        // bool foundID = false;
                        ModelID * modelIDs = null;
                        Meters * depths = null;
                        if(geometry.isMulti)
                        {
                           Array<Array<double>> multiPoints = (Array<Array<double>>)geometry.coordinates;
                           if(multiPoints)
                           {
                              if(mFeature)
                              {
                                 mFeature->modelIDs = modelIDs = new0 ModelID[multiPoints.count];
                                 mFeature->depths = depths = new0 Meters[multiPoints.count];
                              }
                              else if(p3dFeature)
                                 p3dFeature->depths = depths = new0 Meters[1];
                              points.size = multiPoints.count;
                              for(j = 0; j < multiPoints.count; j++)
                              {
                                 Array<double> point = multiPoints[j];
                                 if(point && point.count >= 2)
                                 {
                                    generatePointFromCoordinates(points[j], point, j, i, depths, ignorePJ, pj, crs, &is3D);
                                 }
                                 delete point;
                              }
                              delete multiPoints;
                           }
                        }
                        else
                        {
                           Array<double> point = (Array<double>)geometry.coordinates;
                           if(point && point.count >= 2)
                           {
                              points.size = 1;
                              if(mFeature)
                              {
                                 mFeature->modelIDs = modelIDs = new0 ModelID[1];
                                 mFeature->depths = depths = new0 Meters[1];
                              }
                              else if(p3dFeature)
                                 p3dFeature->depths = depths = new0 Meters[1];
                              generatePointFromCoordinates(points[0], point, 0, 0, depths, ignorePJ, pj, crs, &is3D);
                           }
                           delete point;
                        }

                        geometry.coordinates = null;
                        if(modelIDs && it.Index("model::id", false))
                        {
                           FieldValue * dv = (FieldValue *)it.GetData();
                           if(dv->type.type == text)
                           {
                              String s = dv->s;
                              while(isalpha(s[0])) s++;
                              // TOCHECK: single vs. multi points and 3D models?
                              modelIDs[0] = (uint)strtoul(s, null, 10);
                              // foundID = true;   // TOCHECK: ?
                           }
                           else if(dv->type.type == integer)
                           {
                              modelIDs[0] = (ModelID)dv->i;
                           }
                        }
                        if(it.Index("model::orientation", false))
                        {
                           FieldValue * dv = (FieldValue *)it.GetData();
                           if(dv->type.type == blob) // FIXME: Other branch changes to array
                           {
                              Array<double> o = dv->b;
                              if(o && o._class == class(Array<double>))
                              {
                                 Degrees * orientations = new0 Degrees[3 * points.count];   // REVIEW: Per feature or per point?
                                 mFeature->orientations = (Degrees *)orientations;

                                 if(o.count > 0) orientations[0] = o[0];
                                 if(o.count > 1) orientations[1] = o[1];
                                 if(o.count > 2) orientations[2] = o[2];
                              }
                           }
                        }
                        feature->geometry = points;
                     }
                     if(jsonFeature.properties)
                     {
                        MapIterator<String, FieldValue> it { map = jsonFeature.properties };
                        if(it.Index("feature::id", false) || it.Index("id", false) || it.Index("Feature ID", false))
                        {
                           FieldValue * dv = (FieldValue *)it.GetData();
                           if(dv->type.type == integer)
                              id = dv->i;
                           else if(dv->type.type == text)
                           {
                              id = textToID(dv->s);
                              delete dv->s;
                           }
                        }
                     }
                     setJSONFeatureID(&id, jsonFeature);
                     feature->id = id++;
                  }
               }
               result = pointFeatures ? pointFeatures : p3dfc ? p3dfc : mfc ? mfc : null;
            }
            else if(restrictedType == none && vType == none)
            {
               FeatureCollection<VectorFeature> genericFeatures { size = count, type = { vector } };

               for(i = 0; i < count; i++)
               {
                  GeoJSONFeature jsonFeature = features[i];
                  VectorFeature * feature = &genericFeatures[i];
                  if(jsonFeature)
                  {
                     if(jsonFeature.properties)
                     {
                        MapIterator<String, FieldValue> it { map = jsonFeature.properties };
                        FieldValue * dv;
                        if(it.Index("feature::id", false) || it.Index("id", false) || it.Index("Feature ID", false))
                        {
                           dv = (FieldValue *)it.GetData();
                           if(dv->type.type == integer)
                              id = dv->i;
                           else if(dv->type.type == text)
                           {
                              id = textToID(dv->s);
                              delete dv->s;
                           }
                        }
                     }
                     setJSONFeatureID(&id, jsonFeature);
                     feature->id = id++;
                  }
               }
               result = genericFeatures;
            }
         }
      }

      if(geoJSON && geoJSON.features && result && result.count && !skipAttribCache && attribs)
      {
         int i;
         //GeoDataCache cache = (GeoDataCache)globalGeoDataCaches[source];

         //if(cache)
         {
            //MinimalAttributeStore attributes = source.attributes;
            uint fSize = result._class.templateArgs[0].dataTypeClass.structSize;

            for(i = 0; i < geoJSON.features.count; i++)
            {
               GeoJSONFeature feature = geoJSON.features[i];
               if(feature && (feature.properties || feature.id.type.type == text))
               {
                  VectorFeature * f = (VectorFeature *)((byte *)result.array + i * fSize); // TODO: Make this easier
                  int64 featureID = f->id;
                  Map<String, FieldValue> keyMap { };
                  // NOTE: for mixed type, with current handling features count will exceed result array
                  // must use restrictedType param and pass attribs for each type in the feature collection
                  if(featureID != 0)
                  {
                     MapIterator<String, FieldValue> it { map = feature.properties };
                     attribs[featureID] = keyMap;

                     while(it.Next())
                     {
                        const String key = it.key;
                        //uint fieldID = cache.data.attributes.getFieldIndex(key);
                        //FieldType type = feature.id.type.type;//attributes.getFieldType(fieldID);
                        FieldValue * value = (FieldValue *)it.GetData();
                        //FieldType vt = value ? value->type.type : nil;

                        if(value && strcmp(key, "line::hidden") && strcmp(key, "feature::id"))
                        {
                           // TODO: call this cacheAttribute method from the 2 places from GeoPackageStore and OGCAPIStore place loadGeoJSON is called
                           //cache.cacheAttribute(featureID, fieldID, value);
                           FieldValue v;
                           v.OnCopy(value);
                           keyMap[key] = v;
                        }
                     }

                     // Preserve original text ID as a special property
                     if(feature.id.type.type == text || feature.id.type.type == integer)
                     {
                        FieldValue v;
                        v.OnCopy(feature.id);
                        keyMap["feature::sourceID"] = v;
                     }

                     // add COGSTAC assets to properties keyMap
                     // NEW: add to its own map with "items_assets" key, then add that map to keyMap
                     if(feature.assets)
                     {
                        keyMap["items_assets"] = { type = { map, true }, m = feature.assets };
                        feature.assets = null; // steal map
                     }
                  }
                  if(feature.time && (feature.time.interval || feature.time.instant)) // NOTE: currently treating 'when' as an attribute
                  {
                     FieldValue v1 { type = { integer, isDateTime = true } }; // for possible array
                     FieldValue v2 { type = { integer, isDateTime = true } };
                     DateTime startTime {};
                     DateTime endTime {};
                     if(feature.time.instant && feature.time.instant[0])
                     {
                        startTime.OnGetDataFromString(feature.time.instant);
                        *&v1.i = (int64)(SecSince1970)startTime;
                     }
                     else if(feature.time.interval && feature.time.interval.count==2)
                     {
                        if(feature.time.interval[0])
                           startTime.OnGetDataFromString(feature.time.interval[0]);
                        if(feature.time.interval[1])
                           endTime.OnGetDataFromString(feature.time.interval[1]);
                        *&v1.i = (int64)(SecSince1970)startTime;
                        *&v2.i = (int64)(SecSince1970)endTime;
                     }
                     keyMap["timeStart"] = v1;
                     keyMap["timeEnd"] = endTime.year ? v2 : v1;
                  }
               }
            }
         }
      }

      if(retLinks && geoJSON.links)
      {
         *retLinks = geoJSON.links;
         geoJSON.links = null;
      }
   }
   delete geoJSON;
   delete geoJSONFeature;
   delete parser;

   return result;
}
static void setJSONFeatureID(uint64 * id, GeoJSONFeature jsonFeature)
{
   if(jsonFeature.id.type.type == integer)
      *id = jsonFeature.id.i;
   else if(jsonFeature.id.type.type == text)
      *id = textToID(jsonFeature.id.s);
}

void writeGeoJSONProperties(File f, Map<String, FieldValue> keyMap, MinimalAttributeStore store, Array<int> fieldsIX,
   int64 id, int indent, bool startWithComma)
{
   //check for MemAttributesStore?
   bool allValues = fieldsIX == null;
   Array<RecordField> storeFields = store ? store.fields : null;
   bool prev = startWithComma;
   if(keyMap)
   {
      MapIterator<String, FieldValue> it { map = keyMap };
      while(it.Next())
      {
         const String key = it.key;
         FieldValue * value = (FieldValue *)it.GetData();
         FieldType vt = value ? value->type.type : nil;
         if(value && (vt != nil))
         {
            if(prev) f.PrintLn(",");

            printIndent(indent, f);
            f.Print("         \"", key, "\" : ");
            writeGeoJSONPropertyValues(f, value, indent);
            prev = true;
         }
      }
   }
   else if(storeFields)
   {
      // TODO: Re-use pre-allocated buffer for all features
      FieldValue * values = allValues ? store.getAllValues(id, null, 0) : null;
      int i, count = (allValues ? storeFields.count : fieldsIX.count);
      for(i = 0; i < count; i++)
      {
         int fieldIX = allValues ? i : fieldsIX[i];
         RecordField * field = &storeFields[fieldIX];
         FieldValue value;
         if(values)
            value = values[i];
         else
            store.getValue(id, fieldIX, value);
         if(value.type.type != nil || !allValues)
         {
            if(prev) f.PrintLn(",");
            f.Print("         \"", field->name, "\" : ");
            writeGeoJSONPropertyValues(f, value, indent);
            prev = true;
            value.OnFree();
         }
      }
      delete values;
   }
}

void writeGeoJSONPropertyValues(File f, FieldValue * value, int indent)
{
   FieldType vt = value->type.type;
   switch(vt)
   {
      case text:
      {
         String s = value->s;
         if(s && !UTF8Validate(s))
         {
            int len = strlen(s);
            String tmp = new char[len*2+1];
            ISO8859_1toUTF8(tmp, s, len*2+1);
            s = tmp;
         }
         WriteONString(f, value->s, false, 0);
         if(s != value->s) delete s;
         break;
      }
      case map:
      {
         f.PrintLn("{");
         indent++;
         writeGeoJSONProperties(f, value->m, null, null, 0, indent, false);
         indent--;
         f.PrintLn("");
         printIndent(indent, f);
         f.Print("         }");
         break;
      }
      case array:
      {
         int n;
         f.PrintLn("[ ");
         indent++;
         for ( n=0; n< value->a.count; n++ )
         {
            if(n>0)
               f.PrintLn(", ");
            printIndent(indent, f);
            if(value->a[n].type.type != nil)
            {
               if(value->a[n].type.type == map)
                  f.Print("         ");
               writeGeoJSONPropertyValues(f, value->a[n], indent);
            }
         }
         indent--;
         printIndent(indent, f);
         f.PrintLn("         ]");
         break;
      }
      case integer: f.Print(value->i); break;
      case real:    f.Print(value->r); break;
      case nil: default: f.Print("null"); break;
   }
}

public bool writeGeoJSON(FeatureCollection fc, File f, MinimalAttributeStore store, Array<String> properties, HashMap<int64, Map<String, FieldValue>> keyMap)
{
   return writeFilteredGeoJSON(fc, null, f, store, properties, false, null, false, 0, 0, 0, -1, null, null, null, false, null, 0, 0, 0, keyMap, 0, 0, 0, 0);
}

// REVIEW: Should this take a HashTable instead?
static bool filterFeature(Array<int64> featureIDs, int64 featureID)
{
   bool selected = true;
   if(featureIDs)
   {
      // TODO: Optimize Array::Find()!
      int64 * fIDs = featureIDs.array;
      int count = featureIDs.count;
      int k;
      selected = false;
      for(k = 0; k < count; k++, fIDs++)
         if(*fIDs == featureID)
         {
            selected = true;
            break;
         }
   }
   return selected;
}

public bool writeFilteredGeoJSON(FeatureCollection fc, const String baseHREF, File f,
   MinimalAttributeStore store, Array<String> properties, bool omitGeometry, Array<int64> featureIDs, bool singleFeature,
   int64 curOffset, int64 nextOffset, int pagingCount, int64 matchedResults, const String filterString,
   const String bbox, const String cbox, bool isFG, TimeIntervalSince1970 dateTime, CRS crsID, CRS bboxCRSID, CRS cboxCRSID,
   HashMap<int64, Map<String, FieldValue>> keyMap, int curCSID, int nextCSID, int prevCSID, CRS srcCRS)
{
   bool result = true;
   Array<int> reqFields = null;
   FeatureDataType dataType = fc ? fc.type : { none };
   VectorType type = dataType.vectorType;
   bool writeGeometry = !omitGeometry;
   FeatureCollection<PointFeature> tmpFC = null;
   Array<int64> records = null;
   const String crs = crsToURI(crsID);
   const String bboxCRS = crsToURI(bboxCRSID);
   const String cboxCRS = crsToURI(cboxCRSID);

   if(properties && store)
   {
      int i;
      int j = 0;
      reqFields = { size = properties.count };
      writeGeometry = false;
      for(i = 0; i < reqFields.count; i++)
      {
         int id = store.getFieldIndex(properties[i]);
         if(!strcmpi(properties[i], "geometry"))
            writeGeometry = true;
         if(id >= 0)
            reqFields[j++] = id;
      }
      reqFields.size = j;
   }

   // TOCHECK: How should formats properly handle outputting properties only?
   if(!writeGeometry && !fc && store)
   {
      records = featureIDs ? store.validateRecords(featureIDs) : store.queryAllRecords();
      if(records)
      {
         int i;

         tmpFC = { size = records.size };
         fc = tmpFC;
         //type = points;
         for(i = 0; i < records.size; i++)
            tmpFC[i].id = records[i];
      }
   }

   // 'when' or 'timeStamp' property should come from data attributes, and any filtering e.g. from OGC API - Features
   // 'dateTime' query parameter should already be in 'dateTime' parameter here (which maybe should be an interval?)
   if(!singleFeature)
   {
      f.PrintLn("{");
      f.PrintLn("   \"type\" : \"FeatureCollection\",");

      // @context and @type ? "geojson:FeatureCollection",
      if(isFG)
      {
         f.PrintLn("   \"coordRefSys\" : \"", crs, "\",");
         f.PrintLn("   \"conformsTo\": [ \"http://www.opengis.net/spec/json-fg-1/0.2/conf/core\" ],");
         if(type != none)
            f.PrintLn("   \"geometryDimension\": ", type == points ? 0 : type == lines ? 1 : type == polygons ? 2 : 0, ",");
      }
      else if(crsID && crsID != { ogc, 84 } && crsID != { ogc, 84, true }) // use deprecated property to indicate requested crs in regular geojson
         f.PrintLn("   \"crs\" : { \"type\" : \"name\", \"properties\" : { \"name\" : \"", crs, "\" } },");

      // bbox
      f.Print("   \"features\" : [");
   }
   switch(type)
   {
      case points:   result = writeGeoJSONPointFeatures  ((FeatureCollection<  PointFeature>)fc, f, keyMap, store, dataType, writeGeometry, reqFields, featureIDs, singleFeature, baseHREF, pagingCount, curOffset, nextOffset, filterString, bbox, cbox, crsID, bboxCRSID, cboxCRSID, isFG, curCSID, nextCSID, prevCSID, dateTime, srcCRS); break;
      case lines:    result = writeGeoJSONLineFeatures   ((FeatureCollection<   LineFeature>)fc, f, keyMap, store, writeGeometry, reqFields, featureIDs, singleFeature, baseHREF, pagingCount, curOffset, nextOffset, filterString, bbox, cbox, crsID, bboxCRSID, cboxCRSID, isFG, curCSID, nextCSID, prevCSID, dateTime, srcCRS); break;
      case polygons: result = writeGeoJSONPolygonFeatures((FeatureCollection<PolygonFeature>)fc, f, keyMap, store, writeGeometry, reqFields, featureIDs, singleFeature, baseHREF, pagingCount, curOffset, nextOffset, filterString, bbox, cbox, crsID, bboxCRSID, cboxCRSID, isFG, curCSID, nextCSID, prevCSID, dateTime, srcCRS); break;
      case none:
         if(records)
         {
            // Only properties...
            bool previous = false;
            for(feature : records)
            {
               int64 id = feature;
               Map<String, FieldValue> km = keyMap ? keyMap[id] : null;
               if(featureIDs && !tmpFC && !filterFeature(featureIDs, id))
                  continue;

               if(previous)
                  f.PrintLn("   }, {");
               else
                  f.PrintLn(" {");
               f.PrintLn("      \"type\" : \"Feature\",");
               f.PrintLn("      \"id\" : ", id, ",");
               if(!omitGeometry)
                  f.PrintLn("      \"geometry\" : null,");
               f.PrintLn("      \"properties\" : {");
               f.Print("         \"feature::id\" : ", id);
               if(km || (store && (!reqFields || reqFields.count)))
                  writeGeoJSONProperties(f, km, store, reqFields, id, 0, true);
               f.PrintLn("");
               f.PrintLn("      }");
               previous = true;
            }
            if(previous)
               f.Print(singleFeature ? "}\n" : "   }");
         }
         else if(keyMap)
         {
            // Only properties...
            bool previous = false;
            HashMapIterator<int64, Map<String, FieldValue>> it { keyMap };
            while(it.Next())
            {
               int64 id = it.key;
               Map<String, FieldValue> km = it.data;
               if(featureIDs && !tmpFC && !filterFeature(featureIDs, id))
                  continue;

               if(previous)
                  f.PrintLn("   }, {");
               else
                  f.PrintLn(" {");
               f.PrintLn("      \"type\" : \"Feature\",");
               f.PrintLn("      \"id\" : ", id, ",");
               if(!omitGeometry)
                  f.PrintLn("      \"geometry\" : null,");
               f.PrintLn("      \"properties\" : {");
               f.Print("         \"feature::id\" : ", id);
               if(km || (store && (!reqFields || reqFields.count)))
                  writeGeoJSONProperties(f, km, store, reqFields, id, 0, true);
               f.PrintLn("");
               f.PrintLn("      }");
               previous = true;
            }
            if(previous)
               f.Print(singleFeature ? "}\n" : "   }");
         }
         break;
   }
   if(!singleFeature)
   {
      f.Print(" ]");
      if(baseHREF)
         writeFeaturesLinks(f, baseHREF, 0, pagingCount, curOffset, nextOffset, matchedResults,
            matchedResults >= 0 ? (fc ? fc.count : 0) : -1, properties, filterString,
            crsID == { ogc, 84 } ? null : crs, bboxCRS, cboxCRS, bbox, cbox, isFG, curCSID, nextCSID, prevCSID, dateTime);
      f.PrintLn("");
      f.PrintLn("}");
   }

   delete reqFields;
   delete records;
   delete tmpFC;

   return result;
}

// TOCHECK: Currently public for use in routing engine...
public /*static */void writeGeoJSONCoordinates(File f, int nPoints, const GeoPoint * points,
   const Meters * depths, bool repeatFirst, CRS crsID, CRS srcCRS, bool pointsArray)
{
   bool previous = false;
   MinimalProjection pj = crsID == srcCRS ? null : MinimalProjection::fromCRS(crsID);
   int i = 0;
   double multiplier = pj && crsID != { ogc, 153456 } && crsID != { ogc, 1534 } ? wgs84Major : 1.0;
   bool isGeographic = !crsID || crsID == { ogc, 84 } || crsID == { ogc, 84, h = 1 } || crsID == { ogc, 4326 } || crsID == { ogc, 4979 };
   int prec = pj || (crsID == srcCRS && !isGeographic) ? (crsID == { ogc, 153456 } || crsID == { ogc, 1534 } ? 7 : 5) : 13;
   bool latFirst = crsID != srcCRS && (crsID == { epsg, 4326 } || crsID == { epsg, 4979 });

   if(pointsArray) f.Puts("[ ");
   for(i = 0; i < nPoints; i++)
   {
      const GeoPoint * p = &points[i];
      if(previous) f.Puts(", ");
      if(pj)
      {
         GeoPoint pnt { p->lat, p->lon };
         Pointd pv;
         pj.geoToCartesian(pnt, pv);
         f.Puts("[");
         printDoubleDecFile(f, pv.x * multiplier, prec);
         f.Puts(", ");
         printDoubleDecFile(f, pv.y * multiplier, prec);
      }
      else if(latFirst)
      {
         f.Puts("[");
         printDoubleDecFile(f, (double)p->lat, prec);
         f.Puts(", ");
         printDoubleDecFile(f, (double)p->lon, prec);
      }
      else
      {
         f.Puts("[");
         printDoubleDecFile(f, (double)p->lon, prec);
         f.Puts(", ");
         printDoubleDecFile(f, (double)p->lat, prec);
      }
      if(depths)
      {
         f.Puts(", ");
         printDoubleDecFile(f, depths[i], 13);
      }
      f.Puts("]");
      previous = true;
   }
   if(repeatFirst && nPoints > 0)
   {
      const GeoPoint * p = &points[0];
      f.Puts(", ");
      if(pj)
      {
         GeoPoint pnt { p->lat, p->lon };
         Pointd pv;
         pj.geoToCartesian(pnt, pv);

         f.Puts("[");
         printDoubleDecFile(f, pv.x * multiplier, prec);
         f.Puts(", ");
         printDoubleDecFile(f, pv.y * multiplier, prec);
      }
      else if(latFirst)
      {
         f.Puts("[");
         printDoubleDecFile(f, (double)p->lat, prec);
         f.Puts(", ");
         printDoubleDecFile(f, (double)p->lon, prec);
      }
      else
      {
         f.Puts("[");
         printDoubleDecFile(f, (double)p->lon, prec);
         f.Puts(", ");
         printDoubleDecFile(f, (double)p->lat, prec);
      }
      if(depths)
      {
         f.Puts(", ");
         printDoubleDecFile(f, depths[i], 13);
      }
      f.Puts("]");
   }
   if(pointsArray) f.Puts(" ]");
}

static void writeGeoJSONHidden(File f, Container<StartEndPair> hidden, int count)
{
   bool previous = false;
   f.Print("[ ");
   for(h : hidden)
   {
      if(previous) f.Print(", ");
      f.Print("{ \"from\" : ", h.start, ", \"to\" : ", h.end ? h.end : count, " }");
      previous = true;
   }
   f.Print(" ]");
}

bool writeGeoJSONPolygonFeatures(FeatureCollection<PolygonFeature> features, File f, HashMap<int64, Map<String, FieldValue>> keyMap, MinimalAttributeStore store, bool writeGeometry,
   Array<int> fieldsIX, Array<int64> featureIDs, bool singleFeature, const String baseHREF,
   int pagingCount, int64 curOffset, int64 nextOffset, const String filterString, const String bbox, const String cbox,
   CRS crsID, CRS bboxCRSID, CRS cboxCRSID, bool isFG, int curCSID, int nextCSID, int prevCSID, TimeIntervalSince1970 dateTime, CRS srcCRS)
{
   bool result = true;
   const String crs = crsToURI(crsID);
   const String bboxCRS = crsToURI(bboxCRSID);
   const String cboxCRS = crsToURI(cboxCRSID);

   if(features && features.count)
   {
      bool previous = false;
      for(feature : features)
      {
         PolygonFeature pf = feature;
         Array<Polygon> geometry = (Array<Polygon>)pf.geometry;
         if(featureIDs && !filterFeature(featureIDs, pf.id))
            continue;

         if(previous)
            f.PrintLn("   }, {");
         else
            f.PrintLn(" {");
         f.PrintLn("      \"type\" : \"Feature\",");
         f.PrintLn("      \"id\" : ", pf.id, ",");

         if(singleFeature)
         {
            if(isFG)
            {
               f.PrintLn("      \"coordRefSys\" : \"", crs, "\",");
               f.PrintLn("      \"conformsTo\": [ \"http://www.opengis.net/spec/json-fg-1/0.2/conf/core\" ],");
               f.PrintLn("      \"geometryDimension\": 2,");
            }
            else if(crsID != { ogc, 84 } && crsID != { ogc, 84, true }) // use deprecated property to indicate requested crs in regular geojson
               f.PrintLn("      \"crs\" : { \"type\" : \"name\", \"properties\" : { \"name\" : \"", crs, "\" } },");
         }

         if(isFG)
            f.PrintLn("      \"time\" : null,");
         if(writeGeometry)
         {
            if(!geometry || !geometry.count)
            {
               f.PrintLn("      \"geometry\" : null,");
               if(isFG)
                  f.PrintLn("      \"place\" : null,");
            }
            else
            {
               f.Print("      \"geometry\" : ");
               writeGeoJSONPolygons(geometry && geometry.count > 1,
                  geometry ? geometry.count : 0, geometry ? geometry.array : null,
                  f, isFG ? { ogc, 84 } : crsID, srcCRS);
               f.PrintLn(",");
               if(crsID != { ogc, 84 } && isFG) // write 'null' for place? -- is geometry required in GeoJSON schema?
               {
                  f.Print("      \"place\" : ");
                  writeGeoJSONPolygons(geometry && geometry.count > 1,
                     geometry ? geometry.count : 0, geometry ? geometry.array : null,
                     f, crsID, srcCRS);
                  f.PrintLn(",");
               }
               else if(isFG)
                  f.PrintLn("      \"place\" : null,");
            }
         }
         f.PrintLn("      \"properties\" : {");
         f.Print("         \"feature::id\" : ", pf.id);

         {
            bool hasHidden = false;
            if(writeGeometry)
            {
               for(polygon : pf.geometry)
               {
                  Polygon p = polygon;
                  PolygonContour outer = p.outer;
                  Array<PolygonContour> inner = (Array<PolygonContour>)p.inner;
                  Array<StartEndPair> hidden = outer ? (Array<StartEndPair>)outer.hidden : null;
                  if(hidden && hidden.count) { hasHidden = true; break; }
                  if(outer && inner)
                  {
                     for(contour : inner)
                     {
                        hidden = inner ? (Array<StartEndPair>)contour.hidden : null;
                        if(hidden && hidden.count)
                        {
                           hasHidden = true;
                           break;
                        }
                     }
                  }
                  delete inner; // It's a bit clunky, but the Polygon::inner property
                                // return a new object that must be deleted
                  if(hasHidden) break;
               }
            }
            if(hasHidden && writeGeometry)
            {
               bool previous = false;
               f.PrintLn(",");
               f.PrintLn("         \"line::hidden\" : [");
               if(pf.geometry.GetCount() > 1)
               {
                  int count = 0;
                  for(polygon : pf.geometry)
                  {
                     Polygon p = polygon;
                     PolygonContour outer = p.outer;
                     Array<PolygonContour> inner = (Array<PolygonContour>)p.inner;
                     Array<StartEndPair> hidden = (Array<StartEndPair>)outer.hidden;
                     if(hidden && hidden.count)
                     {
                        Array<GeoPoint> points = (Array<GeoPoint>)outer.points;
                        if(previous)
                           f.PrintLn(",");
                        f.Print("            { \"polygon\" : ", count, ", \"contour\" : ", 0, ", \"segments\" : ");
                        writeGeoJSONHidden(f, hidden, points.count);
                        f.Print(" }");
                        previous = true;
                     }
                     if(inner)
                     {
                        int i = 1;
                        for(contour : inner)
                        {
                           hidden = (Array<StartEndPair>)contour.hidden;
                           if(hidden && hidden.count)
                           {
                              Array<GeoPoint> points = (Array<GeoPoint>)contour.points;
                              if(previous)
                                 f.PrintLn(",");
                              f.Print("            { \"polygon\" : ", count, ", \"contour\" : ", i, ", \"segments\" : ");
                              writeGeoJSONHidden(f, hidden, points.count);
                              f.Print(" }");
                              previous = true;
                           }
                        }
                        delete inner; // It's a bit clunky, but the Polygon::inner property
                                      // returnn a new object that must be deleted
                     }
                     count++;
                  }
                  f.PrintLn("");
               }
               else
               {
                  Polygon p = pf.geometry[0];
                  PolygonContour outer = p.outer;
                  Array<PolygonContour> inner = (Array<PolygonContour>)p.inner;
                  Array<StartEndPair> hidden = (Array<StartEndPair>)outer.hidden;
                  if(hidden && hidden.count)
                  {
                     if(previous)
                        f.PrintLn(",");
                     f.Print("            { \"contour\" : ", 0, ", \"segments\" : ");
                     writeGeoJSONHidden(f, hidden, ((Array<GeoPoint>)outer.points).count);
                     f.Print(" }");
                     previous = true;
                  }
                  if(inner)
                  {
                     int i = 1;
                     for(contour : inner)
                     {
                        hidden = (Array<StartEndPair>)contour.hidden;
                        if(hidden && hidden.count)
                        {
                           if(previous)
                              f.PrintLn(",");
                           f.Print("            { \"contour\" : ", i, ", \"segments\" : ");
                           writeGeoJSONHidden(f, hidden, ((Array<GeoPoint>)contour.points).count);
                           f.Print(" }");
                           previous = true;
                        }
                     }
                     delete inner; // It's a bit clunky, but the Polygon::inner property
                                   // returnn a new object that must be deleted
                  }
                  f.PrintLn("");
               }
               f.Print("         ]");
            }
         }
         if(keyMap || (store && (!fieldsIX || fieldsIX.count)))
         {
            Map<String, FieldValue> km = keyMap ? keyMap[pf.id] : null;
            writeGeoJSONProperties(f, km, store, fieldsIX, pf.id, 0, true);
         }
         f.PrintLn("");
         f.Print("      }");
         if(baseHREF && singleFeature) //featureIDs && featureIDs.count == 1 && !pagingCount)
            writeFeaturesLinks(f, baseHREF, pf.id, pagingCount, curOffset, nextOffset, -1, -1, null, filterString,
               crsID == { ogc, 84 } ? null : crs,
               bboxCRSID == { ogc, 84 } ? null : bboxCRS,
               cboxCRSID == { ogc, 84 } ? null : cboxCRS,
               bbox, cbox, isFG, curCSID, nextCSID, prevCSID, dateTime);
         f.PrintLn("");
         previous = true;
      }
      if(previous)
         f.Print(singleFeature ? "}\n" : "   }");
   }
   return result;
}

bool writeGeoJSONLineFeatures(FeatureCollection<LineFeature> features, File f, HashMap<int64, Map<String, FieldValue>> keyMap, MinimalAttributeStore store, bool writeGeometry,
   Array<int> fieldsIX, Array<int64> featureIDs, bool singleFeature, const String baseHREF,
   int pagingCount, int64 curOffset, int64 nextOffset, const String filterString, const String bbox, const String cbox,
   CRS crsID, CRS bboxCRSID, CRS cboxCRSID, bool isFG, int curCSID, int nextCSID, int prevCSID, TimeIntervalSince1970 dateTime, CRS srcCRS)
{
   bool result = true;
   bool previous = false;
   const String crs = crsToURI(crsID);
   const String bboxCRS = crsToURI(bboxCRSID);
   const String cboxCRS = crsToURI(cboxCRSID);

   for(feature : features)
   {
      LineFeature lf = feature;
      Array<LineString> geometry = (Array<LineString>)lf.geometry;
      if(featureIDs && !filterFeature(featureIDs, lf.id))
         continue;

      if(previous)
         f.PrintLn("   }, {");
      else
         f.PrintLn(" {");
      f.PrintLn("      \"type\" : \"Feature\",");
      f.PrintLn("      \"id\" : ", lf.id, ",");
      if(singleFeature)
      {
         if(isFG)
         {
            f.PrintLn("      \"coordRefSys\" : \"", crs, "\",");
            f.PrintLn("      \"conformsTo\": [ \"http://www.opengis.net/spec/json-fg-1/0.2/conf/core\" ],");   // [ogc-json-fg-1-0.2:core]
            f.PrintLn("      \"geometryDimension\": 1,");
         }
         else if(crsID != { ogc, 84 } && crsID != { ogc, 84, true }) // use deprecated property to indicate requested crs in regular geojson
            f.PrintLn("      \"crs\" : { \"type\" : \"name\", \"properties\" : { \"name\" : \"", crs, "\" } },");
      }

      if(isFG)
         f.PrintLn("      \"time\" : null,");
      if(writeGeometry)
      {
         if(!geometry || !geometry.count)
         {
            f.PrintLn("      \"geometry\" : null,");
            if(isFG)
               f.PrintLn("      \"place\" : null,");
         }
         else
         {
            f.Print("      \"geometry\" : ");
            writeGeoJSONLines(geometry && geometry.count > 1,
               geometry ? geometry.count : 0, geometry ? geometry.array : null,
               f, isFG ? { ogc, 84 } : crsID, srcCRS);
            f.PrintLn(",");
            if(crsID != { ogc, 84 } && isFG) // write 'null' for place?
            {
               f.Print("      \"place\" : ");
               writeGeoJSONLines(geometry && geometry.count > 1,
                  geometry ? geometry.count : 0, geometry ? geometry.array : null,
                  f, crsID, srcCRS);
               f.PrintLn(",");
            }
            else if(isFG)
               f.PrintLn("      \"place\" : null,");
         }
      }
      f.PrintLn("      \"properties\" : {");
      f.Print("         \"feature::id\" : ", lf.id);
      if(keyMap || (store && (!fieldsIX || fieldsIX.count)))
      {
         Map<String, FieldValue> km = keyMap ? keyMap[lf.id] : null;
         writeGeoJSONProperties(f, km, store, fieldsIX, lf.id, 0, true);
      }
      f.PrintLn("");
      f.Print("      }");
      if(baseHREF && singleFeature) //&& featureIDs && featureIDs.count == 1 && !pagingCount)
         writeFeaturesLinks(f, baseHREF, lf.id, pagingCount, curOffset, nextOffset, -1, -1, null, filterString,
            crsID == { ogc, 84 } ? null : crs,
            bboxCRSID == { ogc, 84 } ? null : bboxCRS,
            cboxCRSID == { ogc, 84 } ? null : cboxCRS,
            bbox, cbox, isFG, curCSID, nextCSID, prevCSID, dateTime);
      f.PrintLn("");
      previous = true;
   }
   if(previous)
      f.Print(singleFeature ? "}\n" : "   }");
   return result;
}

bool writeGeoJSONPointFeatures(FeatureCollection<PointFeature> fc, File f, HashMap<int64, Map<String, FieldValue>> keyMap, MinimalAttributeStore store, FeatureDataType type, bool writeGeometry,
   Array<int> fieldsIX, Array<int64> featureIDs, bool singleFeature, const String baseHREF,
   int pagingCount, int64 curOffset, int64 nextOffset, const String filterString, const String bbox, const String cbox,
   CRS crsID, CRS bboxCRSID, CRS cboxCRSID, bool isFG, int curCSID, int nextCSID, int prevCSID, TimeIntervalSince1970 dateTime, CRS srcCRS)
{
   bool result = true;
   bool previous = false;
   PointFeature * pf = fc.array;
   uintsize featureSize = fc._class.templateArgs[0].dataTypeClass.structSize;
   bool is3D = type.is3D;
   bool isModel = type.isModel;
   int i = 0;
   const String crs = crsToURI(crsID);
   const String bboxCRS = crsToURI(bboxCRSID);
   const String cboxCRS = crsToURI(cboxCRSID);

   for(i = 0; i < fc.count; i++)
   {
      Point3DFeature * p3df = is3D ? (Point3DFeature *)pf : null;
      Models3DFeature * mf = isModel ? (Models3DFeature *)pf : null;
      char s1[20], s2[20], s3[20];
      Array<GeoPoint> geometry = (Array<GeoPoint>)pf->geometry;
      if(featureIDs && !filterFeature(featureIDs, pf ? pf->id : p3df ? p3df->id : mf ? mf->id : 0))
         continue;

      if(previous)
         f.PrintLn("   }, {");
      else
         f.PrintLn(" {");
      f.PrintLn("      \"type\" : \"Feature\",");
      f.PrintLn("      \"id\" : ", pf->id, ",");

      if(singleFeature)
      {
         if(isFG)
         {
            f.PrintLn("      \"coordRefSys\" : \"", crs, "\",");
            f.PrintLn("      \"conformsTo\": [ \"http://www.opengis.net/spec/json-fg-1/0.2/conf/core\" ],");
            f.PrintLn("      \"geometryDimension\": 0,");
         }
         else if(crsID != { ogc, 84 } && crsID != { ogc, 84, true }) // use deprecated property to indicate requested crs in regular geojson
            f.PrintLn("      \"crs\" : { \"type\" : \"name\", \"properties\" : { \"name\" : \"", crs, "\" } },");
      }

      if(isFG)
         f.PrintLn("      \"time\" : null,");
      if(writeGeometry)
      {
         if(!geometry || !geometry.count)
         {
            f.PrintLn("      \"geometry\" : null,");
            if(isFG)
               f.PrintLn("      \"place\" : null,");
         }
         else
         {
            f.Print("      \"geometry\" : ");
            writeGeoJSONPoints(geometry && geometry.count > 1,
               geometry ? geometry.count : 0, geometry ? geometry.array : null,
               f, p3df ? p3df->depths : null, isFG ? { ogc, 84 } : crsID, srcCRS);
            f.PrintLn(",");
            if(crsID != { ogc, 84 } && isFG) // write 'null' for place?
            {
               f.Print("      \"place\" : ");
               writeGeoJSONPoints(geometry && geometry.count > 1,
                  geometry ? geometry.count : 0, geometry ? geometry.array : null,
                  f, p3df ? p3df->depths : null, crsID, srcCRS);
               f.PrintLn(",");
            }
            else if(isFG)
               f.PrintLn("      \"place\" : null,");
         }
      }
      f.PrintLn("      \"properties\" : {");
      f.Print("         \"feature::id\" : ", pf->id);
      // TODO: Single vs. multi-point 3d points / models?
      /*
      if(p3df && p3df->depths)
      {
         printDoubleDec(p3df->depths[0], 3, s1, 20);
         f.Print(",\n         \"feature::altitude\" : ", s1);
      }
      */
      if(mf)
      {
         ModelID * modelIDs = mf->modelIDs;
         if(modelIDs)
            f.Print(",\n         \"model::id\" : ", (uint64)modelIDs[0]);
         if(type.hasScale)
         {
            float * scales = mf->scales;
            if(scales)
            {
               printDoubleDec(scales[0], 5, s1, 20);
               printDoubleDec(scales[1], 5, s2, 20);
               printDoubleDec(scales[2], 5, s3, 20);
               f.Print(",\n         \"model::scale\" : [", s1, ",", s2, ",", s3, "]");
            }
         }
         if(type.hasYaw)
         {
            const Degrees * orientations = mf->orientations;
            if(orientations)
            {
               printDoubleDec(orientations[0], 2, s1, 20);
               printDoubleDec(orientations[1], 2, s2, 20);
               printDoubleDec(orientations[2], 2, s3, 20);
               f.Print(",\n         \"model::orientation\" : [", s1, ",", s2, ",", s3, "]");
            }
         }
      }
      if(keyMap || (store && (!fieldsIX || fieldsIX.count)))
      {
         Map<String, FieldValue> km = keyMap ? keyMap[pf->id] : null;
         writeGeoJSONProperties(f, km, store, fieldsIX, pf->id, 0, true);
      }
      f.PrintLn("");
      f.Print("      }");

      if(baseHREF && singleFeature) //&& featureIDs && featureIDs.count == 1 && !pagingCount)
         writeFeaturesLinks(f, baseHREF, pf->id, pagingCount, curOffset, nextOffset, -1, -1, null, filterString,
            crsID == { ogc, 84 } ? null : crs,
            bboxCRSID == { ogc, 84 } ? null : bboxCRS,
            cboxCRSID == { ogc, 84 } ? null : cboxCRS,
            bbox, cbox, isFG, curCSID, nextCSID, prevCSID, dateTime);
      f.PrintLn("");
      previous = true;

      pf = (PointFeature *)((byte *)pf + featureSize);
   }
   if(previous)
      f.Print(singleFeature ? "}\n" : "   }");
   return result;
}

static void writeGeoJSONPoints(bool multiPoint, int nPoints, const GeoPoint * points,
   File f, const Meters * depths, CRS crsID, CRS srcCRS)
{
   if(points && nPoints)
   {
      f.PrintLn("{");
      f.PrintLn("         \"type\" : \"", multiPoint || nPoints > 1 ? "MultiPoint" : "Point", "\",");
      f.Print  ("         \"coordinates\" : ");
      writeGeoJSONCoordinates(f, nPoints, points, depths, false, crsID, srcCRS, multiPoint);
      f.Print("\n      }");
   }
   else
      f.Print("null");
}

static void writeGeoJSONLines(bool multi, int nLineStrings, const LineString * lineStrings,
   File f, CRS crsID, CRS srcCRS )
{
   if(lineStrings && nLineStrings)
   {
      f.PrintLn("      {");
      if(multi || nLineStrings > 1)
      {
         bool previous = false;
         int i;
         f.PrintLn("         \"type\" : \"MultiLineString\",");
         f.PrintLn("         \"coordinates\" : [");
         for(i = 0; i < nLineStrings; i++)
         {
            const LineString * l = &lineStrings[i];
            Array<GeoPoint> points = (Array<GeoPoint>)l->points;

            if(previous)
               f.PrintLn(",");
            f.Print("               ");
            writeGeoJSONCoordinates(f, points ? points.count : 0,
               points ? points.array : null, l->depths, false, crsID, srcCRS, true);
            previous = true;
         }
         f.PrintLn("");
         f.PrintLn("         ]");
      }
      else
      {
         const LineString * l = lineStrings;
         Array<GeoPoint> points = (Array<GeoPoint>)l->points;

         f.PrintLn("         \"type\" : \"LineString\",");
         f.PrintLn("         \"coordinates\" :");
         f.Print("            ");
         writeGeoJSONCoordinates(f, points ? points.count : 0,
            points ? points.array : null, l->depths, false, crsID, srcCRS, true);
         f.PrintLn("");
      }
      f.Print("      }");
   }
   else
      f.Print("null");
}

static void writeGeoJSONPolygons(bool multi, int nPolygons, const Polygon * polygons,
   File f, CRS crsID, CRS srcCRS)
{
   if(polygons && nPolygons)
   {
      f.PrintLn("      {");
      if(multi || nPolygons > 1)
      {
         bool previous = false;
         int p;

         f.PrintLn("         \"type\" : \"MultiPolygon\",");
         f.PrintLn("         \"coordinates\" : [");
         for(p = 0; p < nPolygons; p++)
         {
            const Polygon * polygon = &polygons[p];
            PolygonContour outer = polygon->outer;
            if(outer)
            {
               Array<GeoPoint> points = (Array<GeoPoint>)outer.points;
               Array<PolygonContour> inner = (Array<PolygonContour>)polygon->inner;

               if(previous)
                  f.PrintLn(", [");
               else
                  f.PrintLn("            [");
               f.Print("               ");
               writeGeoJSONCoordinates(f, points ? points.count : 0, points ? points.array : null,
                  outer.depths, true, crsID, srcCRS, true);
               if(inner)
               {
                  for(i : inner)
                  {
                     points = (Array<GeoPoint>)i.points;
                     f.PrintLn(",");
                     f.Print("               ");
                     writeGeoJSONCoordinates(f, points ? points.count : 0, points ? points.array : null,
                        i.depths, true, crsID, srcCRS, true);
                  }

                  delete inner; // It's a bit clunky, but the Polygon::inner property
                                // returnn a new object that must be deleted
               }
               f.PrintLn("");
               f.Print("            ]");
               previous = true;
            }
         }
         f.PrintLn("");
         f.PrintLn("         ]");
      }
      else
      {
         const Polygon * polygon = &polygons[0];
         PolygonContour outer = polygon->outer;

         f.PrintLn("         \"type\" : \"Polygon\",");
         f.PrintLn("         \"coordinates\" : [");
         f.Print("            ");
         if(outer)
         {
            Array<GeoPoint> points = (Array<GeoPoint>)outer.points;
            Array<PolygonContour> inner = (Array<PolygonContour>)polygon->inner;

            writeGeoJSONCoordinates(f, points ? points.count : 0, points ? points.array : null,
               outer.depths, true, crsID, srcCRS, true);

            if(inner)
            {
               for(i : inner)
               {
                  Array<GeoPoint> points = (Array<GeoPoint>)i.points;

                  f.PrintLn(",");
                  f.Print("            ");
                  writeGeoJSONCoordinates(f, points ? points.count : 0, points ? points.array : null,
                     i.depths, true, crsID, srcCRS, true);
               }

               delete inner; // It's a bit clunky, but the Polygon::inner property
                             // returnn a new object that must be deleted
            }
         }
         f.PrintLn("");
         f.PrintLn("         ]");
      }
      f.Print("      }");
   }
   else
      f.Print("null");
}

bool printDateTimeParameter(char dtParam[1024], const TimeIntervalSince1970 dateTime)
{
   bool result = false;
   dtParam[0] = 0;
   if(dateTime != null && dateTime.start != unsetTime)
   {
      char dt[1024];

      strcpy(dtParam, "datetime=");
      if(dateTime.start == earliestTime)
         strcat(dtParam, "..");
      else
      {
         printTimeBuf(dt, sizeof(dt), { year = true, month = true, day = true, hour = true, minute = true, second = true }, dateTime.start, 0);
         strcat(dtParam, dt);
      }

      if(dateTime.end != unsetTime)
      {
         strcat(dtParam, "/");
         if(dateTime.end == latestTime)
            strcat(dtParam, "..");
         else
         {
            printTimeBuf(dt, sizeof(dt), { year = true, month = true, day = true, hour = true, minute = true, second = true }, dateTime.end, 0);
            strcat(dtParam, dt);
         }
      }
      result = true;
   }
   return result;
}

static void writeFeaturesLinks(File f, const String baseHREF, int64 fid, int pagingCount, int64 curOffset, int64 nextOffset,
   int64 matchedResults, int returnedResults, Array<String> properties, const String filterString, const String crs, const String bboxCRS,
      const String cboxCRS, const String bbox, const String cbox, bool isFG, int curCSID, int nextCSID, int prevCSID, TimeIntervalSince1970 dateTime)
{
   // We only need links for single features?
   // TODO: add selected properties as well?
   ZString zPropString { allocType = heap };
   const String propString = "";
   String crsString = null;
   const String type = isFG ? "application/vnd.ogc.fg+json" : "application/geo+json";
   const String format = isFG ? "jsonfg" : "json";

   if(crs || bboxCRS || cboxCRS)
      crsString = PrintString(
         crs ? "&crs=" : null, crs ? crs : "",
         bboxCRS ? "&bbox-crs=" : "", bboxCRS ? bboxCRS : "",
         cboxCRS ? "&clipbox-crs=" : "", cboxCRS ? cboxCRS : "");

   if(properties)
   {
      bool first = true;
      zPropString.concatx("&properties=");
      for(p : properties)
      {
         if(!first) zPropString.concatx(",");
         zPropString.concatx(p);
         first = false;
      }
      propString = zPropString.string;
   }

   f.PrintLn(",");
   if(matchedResults >= 0)
      f.PrintLn("   \"numberMatched\" : ", matchedResults, ",");
   if(returnedResults >= 0)
      f.PrintLn("   \"numberReturned\" : ", returnedResults, ",");
   f.PrintLn("   \"links\" : [");
   f.PrintLn("      {");

   // Self Links
   f.PrintLn("         \"rel\" : \"self\",");
   f.PrintLn("         \"type\" : \"",type,"\",");
   if(fid)
      f.PrintLn("         \"href\" : \"", baseHREF, "/items/", fid, "?f=", format, crsString,
         bbox ? "&bbox=" : "", bbox ? bbox : "", cbox ? "&clipbox=" : "", cbox ? cbox : "", "\"");
   else if(curOffset || curCSID)
   {
      f.Print("         \"href\" : \"", baseHREF, "/items?");
      if(curCSID)
         f.Print("cspage=", curCSID);
      else
         f.Print("offset=", curOffset);
      if(pagingCount > 0)
         f.Print("&limit=", pagingCount);
      f.Print(propString);
      if(filterString) f.Puts(filterString);
      f.Print(crsString, "&f=", format,
            bbox ? "&bbox=" : "", bbox ? bbox : "", cbox ? "&clipbox=" : "", cbox ? cbox : "", "\"", "\n");
   }
   else if(pagingCount > 0)
   {
      f.Print("         \"href\" : \"", baseHREF, "/items?limit=", pagingCount, propString);
      if(filterString) f.Print(filterString);
      f.PrintLn(crsString, "&f=", format,
         bbox ? "&bbox=" : "", bbox ? bbox : "", cbox ? "&clipbox=" : "", cbox ? cbox : "", "\"");
   }
   else
   {
      f.Print("         \"href\" : \"", baseHREF, "/items?f=", format, propString);
      if(filterString) f.Puts(filterString);
      f.PrintLn(crsString,
         bbox ? "&bbox=" : "", bbox ? bbox : "", cbox ? "&clipbox=" : "", cbox ? cbox : "", "\"");
   }
   f.PrintLn("      },");
   f.PrintLn("      {");
   f.PrintLn("         \"rel\" : \"alternate\",");
   f.PrintLn("         \"type\" : \"text/html\",");
   if(fid)
      f.PrintLn("         \"href\" : \"", baseHREF, "/items/", fid, "?f=html", crsString,
         bbox ? "&bbox=" : "", bbox ? bbox : "", cbox ? "&clipbox=" : "", cbox ? cbox : "", "\"");
   else if(curOffset || curCSID)
   {
      f.Print("         \"href\" : \"", baseHREF, "/items?");
      if(curCSID)
         f.Print("cspage=", curCSID);
      else
         f.Print("offset=", curOffset);
      if(pagingCount > 0)
      {
         if(dateTime != null && dateTime.start != unsetTime)
         {
            char param[1024];
            if(printDateTimeParameter(param, dateTime))
               f.Puts("&"), f.Puts(param);
         }
         f.Print("&limit=", pagingCount, propString);
         if(filterString) f.Puts(filterString);
         f.Print(crsString, "&f=html",
            bbox ? "&bbox=" : "", bbox ? bbox : "", cbox ? "&clipbox=" : "", cbox ? cbox : "");
      }
      f.PrintLn("\"");
   }
   else if(pagingCount > 0)
   {
      f.Print("         \"href\" : \"", baseHREF, "/items?limit=", pagingCount, propString);
      if(filterString) f.Puts(filterString);
      f.Print(crsString, "&f=html",
         bbox ? "&bbox=" : "", bbox ? bbox : "", cbox ? "&clipbox=" : "", cbox ? cbox : "");
      if(dateTime != null && dateTime.start != unsetTime)
      {
         char param[1024];
         if(printDateTimeParameter(param, dateTime))
            f.Puts("&"), f.Puts(param);
      }
      f.PrintLn("\"");
   }
   else
   {
      f.Print("         \"href\" : \"", baseHREF, "/items?f=html", propString);
      if(filterString) f.Puts(filterString);
      f.Print(crsString,
         bbox ? "&bbox=" : "", bbox ? bbox : "", cbox ? "&clipbox=" : "", cbox ? cbox : "");
      if(dateTime != null && dateTime.start != unsetTime)
      {
         char param[1024];
         if(printDateTimeParameter(param, dateTime))
            f.Puts("&"), f.Puts(param);
      }
      f.PrintLn("\"");
   }
   f.PrintLn("      },");

   // Next link
   if((nextOffset || nextCSID) && !fid)
   {
      f.PrintLn("      {");
      f.PrintLn("         \"rel\" : \"next\",");
      f.PrintLn("         \"type\" : \"",type,"\",");
      f.Print("         \"href\" : \"", baseHREF, "/items?");//"/items?offset=", nextOffset, "&limit=", pagingCount);
      if(nextCSID)
         f.Print("cspage=", nextCSID);
      else
         f.Print("offset=", nextOffset);
      if(dateTime != null && dateTime.start != unsetTime)
      {
         char param[1024];
         if(printDateTimeParameter(param, dateTime))
            f.Puts("&"), f.Puts(param);
      }

      f.Print("&limit=", pagingCount, propString);
      if(filterString) f.Puts(filterString);
      f.Print(crsString, "&f=", format,
         bbox ? "&bbox=" : "", bbox ? bbox : "", cbox ? "&clipbox=" : "", cbox ? cbox : "", "\"", "\n");
      f.PrintLn("      },");
   }

   // Previous Link
   if(!fid && (curOffset || prevCSID > -1))
   {
      f.PrintLn("      {");
      f.PrintLn("         \"rel\" : \"prev\",");
      f.PrintLn("         \"type\" : \"",type,"\",");
      f.Print("         \"href\" : \"", baseHREF, "/items?");
      if(prevCSID > -1)
      {
         if(prevCSID)
            f.Print("cspage=", prevCSID);
      }
      else
         f.Print("offset=", curOffset - pagingCount);
      if(dateTime != null && dateTime.start != unsetTime)
      {
         char param[1024];
         if(printDateTimeParameter(param, dateTime))
            f.Puts("&"), f.Puts(param);
      }
      f.Print("&limit=", pagingCount, propString);
      if(filterString) f.Puts(filterString);
      f.Print(crsString, "&f=", format,
         bbox ? "&bbox=" : "", bbox ? bbox : "", cbox ? "&clipbox=" : "", cbox ? cbox : "", "\"", "\n");
      f.PrintLn("      },");
   }

   // Single features need link back to collection
   f.PrintLn("      {");
   f.PrintLn("         \"rel\" : \"collection\",");
   f.PrintLn("         \"type\" : \"application/json\",");
   f.PrintLn("         \"href\" : \"", baseHREF, "\"");
   f.PrintLn("      }");
   f.PrintLn("   ],");
   {
      char ts[1024];
      DateTime t { };
      t.GetLocalTime();
      printTimeBuf(ts, sizeof(ts),
         { year = true, month = true, day = true, hour = true, minute = true, second = true }, t.global, 0);
      f.Print("   \"timeStamp\" : \"", ts, "\"");
   }

   delete zPropString;
   delete crsString;
}

// REVIEW: Used for CQL2-JSON
public void generatePolygonFromCoordinates(Polygon * poly, Array<Array<Array<double>>> polygon, bool ignorePJ, MinimalProjection pj, CRS crs, bool * is3D)
{
   int j;
   Array<PolygonContour> contours { size = polygon.count };
   poly->setContours(contours);
   for(j = 0; j < polygon.count; j++)
   {
      Array<Array<double>> contour = polygon[j];
      contours[j] = generateContoursFromCoordinates(j > 0, contour, ignorePJ, pj, crs, is3D);
      if(contour.count > 0)
         delete contour[contour.count-1];
      delete contour;
   }
}

static PolygonContour generateContoursFromCoordinates(bool inner, Array<Array<double>> contour, bool ignorePJ, MinimalProjection pj, CRS crs, bool * is3D)
{
   PolygonContour c { };
   int k;
   Array<GeoPoint> points = (Array<GeoPoint>)c.points;

   c.inner = inner;
   points.size = contour.count-1;
   for(k = 0; k < contour.count-1; k++)
   {
      Array<double> point = contour[k];
      if(point && point.count >= 2)
      {
         if(pj && !ignorePJ)
            deprojectPoint(point.array, points[k], pj);
         else if(crs == { epsg, 4326 })
            points[k] = { point[0], point[1] };
         else
         {
            points[k] = { point[1], point[0] };
            if(point.count == 3)
            {
               *is3D = true;
               if(!c.depths)
                  c.depths = new0 Meters[contour.count];
               c.depths[k] = point[2];
            }
         }
      }
      delete point;
   }
   c.clockwise = c.computeEuclideanArea() < 0; // Clockwise computes negative area for (lat, lon)
   return c;
}

public void generateLineStringFromCoordinates(LineString * line, Array<Array<double>> lineString, bool ignorePJ, MinimalProjection pj, CRS crs, bool * is3D)
{
   int j;
   Array<GeoPoint> points { size = lineString.count };
   line->points = points;

   for(j = 0; j < lineString.count; j++)
   {
      Array<double> point = lineString[j];
      if(point.count >= 2)
      {
         if(pj && !ignorePJ)
            deprojectPoint(point.array, points[j], pj);
         else if(crs.crsID == 4326)
            points[j] = { point[0], point[1] };
         else
         {
            points[j] = { point[1], point[0] };
            if(point.count >= 3)
            {
               *is3D = true;
               if(!line->depths)
                  line->depths = new0 Meters[lineString.count];
               line->depths[j] = point[2];
            }
         }
      }
      delete point;
   }
}

public void generatePointFromCoordinates(GeoPoint pt, Array<double> point, int pIndex, int fIndex, Meters * depths, bool ignorePJ, MinimalProjection pj, CRS crs, bool * is3D)
{
   if(pj && !ignorePJ)
      deprojectPoint(point.array, pt, pj);
   else if(crs.crsID == 4326)
      pt = { point[0], point[1] };
   else
      pt = { point[1], point[0] };
   if(point.count == 3 && depths)
   {
      *is3D = true;
      depths[fIndex] = point[2];
   }
}

static void writeGeoJSONGeometryCollection(int nGeometries, const Geometry * geometries,
   File f, CRS crsID, CRS srcCRS)
{
   if(geometries && nGeometries)
   {
      bool previous = false;
      int i;

      f.PrintLn("      {");
      f.PrintLn("         \"type\" : \"GeometryCollection\",");
      f.PrintLn("         \"geometries\" : [");
      for(i = 0; i < nGeometries; i++)
      {
         if(previous)
            f.PrintLn(",");
         writeGeoJSONGeometry(f, geometries[i], crsID, srcCRS);
         previous = true;
      }
      f.PrintLn("");
      f.PrintLn("         ]");
      f.Print("      }");
   }
   else
      f.Print("null");
}

public bool writeGeoJSONGeometry(File f, const Geometry geometry, CRS crsID, CRS srcCRS)
{
   bool result = false;

   switch(geometry.type)
   {
      case point:
         writeGeoJSONPoints(false, 1, &geometry.point, f, null, crsID, srcCRS);
         result = true;
         break;
      case multiPoint:
      {
         Array<GeoPoint> mp = (Array<GeoPoint>)geometry.multiPoint;
         writeGeoJSONPoints(true, mp ? mp.count : 0, mp ? mp.array : null, f, null, crsID, srcCRS);
         result = true;
         break;
      }
      case lineString:
         writeGeoJSONLines(false, 1, &geometry.lineString, f, crsID, srcCRS);
         result = true;
         break;
      case multiLineString:
      {
         Array<LineString> ml = (Array<LineString>)geometry.multiLineString;
         writeGeoJSONLines(true, ml ? ml.count : 0, ml ? ml.array : null, f, crsID, srcCRS);
         result = true;
         break;
      }
      case polygon:
         writeGeoJSONPolygons(false, 1, &geometry.polygon, f, crsID, srcCRS);
         result = true;
         break;
      case multiPolygon:
      {
         Array<Polygon> mp = (Array<Polygon>)geometry.multiPolygon;
         writeGeoJSONPolygons(true, mp ? mp.count : 0, mp ? mp.array : null, f, crsID, srcCRS);
         result = true;
         break;
      }
      case geometryCollection:
      {
         Array<Geometry> gc = (Array<Geometry>)geometry.geometryCollection;
         writeGeoJSONGeometryCollection(gc ? gc.count : 0, gc ? gc.array : 0, f, crsID, srcCRS);
         result = true;
         break;
      }
   }
   return result;
}
