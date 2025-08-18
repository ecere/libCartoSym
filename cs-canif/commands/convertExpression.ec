public import IMPORT_STATIC "ecrt"
public import IMPORT_STATIC "SFGeometry"
public import IMPORT_STATIC "CQL2"
public import IMPORT_STATIC "CartoSym"

CQL2Expression readCQL2Text(const String fileName)
{
   CQL2Expression result = null;
   if(fileName)
   {
      File f = FileOpen(fileName, read);
      if(f)
      {
         uint64 size = f.GetSize();
         String string = new char[size + 1];
         f.Read(string, 1, size);
         if(string)
         {
            string[size] = 0;
            result = parseCQL2Expression(string);
            delete string;
         }
         delete f;
      }
   }
   return result;
}

bool writeCQL2Text(CQL2Expression e, const String fileName)
{
   bool result = false;
   if(e)
   {
      File f = FileOpen(fileName, write);
      if(f)
      {
         CQL2Expression n = normalizeCQL2(e);
         if(n)
         {
            n.print(f, 0, { strictCQL2 = true });
            result = true;
         }
         delete n;
         delete f;
      }
   }
   return result;
}

CQL2Expression readCQL2JSON(const String fileName)
{
   CQL2Expression result = null;
   if(fileName)
   {
      File f = FileOpen(fileName, read);
      if(f)
      {
         result = parseCQL2JSONExpressionFile(f);
         delete f;
      }
   }
   return result;
}

bool writeCQL2JSON(CQL2Expression e, const String fileName)
{
   bool result = false;
   PrintLn("CQL2-JSON expression output not yet implemented");
   /*
   File f = FileOpen(fileName, write);
   if(f)
   {
      FieldValue json { };
      e.toCQL2JSON(json);
      result = WriteJSONObject(f, class(Fieldvalue), json, 0);
      json.OnFree();
      delete f;
   }
   */
   return result;
}

bool convertExpression(
   const String inputFile, const String inType,
   const String outputFile, const String outType)
{
   bool result = false;
   char inExt[MAX_EXTENSION], outExt[MAX_EXTENSION];
   CQL2Expression e = null;

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

   if(strcmpi(outType, "json") && strcmpi(outType, "cql2json") &&
      strcmpi(outType, "cql2") && strcmpi(outType, "cql2text"))
   {
      PrintLn($"Unrecognized expression output format");
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
      if(!strcmpi(outType, "json") || !strcmpi(outType, "cql2json"))
      {
         if(writeCQL2JSON(e, outputFile))
            result = true;
         else
            PrintLn($"Failed to write expression as CQL2-JSON");
      }
      else if(!strcmpi(outType, "cql2") || !strcmpi(outType, "cql2text"))
      {
         if(writeCQL2Text(e, outputFile))
            result = true;
         else
            PrintLn($"Failed to write expression as CQL2-Text");
      }
      delete e;
   }
   return result;
}
