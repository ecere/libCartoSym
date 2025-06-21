public import IMPORT_STATIC "ecrt"
public import IMPORT_STATIC "CartoSym"

private:

import "testingFramework"

import "sldWriter"
import "sldParser"

import "mbglParser"
import "mbglWriter"

/* static */ struct CSTestCase // NOTE: Builds but crashes if static
{
   const String id;
   const String inputFile;
   Map<String, FeatureDataType> typeMap;
};

static Array<CSTestCase> testCases
{ [
   {
      id = "1-core",
      inputFile = "../cscss/1-core.cscss"
   },
   {
      id = "2-vector-polygon",
      inputFile = "../cscss/2-vector-polygon.cscss"
   },
   {
      id = "3-vector-line",
      inputFile = "../cscss/3-vector-line.cscss"
   },
   {
      id = "4-vector-point",
      inputFile = "../cscss/4-vector-point.cscss"
   },
   {
      id = "5-coverage-dem",
      inputFile = "../cscss/5-coverage-dem.cscss",
      typeMap = { [ { "Elevation", { coverage } } ] }
   },
   {
      id = "6-coverage-sentinel2",
      inputFile = "../cscss/6-coverage-sentinel2.cscss"
   },
   {
      id = "7-coverage-ndvi",
      inputFile = "../cscss/7-coverage-ndvi.cscss"
   },
   {
      id = "8-coverage-hillshading",
      inputFile = "../cscss/8-coverage-hillshading.cscss"
   },
   {
      id = "9-coverage-hillshading-opacity",
      inputFile = "../cscss/9-coverage-hillshading-opacity.cscss"
   },
   {
      id = "10-natural_earth_economies",
      inputFile = "../cscss/10-natural_earth_economies.cscss"
   },
   {
      id = "11-natural_earth_continents",
      inputFile = "../cscss/11-natural_earth_continents.cscss"
   },
   {
      id = "mbox-rbt-job",
      inputFile = "../mbgl/rbt-jog.json"
   }
] };

public class TestCartoSymParsing : eTest
{
   void testStyle(const CSTestCase test)
   {
      char ext[MAX_EXTENSION];

      GetExtension(test.inputFile, ext);

      if(!strcmpi(ext, "cscss"))
      {
         CartoStyle style = CartoStyle::load(test.inputFile);

         if(style)
         {
            char fileName[MAX_LOCATION];

            sprintf(fileName, "%s/%s.cscss", outputPath, test.id);
            if(style.write(fileName))
            {
               sprintf(fileName, "%s/%s.sld", outputPath, test.id);

               if(writeSLD(style, fileName, test.typeMap, 0, null))
               {
                  CartoStyle sld = loadSLD(fileName, null, null);

                  if(sld)
                  {
                     sprintf(fileName, "%s/%s-fromSLD.cscss", outputPath, test.id);

                     if(sld.write(fileName))
                     {
                        // TODO: Gold files comparison
                        pass(test.id, test.inputFile);
                     }
                     else
                        fail(test.id, fileName, "of failure to write CartoSym-CSS style transcoded back from SLD/SE");

                     delete sld;
                  }
                  else
                     fail(test.id, fileName, "of failure to load transcoded SLD/SE style");
               }
               else
                  fail(test.id, fileName, "of failure to output transcoded SLD/SE style");
            }
            else
               fail(test.id, fileName, "of failure to write style");
            delete style;
         }
         else
            fail(test.id, test.inputFile, "of failure to load style");
      }
      else if(!strcmpi(ext, "json"))
      {
         // Mapbox styles
         File f = FileOpen(test.inputFile, read);
         if(f)
         {
            CartoStyle style = loadMapboxgl(f, false, null);

            if(style)
            {
               char fileName[MAX_LOCATION];

               sprintf(fileName, "%s/%s.cscss", outputPath, test.id);
               if(style.write(fileName))
               {
                  style.write(fileName);

                  //sprintf(fileName, "%s/%s.sld", outputPath, test.id);
                  //writeSLD(style, fileName, test.typeMap, 0, null);

                  sprintf(fileName, "%s/%s.json", outputPath, test.id);

                  if(writeMBGL(style, fileName, null, null, null, null, false, false, false))
                  {
                     // TODO: Gold files comparison
                     pass(test.id, test.inputFile);
                  }
                  else
                     fail(test.id, fileName, "of failure to write style transcoded back to Mapbox");
               }
               else
                  fail(test.id, fileName, "of failure to write CartoSym-CSS style transcoded from Mapbox style");
            }
            else
               fail(test.id, test.inputFile, "of failure to load Mapbox style");
            delete style;
         }
         else
            fail(test.id, test.inputFile, "of failure to open Mapbox style");
      }
   }

   bool prepareTests()
   {
      for(t : testCases)
         if(FileExists(t.inputFile) != { isFile = true } )
         {
            PrintLn("Error opening input file ", t.inputFile, " for test ", t.id);
            return false;
         }

      if(!MakeDir(outputPath))
      {
         PrintLn("Error creating output directory ", outputPath);
         return false;
      }
      return true;
   }

   void executeTests()
   {
      for(t : testCases)
         testStyle(t);
   }

   void cleanTests()
   {

   }
}
