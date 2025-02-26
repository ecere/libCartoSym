public import IMPORT_STATIC "ecere"
public import IMPORT_STATIC "EDA"   // For FieldValue

import "expressions"
#include <math.h> // NOTE: remove this once interpolate function moved

default:
__attribute__((unused)) static void UnusedFunction()
{
   int a = 0;
   a.OnCopy(0);
}
extern int __ecereVMethodID_class_OnCopy;

private:

enum ECCSSFunctionIndex : int
{
   unresolved = -1,
   // Text manipulation
   strupr = 1,
   strlwr,
   strtod,
   subst,
   format,
   concatenate,
   pow,
   log,
   like,
   casei,
   accenti,
   interpolate,
   map
};

static int strncpymax(String output, const String input, int count, int max)
{
   int copied = Min(count, Max(0, max - 1));
   if(copied)
   {
      memcpy(output, input, copied);
      output[copied] = 0;
   }
   return copied;
}

static String formatValues(const String format, int numArgs, const FieldValue * values)
{
   char output[1024];
   int totalLen = 0;
   int formatLen = format ? strlen(format) : 0;
   const String start = format;
   int arg = 0;
   const FieldValue * value = &values[arg];

   output[0] = '\0';

   while(true)
   {
      String nextArg = strchr(start, '%');
      if(nextArg)
      {
         if(nextArg[1] == '%')
         {
            totalLen += strncpymax(output + totalLen, start, (int)(nextArg+1 - start), sizeof(output) - totalLen);
            start = nextArg + 2;
         }
         else
         {
            bool valid = true;
            FieldType type = integer;
            String s = nextArg + 1;
            bool argWidth = false, argPrecision = false;
            int width = 0, precision = 0;

            totalLen += strncpymax(output + totalLen, start, (int)(nextArg - start), sizeof(output) - totalLen);

            while(true)
            {
               bool done = false;
               switch(*s)
               {
                  case '-': case '+': case '#': case ' ': case '0':
                     s++;
                     break;
                  default:
                     done = true;
               }
               if(done) break;
            }
            if(*s == '*')
            {
               argWidth = true;
               if(arg < numArgs)
               {
                  switch(value->type.type)
                  {
                     default:
                     case integer: width = (int)value->i; break;
                     case text:    width = strtol(value->s, null, 0); break;
                     case real:    width = (int)value->r; break;
                  }
                  value = &values[++arg];
               }
            }
            else
               strtol(s, &s, 10);

            if(*s == '.')
            {
               s++;
               if(*s == '*')
               {
                  argPrecision = true;
                  if(arg < numArgs)
                  {
                     switch(value->type.type)
                     {
                        default:
                        case integer: precision = (int)value->i; break;
                        case text:    precision = strtol(value->s, null, 0); break;
                        case real:    precision = (int)value->r; break;
                     }
                     value = &values[++arg];
                  }
               }
               else
                  strtol(s, &s, 10);
            }

            switch(*s)
            {
               case 'c': case 'd': case 'i': case 'o': case 'u': case 'x': case 'X':
                  type = integer;
                  s++;
                  break;
               case 'f': case 'F': case 'e': case 'E': case 'g': case 'G':
                  type = real;
                  s++;
                  break;
               case 's':
                  type = text;
                  s++;
                  break;
               default:
                  valid = false;
            }
            start = s;

            if(valid && arg < numArgs)
            {
               char argFormat[256];
               memcpy(argFormat, nextArg, (int)(s - nextArg));
               argFormat[s - nextArg] = '\0';

               if(type == text && value->type.type == text && argFormat[0] == '%' && argFormat[1] == 's')
               {
                  if(value->s)
                     totalLen += strncpymax(output + totalLen, value->s, strlen(value->s), sizeof(output) - totalLen);
               }
               else
               {
                  char argString[1024];
                  int numArgs = 0;
                  switch(type)
                  {
                     case integer:
                     {
                        if(value->type.type != nil)
                        {
                           int intValue;
                           switch(value->type.type)
                           {
                              default:
                              case integer: intValue = (int)value->i; break;
                              case real:    intValue = (int)value->r; break;
                              case text:    intValue = value->s ? strtol(value->s, null, 0) : 0; break;
                           }
                           if(argWidth && argPrecision)
                              numArgs = sprintf(argString, argFormat, width, precision, intValue);
                           else if(argWidth)
                              numArgs = sprintf(argString, argFormat, width, intValue);
                           else if(argPrecision)
                              numArgs = sprintf(argString, argFormat, precision, intValue);
                           else
                              numArgs = sprintf(argString, argFormat, intValue);
                        }
                        else
                           argString[0] = '\0';
                        break;
                     }
                     case real:
                     {
                        if(value->type.type != nil)
                        {
                           double doubleValue;
                           switch(value->type.type)
                           {
                              default:
                              case integer: doubleValue = (double)value->i; break;
                              case real:    doubleValue = value->r; break;
                              case text:    doubleValue = value->s ? strtod(value->s, null) : 0; break;
                           }
                           if(argWidth && argPrecision)
                              numArgs = sprintf(argString, argFormat, width, precision, doubleValue);
                           else if(argWidth)
                              numArgs = sprintf(argString, argFormat, width, doubleValue);
                           else if(argPrecision)
                              numArgs = sprintf(argString, argFormat, precision, doubleValue);
                           else
                              numArgs = sprintf(argString, argFormat, doubleValue);
                        }
                        else
                           argString[0] = '\0';
                        break;
                     }
                     case text:
                     {
                        char temp[100];
                        const String strValue;
                        switch(value->type.type)
                        {
                           default:
                           case integer: strValue = (sprintf(temp, FORMAT64D, value->i), temp); break;
                           case real:    strValue = value->r.OnGetString(temp, null, null); break;
                           case text:    strValue = value->s ? value->s : ""; break;
                           case nil:     strValue = ""; break;
                        }
                        if(argWidth && argPrecision)
                           numArgs = sprintf(argString, argFormat, width, precision, strValue);
                        else if(argWidth)
                           numArgs = sprintf(argString, argFormat, width, strValue);
                        else if(argPrecision)
                           numArgs = sprintf(argString, argFormat, precision, strValue);
                        else
                           numArgs = sprintf(argString, argFormat, strValue);
                        break;
                     }
                  }
                  if(numArgs > 0)
                     totalLen += strncpymax(output + totalLen, argString, numArgs, sizeof(output) - totalLen);
               }

               value = &values[++arg];
            }
         }
      }
      else
      {
         totalLen += strncpymax(output + totalLen, start, (int)(formatLen - (start - format)), sizeof(output) - totalLen);
         break;
      }
   }
   return CopyString(output);
}

// For extending ECCSS with custom identifiers and styling properties
public struct ECCSSEvaluator
{
   subclass(ECCSSEvaluator) evaluatorClass;        // This is effectively adding a virtual function table...

