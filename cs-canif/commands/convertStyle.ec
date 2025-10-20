public import IMPORT_STATIC "ecrt"
public import IMPORT_STATIC "CartoSym"

import "sldWriter"
import "sldParser"

import "mbglParser"
import "mbglWriter"

bool convertStyle(
   const String inputFile, const String inType,
   const String outputFile, const String outType,
   Map<String, FeatureDataType> typeMap, const String layerID)
{
   bool result = false;
   char inExt[MAX_EXTENSION], outExt[MAX_EXTENSION];
   CartoStyle style = null;

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

   if(!strcmpi(outType, "csjson"))
   {
      PrintLn($"CartoSym-JSON output not yet implemented");
      return false;
   }
   else if(strcmpi(outType, "cscss") && strcmpi(outType, "json")
      && strcmpi(outType, "mbgl") && strcmpi(outType, "sld"))
   {
      PrintLn($"Unrecognized style output format");
      return false;
   }

   if(!strcmpi(inType, "cscss"))
   {
      style = CartoStyle::load(inputFile);
      if(!style)
         PrintLn($"Failed to parse ", inputFile, $" as CartoSym-CSS style");
   }
   else if(!strcmpi(inType, "csjson"))
   {
      PrintLn($"CartoSym-JSON parsing not yet implemented");
   }
   else if(!strcmpi(inType, "json") || !strcmpi(inType, "mbgl"))
   {
      File f = FileOpen(inputFile, read);
      if(f)
      {
         style = loadMapboxgl(f, false, null);
         if(!style)
            PrintLn($"Failed to parse ", inputFile, $" as Mapbox GL / MapLibre style");
         delete f;
      }
   }
   else if(!strcmpi(inType, "sld"))
   {
      style = loadSLD(inputFile, null, null);
      if(!style)
         PrintLn($"Failed to parse ", inputFile, $" as SLD/SE style");
   }

   if(style)
   {
      if(layerID)
      {
         CartoSymEvaluator evaluator { class(CartoSymEvaluator) };
         CartoStyle boundStyle;

         evaluator.setFeatureID(-1);
         evaluator.setLayerID(layerID);

         boundStyle = style.bind(evaluator, class(CartoSymbolizer), layerID);
         // boundStyle.resolve(evaluator, class(CartoSymbolizer));

         delete style;
         style = boundStyle;
      }

      if(!strcmpi(outType, "cscss"))
      {
         if(style.write(outputFile))
            result = true;
         else
            PrintLn($"Failed to write style as CartoSym-CSS");
      }
      else if(!strcmpi(outType, "sld"))
      {
         if(writeSLD(style, outputFile, typeMap, 0, null))
            result = true;
         else
            PrintLn($"Failed to write style as SLD/SE");
      }
      else if(!strcmpi(outType, "json"))
      {
         if(writeMBGL(style, outputFile, null, null, null, null, false, false, false))
            result = true;
         else
            PrintLn($"Failed to write style as Mapbox GL / MapLibre style");
      }
      delete style;
   }
   return result;
}
