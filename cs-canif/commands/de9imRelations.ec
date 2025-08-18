public import IMPORT_STATIC "ecrt"
public import IMPORT_STATIC "SFGeometry"
public import IMPORT_STATIC "CQL2"
public import IMPORT_STATIC "DE9IM"
public import IMPORT_STATIC "CartoSym"

import "convertGeometry"

bool de9imRelations(
   const String geomAFile, const String geomAType,
   const String geomBFile, const String geomBType)
{
   bool result = false;
   char aExt[MAX_EXTENSION], bExt[MAX_EXTENSION];
   Geometry geomA { };
   Geometry geomB { };

   if(!geomAType)
   {
      GetExtension(geomAFile, aExt);
      geomAType = aExt;
   }
   if(!geomBType)
   {
      GetExtension(geomBFile, bExt);
      geomBType = bExt;
   }

   if(strcmpi(geomAType, "geojson") && strcmpi(geomAType, "json")
      && strcmpi(geomAType, "wkt") && strcmpi(geomAType, "wkb"))
   {
      PrintLn($"Unrecognized geometry A format");
      return false;
   }

   if(strcmpi(geomBType, "geojson") && strcmpi(geomBType, "json")
      && strcmpi(geomBType, "wkt") && strcmpi(geomBType, "wkb"))
   {
      PrintLn($"Unrecognized geometry A format");
      return false;
   }

   if(!strcmpi(geomAType, "geojson") || !strcmpi(geomAType, "json"))
   {
      if(!readGeoJSONGeometryFile(geomA, geomAFile))
         PrintLn($"Failed to parse ", geomAFile, $" as GeoJSON geometry");
   }
   else if(!strcmpi(geomAType, "wkt"))
   {
      if(!readWKTGeometry(geomA,geomAFile))
         PrintLn($"Failed to parse ", geomAFile, $" as Well-Known Text geometry");
   }
   else if(!strcmpi(geomAType, "wkb"))
   {
      if(!readWKBGeometry(geomA, geomAFile))
         PrintLn($"Failed to parse ", geomAFile, $" as Well-Known text Binary geometry");
   }

   if(!strcmpi(geomBType, "geojson") || !strcmpi(geomBType, "json"))
   {
      if(!readGeoJSONGeometryFile(geomB, geomBFile))
         PrintLn($"Failed to parse ", geomBFile, $" as GeoJSON geometry");
   }
   else if(!strcmpi(geomBType, "wkt"))
   {
      if(!readWKTGeometry(geomB,geomBFile))
         PrintLn($"Failed to parse ", geomBFile, $" as Well-Known Text geometry");
   }
   else if(!strcmpi(geomBType, "wkb"))
   {
      if(!readWKBGeometry(geomB, geomBFile))
         PrintLn($"Failed to parse ", geomBFile, $" as Well-Known text Binary geometry");
   }

   if(geomA.type != none && geomB.type != none)
   {
      DE9IM de9im, flipped;
      char aType[20];
      int i, l;

      aType[0] = 0;
      geomA.type.OnGetString(aType, null, null);
      l = strlen(aType);

      geometryRelate(geomA, geomB, de9im);
      flipped.flip(de9im);

      PrintLn("");
      PrintLn($"Dimensionally Extended 9 Intersection Matrix for geometries A and B:");
      PrintLn("");

      PrintLn("                      ", geomB.type, " B");
      PrintLn("");
      PrintLn("                           I B E");
      PrintLn("                           -----");
      PrintLn("                       I | ", de9im.m[0], " ", de9im.m[1], " ", de9im.m[2]);
      Print(aType, " A");
      for(i = 0; i < 21 - l; i++)
         Print(" ");
      PrintLn("B | ", de9im.m[3], " ", de9im.m[4], " ", de9im.m[5]);
      PrintLn("                       E | ", de9im.m[6], " ", de9im.m[7], " ", de9im.m[8]);

      PrintLn("");

      PrintLn("A RELATE     B: ", de9im);
      PrintLn("A INTERSECTS B: ", de9im.intersects());
      PrintLn("A DISJOINT   B: ", de9im.disjoint());
      PrintLn("A EQUALS     B: ", de9im.equals());
      PrintLn("A CONTAINS   B: ", de9im.contains());
      PrintLn("A WITHIN     B: ", de9im.within());
      PrintLn("A TOUCHES    B: ", de9im.touches());
      PrintLn("A COVERS     B: ", de9im.covers());
      PrintLn("A COVEREDBY  B: ", de9im.coveredBy());
      PrintLn("A OVERLAPS   B: ", de9im.overlaps(geomA.dimension, geomB.dimension));
      PrintLn("A CROSSES    B: ", de9im.crosses(geomA.dimension, geomB.dimension));

      PrintLn("");
      PrintLn("B RELATE     A: ", flipped);
      PrintLn("B INTERSECTS A: ", flipped.intersects());
      PrintLn("B DISJOINT   A: ", flipped.disjoint());
      PrintLn("B EQUALS     A: ", flipped.equals());
      PrintLn("B CONTAINS   A: ", flipped.contains());
      PrintLn("B WITHIN     A: ", flipped.within());
      PrintLn("B TOUCHES    A: ", flipped.touches());
      PrintLn("B COVERS     A: ", flipped.covers());
      PrintLn("B COVEREDBY  A: ", flipped.coveredBy());
      PrintLn("B OVERLAPS   A: ", flipped.overlaps(geomB.dimension, geomA.dimension));
      PrintLn("B CROSSES    A: ", flipped.crosses(geomB.dimension, geomA.dimension));
   }
   geomA.OnFree();
   geomB.OnFree();
   return result;
}