   virtual Class resolve(const CartoSymIdentifier identifier, bool isFunction, int * id, ExpFlags * flags)
   {
      Class expType = null;
      if(isFunction)
      {
         ECCSSFunctionIndex fnIndex = unresolved;

         if(fnIndex.OnGetDataFromString(identifier.string))
         {
            *id = fnIndex;
            expType = class(GlobalFunction);
            flags->resolved = true;
         }
         else
            *id = ECCSSFunctionIndex::unresolved;
      }
      return expType;
   }
   virtual void compute(int id, const CartoSymIdentifier identifier, bool isFunction, FieldValue value, ExpFlags * flags)
   {
      if(isFunction)
      {
         if(id != -1)
         {
            value = { type = { integer }, i = id };
            flags->resolved = true;
         }
      }
   }
   virtual void evaluateMember(DataMember prop, CartoSymExpression exp, const FieldValue parentVal, FieldValue value, ExpFlags * flags);
   virtual Class resolveFunction(const FieldValue e, CartoSymExpList args, ExpFlags * flags, Class destType)
   {
      Class expType = null;

      if(e.type.type == integer)
      {
         ECCSSFunctionIndex fnIndex = (ECCSSFunctionIndex)e.i;
         switch(fnIndex)
         {
            case strlwr:
            case strupr:
            {
               if(args.list.count >= 1) args[0].destType = class(String);
               expType = class(String);
               break;
            }
            case subst:
            {
               if(args.list.count >= 1) args[0].destType = class(String);
               if(args.list.count >= 2) args[1].destType = class(String);
               if(args.list.count >= 3) args[2].destType = class(String);
               expType = class(String);
               break;
            }
            case format:
            {
               if(args.list.count >= 1) args[0].destType = class(String);
               expType = class(String);
               break;
            }
            case concatenate:
            {
               if(args.list.count >= 1) args[0].destType = class(String);
               expType = class(String);
               break;
            }
            case pow:
            {
               if(args.list.count >= 1) args[0].destType = class(double);
               if(args.list.count >= 2) args[1].destType = class(double);
               expType = class(double);
               break;
            }
            case log:
            {
               if(args.list.count >= 1) args[0].destType = class(double);
               // NOTE: With 2 arguments, the first argument is understood as the base
               if(args.list.count >= 2) args[1].destType = class(double);
               expType = class(double);
               break;
            }
            case strtod:
            {
               if(args.list.count >= 1) args[0].destType = class(double);
               // NOTE: We could also support 2 arguments, with first argument being base in that case?
               // if(args.list.count >= 2) args[1].destType = class(double);
               expType = class(double);
               break;
            }
            case like:
            {
               if(args.list.count >= 1) args[0].destType = class(String);
               if(args.list.count >= 2) args[1].destType = class(String);
               expType = class(bool);
               break;
            }
            case accenti:
            case casei:
            {
               if(args.list.count == 1) args[0].destType = class(String);
               expType = class(String);
               break;
            }
            case interpolate:
            {
               if(args.list.count > 1) args[0].destType = class(String);
               if(destType && args.list.count >= 4)
               {
                  int i;
                  args[1].destType = class(double);
                  for(i = 2; i < args.list.count; i++)
                  {
                     if(i & 1)
                        args[i].destType = destType;
                     else
                        args[i].destType = class(double);
                  }
                  expType = destType;
               }
               break;
            }
            case map:
            {
               if(destType && args.list.count >= 4)
               {
                  int i, count = args.list.count;

                  args[0].destType = class(int); //double);
                  for(i = 1; i < count; i++)
                  {
                     if((i & 1) || i == count-1)
                        args[i].destType = class(int);//double);
                     else
                        args[i].destType = destType;
                  }
                  expType = destType;
               }
               break;
            }
         }
      }
      return expType;
   }

   virtual Class computeFunction(FieldValue value, const FieldValue e, const FieldValue * args, int numArgs, CartoSymExpList arguments, ExpFlags * flags)
   {
      Class expType = null;
      value = { { nil } };

      if(e.type.type == integer)
      {
         ECCSSFunctionIndex fnIndex = (ECCSSFunctionIndex)e.i;
         switch(fnIndex)
         {
            case strlwr:
            case strupr:
            {
               if(numArgs >= 1 && args[0].type.type == text)
               {
                  value.type = { type = text, mustFree = true };
                  value.s = CopyString(args[0].s);
                  if(fnIndex == strlwr)
                     strlwr(value.s);
                  else
                     strupr(value.s);
                  expType = class(String);
               }
               break;
            }
            case subst:
            {
               if(numArgs >= 3 && args[0].type.type == text && args[1].type.type == text && args[2].type.type == text)
               {
                  String n = SearchString(args[0].s, 0, args[1].s, false, false);
                  if(n)
                  {
                     int len = strlen(args[0].s);
                     int startLen = (uint)(n - args[0].s);
                     int replacedLen = strlen(args[1].s);
                     int replacingLen = strlen(args[2].s);
                     int remainingLen = len - startLen - replacedLen;
                     value.s = new char[startLen + replacingLen + remainingLen + 1];
                     memcpy(value.s, args[0].s, startLen);
                     memcpy(value.s + startLen, args[2].s, replacingLen);
                     memcpy(value.s + startLen + replacingLen, args[0].s + startLen + replacedLen, remainingLen);
                     value.s[startLen + replacingLen] = 0;
                  }
                  else
                     value.s = CopyString(args[0].s);
                  value.type = { text, true };
                  expType = class(String);
               }
               break;
            }
            case format:
            {
               if(numArgs >= 1 && args[0].type.type == text)
               {
                  value.type = { text, true };
                  value.s = formatValues(args[0].s, numArgs-1, &args[1]);
                  expType = class(String);
               }
               break;
            }
            case concatenate:
            {
               if(numArgs >= 1)
               {
                  int i;
                  char newStr[MAX_LOCATION];
                  newStr[MAX_LOCATION-1] = '\0';
                  newStr[0] = 0;
                  value.type = { text, true };
                  for(i = 0; i < numArgs; i++)
                  {
                     if(args[i].type.type == text)
                        strcat(newStr, args[i].s);
                     else
                     {
                        switch(args[i].type.type)
                        {
                           case integer: strcatf(newStr,"%d",args[i].i);break;
                           case real: strcatf(newStr, "%f", args[i].r);break;
                        }
                     }
                  }
                  value.s = CopyString(newStr);
               }
               break;
            }
            case pow:
            {
               if(numArgs == 2 &&
                  (args[0].type.type == integer || args[0].type.type == real) &&
                  (args[1].type.type == integer || args[1].type.type == real))
               {
                  value.type = { real };
                  value.r = pow(
                     args[0].type.type == integer ? (double)args[0].i : args[0].r,
                     args[1].type.type == integer ? (double)args[1].i : args[1].r);
                  expType = class(double);
               }
               break;
            }
            case log:
            {
               if((numArgs == 1 || numArgs == 2) &&
                  (args[0].type.type == integer || args[0].type.type == real) &&
                  (numArgs == 1 || (args[1].type.type == integer || args[1].type.type == real)))
               {
                  value.type = { real };
                  if(numArgs == 1)
                     value.r = log(args[0].type.type == integer ? (double)args[0].i : args[0].r);
                  else
                     value.r =
                        log(args[1].type.type == integer ? (double)args[1].i : args[1].r) /
                        log(args[0].type.type == integer ? (double)args[0].i : args[0].r);
               }
               break;
            }
            case like:
            {
               if(numArgs >= 2 && args[0].type.type == text && args[1].type.type == text)
               {
                  value.type = { type = integer/*, format = boolean*/ };
                  value.i = StringLikePattern(args[0].s, args[1].s);
                  expType = class(bool);
               }
               break;
            }
            case casei:
            {
               if(numArgs == 1 && args[0].type.type == text)
               {
                  value.type = { text, true };
                  value.s = casei(args[0].s);
                  expType = class(String);
               }
               break;
            }
            case accenti:
            {
               if(numArgs == 1 && args[0].type.type == text)
               {
                  value.type = { text, true };
                  value.s = accenti(args[0].s);
                  expType = class(String);
               }
               break;
            }
            case interpolate:
            {
               if(numArgs >= 5 && args[0].type.type == text)
               {
                  // NOTE: may move this to a function somewhere
                  // basedon : https://stackoverflow.com/questions/13488957/interpolate-from-one-color-to-another
                  bool isExponential = !strcmp(args[0].s, "exponential");
                  double base = isExponential ?
                     (args[numArgs-1].type.type == integer ? (double)args[numArgs-1].i : args[numArgs-1].r) : 1;
                  double input = args[1].type.type == integer ? (double)args[1].i : args[1].r;
                  int lastStep = isExponential ? numArgs-3 : numArgs-2;
                  bool isColor = args[3].type.type == integer && args[3].type.format == color;
                  double start = args[2].type.type == integer ? (double)args[2].i : args[2].r, end;
                  double firstVal = args[3].type.type == integer ? (double)args[3].i : args[3].r, secondVal;
                  double fraction;
                  int i;

                  for(i = 2; i <= lastStep; i += 2)
                  {
                     end = start, secondVal = firstVal;
                     if(input <= start || i == lastStep)
                        break;
                     else
                     {
                        double nextStep = args[i+2].type.type == integer ? (double)args[i+2].i : args[i+2].r;
                        double nextValue = args[i+3].type.type == integer ? (double)args[i+3].i : args[i+3].r;
                        if(input < nextStep)
                        {
                           end = nextStep, secondVal = nextValue;
                           break;
                        }
                        else
                           start = nextStep, firstVal = nextValue;
                     }
                  }
                  fraction = (end == start) ? 1 : (input - start) / (end - start);
                  if(base != 1)
                     fraction = (pow(base, fraction) - 1) / (base - 1);

                  if(isColor)
                  {
                     // convert to rgb, interpolate each, convert back to integer
                     Color firstCol = (Color)firstVal, secondCol = (Color)secondVal;
                     value.i = Color
                     {
                        r = (byte)round(firstCol.r + (secondCol.r - firstCol.r) * fraction);
                        g = (byte)round(firstCol.g + (secondCol.g - firstCol.g) * fraction);
                        b = (byte)round(firstCol.b + (secondCol.b - firstCol.b) * fraction);
                     };
                     value.type.format = color;
                  }
                  else
                  {
                     value.type = { real };
                     value.r = firstVal + (secondVal - firstVal) * fraction;
                  }
               }
               break;
            }
            case map:
            {
               if(numArgs >= 4)
               {
                  int64 input = args[0].type.type == integer ? args[0].i : (int64)args[0].r;
                  bool matched = false;
                  int i;

                  for(i = 1; i < numArgs-1; i += 2)
                  {
                     int64 key = args[i].type.type == integer ? args[i].i : (int64)args[i].r;
                     if(key == input)
                     {
                        value = args[i+1];
                        matched = true;
                        break;
                     }
                  }
                  if(!matched)
                     value = args[numArgs-1];
               }
               break;
            }
            case strtod:
            {
               if(numArgs == 1) //TODO: options for base?
               {
                  value.type = { real };
                  if(args[0].type.type == text && strlen(args[0].s) > 1)
                     value.r = strtod(args[0].s, null);
                  // optional fallback value, but this is behavior specific to mbgl 'to-number', not strod
                  /*else if(numArgs > 1 && (args[1].type.type == integer || args[1].type.type == real))
                     value.r = args[1].type.type == integer ? args[1].i : args[1].r;*/
               }
               break;
            }
         }
      }
      return expType;
   }

