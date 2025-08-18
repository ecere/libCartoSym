public import IMPORT_STATIC "ecrt"
public import IMPORT_STATIC "SFGeometry"
public import IMPORT_STATIC "CQL2"
public import IMPORT_STATIC "CartoSym"

// For SFGeometry (although WKT implementation currently depends on libCQL2 and libCartoSym)
bool readWKTGeometry(Geometry geometry, const String fileName)
{
   bool result = false;
   if(fileName)
   {
      File f = FileOpen(fileName, read);
      if(f)
      {
         uintsize size = f.GetSize();
         String buffer = new byte[size + 1];
         if(buffer)
         {
            CQL2Expression cql2;
            f.Read(buffer, 1, size);
            buffer[size] = 0;
            cql2 = parseCQL2Expression(buffer);
            delete buffer;
            if(cql2)
            {
               CQL2Expression iCQL2 = convertToInternalCQL2(cql2);
               if(iCQL2)
               {
                  FieldValue val { };
                  CartoSymEvaluator evaluator { class(CartoSymEvaluator) };
#ifdef _DEBUG
                  CQL2ExpInstance inst =
                     iCQL2._class == class(CQL2ExpInstance) ? (CQL2ExpInstance)iCQL2 : null;
                  const String instType = inst && inst.instance && inst.instance._class ?
                     inst.instance._class.name : null;
#endif

                  iCQL2.compute(val, evaluator, preprocessing, null);
                  iCQL2.compute(val, evaluator, runtime, null);

                  if(val.type.type == blob && val.b)
                  {
                     /*const */Geometry * g = val.b;

                     if(g->type != none)
                     {
#ifdef _DEBUG
                        if(instType)
                           PrintLn($"Successfully parsed a WKT ", instType);
#endif
                        // TODO: Additional checks for Geometry types
                        {
                           // REVIEW: This ensures a deep copy;
                           //         The handling of subelements together with the CQL2 expressions
                           //         need to be reviewed.
                           bool owned = g->subElementsOwned;
                           g->subElementsOwned = true;
                           geometry.OnCopy(g);
                           g->subElementsOwned = owned;
                        }

                        result = true;
                     }
                  }
                  delete iCQL2;
               }
               delete cql2;
            }
         }
         delete f;
      }
   }
   return result;
}

bool writeWKTGeometry(const Geometry geometry, const String fileName)
{
   bool result = false;
   CQL2Expression cql2 = cql2FromGeometry(geometry, false);
   if(cql2)
   {
      File f = FileOpen(fileName, write);
      if(f)
      {
         cql2.print(f, 0, { strictCQL2 = true });
         result = true;
         delete f;
      }
      delete cql2;
   }
   return result;
}

bool readWKBGeometry(Geometry geometry, const String fileName)
{
   bool result = false;
   File f = FileOpen(fileName, read);
   if(f)
   {
      /*result = */readGeometryWKB(f, geometry);
      if(geometry.type != none)
      {
         geometry.subElementsOwned = true;
         result = true;
      }
      delete f;
   }
   return result;
}

bool writeWKBGeometry(const Geometry geometry, const String fileName)
{
   bool result = false;
   File f = FileOpen(fileName, write);
   if(f)
   {
      /*result = */writeGeometryWKB(f, geometry, null, null);
      result = true;
      delete f;
   }
   return result;
}

// For SFCollections:
bool readGeoJSONGeometry(Geometry geometry, const String fileName)
{
   return false;
}

bool writeGeoJSONGeometry(const Geometry geometry, const String fileName)
{
   return false;
}

bool convertGeometry(
   const String inputFile, const String inType,
   const String outputFile, const String outType)
{
   bool result = false;
   char inExt[MAX_EXTENSION], outExt[MAX_EXTENSION];
   Geometry geometry { };

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

   if(strcmpi(outType, "geojson") && strcmpi(outType, "json")
      && strcmpi(outType, "wkt") && strcmpi(outType, "wkb"))
   {
      PrintLn($"Unrecognized geometry output format");
      return false;
   }

   if(!strcmpi(inType, "geojson") || !strcmpi(inType, "json"))
   {
      if(!readGeoJSONGeometry(geometry, inputFile))
         PrintLn($"Failed to parse ", inputFile, $" as GeoJSON geometry");
   }
   else if(!strcmpi(inType, "wkt"))
   {
      if(!readWKTGeometry(geometry, inputFile))
         PrintLn($"Failed to parse ", inputFile, $" as Well-Known Text geometry");
   }
   else if(!strcmpi(inType, "wkb"))
   {
      if(!readWKBGeometry(geometry, inputFile))
         PrintLn($"Failed to parse ", inputFile, $" as Well-Known Binary geometry");
   }

   if(geometry.type != none)
   {
      if(!strcmpi(outType, "geojson") || !strcmpi(outType, "json"))
      {
         if(writeGeoJSONGeometry(geometry, outputFile))
            result = true;
         else
            PrintLn($"Failed to write geometry as GeoJSON");
      }
      else if(!strcmpi(outType, "wkt"))
      {
         if(writeWKTGeometry(geometry, outputFile))
            result = true;
         else
            PrintLn($"Failed to write geometry as Well-Known Text");
      }
      else if(!strcmpi(outType, "wkb"))
      {
         if(writeWKBGeometry(geometry, outputFile))
            result = true;
         else
            PrintLn($"Failed to write geometry as Well-Known Binary geometry");
      }
      geometry.OnFree();
   }
   return result;
}
