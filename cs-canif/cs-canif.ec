public import IMPORT_STATIC "ecrt"
public import IMPORT_STATIC "CartoSym"

private:

import "convertStyle"
import "convertGeometry"

static void showSyntax()
{
   PrintLn(
     $"CartoSym Canif, a Cartographic Symbology, CQL2 and Simple Features transcoder / multi-purpose utility\n"
      "Copyright (c) 2014-2025 Ecere Corporation\n"
      "Syntax:\n"
      "   cs-canif <command> [options] <arguments>\n"
      "\n"
      "Supported cartographic symbology encodings:\n"
      "   .cscss (CartoSym-CSS), .sld (SLD/SE), .json (Mapbox GL / Map Libre)\n"
      "\n"
      "Supported geometry encodings:\n"
      "   .wkt (Well-Known Text), .wkb (Well-Known text Binary)\n"
      "\n"
      "Commands:\n"
      "   convert <input file> <output file>\n"
      "      Transcode cartographic symbology style sheet, geometry, feature collections or expressions\n"
      "\n"
//      "Options:\n"
      );
}

enum CSCanifCommand
{
   convert = 1, de9im, eval
};

public class CSCanif : Application
{
   void Main()
   {
      CSCanifCommand command = 0;
      Map<String, const String> options = null;
      int a;
      const String currentOption = null;
      bool syntaxError = false;
      int cmdArg = 0;
      // Command arguments
      const String inputFile = null, outputFile = null;
      Map<String, FeatureDataType> typeMap = null;

      for(a = 1; !syntaxError && a < argc; a++)
      {
         const char * arg = argv[a];
         if(arg[0] == '-' && !strchr(arg, ',')) // Avoid confusion with negative coordinates
         {
            if(!options) options = {};
            currentOption = arg + 1;

            // Boolean options
            /*
            if(!strcmpi(currentOption, "..."))
               options[currentOption] = "true", currentOption = null;
            */
         }
         else if(currentOption)
         {
            options[currentOption] = arg;
            currentOption = null;
         }
         else
         {
            switch(cmdArg)
            {
               case 0:
                  // Command
                  syntaxError = !command.OnGetDataFromString(arg);
                  break;
               case 1:
                  // First command argument
                  switch(command)
                  {
                     case convert:
                        inputFile = arg;
                        break;
                     default: syntaxError = true; break;
                  }
                  break;
               case 2:
                  // Second command argument
                  switch(command)
                  {
                     case convert:
                        outputFile = arg;
                        break;
                     default: syntaxError = true; break;
                  }
                  break;
               default: syntaxError = true; break;
            }
            cmdArg++;
         }
      }
      if(!command) syntaxError = true;

      if(syntaxError)
      {
         showSyntax();
         exitCode = 1;
      }
      else
      {
         if(!exitCode)
            switch(command)
            {
               case convert:
               {
                  bool result = false;
                  if(inputFile && outputFile)
                  {
                     char ext[MAX_EXTENSION], outExt[MAX_EXTENSION];

                     GetExtension(inputFile, ext);
                     GetExtension(outputFile, outExt);

                     if(!strcmpi(ext, "csjson") || !strcmpi(ext, "cscss") ||
                        !strcmpi(ext, "json") || !strcmpi(ext, "mbgl") ||
                        !strcmpi(ext, "sld"))
                        result = convertStyle(inputFile, null, outputFile, null, typeMap);
                     else if(!strcmpi(ext, "wkt") || !strcmpi(ext, "wkb") ||
                        (!strcmpi(ext, "geojson") &&
                           (!strcmpi(outExt, "wkbc") || !strcmpi(outExt, "geojson"))))
                        result = convertGeometry(inputFile, null, outputFile, null);
                     /*
                     else if(!strcmpi(ext, "geojson") || !strcmpi(ext, "wkbc"))
                        result = convertFeatureCollection(inputFile, null, outputFile, null);
                     else if(!strcmpi(ext, "cql2") || !strcmpi(ext, "cql2json") || !strcmpi(ext, "cql2text"))
                        result = convertCQL2Expression(inputFile, null, outputFile, null);
                     */
                  }
                  else
                     showSyntax();

                  if(!result)
                     exitCode = 1;
                  break;
               }
            }
      }
      delete options;
   }
}