   virtual void * computeInstance(CartoSymInstantiation inst, Class destType, ExpFlags * flags, Class * expTypePtr)
   {
      return createGenericInstance(inst, evaluatorClass.getClassFromInst(inst, destType, null), this, flags);
   }

   virtual Class ::getClassFromInst(CartoSymInstantiation inst, Class destType, Class * stylesClassPtr)
   {
      // TODO: refactor createGenericInstance
      CartoSymSpecName specName = inst ? (CartoSymSpecName)inst._class : null;
      Class c = specName ? eSystem_FindClass(__thisModule, specName.name) : destType;
      // REVIEW: This causes warning for non-styles related stuff
      if(stylesClassPtr && !*stylesClassPtr) *stylesClassPtr = c;
      return c;
   }

   virtual void ::applyStyle(void * object, StylesMask mSet, const FieldValue value, int unit, CartoSymTokenType assignType);

   // NOTE: These are quite likely to get ridden of with more generic code...
   virtual const String ::stringFromMask(StylesMask mask, Class c) { return null; }
   virtual StylesMask ::maskFromString(const String s, Class c) { return 0; }
   virtual Array<Instance> ::accessSubArray(void * obj, StylesMask mask) { return null; }
};

public class CartoSymStyleSheet
{
   ~CartoSymStyleSheet()
   {
      if(list) list.Free(), delete list;
   }

public:
   StylingRuleBlockList list;

   // Returns first rule block intersecting mask and containing name
   StylingRuleBlock findRule(StylesMask mask, const String name)
   {
      if(this && list)
      {
         for(b : list)
         {
            StylingRuleBlock block = b.findRule(mask, name);
            if(block)
               return block;
         }
      }
      return null;
   }

   //NOTE this ignores selectors!
   bool changeStyle(const String layerID, StylesMask mask, const FieldValue value, Class stylesClass, ECCSSEvaluator evaluator,
      bool isNested, Class unitClass)
   {
      bool result = false;
      StylingRuleBlock block = findRule(mask, layerID);
      if(!block)
      {
         block = { id = { string = CopyString(layerID) } };
         if(!list) list = { };
         list.Add(block);
      }
      block.changeStyle(mask, value, stylesClass, evaluator, false, unitClass);
      return result;
   }

   //NOTE this ignores selectors!
   void removeStyle(const String id, StylesMask mask)
   {
      StylingRuleBlock block = findRule(mask, id);
      if(block)
      {
         block.styles.removeStyle(mask);
      }
   }

   CartoSymStyleSheet bind(ECCSSEvaluator evaluator, Class stylesClass, const String name)
   {
      CartoSymStyleSheet result = null;
      if(this && list)
      {
         for(b : list)
         {
            StylingRuleBlock block = b.bind(evaluator, stylesClass, name);
            if(block)
            {
               if(!result) result = { list = { } };
               result.list.Add(block);
            }
         }
      }
      return result;
   }

   bool resolve(ECCSSEvaluator evaluator, Class stylesClass)
   {
      bool result = false;
      if(this && list)
      {
         for(b : list)
         {
            result = b.resolve(evaluator, stylesClass);
            if(!result) break;
         }
      }
      return result;
   }

   bool write(const String path)
   {
      bool result = false;
      File f = FileOpen(path, write);
      if(f)
      {
         result = writeFile(f);
         delete f;
      }
      return result;
   }

   bool writeFile(File f)
   {
      if(list)
         list.print(f, 0, { skipEmptyBlocks = true });
      return true;
   }

