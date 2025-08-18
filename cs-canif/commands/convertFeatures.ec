public import IMPORT_STATIC "ecrt"
public import IMPORT_STATIC "SFGeometry"
public import IMPORT_STATIC "CQL2"
public import IMPORT_STATIC "CartoSym"

FeatureCollection readWKBCFeatures(const String fileName)
{
   FeatureCollection result = null;
   if(fileName)
   {
      File f = FileOpen(fileName, read);
      if(f)
      {
         result = readWKBCollection(f);
         delete f;
      }
   }
   return result;
}

bool writeWKBCFeatures(FeatureCollection features, const String fileName)
{
   bool result = false;
   if(features)
   {
      File f = FileOpen(fileName, write);
      if(f)
      {
         result = writeWKBCollection(features, f);
         delete f;
      }
   }
   return result;
}

FeatureCollection readGeoJSONFeatures(const String fileName,
   HashMap<int64, Map<String, FieldValue>> attributes)
{
   FeatureCollection result = null;
   if(fileName)
   {
      File f = FileOpen(fileName, read);
      if(f)
      {
         result = loadGeoJSON(f, attributes, false);
         delete f;
      }
   }
   return result;
}

bool writeGeoJSONFeatures(FeatureCollection features, const String fileName)
{
   bool result = false;
   File f = FileOpen(fileName, write);
   if(f)
   {
      result = writeGeoJSON(features, f, null, null, null);
      delete f;
   }
   return result;
}

bool convertFeatures(
   const String inputFile, const String inType,
   const String outputFile, const String outType)
{
   bool result = false;
   char inExt[MAX_EXTENSION], outExt[MAX_EXTENSION];
   FeatureCollection features = null;

   if(!inType)
   {
      GetExtension(inputFile, inExt);
      inType = inExt;
   }
   if(!outType)
   {
      GetExtension(outputFile, outExt);
      outType = outExt;
   }

   if(strcmpi(outType, "geojson") && strcmpi(outType, "wkbc"))
   {
      PrintLn($"Unrecognized features output format");
      return false;
   }

   if(!strcmpi(inType, "geojson") || !strcmpi(inType, "json"))
   {
      features = readGeoJSONFeatures(inputFile, null);
      if(!features)
         PrintLn($"Failed to parse ", inputFile, $" as GeoJSON features");
   }
   else if(!strcmpi(inType, "wkbc"))
   {
      features = readWKBCFeatures(inputFile);
      if(!features)
         PrintLn($"Failed to parse ", inputFile, $" as Well-Known text Binary Collection features");
   }

   if(features)
   {
      if(!strcmpi(outType, "geojson") || !strcmpi(outType, "json"))
      {
         if(writeGeoJSONFeatures(features, outputFile))
            result = true;
         else
            PrintLn($"Failed to write features as GeoJSON");
      }
      else if(!strcmpi(outType, "wkbc"))
      {
         if(writeWKBCFeatures(features, outputFile))
            result = true;
         else
            PrintLn($"Failed to write geometry as Well-Known text Binary Collection");
      }
      delete features;
   }
   return result;
}
