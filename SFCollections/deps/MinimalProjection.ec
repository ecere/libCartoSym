public import IMPORT_STATIC "ecrt"
public import IMPORT_STATIC "GeoExtents"

private:

public class MinimalProjection
{
   public virtual bool geoToCartesian(const GeoPoint position, Pointd result);
   public virtual bool cartesianToGeo(const Pointd position, GeoPoint result);

   MinimalProjection ::fromCRS(CRS crs)
   {
      MinimalProjection pj = null;
      if(crs)
      {
         /* TODO:
         switch(crs)
         {
            case CRS { epsg, 3395 }: pj = worldMercatorPJ; break;
            case CRS { epsg, 3857 }: pj = webMercatorPJ;   break;
            case CRS { ogc,  153456 }: pj = iseaDiamondsPJ;  break;
            case CRS { ogc,  1534 }: pj = iseaPlanarPJ;  break;
         }
         */
         // TODO: Implement more projections
         // For now CRS84/EPSG:4326 are both handled as null projection, with flipped axis order handled separately
      }
      return pj;
   }
}

// TODO: Make these support dynamic registration
CRS crsFromID(const String uri)
{
   CRS crs = 0;

   if(SearchString(uri, 0, "3857", false, true))
      crs = { epsg, 3857 };
   else if(SearchString(uri, 0, "3395", false, true))
      crs = { epsg, 3395 };
   else if(SearchString(uri, 0, "4326", false, true))
      crs = { epsg, 4326 };
   else if(SearchString(uri, 0, "4979", false, true))
      crs = { epsg, 4979 };
   else if(SearchString(uri, 0, "CRS84h", false, true))
      crs = { ogc, 84, true };
   else if(SearchString(uri, 0, "CRS84", false, true))
      crs = { ogc, 84 };
   else if(SearchString(uri, 0, "OGC:1534", false, true) || SearchString(uri, 0, "OGC-CRS:1534", false, true) ||
      (SearchString(uri, 0, "/crs/OGC/", false, true) && SearchString(uri, 0, "/1534", false, true)))
      crs = { ogc, 1534 };
   else if(SearchString(uri, 0, "OGC:153456", false, true) || SearchString(uri, 0, "OGC-CRS:15356", false, true) ||
      (SearchString(uri, 0, "/crs/OGC/", false, true) && SearchString(uri, 0, "/153456", false, true)))
      crs = { ogc, 153456 };

   return crs;
}

const String crsToURI(CRS crs)
{
   const String uri = crsIDToDef[crs];
   return uri;
}

Map<CRS, const String> crsIDToDef
{[
   { { epsg, 3857 }, "http://www.opengis.net/def/crs/EPSG/0/3857" },
   { { epsg, 3395 }, "http://www.opengis.net/def/crs/EPSG/0/3395" },
   { { epsg, 4326 }, "http://www.opengis.net/def/crs/EPSG/0/4326" },
   { { epsg, 4979 }, "http://www.opengis.net/def/crs/EPSG/0/4979" },
   { {  ogc,   84 }, "http://www.opengis.net/def/crs/OGC/1.3/CRS84" },
   { {  ogc,   84, h = 1 }, "http://www.opengis.net/def/crs/OGC/1.3/CRS84h" },
   { {  ogc, 1534 }, "http://www.opengis.net/def/crs/OGC/0/1534" },
   { {  ogc, 153456 }, "http://www.opengis.net/def/crs/OGC/0/153456" }
]};

Map<CRS, const String> crsIDToCURI
{[
   { { epsg, 3857 }, "[EPSG:3857]" },
   { { epsg, 3395 }, "[EPSG:3395]" },
   { { epsg, 4326 }, "[EPSG:4326]" },
   { { epsg, 4979 }, "[EPSG:4979]" },
   { {  ogc,   84 }, "[OGC:CRS84]" },
   { {  ogc,   84, h = 1 }, "[OGC:CRS84h]" },
   { {  ogc, 1534 }, "[OGC:1534]" },
   { {  ogc, 153456 }, "[OGC:153456]" }
]};

