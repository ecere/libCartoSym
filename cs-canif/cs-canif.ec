public import IMPORT_STATIC "ecrt"
public import IMPORT_STATIC "CartoSym"

private:

import "convertStyle"

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
      "Commands:\n"
      "   convert <input file> <output file>\n"
      "      Transcode cartographic symbology style sheet from one encoding to another\n"
      "\n"
//      "Options:\n"
      );
}

enum CSCanifCommand
{
   convert = 1
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
                  result = convertStyle(inputFile, null, outputFile, null, typeMap);

                  if(!result)
                     exitCode = 1;
                  break;
               }
            }
      }
      delete options;
   }
}