   CartoSymStyleSheet ::loadFile(File f)
   {
      bool result = true;
      StylingRuleBlockList list = null;
      if(f)
      {
         CartoSymLexer lexer { };
         lexer.initFile(f);
         list = StylingRuleBlockList::parse(lexer);
         if(lexer.type == lexingError ||
            lexer.type == syntaxError ||
            (lexer.nextToken && (lexer.nextToken.type != endOfInput)))
         {
#ifdef _DEBUG
            if(lexer.type == lexingError)
               PrintLn("ECCSS Lexing Error at line ", lexer.pos.line, ", column ", lexer.pos.col);
            else
               PrintLn("ECCSS Syntax Error: Unexpected token ", lexer.nextToken.type,
                  lexer.nextToken.text ? lexer.nextToken.text : "",
                  " at line ", lexer.pos.line, ", column ", lexer.pos.col);
#endif
            delete list;
            result = false;
         }

         delete lexer;
      }
      return result ? CartoSymStyleSheet { list = list ? list : { } } : null;
   }

   CartoSymStyleSheet ::load(const String fileName)
   {
      CartoSymStyleSheet result = null;
      File f = fileName ? FileOpen(fileName, read) : null;
      if(f)
      {
         result = loadFile(f);
         delete f;
      }
      return result;
   }

   CartoSymStyleSheet ::loadString(const String s)
   {
      CartoSymStyleSheet result = null;
      if(s)
      {
         TempFile tmp { buffer = (byte *)s, size = strlen(s) };
         result = loadFile(tmp);
         tmp.StealBuffer();
         delete tmp;
      }
      return result;
   }

   CartoSymStyleSheet copy()
   {
      CartoSymStyleSheet sheet { list = list.copy() };
      return sheet;
   }
}

public class StylesMask : uint64 { bool bitMember:1:63; } // Just to force this to be a bit class...

// This is a semi-colon-separated list
public class StylesList : CartoSymInstInitList
{
public:
   StylesList ::parse(CartoSymLexer lexer)
   {
      StylesList list = null;
      while(true)
      {
         CartoSymMemberInitList e = CartoSymMemberInitList::parse(lexer);
         if(e)
         {
            if(!list) list = StylesList { };
            list.Add(e);
         }
         else
            break;
         lexer.peekToken();
         if(lexer.nextToken.type == '#' || lexer.nextToken.type == '[' ||
            lexer.nextToken.type == '{' || lexer.nextToken.type == '}' || !lexer.nextToken.type)
            break;
      }
      return list;
   }
}

public class StylingRuleSelector : CartoSymNode
{
public:
   CartoSymExpression exp;

   ~StylingRuleSelector()
   {
      delete exp;
   }

   StylingRuleSelector ::parse(CartoSymLexer lexer)
   {
      StylingRuleSelector selector = null;
      CartoSymExpression e;
      if(lexer.peekToken().type == '[')
         lexer.readToken();
      e = CartoSymExpression::parse(lexer);
      if(e)
         selector = { exp = e };
      if(lexer.peekToken().type == ']')
         lexer.readToken();
      return selector;
   }

   void print(File out, int indent, CartoSymOutputOptions o)
   {
      out.Print("[");
      exp.print(out, indent, o);
      out.Print("]");
   }
   StylingRuleSelector copy()
   {
      StylingRuleSelector s = null;
      if(this)
      {
         s = eInstance_New(_class);
         incref s;
         s.exp = exp.copy();
      }
      return s;
   }
}

public class SelectorList : CartoSymList<StylingRuleSelector>
{
public:
   SelectorList ::parse(CartoSymLexer lexer)
   {
      SelectorList list = null;
      while(true)
      {
         StylingRuleSelector e = StylingRuleSelector::parse(lexer);
         if(e)
         {
            if(!list) list = SelectorList { };
            list.Add(e);
         }
         else
            break;
         lexer.peekToken();
         if(lexer.nextToken.type == '#' || lexer.nextToken.type == '{' || lexer.nextToken.type == '}' || !lexer.nextToken.type)
            break;
      }
      return list;
   }

   void print(File out, int indent, CartoSymOutputOptions o)
   {
      CartoSymList::print(out, indent, o);
   }

   void printSep(File out)
   {

   }
}

public class StylingRuleBlockList : CartoSymList<StylingRuleBlock>
{
   // TODO: Optimization Maps per re-used attributes of values -> relevant nested rules

public:
   StylingRuleBlockList ::parse(CartoSymLexer lexer)
   {
      return (StylingRuleBlockList)CartoSymList::parse(class(StylingRuleBlockList), lexer, StylingRuleBlock::parse, 0);
   }
   StylesMask mask;

   void print(File out, int indent, CartoSymOutputOptions o)
   {
      CartoSymList::print(out, indent, o);
   }

   void printSep(File out)
   {
   }

   StylesMask apply(void * object, StylesMask m, ECCSSEvaluator evaluator, ExpFlags * flg)
   {
      Link it = list.last;
      //Iterator<StylingRuleBlock> it { list };
      while(m && it) //it.Prev())
      {
         StylingRuleBlock block = (StylingRuleBlock)(uint64)it.data;
         StylesMask bm = block.mask & m;
         if(bm)
            m = block.apply(object, m, evaluator, flg, false);
         it = it.prev;
      }
      return m;
   }

   StylesMask apply2(void * object, StylesMask m, ECCSSEvaluator evaluator, ExpFlags * flg, StylesMask * fm)
   {
      Link it = list.last;
      //Iterator<StylingRuleBlock> it { list };
      while(m && it) //it.Prev())
      {
         StylingRuleBlock block = (StylingRuleBlock)(uint64)it.data;
         StylesMask bm = block.mask & m;
         if(bm)
            m = block.apply2(object, m, evaluator, flg, false, fm);
         it = it.prev;
      }
      return m;
   }
}

static void deleteInstance(Class type, void * instData)
{
   if(type && type.type != structClass)
   {
      if(type.type != noHeadClass) // TOCHECK: No ref count, likely deleted elsewhere
         eInstance_DecRef(instData);
      else
      {
         if(type.Destructor)
            type.Destructor(instData);
         eSystem_Delete(instData);
      }
   }
   else
      delete instData;
}

private Instance createGenericInstance(CartoSymInstantiation inst, Class c, ECCSSEvaluator evaluator, ExpFlags * flg)
{
   Instance instance = c && c.structSize ? eInstance_New(c) : null;
   if(instance)
   {
      if(c.type == normalClass)
         instance._refCount++;

      setGenericInstanceMembers(instance, inst, evaluator, flg, c);
      if(!flg->resolved)
      {
         deleteInstance(c, instance);
         instance = null;
      }
   }
   return instance;
}

private void setGenericBitMembers(CartoSymExpInstance expInst, uint64 * bits, ECCSSEvaluator evaluator, ExpFlags * flg, Class stylesClass)
{
   if(expInst)
   {
      for(i : expInst.instance.members)
      {
         CartoSymMemberInitList members = i;
         for(m : members)
         {
            CartoSymMemberInit mInit = m;
            if(mInit.initializer)
            {
               CartoSymExpression exp = mInit.initializer;
               Class destType = exp.destType;
               if(destType)
               {
                  FieldValue val { };
                  ExpFlags flag = exp.compute(val, evaluator, runtime, stylesClass);
                  BitMember member = (BitMember)mInit.dataMember;

                  *bits |= (val.i << member.pos) & member.mask;

                  *flg |= flag;
               }
               else
               {
                  // PrintLn("null destType ?");
               }
            }
         }
      }
   }
}

