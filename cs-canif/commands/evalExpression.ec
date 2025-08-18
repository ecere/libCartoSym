public import IMPORT_STATIC "ecrt"
public import IMPORT_STATIC "CartoSym"

import "sldParser"
import "mbglParser"

import "convertFeatures"
import "convertExpression"

bool evaluateExpression(
   const String inputFile, const String inType,
   const String featuresFile, const String ftType,
   const String featureIDString, const String layerID)
{
   bool result = false;
   char inExt[MAX_EXTENSION], ftExt[MAX_EXTENSION];
   CQL2Expression e = null;

   if(!inType)
   {
      GetExtension(inputFile, inExt);
      inType = inExt;
   }
   if(!ftType && featuresFile)
   {
      GetExtension(featuresFile, ftExt);
      ftType = ftExt;
   }
   if(featuresFile && strcmpi(ftType, "geojson") && strcmpi(ftType, "wkbc"))
   {
      PrintLn($"Unrecognized features format");
      return false;
   }

   if(!strcmpi(inType, "cql2json") || !strcmpi(inType, "json"))
   {
      e = readCQL2JSON(inputFile);
      if(!e)
         PrintLn($"Failed to parse ", inputFile, $" as a CQL2-JSON expression");
   }
   else if(!strcmpi(inType, "cql2") || !strcmpi(inType, "cql2text"))
   {
      e = readCQL2Text(inputFile);
      if(!e)
         PrintLn($"Failed to parse ", inputFile, $" as a CQL2-Text expression");
   }

   if(e)
   {
      CQL2Expression iCQL2 = convertToInternalCQL2(e);
      FeatureCollection features = null;
      int64 featureID = -1;
      HashMap<int64, Map<String, FieldValue>> attributes = null;

      if(featuresFile)
      {
         if(!strcmpi(ftType, "geojson") || !strcmpi(ftType, "json"))
         {
            attributes = { };
            features = readGeoJSONFeatures(featuresFile, attributes);
            if(!features)
               PrintLn($"Failed to parse ", featuresFile, $" as GeoJSON features");
         }
         else if(!strcmpi(ftType, "wkbc"))
         {
            features = readWKBCFeatures(featuresFile);
            if(!features)
               PrintLn($"Failed to parse ", featuresFile, $" as Well-Known text Binary Collection features");
         }

         if(featureIDString)
         {
            featureID = strtoll(featureIDString, null, 0);
         }
      }

      if(iCQL2)
      {
         FieldValue val { };
         CartoSymEvaluator evaluator { class(CartoSymEvaluator) };
         CartoExpFlags flags;

         evaluator.setLayerID(layerID);
         evaluator.setFeatureID(featureID);
         evaluator.setAttribsMap(attributes);

         iCQL2.compute(val, evaluator, preprocessing, null);
         flags = (CartoExpFlags)iCQL2.compute(val, evaluator, runtime, null);

         if(flags.resolved)
         {
            String resolvedString;
            iCQL2 = simplifyResolved(val, iCQL2);
            resolvedString = iCQL2.toString(0);
            PrintLn(resolvedString);
            delete resolvedString;
            result = true;
         }
         else
            PrintLn("Unresolved expression (flags: ", flags, ")");
      }

      if(attributes)
         attributes.Free(), delete attributes;

      delete e;
   }
   return result;
}