Map<CRS, const String> crsIDToWKT2
{[
   /*fixthisone*/{ { epsg, 3857 }, "GEOGCRS[\"WGS 84\",ENSEMBLE[\"World Geodetic System 1984 ensemble\",MEMBER[\"World Geodetic System 1984 (Transit)\"],MEMBER[\"World Geodetic System 1984 (G730)\"],MEMBER[\"World Geodetic System 1984 (G873)\"],MEMBER[\"World Geodetic System 1984 (G1150)\"],MEMBER[\"World Geodetic System 1984 (G1674)\"],MEMBER[\"World Geodetic System 1984 (G1762)\"],MEMBER[\"World Geodetic System 1984 (G2139)\"],ELLIPSOID[\"WGS 84\",6378137,298.257223563,LENGTHUNIT[\"metre\",1]],ENSEMBLEACCURACY[2.0]],PRIMEM[\"Greenwich\",0,ANGLEUNIT[\"degree\",0.0174532925199433]],CS[ellipsoidal,2],AXIS[\"geodetic latitude (Lat)\",north,ORDER[1],ANGLEUNIT[\"degree\",0.0174532925199433]],AXIS[\"geodetic longitude (Lon)\",east,ORDER[2],ANGLEUNIT[\"degree\",0.0174532925199433]],USAGE[SCOPE[\"Horizontal component of 3D system.\"],AREA[\"World.\"],BBOX[-90,-180,90,180]],ID[\"EPSG\",4326]]" },
   { { epsg, 3395 }, "PROJCRS[\"WGS 84 / World Mercator\",BASEGEOGCRS[\"WGS 84\",ENSEMBLE[\"World Geodetic System 1984 ensemble\",MEMBER[\"World Geodetic System 1984 (Transit)\"],MEMBER[\"World Geodetic System 1984 (G730)\"],MEMBER[\"World Geodetic System 1984 (G873)\"],MEMBER[\"World Geodetic System 1984 (G1150)\"],MEMBER[\"World Geodetic System 1984 (G1674)\"],MEMBER[\"World Geodetic System 1984 (G1762)\"],MEMBER[\"World Geodetic System 1984 (G2139)\"],ELLIPSOID[\"WGS 84\",6378137,298.257223563,LENGTHUNIT[\"metre\",1]],ENSEMBLEACCURACY[2.0]],PRIMEM[\"Greenwich\",0,ANGLEUNIT[\"degree\",0.0174532925199433]],ID[\"EPSG\",4326]],CONVERSION[\"World Mercator\",METHOD[\"Mercator (variant A)\",ID[\"EPSG\",9804]],PARAMETER[\"Latitude of natural origin\",0,ANGLEUNIT[\"degree\",0.0174532925199433],ID[\"EPSG\",8801]],PARAMETER[\"Longitude of natural origin\",0,ANGLEUNIT[\"degree\",0.0174532925199433],ID[\"EPSG\",8802]],PARAMETER[\"Scale factor at natural origin\",1,SCALEUNIT[\"unity\",1],ID[\"EPSG\",8805]],PARAMETER[\"False easting\",0,LENGTHUNIT[\"metre\",1],ID[\"EPSG\",8806]],PARAMETER[\"False northing\",0,LENGTHUNIT[\"metre\",1],ID[\"EPSG\",8807]]],CS[Cartesian,2],AXIS[\"(E)\",east,ORDER[1],LENGTHUNIT[\"metre\",1]],AXIS[\"(N)\",north,ORDER[2],LENGTHUNIT[\"metre\",1]],USAGE[SCOPE[\"Very small scale conformal mapping.\"],AREA[\"World between 80Â°S and 84Â°N.\"],BBOX[-80,-180,84,180]],ID[\"EPSG\",3395]]" },
   { { epsg, 4326 }, "GEOGCRS[\"WGS 84\",ENSEMBLE[\"World Geodetic System 1984 ensemble\",MEMBER[\"World Geodetic System 1984 (Transit)\"],MEMBER[\"World Geodetic System 1984 (G730)\"],MEMBER[\"World Geodetic System 1984 (G873)\"],MEMBER[\"World Geodetic System 1984 (G1150)\"],MEMBER[\"World Geodetic System 1984 (G1674)\"],MEMBER[\"World Geodetic System 1984 (G1762)\"],MEMBER[\"World Geodetic System 1984 (G2139)\"],ELLIPSOID[\"WGS 84\",6378137,298.257223563,LENGTHUNIT[\"metre\",1]],ENSEMBLEACCURACY[2.0]],PRIMEM[\"Greenwich\",0,ANGLEUNIT[\"degree\",0.0174532925199433]],CS[ellipsoidal,2],AXIS[\"geodetic latitude (Lat)\",north,ORDER[1],ANGLEUNIT[\"degree\",0.0174532925199433]],AXIS[\"geodetic longitude (Lon)\",east,ORDER[2],ANGLEUNIT[\"degree\",0.0174532925199433]],USAGE[SCOPE[\"Horizontal component of 3D system.\"],AREA[\"World.\"],BBOX[-90,-180,90,180]],ID[\"EPSG\",4326]]" },
   { { epsg, 4979 }, "https://epsg.io/4979.wkt2" },
   { {  ogc,   84 }, "OGC:CRS84" },
   { {  ogc,   84, h = 1 }, "OGC:CRS84h" },
   { {  ogc, 1534 }, "OGC:1534" },
   { {  ogc, 153456 }, "OGC:153456" }
]};

const String getCURIFromCRS(CRS crs)
{
   const String curi = crsIDToCURI[crs];
   return curi;
}

const String getWKT2FromCRS(CRS crs)
{
   const String wkt2 = crsIDToWKT2[crs];
   return wkt2;
}