private void setGenericInstanceMembers(Instance object, CartoSymInstantiation instance, ECCSSEvaluator evaluator, ExpFlags * flg, Class stylesClass)
{
   bool unresolved = false;
   if(instance)
   {
      for(i : instance.members)
      {
         CartoSymMemberInitList members = i;
         for(m : members)
         {
            CartoSymMemberInit mInit = m;
            if(mInit.initializer)
            {
               CartoSymExpression exp = mInit.initializer;
               Class destType = exp.destType;
               if(destType)
               {
                  FieldValue val { };
                  ExpFlags flag = exp.compute(val, evaluator, runtime, stylesClass);
                  if(stylesClass && stylesClass == class(DateTime) && val.type.type == text)
                  {
                     if(((DateTime *)object)->OnGetDataFromString(val.s))
                        flg->resolved = true;
                     return;
                  }

                  if(mInit.dataMember && mInit.dataMember.isProperty)
                  {
                     Property prop = (Property)mInit.dataMember;

                     if(!prop.Set);
                     else if(destType == class(int) || destType == class(bool) || destType == class(Color) ||
                        ((destType.type == enumClass || destType.type == bitClass) && destType.typeSize == sizeof(int)))
                     {
                        void (* setInt)(void * o, int v) = (void *)prop.Set;
                        setInt(object, val.type.type == integer ? (int)val.i : val.type.type == real ? (int)val.r : 0);
                     }
                     else if(destType == class(int64) ||
                        ((destType.type == enumClass || destType.type == bitClass) && destType.typeSize == sizeof(int64)))
                     {
                        void (* setInt64)(void * o, int64 v) = (void *)prop.Set;
                        setInt64(object, val.type.type == integer ? (int64)val.i : val.type.type == real ? (int64)val.r : 0);
                     }
                     else if(destType == class(double))
                     {
                        void (* setDouble)(void * o, double v) = (void *)prop.Set;
                        setDouble(object, val.type.type == integer ? (double)val.i : val.type.type == real ? val.r : 0);
                     }
                     else if(destType == class(float))
                     {
                        void (* setFloat)(void * o, float v) = (void *)prop.Set;
                        setFloat(object, val.type.type == integer ? (float)val.i : val.type.type == real ? (float)val.r : 0);
                     }
                     else if(destType == class(String))
                     {
                        void (* setString)(void * o, String v) = (void *)prop.Set;
                        String s =
                           (val.type.type == text)    ? (val.type.mustFree ? val.s : CopyString(val.s)) :
                           (val.type.type == real)    ? PrintString(val.r) :
                           (val.type.type == integer) ? PrintString(val.i) : null;
                        setString(object, s);
                        delete s;
                     }
                     else if((destType.type == noHeadClass || destType.type == normalClass) && exp._class == class(CartoSymExpInstance))
                     {
                        void (* setInstance)(void * o, void * v) = (void *)prop.Set;
                        Instance instance;

                        if(destType.type == normalClass)
                        {
                           instance = (Instance)(uintptr)val.b;
                        }
                        else if(destType.type == noHeadClass)
                        {
                           // Make a copy for noHeadClass since both instData and the aggregating object own a copy
                           void (* onCopy)(void *, void *, void *) = destType._vTbl[__ecereVMethodID_class_OnCopy];
                           onCopy(destType, &instance, (void *)(uintptr)val.b);
                        }

                        setInstance(object, instance);

                        if(destType.type == normalClass)
                           ; //eInstance_DecRef((Instance)(uintptr)val.i);
                        else if(destType.type == noHeadClass)
                        {
                           // TODO: base classes destructors?
                           /*
                           if(destType.Destructor)
                              destType.Destructor((void *)(uintptr)val.i);
                           eSystem_Delete((void *)(uintptr)val.i);
                           */
                        }

                        //if we're freeing these Instances later, is it then the case that
                        //we give CartoSymExpInstance this instData member and free it in destructor
                     }
                     else if(destType.type == structClass && exp._class == class(CartoSymExpInstance))
                     {
                        void (* setInstance)(void * o, void * v) = (void *)prop.Set;
                        if(val.i)    // REVIEW: Was getting a crash on GEFont...
                           setInstance(object,  (void *)(uintptr)val.i);
                     }
                     else if((destType.type == noHeadClass || destType.type == normalClass) && exp._class == class(CartoSymExpArray))
                     {
                        void (* setInstance)(void * o, void * v) = (void *)prop.Set;
                        CartoSymExpArray arrayExp = (CartoSymExpArray) exp;
                         // memcpy and renew instead?
                        if(mInit.assignType == addAssign && object) // instantiated check?
                        {
                           Array array = arrayExp.array;
                           if(array)
                           {
                              IteratorPointer i;
                              int c;
                              for(c = 0, i = array.GetFirst(); i; i = array.GetNext(i), c++)
                              {
                                 uintptr data = (uintptr)array.GetData(i);
                                 ((Array<uintptr>)object).Add(data);
                              }
                           }
                        }
                        else
                           setInstance(object, arrayExp.array);
                     }
                     else if(flag.resolved) //!flag.callAgain && !flag.record)  //flag.resolved) //
                     {
                        /*ConsoleFile con { };
                        exp.print(con, 0,0);
                        */
   #ifdef _DEBUG
                        PrintLn("Unexpected!");
   #endif
                     }
                  }
                  else
                  {
                     if(destType == class(int) || destType == class(bool) || destType == class(Color) ||
                        ((destType.type == enumClass || destType.type == bitClass) && destType.typeSize == sizeof(int)))
                        *(int *)((byte *)object + mInit.offset) = val.type.type == integer ? (int)val.i : val.type.type == real ? (int)val.r : 0;
                     else if(destType == class(int64) ||
                        ((destType.type == enumClass || destType.type == bitClass) && destType.typeSize == sizeof(int64)))
                        *(int64 *)((byte *)object + mInit.offset) = val.type.type == integer ? (int64)val.i : val.type.type == real ? (int64)val.r : 0;
                     // TODO: Better units handling
                     else if(destType == class(double) || destType == class(Radians) || destType == class(Meters))
                        *(double *)((byte *)object + mInit.offset) = val.type.type == integer ? (double)val.i : val.type.type == real ? val.r : 0;
                     else if(destType == class(Degrees))
                     {
                        *(double *)((byte *)object + mInit.offset) =
                           Pi / 180 * (val.type.type == integer ? (double)val.i : val.type.type == real ? val.r : 0);
                     }
                     else if(destType == class(float))
                        *(float *)((byte *)object + mInit.offset) = val.type.type == integer ? (float)val.i : val.type.type == real ? (float)val.r : 0;
                     else if(destType == class(String))
                     {
                        *(String *)((byte *)object + mInit.offset) =
                           (val.type.type == text)    ? (val.type.mustFree ? val.s : CopyString(val.s))  :
                           (val.type.type == real)    ? PrintString(val.r) :
                           (val.type.type == integer) ? PrintString(val.i) : null;
                     }
                     else if((destType.type == noHeadClass || destType.type == normalClass) && exp._class == class(CartoSymExpInstance))
                     {
                        // TOFIX: We should probably be deleting existance value here?

                        *(Instance *)((byte *)object + mInit.offset) = (Instance)(uintptr)val.i;
                     }
                     else if(destType.type == structClass && exp._class == class(CartoSymExpInstance))
                     {
                        if(val.i) // REVIEW: Crash on GEFont
                           memcpy((byte *)object + mInit.offset, (void *)(uintptr)val.i, destType.structSize);
                     }
                     // for TimeInterval case
                     else if(destType == class(DateTime))
                     {
                        if(val.type.type == integer && exp.expType == class(int64))
                           *(DateTime *)((byte *)object + mInit.offset) = (SecSince1970)(int64)val.i;
                        else if(val.type.type == text)
                           ((DateTime *)((byte *)object + mInit.offset))->OnGetDataFromString(val.s);
                     }
                     else if(destType == class(SecSince1970))
                     {
                        if(val.type.type == integer && exp.expType == class(int64))
                           *(SecSince1970 *)((byte *)object + mInit.offset) = (SecSince1970)(int64)val.i;
                        else if(val.type.type == text)
                           ((SecSince1970 *)((byte *)object + mInit.offset))->OnGetDataFromString(val.s);
                        else if(val.type.type == nil)
                           *((SecSince1970 *)((byte *)object + mInit.offset)) = MININT64; // unsetTime;
                     }
                     else if(flag.resolved) //!flag.callAgain && !flag.record)  //flag.resolved) //
                     {
                        /*ConsoleFile con { };
                        exp.print(con, 0,0);
                        */
   #ifdef _DEBUG
                        PrintLn("Unexpected!");
   #endif
                     }
                  }
                  if(!flag.resolved)
                     unresolved = true;
                  *flg |= flag;
               }
               else
               {
                  // PrintLn("null destType ?");
               }
            }
         }
      }
   }
   flg->resolved = !unresolved;
}

public class StylingRuleBlock : CartoSymNode
{
   class_no_expansion;
public:
   StylingRuleBlockList nestedRules;
   SelectorList selectors;
   CartoSymIdentifier id;
   StylesList styles;
   StylesMask mask;

   StylingRuleBlock ::parse(CartoSymLexer lexer)
   {
      lexer.peekToken();

      if(lexer.nextToken.type == '[' || lexer.nextToken.type == '#' || lexer.nextToken.type == '{')
      {
         StylingRuleBlock block { };

         if(lexer.peekToken().type == '#')
         {
            lexer.readToken();
            if(lexer.peekToken().type == identifier)
               block.id = CartoSymIdentifier::parse(lexer);
         }

         if(lexer.peekToken().type == '[')
            block.selectors = SelectorList::parse(lexer);

         if(lexer.peekToken().type == '{')
            lexer.readToken();

         if(lexer.peekToken().type == identifier)
            block.styles = StylesList::parse(lexer);

         lexer.peekToken();
         if(lexer.nextToken.type == '[' || lexer.nextToken.type == '#' || lexer.nextToken.type == '{')
            block.nestedRules = StylingRuleBlockList::parse(lexer);

         if(lexer.peekToken().type == '}')
            lexer.readToken();
         return block;
      }
      return null;
   }

   // Returns first rule block intersecting mask and containing name
   StylingRuleBlock findRule(StylesMask mask, const String name)
   {
      if(id && id.string && name && strcmpi(id.string, name))
         return null;

      if(styles && styles.GetCount())
      {
         for(s : styles)
         {
            for(m : s)
            {
               CartoSymMemberInit mInit = m;
               StylesMask sm = mInit.stylesMask;
               if(sm & mask)
                  return this;
            }
         }
      }

      if(nestedRules)
      {
         for(b : nestedRules)
         {
            StylingRuleBlock block = b.findRule(mask, name);
            if(block)
               return b;
         }
      }

      return null;
   }

   private StylingRuleBlock bind(ECCSSEvaluator evaluator, Class stylesClass, const String name)
   {
      StylingRuleBlock result = null;
      bool keep = true;
      SelectorList newSelectors = null;

      // Layer ID filter
      if(id && id.string && name && strcmpi(id.string, name))
         keep = false;

      // Selector expressions filter
      if(keep && selectors)
      {
         // TODO: Per-record flags for selectors?
         for(s : selectors)
         {
            FieldValue value { };
            CartoSymExpression e = s.exp.copy();
            ExpFlags flags = e.compute(value, evaluator, preprocessing, stylesClass);
            if(flags.resolved)
            {
               e = simplifyResolved(value, e);
               delete e; // NOTE: viz.sd operations were being deleted when resolved
               if(!value.i)
               {
                  keep = false;
                  break;
               }
            }
            else
            {
               if(!newSelectors) newSelectors = { };
               newSelectors.Add(StylingRuleSelector { exp = e });
            }
         }
         if(!keep) delete newSelectors;
      }

      if(keep)
      {
         StylingRuleBlock block { selectors = newSelectors };
         StylesMask mask = 0;
         if(id) block.id = { string = CopyString(id.string) };
         if(styles)
         {
            StylesList newStyles { };
            for(s : styles)
            {
               CartoSymMemberInitList style = s;
               CartoSymMemberInitList newStyle { };
               for(m : style)
               {
                  CartoSymMemberInit member = m.copy();
                  /*ExpFlags flags = */member.precompute(stylesClass, stylesClass, 0, null, evaluator);  // TODO: Consider these flags
                  newStyle.Add(member);
                  newStyles.mask |= member.stylesMask;
               }
               newStyles.Add(newStyle);
            }
            block.styles = newStyles;
            mask |= newStyles.mask;
         }

         if(nestedRules)
         {
            for(b : nestedRules)
            {
               StylingRuleBlock nb = b.bind(evaluator, stylesClass, name);
               if(nb)
               {
                  if(!block.nestedRules) block.nestedRules = { };
                  block.nestedRules.Add(nb);
                  block.nestedRules.mask |= nb.mask;
               }
            }
            if(block.nestedRules) mask |= block.nestedRules.mask;
         }
         block.mask = mask;
         result = block;
      }
      return result;
   }

   private bool resolve(ECCSSEvaluator evaluator, Class stylesClass)
   {
      bool result = false;
      if(selectors)
      {
         // TODO: Per-record flags for selectors?
         for(s : selectors)
         {
            FieldValue value { };
            CartoSymExpression e = s.exp;
            ExpFlags flags = e.compute(value, evaluator, preprocessing, stylesClass);
            if(flags.resolved)
            {
               e = simplifyResolved(value, e);
               s.exp = e;
               //delete e; // NOTE: viz.sd operations were being deleted when resolved
            }
         }
      }

      if(styles)
      {
         for(s : styles)
         {
            CartoSymMemberInitList style = s;
            for(m : style)
            {
               CartoSymMemberInit member = m;
               // passing stylesClass here just passes irrelevant GeoSymbolizer class, but the others are not yet bound
               member.precompute(stylesClass, stylesClass, 0, null, evaluator);  // TODO: Consider these flags
               styles.mask |= member.stylesMask;
            }
         }
         this.mask |= styles.mask;
      }

      if(nestedRules)
      {
         for(b : nestedRules)
         {
            b.resolve(evaluator, stylesClass);
            nestedRules.mask |= b.mask;
         }
         mask |= nestedRules.mask;
      }
      result = true;

      return result;
   }

   CartoSymExpression getStyle(StylesMask mask)
   {
      return styles ? styles.getStyle(mask) : null;
   }


   void setStyle(Class c, const String idString, StylesMask msk, bool createSubInstance, CartoSymExpression expression,
      ECCSSEvaluator evaluator, Class stylesClass)
   {
      if(msk)
      {
         if(!styles) styles = { };
         styles.setMember2(c, idString, msk, createSubInstance, expression, evaluator, stylesClass, none);
         mask |= msk;
      }
   }

   void setStyleEx(Class c, const String idString, StylesMask msk, bool createSubInstance, CartoSymExpression expression,
      ECCSSEvaluator evaluator, Class stylesClass, CartoSymTokenType tt)
   {
      if(msk)
      {
         if(!styles) styles = { };
         styles.setMember2(c, idString, msk, createSubInstance, expression, evaluator, stylesClass, tt);
         mask |= msk;
      }
   }

   // NOTE: isNested means this is a nested rule, and we want to set top.sub = as opposed to top = { sub = }
   bool changeStyle(StylesMask msk, const FieldValue value, Class c, ECCSSEvaluator evaluator, bool isNested, Class unitClass)
   {
      if(msk)
      {
         if(!styles) styles = { };
         if(styles.changeStyle(msk, value, c, evaluator, isNested, unitClass))
         {
            mask |= msk;
            return true;
         }
      }
      return false;
   }

   void removeStyle(StylesMask msk)
   {
      if(this)
      {
         styles.removeStyle(msk);
      }
   }

   void print(File out, int indent, CartoSymOutputOptions o)
   {
      const char * ln = o.dbgOneLiner ? " " : "\n";

      if(o.skipEmptyBlocks &&
         (!styles || !styles.list.first) &&
         (!nestedRules || !nestedRules.list.count))
         return;

      out.Print(ln);
      if(!o.dbgOneLiner) printIndent(indent, out);
      if(id)
      {
         out.Print("#");
         id.print(out, indent, o);
      }

      if(selectors)
         selectors.print(out, indent, o);

      if(id || selectors)
      {
         out.Print(ln);
         if(!o.dbgOneLiner) printIndent(indent, out);
      }
      out.Print("{", ln);
      indent++;

      if(styles)
      {
         Iterator<CartoSymMemberInitList> it { styles };
         while(it.Next())
         {
            CartoSymMemberInitList list = it.data;

            if(!o.dbgOneLiner) printIndent(indent, out);
            list.print(out, indent, o);
            out.Print(";", ln);
         }
      }
      if(nestedRules)
         nestedRules.print(out, indent, o);

      indent--;
      if(!o.dbgOneLiner) printIndent(indent, out);

      out.Print("}", ln);
   }

   void debugPrintRule(File out, const String name)
   {
      out.Print("   ", name, " @", this ? "" : "0x0", (uintptr)this, ": ");
      if(this) print(out, 32, { dbgOneLiner = true });
      out.PrintLn("");
   }

   ~StylingRuleBlock()
   {
      delete selectors;
      delete id;
      delete styles;
      delete nestedRules;
   }

   StylingRuleBlock copy()
   {
      StylingRuleBlock b = null;

      if(this)
      {
         b = eInstance_New(_class);
         incref b;
         b.mask = mask;
         b.id = (id && id.string) ? { string = CopyString(id.string) } : null;
         if(nestedRules)
         {
            b.nestedRules = { mask = nestedRules.mask };
            for(n : nestedRules)
               b.nestedRules.Add(n.copy());
         }
         if(selectors)
         {
            b.selectors = { };
            for(n : selectors)
               b.selectors.Add(n.copy());
         }
         if(styles)
         {
            b.styles = { mask = styles.mask };
            for(n : styles)
               b.styles.Add(n.copy());
         }
      }
      return b;
   }

   // This should return the mask of symbolization properties which could be different based on exp flags...
   private StylesMask apply2(void * object, StylesMask m, ECCSSEvaluator evaluator, ExpFlags * flg, bool ignoreSelectors, StylesMask * fm)
   {
      StylesMask result = m;
      ExpFlags flags = 0;
      bool apply = true;
      bool neverHappening = false;

      if(selectors && !ignoreSelectors)
      {
         Link s;
         for(s = selectors.list.first; s; s = s.next)
         {
            StylingRuleSelector sel = (StylingRuleSelector)(uintptr)s.data;
            FieldValue value { };
            // REVIEW: scale-dependent compute() was broken without a copy
            CartoSymExpression e = sel.exp; // ? sel.exp.copy() : null;
            ExpFlags sFlags = e.compute(value, evaluator, runtime, null);
            flags |= sFlags;

            if(sFlags.resolved /* == ExpFlags { resolved = true }*/ && !value.i)
               neverHappening = true;

            if(!sFlags.resolved || !value.i)
               apply = false;
            //delete e;
         }
         *flg |= flags;
      }

      if(apply || (!neverHappening && (flags & ~ ExpFlags { resolved = true })))
      {
         StylesMask nfm = 0;
         if(nestedRules)
         {
            m = nestedRules.apply2(apply ? object : null, m, evaluator, flg, &nfm);
            if(apply)
               result = m;
            if(fm)
               *fm |= nfm;
         }
         if(m)
         {
            Link itStyle = styles ? styles.list.last : null;
            while(itStyle)
            {
               CartoSymMemberInitList initList = (CartoSymMemberInitList)(uintptr)itStyle.data;
               Link itMember = initList.list.last;
               while(itMember)
               {
                  CartoSymMemberInit member = (CartoSymMemberInit)itMember.data;
                  CartoSymExpression e = member.initializer;
                  StylesMask sm = member.stylesMask;
                  ExpFlags f = 0;

                  if(apply)
                  {
                     // since the stylesMask for the CartoSymMemberInit in a += scenario could repeat, subsequent elements will be filtered out here with the mask logic
                     // TODO: retrieve the masks from the initializer?
                     /*if(member.assignType == addAssign && e._class == class(CartoSymExpInstance))
                     {
                        CartoSymExpInstance inst = (CartoSymExpInstance)e;
                        CartoSymSpecName spec = (CartoSymSpecName)inst.instance._class;
                        String n = spec ? spec.name : null;
                        if(n) sm = evaluator.evaluatorClass.maskFromString(n, evaluator.evaluatorClass.getClassFromInst(inst.instance, inst.destType, null));
                     }
                     else*/
                        sm = member.stylesMask;
                     if((sm & m) || (member.assignType == addAssign))
                     {
                        applyStyle(object, sm & m, evaluator, e, &f, 0, member.assignType);
                        *flg |= f;
                        if(!(member.assignType == addAssign))
                        {
                           m &= ~sm;
                           result = m;
                        }
                     }
                  }
                  else
                  {
                     FieldValue value { };
                     f = e.compute(value, evaluator, runtime, e.destType);
                  }
                  if(fm && (f | flags) & ~ExpFlags { resolved = true })
                     *fm |= sm;
                  itMember = itMember.prev;
               }
               itStyle = itStyle.prev;
            }
         }
      }
      return result;
   }

   // TOCHECK: Both mask and flags must be returned?
   public /*private static*/ StylesMask apply(void * object, StylesMask m, ECCSSEvaluator evaluator, ExpFlags * flg, bool ignoreSelectors)
   {
      ExpFlags flags = 0;
      bool apply = true;

      if(selectors && !ignoreSelectors)
      {
         Link s;
         // TODO: Per-record flags for selectors?
         for(s = selectors.list.first; s; s = s.next)
         {
            StylingRuleSelector sel = (StylingRuleSelector)(uintptr)s.data;
            FieldValue value { };
            // REVIEW: scale-dependent compute() was broken without a copy
            CartoSymExpression e = sel.exp; // ? sel.exp.copy() : null;
            ExpFlags sFlags = e.compute(value, evaluator, runtime, null);
            flags |= sFlags;

            if(!sFlags.resolved || !value.i)
               apply = false;
            //callAgain = flags.callAgain;
            //delete e;
         }
         *flg |= flags;
      }

      if(apply)
      {
         if(nestedRules)
            m = nestedRules.apply(object, m, evaluator, flg);
         if(m)
         {
            //Iterator<CartoSymMemberInitList> itStyle { styles };
            Link itStyle = styles ? styles.list.last : null;
            while(itStyle) //.Prev())
            {
               CartoSymMemberInitList initList = (CartoSymMemberInitList)(uintptr)itStyle.data;
               //Iterator<CartoSymMemberInit> itMember { itStyle.data };
               Link itMember = initList.list.last;
               while(itMember) //.Prev())
               {
                  CartoSymMemberInit member = (CartoSymMemberInit)itMember.data;
                  CartoSymExpression e = member.initializer;
                  StylesMask sm = member.stylesMask;
                  if((sm & m) || (member.assignType == addAssign))
                  {
                     applyStyle(object, sm & m, evaluator, e, flg, 0, member.assignType);
                     //m &= ~sm;
                     if(!(member.assignType == addAssign))
                        m &= ~sm;
                  }
                  itMember = itMember.prev;
               }
               itStyle = itStyle.prev;
            }
         }
      }
      return m;
   }

   private static void ::applyStyle(void * object, StylesMask mSet, ECCSSEvaluator evaluator, CartoSymExpression e, ExpFlags * flg, int unitVal, CartoSymTokenType assignType)
   {
      CartoSymExpInstance inst = null;
      CartoSymExpArray arr = null;
      CartoSymExpConditional cond = null;
      int unit = unitVal;
      subclass(ECCSSEvaluator) evaluatorClass = evaluator.evaluatorClass;

      if(e)
      {
         inst = e._class == class(CartoSymExpInstance) ? (CartoSymExpInstance)e : null;
         arr = e._class == class(CartoSymExpArray) ? (CartoSymExpArray)e : null;
         cond = e._class == class(CartoSymExpConditional) ? (CartoSymExpConditional)e : null;
      }

      // REVIEW: Shouldn't the expType be what indicate the unit?
      // special handling for conditional with potential unitClass as a compute on conditional would not yield the unit
      if(cond && cond.condition)
      {
         CartoSymExpression lastExp = cond.expList ? cond.expList.lastIterator.data : null;
         if((lastExp && lastExp._class == class(CartoSymExpInstance)) ||
            (cond.elseExp && cond.elseExp._class == class(CartoSymExpInstance)))
         {
            FieldValue condValue {};
            ExpFlags flagsCond = cond.condition.compute(condValue, evaluator, runtime, e.destType);
            if(flagsCond.resolved && condValue.i)
            {
               inst = lastExp._class == class(CartoSymExpInstance) ? (CartoSymExpInstance)lastExp : null;
            }
            else if(flagsCond.resolved && cond.elseExp && cond.elseExp._class == class(CartoSymExpInstance))
            {
               inst = (CartoSymExpInstance)cond.elseExp;
            }
         }
      }
      if(inst && inst.instance)
      {
         CartoSymSpecName spec = (CartoSymSpecName)inst.instance._class;
         String n = spec ? spec.name : null;
         if(n && !strcmpi(n, "Meters"))     // TODO: make this generic
         {
            unit = 1; // meters
            /*e = null;
            for(i : inst.instance.members)
            {
               CartoSymMemberInitList members = i;
               for(m : members)
               {
                  CartoSymMemberInit mInit = m;
                  if(mInit.initializer)
                  {
                     e = mInit.initializer;
                     if(!e.destType) e.destType = class(double);
                     break;
                  }
               }
               if(e) break;
            }
            inst = null;*/
         }
         if(object) //else if(object)
         {
            if(assignType == addAssign) // also pass mInit desttype to be sure of object?
            {
               Array<Instance> array = object ? evaluatorClass.accessSubArray(object, mSet) : null;
               if(array)
               {
                  array.Add(createGenericInstance(inst.instance,
                     evaluatorClass.getClassFromInst(inst.instance, inst.destType, null), evaluator, flg));
               }
            }
            else
               applyInstanceStyle(object, mSet, inst, evaluator, flg, unit);
         }
      }

      if(arr)
      {
         if(evaluator != null)
         {
            // TODO: Do this in a more generic manner
            Array<Instance> array = object ? evaluatorClass.accessSubArray(object, mSet) : null;
            if(array)
               for(e : arr.elements; e._class == class(CartoSymExpInstance))
               {
                  CartoSymExpInstance expInstance = (CartoSymExpInstance)e;
                  Instance createdInstance = createGenericInstance(expInstance.instance,
                     evaluatorClass.getClassFromInst(expInstance.instance, expInstance.destType, null), evaluator, flg);
                  if(createdInstance) array.Add(createdInstance);
               }
            else
            {
               // New more generic approach for colormaps etc. with blob, which could eventually work for GEs as well?
               FieldValue value { };
               ExpFlags mFlg = e.compute(value, evaluator, runtime, e.destType); // TODO: Review stylesClass here?
               if(object)
                  evaluatorClass.applyStyle(object, mSet, value, unit, 0);
               *flg |= mFlg;
            }
         }
      }
      else if(e && !inst)
      {
         FieldValue value { };
         ExpFlags mFlg = e.compute(value, evaluator, runtime, e.destType); // TODO: Review stylesClass here?
         Class destType = e.destType;
         Class expType = e.expType;

         if(expType && expType == class(Meters))
            unit = 1; // meters
         if(mFlg.resolved && destType && expType != destType)
         {
            if(destType == class(float) || destType == class(double))
               convertFieldValue(value, {real}, value);
            else if(destType == class(String))
               convertFieldValue(value, {text}, value);
            else if(destType == class(int64) || destType == class(int) || destType == class(uint64) || destType == class(uint))
               convertFieldValue(value, {integer}, value);
         }
         if(object)
            evaluatorClass.applyStyle(object, mSet, value, unit, 0);
         *flg |= mFlg;
      }
   }

   private static void ::applyInstanceStyle(void * object, StylesMask mask, CartoSymExpInstance inst,
      ECCSSEvaluator evaluator, ExpFlags * flg, int unit)
   {
      if(inst)
      {
         CartoSymInstInitList instMembers = inst.instance.members;
         List<CartoSymMemberInitList> membersInitList = instMembers ? instMembers.list : null;
         Link i;
         for(i = membersInitList ? membersInitList.first : null; i; i = i.next)
         {
            CartoSymMemberInitList members = (CartoSymMemberInitList)(uintptr)i.data;
            List<CartoSymMemberInit> membersList = members.list;
            Link m;
            for(m = membersList.first; m; m = m.next)
            {
               CartoSymMemberInit mInit = (CartoSymMemberInit)(uintptr)m.data;
               if(mInit.initializer)
               {
                  StylesMask sm = mInit.stylesMask;
                  if(sm & mask) // || unit
                  {
                     applyStyle(object, sm & mask, evaluator, mInit.initializer, flg, unit, mInit.assignType);
                     mask &= ~sm;
                  }
               }
            }
         }
      }
   }
};
