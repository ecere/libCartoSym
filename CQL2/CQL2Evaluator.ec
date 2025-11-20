public import IMPORT_STATIC "ecrt"
public import IMPORT_STATIC "DE9IM"

private:

import "CQL2Expressions"
import "Colors"

#include <math.h> // NOTE: remove this once interpolate function moved

default:
__attribute__((unused)) static void UnusedFunction()
{
   int a = 0;
   a.OnCopy(0);
}
extern int __eCVMethodID_class_OnCopy;

private:

public enum CQL2FunctionIndex : int
{
   unresolved = -1,

   // Spatial comparison functions
   s_intersects = 100,
   s_contains,
   s_disjoint,
   s_touches,
   s_within,
   s_crosses,
   s_overlaps,
   s_equals,

   // Temporal comparison functions
   t_after,
   t_before,
   t_equals,
   t_intersects,
   t_contains,
   t_disjoint,
   t_during,
   t_finishedby,
   t_finishes,
   t_meets,
   t_metby,
   t_overlappedby,
   t_overlaps,
   t_startedby,
   t_starts,

   // Array functions
   a_containedby,
   a_contains,
   a_equals,
   a_overlaps,

   // Case and Accent Insensitive Comparison
   casei,
   accenti,

   // *** Extensions and Internal functions ***
   min = 200,
   max,
   avg,

   aggregateMulti,

   // Text manipulation
   strupr,
   strlwr,
   strtod,
   subst,
   format,
   concatenate,
   pow,
   log,
   like,
   interpolate,
   map
};

static String formatValues(const String format, int numArgs, const FieldValue * values)
{
   String result;
   ZString output { allocType = heap, minSize = 1024 };
   int formatLen = format ? strlen(format) : 0;
   const String start = format;
   int arg = 0;
   const FieldValue * value = &values[arg];

   while(true)
   {
      String nextArg = strchr(start, '%');
      if(nextArg)
      {
         if(nextArg[1] == '%')
         {
            output.concatn(start, (int)(nextArg+1 - start));
            start = nextArg + 2;
         }
         else
         {
            bool valid = true;
            FieldType type = integer;
            String s = nextArg + 1;
            bool argWidth = false, argPrecision = false;
            int width = 0, precision = 0;

            output.concatn(start, (int)(nextArg - start));
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
                     output.concatn(value->s, strlen(value->s));
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
                     output.concatn(argString, numArgs);
               }

               value = &values[++arg];
            }
         }
      }
      else
      {
         output.concatn(start, (int)(formatLen - (start - format)));
         break;
      }
   }
   result = output._string;
   output._string = null;
   delete output;
   return result;
}

// For extending ECCSS with custom identifiers and styling properties
public struct CQL2Evaluator
{
   subclass(CQL2Evaluator) evaluatorClass;        // This is effectively adding a virtual function table...

   virtual Class resolve(const CQL2Identifier identifier, bool isFunction, int * id, ExpFlags * flags)
   {
      Class expType = null;
      if(isFunction)
      {
         CQL2FunctionIndex fnIndex = unresolved;

         if(fnIndex.OnGetDataFromString(identifier.string))
         {
            *id = fnIndex;
            expType = class(GlobalFunction);
            flags->resolved = true;
         }
         else
            *id = CQL2FunctionIndex::unresolved;
      }
      return expType;
   }
   virtual void compute(int id, const CQL2Identifier identifier, bool isFunction, FieldValue value, ExpFlags * flags)
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
   virtual void evaluateMember(DataMember prop, CQL2Expression exp, const FieldValue parentVal, FieldValue value, ExpFlags * flags);
   virtual Class resolveFunction(const FieldValue e, CQL2ExpList args, ExpFlags * flags, Class destType)
   {
      Class expType = null;

      if(e.type.type == integer)
      {
         CQL2FunctionIndex fnIndex = (CQL2FunctionIndex)e.i;

         if(fnIndex >= s_intersects && fnIndex <= s_equals)
         {
            // Spatial comparison functions
            if(args.list.count >= 2)
            {
               CQL2Expression a0 = args[0], a1 = args[1];
               if(a0 && a1)
               {
                  args[0].destType = class(Geometry);
                  args[1].destType = class(Geometry);
                  expType = class(bool);
               }
            }
         }
         else if(fnIndex >= t_after && fnIndex <= t_starts)
         {
            // Temporal comparison functions
            if(args.list.count >= 2)
            {
               CQL2Expression a0 = args[0], a1 = args[1];
               if(a0 && a1)
               {
                  a0.destType = class(TimeIntervalSince1970);
                  a1.destType = class(TimeIntervalSince1970);
                  expType = class(bool);
               }
            }
         }
         else if(fnIndex >= a_containedby && fnIndex <= a_overlaps)
         {
            // Array comparison functions
            if(args.list.count == 2)
            {
               CQL2Expression a0 = args[0], a1 = args[1];
               if(a0 && a1)
               {
                  a0.destType = class(Array<FieldValue>);
                  a1.destType = class(Array<FieldValue>);
                  expType = class(bool);
               }
            }
         }
         else if(fnIndex >= min && fnIndex <= avg)
         {
            // Condenser/Reducer Operations -- TODO: aggregate on all dimensions?
            // Temporal comparison functions
            /*
            if(args.list.count >= 2)
            {
               CQL2Expression a0 = args[0], a1 = args[1];
               if(a0 && a1)
               {
                  a1.destType = class(Array<String>);
               }
               // REVIEW: 3 extra parameters for complex seasonal aggregations
            }
            */
         }
         else if(fnIndex == aggregateMulti)
         {
            if(args.list.count >= 3)
            {
               CQL2Expression a0 = args[0], a1 = args[1], a2 = args[2];
               if(a0 && a1 && a2)
               {
                  // a0 is field expression, a2 is reducer operation
                  a1.destType = class(GlobalFunction);
                  a2.destType = class(Array<String>);
                  if(args.list.count >= 4)
                  {
                     CQL2Expression a3 = args[3];
                     // REVIEW: Non-string resolution
                     if(a3) a3.destType = class(Array<String>);
                     if(args.list.count >= 5)
                     {
                        CQL2Expression a4 = args[4];
                        if(a4) a3.destType = class(Array<String>);
                        if(args.list.count >= 6)
                        {
                           // REVIEW: Non-string shift
                           CQL2Expression a5 = args[5];
                           if(a4) a5.destType = class(Array<String>);
                        }
                     }
                  }
               }
            }
         }
         else
         {
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
      }
      return expType;
   }

   virtual Class computeFunction(FieldValue value, const FieldValue e, const FieldValue * args, int numArgs, CQL2ExpList arguments, ExpFlags * flags)
   {
      Class expType = null;
      value = { { nil } };

      if(e.type.type == integer)
      {
         CQL2FunctionIndex fnIndex = (CQL2FunctionIndex)e.i;
         if(fnIndex >= s_intersects && fnIndex <= s_equals)
         {
            // Spatial comparison functions
            if(args[0].b && args[1].b)
            {
               Geometry * geometry = args[0].b;
               value = { type = { integer, format = boolean } };
               expType = class(bool);

               switch(fnIndex)
               {
                  case s_intersects:
                     value.i = geometryIntersects(geometry, args[1].b);
                     // REVIEW: How to handle dateline properly throughout DE9IM operations?
                     if(!value.i && geometry->crs && geometry->crs == { epsg, 4326 } && geometry->type == bbox &&
                        (geometry->bbox.ur.lon > 90 || (geometry->bbox.ur.lon > 0 && geometry->bbox.ll.lat < -85)))
                     {
                        Geometry r = *geometry;
                        r.bbox.ur.lon -= 2*Pi;
                        r.bbox.ll.lon -= 2*Pi;
                        value.i = geometryIntersects(r, args[1].b);
                     }
                     if(!value.i && geometry->crs && geometry->crs == { epsg, 4326 } && geometry->type == bbox && geometry->bbox.ll.lon < -90)
                     {
                        Geometry r = *geometry;
                        r.bbox.ur.lon += 2*Pi;
                        r.bbox.ll.lon += 2*Pi;
                        value.i = geometryIntersects(r, args[1].b);
                     }
                     if(!value.i && geometry->crs && geometry->crs == { epsg, 4326 } && geometry->type == bbox &&
                        (geometry->bbox.ll.lat < -90 && geometry->bbox.ur.lat > -90))
                     {
                        Geometry r = *geometry;

                        r.bbox.ll.lat = -Pi/2;
                        r.bbox.ur.lat = Max((Radians)geometry->bbox.ur.lat, -Pi - (Radians)geometry->bbox.ll.lat);
                        r.bbox.ll.lon = Pi + geometry->bbox.ll.lon;
                        r.bbox.ur.lon = Pi + geometry->bbox.ur.lon;
                        value.i = geometryIntersects(r, args[1].b);
                     }
                     break;
                  case s_contains: value.i = geometryContains(geometry, args[1].b); break;
                  case s_touches:  value.i = geometryTouches(geometry, args[1].b); break;
                  case s_disjoint: value.i = geometryDisjoint(geometry, args[1].b); break;
                  case s_within:   value.i = geometryWithin(geometry, args[1].b); break;
                  case s_crosses:  value.i = geometryCrosses(geometry, args[1].b); break;
                  case s_overlaps: value.i = geometryOverlaps(geometry, args[1].b); break;
                  case s_equals:   value.i = geometryEquals(geometry, args[1].b); break;
               }
            }
         }
         else if(fnIndex >= t_after && fnIndex <= t_starts)
         {
            // Temporal comparison functions
            TimeIntervalSince1970 tmp0 { };
            TimeIntervalSince1970 tmp1 { };
            TimeIntervalSince1970 * time0 = null, * time1 = null;

            if(args[0].type.type == blob) time0 = args[0].b;
            else if(args[0].type == { integer, isDateTime = true }) tmp0 = { (SecSince1970)args[0].i, unsetTime }, time0 = &tmp0;
            else if(args[0].type.type == text && tmp0.OnGetDataFromString(args[0].s)) time0 = &tmp0;
#ifdef _DEBUG
            else if(args[0].type.type != nil)
               PrintLn("WARNING: Error resolving time argument");
#endif

            if(args[1].type.type == blob) time1 = args[1].b;
            else if(args[1].type == { integer, isDateTime = true }) tmp1 = { (SecSince1970)args[1].i, unsetTime }, time1 = &tmp1;
            else if(args[1].type.type == text && tmp1.OnGetDataFromString(args[1].s)) time1 = &tmp1;
#ifdef _DEBUG
            else if(args[1].type.type != nil)
               PrintLn("WARNING: Error resolving time argument");
#endif

            if(time0 && time1 && time0->start != unsetTime && time1->start != unsetTime)
            {
               value = { type = { integer, format = boolean } };
               expType = class(bool);
               switch(fnIndex)
               {
                  case t_disjoint:     value.i = time0->disjoint(time1); break;
                  case t_equals:       value.i = time0->equals(time1); break;
                  case t_intersects:   value.i = time0->intersects(time1); break;
                  case t_after:        value.i = time0->after(time1); break;
                  case t_before:       value.i = time0->before(time1); break;
                  case t_contains:     value.i = time0->contains(time1); break;
                  case t_during:       value.i = time0->during(time1); break;
                  case t_finishedby:   value.i = time0->finishedby(time1); break;
                  case t_finishes:     value.i = time0->finishes(time1); break;
                  case t_meets:        value.i = time0->meets(time1); break;
                  case t_metby:        value.i = time0->metby(time1); break;
                  case t_overlappedby: value.i = time0->overlappedby(time1); break;
                  case t_overlaps:     value.i = time0->overlaps(time1); break;
                  case t_startedby:    value.i = time0->startedby(time1); break;
                  case t_starts:       value.i = time0->starts(time1); break;
               }
            }
         }
         else if(fnIndex >= a_containedby && fnIndex <= a_overlaps)
         {
            if(args[0].type.type == array && args[1].type.type == array)
            {
               Array<FieldValue> array1 = (Array<FieldValue>)args[0].b, array2 = (Array<FieldValue>)args[1].b;
               value = { type = { integer, format = boolean } };
               expType = class(bool);
               // TODO: move array functions where?
               switch(fnIndex)
               {
                  case a_containedby:  value.i = arrayfuncContainedby(array1, array2); break;
                  case a_contains:     value.i = arrayfuncContains(array1, array2); break;
                  case a_equals:       value.i = arrayfuncEquals(array1, array2); break;
                  case a_overlaps:     value.i = arrayfuncOverlaps(array1, array2); break;
               }
            }
         }
         /* TODO:
         else if(fnIndex == aggregateMulti && numArgs >= 3)
            expType = computeAggregation(value, args, numArgs, arguments, flags);
         */
         else
         {
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
                     ZString newStr { allocType = heap };
                     value.type = { text, true };
                     for(i = 0; i < numArgs; i++)
                     {
                        if(args[i].type.type == text)
                           newStr.concat(args[i].s);
                        else
                        {
                           switch(args[i].type.type)
                           {
                              case integer: newStr.concatf("%d",args[i].i);break;
                              case real: newStr.concatf("%f", args[i].r);break;
                           }
                        }
                     }
                     value.s = newStr._string;
                     newStr._string = null;
                     delete newStr;
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
      }
      return expType;
   }

   virtual void * computeInstance(CQL2Instantiation inst, Class destType, ExpFlags * flags, Class * expTypePtr)
   {
      // NOTE: flip the Lat,Lon order for now, assuming CRS84 for WKT and EPSG:4326 for CS by default
      bool flipCoords = true;
      void * instData = createGenericInstance(inst, evaluatorClass.getClassFromInst(inst, destType, null), this, flags);

      if(inst && instData)
      {
         CQL2SpecName specName = inst._class;
         Class c = inst ? getClassFromInst(inst, destType, null) : null;

         if((c == class(GeoPoint) && specName) ||
            c == class(GeoExtent) || (c == class(LineString) && specName) || (c == class(Polygon) && specName) ||
            c == class(Array<Polygon>) || c == class(Array<LineString>) || c == class(Array<GeoPoint>) ||
            c == class(Array<Geometry>))
         {
            Geometry * geometry = new0 Geometry[1];
            // REVIEW: subElementsOwned is not being set here...
            if(c == class(GeoPoint))
            {
               GeoPoint * p = (GeoPoint *)instData;
               geometry->type = point;
               geometry->point = flipCoords ? { p->lon, p->lat } : *p;
               delete instData;
            }
            else if(c == class(GeoExtent))
            {
               GeoExtent * e = (GeoExtent *)instData;
               geometry->type = bbox;
               if(flipCoords)
                  e->ll = { e->ll.lon, e->ll.lat }, e->ur = { e->ur.lon, e->ur.lat };
               geometry->bbox = *e;
               delete instData;
            }
            else if(c == class(LineString))
            {
               LineString * l = (LineString *)instData;
               Array<GeoPoint> points = (Array<GeoPoint>)l->points;

               geometry->type = lineString;
               if(flipCoords && points)
                  flipPoints(points);
               geometry->lineString = *l;
               delete instData;
            }
            else if(c == class(Polygon))
            {
               Polygon * poly = (Polygon *)instData;
               Array<PolygonContour> contours = poly->getContours();
               geometry->type = polygon;
               if(contours)
               {
                  for(c : contours)
                     fixPointsContour(c, flipCoords);
               }
               geometry->polygon = *poly;
               delete instData;
            }
            else if(c == class(Array<Polygon>))
            {
               Array<Polygon> polygons = (Array<Polygon>)instData;
               geometry->type = multiPolygon;

               for(poly : polygons)
               {
                  Array<PolygonContour> contours = poly.getContours();
                  if(contours)
                  {
                     for(c : contours)
                        fixPointsContour(c, flipCoords);
                  }
               }
               geometry->multiPolygon = polygons;
               instData = null;
            }
            else if(c == class(Array<LineString>))
            {
               Array<LineString> lines = (Array<LineString>)instData;
               geometry->type = multiLineString;
               for(l : lines)
               {
                  Array<GeoPoint> points = (Array<GeoPoint>)l.points;
                  if(flipCoords && points)
                     flipPoints(points);
               }
               geometry->multiLineString = lines;
               instData = null;
            }
            else if(c == class(Array<GeoPoint>))
            {
               Array<GeoPoint> points = (Array<GeoPoint>)instData;
               geometry->type = multiPoint;
               if(flipCoords)
                  flipPoints(points);

               geometry->multiPoint = points;
               instData = null;
            }
            else if(c == class(Array<Geometry>))
            {
               Array<Geometry> geom = (Array<Geometry>)instData;
               geometry->type = geometryCollection;
               // TODO: refactor to flip points per geom type?
               for(g : geom)
               {
                  if(g.type == point)
                  {
                     GeoPoint p = g.point;
                     p = flipCoords ? { p.lon, p.lat } : p;
                  }
               }
               geometry->geometryCollection = geom;
            }

            instData = geometry;
            *expTypePtr = class(Geometry); // REVIEW: modified expType here vs.
                                           // a different one returned from getClassFromInst and set during preprocessing
         }
      }
      return instData;
   }

   virtual Class ::getClassFromInst(CQL2Instantiation instance, Class destType, Class * stylesClassPtr)
   {
      // TODO: refactor createGenericInstance
      CQL2SpecName specName = instance ? (CQL2SpecName)instance._class : null;
      Class c = specName ? eSystem_FindClass(__thisModule, specName.name) : destType;

      if(specName && specName.name)
      {
         if(!strcmp(specName.name, "Point"))
            c = class(GeoPoint);
         else if(!strcmp(specName.name, "MultiPolygon"))
            c = class(Array<Polygon>);
         else if(!strcmp(specName.name, "MultiLineString"))
            c = class(Array<LineString>);
         else if(!strcmp(specName.name, "MultiPoint"))
            c = class(Array<GeoPoint>);
         else if(!strcmp(specName.name, "GeometryCollection"))
            c = class(Array<Geometry>);
         else if(!strcmp(specName.name, "TimeInterval"))
            c = class(TimeIntervalSince1970);
         else
         {
            c = eSystem_FindClass(specName._class.module, specName.name);
            if(!c)
               c = eSystem_FindClass(specName._class.module.application, specName.name);
         }
      }
      else
         c = destType;
      // REVIEW: This causes warning for non-styles related stuff
      if(c && stylesClassPtr && !*stylesClassPtr &&
         c != class(PolygonContour) &&
         !eClass_IsDerived(c, class(Array)))
         *stylesClassPtr = c;
      return c;
   }

   private static void fixPointsContour(PolygonContour contour, bool flipCoords)
   {
      Array<GeoPoint> points = (Array<GeoPoint>)contour.points;
      if(flipCoords)
         flipPoints(points);
      // Drop repeated last polygon contour points
      if(points.count >= 2 && points[0].lon == points[points.count-1].lon && points[0].lat == points[points.count-1].lat)
         points.size--;
   }

   private static void flipPoints(Array<GeoPoint> points)
   {
      int i;
      for(i = 0; i < points.count; i++)
         points[i] = { points[i].lon, points[i].lat };
   }

   virtual void ::applyStyle(void * object, InstanceMask mSet, const FieldValue value, int unit, CQL2TokenType assignType);

   // NOTE: These are quite likely to get ridden of with more generic code...
   virtual const String ::stringFromMask(InstanceMask mask, Class c) { return null; }
   virtual InstanceMask ::maskFromString(const String s, Class c) { return 0; }
   virtual Array<Instance> ::accessSubArray(void * obj, InstanceMask mask) { return null; }
};


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

public Instance createGenericInstance(CQL2Instantiation inst, Class c, CQL2Evaluator evaluator, ExpFlags * flg)
{
   // FIXME: Buffer overruns for CSLabel rendering RBT_Europe
   //        if CartoStyle.ec module is set up before GraphicalElement.ec (based on project file order)
   // if(c && !strcmpi(c.name, "CSLabel")) return null;
   Instance instance = c && c.structSize ? eInstance_New(c) : null;
   if(instance)
   {
      if(c.type == normalClass)
         instance._refCount++;

      setGenericInstanceMembers(instance, inst, evaluator, flg, c);
      if(!flg->resolved && false)
      {
         deleteInstance(c, instance);
         instance = null;
      }
   }
   return instance;
}

private void setGenericBitMembers(CQL2ExpInstance expInst, uint64 * bits, CQL2Evaluator evaluator, ExpFlags * flg, Class stylesClass)
{
   if(expInst)
   {
      for(i : expInst.instance.members)
      {
         CQL2MemberInitList members = i;
         for(m : members)
         {
            CQL2MemberInit mInit = m;
            if(mInit.initializer)
            {
               CQL2Expression exp = mInit.initializer;
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

private void setGenericInstanceMembers(Instance object, CQL2Instantiation instance, CQL2Evaluator evaluator, ExpFlags * flg, Class stylesClass)
{
   bool unresolved = false;
   if(instance)
   {
      for(i : instance.members)
      {
         CQL2MemberInitList members = i;
         for(m : members)
         {
            CQL2MemberInit mInit = m;
            if(mInit.initializer)
            {
               CQL2Expression exp = mInit.initializer;
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
                     else if((destType.type == noHeadClass || destType.type == normalClass) && exp._class == class(CQL2ExpInstance))
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
                           void (* onCopy)(void *, void *, void *) = destType._vTbl[__eCVMethodID_class_OnCopy];
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
                        //we give CQL2ExpInstance this instData member and free it in destructor
                     }
                     else if(destType.type == structClass && exp._class == class(CQL2ExpInstance))
                     {
                        void (* setInstance)(void * o, void * v) = (void *)prop.Set;
                        if(val.i)    // REVIEW: Was getting a crash on GEFont...
                           setInstance(object,  (void *)(uintptr)val.i);
                     }
                     else if((destType.type == noHeadClass || destType.type == normalClass) && exp._class == class(CQL2ExpArray))
                     {
                        void (* setInstance)(void * o, void * v) = (void *)prop.Set;
                        CQL2ExpArray arrayExp = (CQL2ExpArray) exp;
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
                     else if((destType.type == noHeadClass || destType.type == normalClass) && exp._class == class(CQL2ExpInstance))
                     {
                        // TOFIX: We should probably be deleting existance value here?

                        *(Instance *)((byte *)object + mInit.offset) = (Instance)(uintptr)val.i;
                     }
                     else if(destType.type == structClass && exp._class == class(CQL2ExpInstance))
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

// ARRAY RELATION FUNCTIONS
static bool arrayfuncContainedby(Array<FieldValue> a, Array<FieldValue> b)
{
   bool result = arrayfuncContains(b, a);
   return result;
}

static bool arrayfuncContains(Array<FieldValue> a, Array<FieldValue> b)
{
   bool result = false;
   int i;
   if(a.count >= b.count)
      for(i = 0; i < b.count; i++)
      {
         result = false;
         if(a.Find(*(b.array + i)) != null)
            result = true;
         else
         {
            if(b[i].type.type == array)
            {
               int j;
               for(j = 0; j < a.count; j++)
               {
                  result = a[j].type.type == array ? arrayfuncContains((Array<FieldValue>)a[j].a, (Array<FieldValue>)b[i].a) : false;
                  if(result) break;
               }
            }
            else if(a[i].type == { integer, isDateTime = true } && b[i].type == { integer, isDateTime = true })
            {
               TimeIntervalSince1970 tmp0 = { (SecSince1970)a[i].i, unsetTime }, tmp1 = { (SecSince1970)b[i].i, unsetTime };
               TimeIntervalSince1970 * time0 = &tmp0, * time1 = &tmp1;
               result = time0->equals(time1);
            }
            else if(a[i].type.type == blob && b[i].type.type == blob)
            {
               Geometry * geometry = a[i].b;
               result = geometryEquals(geometry, b[i].b);
            }

            if(!result) break;
         }
      }
   return result;
}

//NOTE: FieldValue::OnCompare would not handle Geometry so avoid for array also, want to invoke S_* and T_* where appropriate
static bool arrayfuncEquals(Array<FieldValue> a, Array<FieldValue> b)
{
   bool result = false;
   int i;
   if(a.count == b.count)
   {
      for(i = 0; i < b.count; i++)
      {
         result = false;
         if(a[i].type.type == array && b[i].type.type == array)
            result = arrayfuncEquals((Array<FieldValue>)a[i].a, (Array<FieldValue>)b[i].a);
         else if(a[i].type.type == blob && b[i].type.type == blob)
         {
            Geometry * geometry = a[i].b;
            result = geometryEquals(geometry, b[i].b);
         }
         else if(a[i].type.type == b[i].type.type && a[i].type.type != nil)
         {
            if(a[i].type == { integer, isDateTime = true } && b[i].type == { integer, isDateTime = true })
            {
               TimeIntervalSince1970 tmp0 = { (SecSince1970)a[i].i, unsetTime }, tmp1 = { (SecSince1970)b[i].i, unsetTime };
               TimeIntervalSince1970 * time0 = &tmp0, * time1 = &tmp1;
               result = time0->equals(time1);
            }
            else
               result = a[i].OnCompare(b[i]) == 0;
         }
         /*if(a[i].type.type == text && b[i].type.type == text)
            result = !strcmpi(a[i].s, b[i].s);
         else if(a[i].type.type == integer && b[i].type.type == integer)
            result = a[i].i == b[i].i;
         else if(a[i].type.type == real && b[i].type.type == real)
            result = a[i].r == b[i].r;*/
         if(!result) break;
      }
      if(a.count == 0)
         result = true;
   }
   return result;
}

static bool arrayfuncOverlaps(Array<FieldValue> a, Array<FieldValue> b)
{
   bool result = false;
   int i;

   for(i = 0; i < b.count; i++)
   {
      if(a.Find(*(b.array + i)) != null)
      {
         result = true;
         break;
      }
      else
      {
         if(b[i].type.type == array)
         {
            int j;
            for(j = 0; j < a.count; j++)
            {
               result = a[j].type.type == array ? arrayfuncEquals((Array<FieldValue>)a[j].a, (Array<FieldValue>)b[i].a) : false;
               if(result) break;
            }
         }
         else if(a[i].type == { integer, isDateTime = true } && b[i].type == { integer, isDateTime = true })
         {
            TimeIntervalSince1970 tmp0 = { (SecSince1970)a[i].i, unsetTime }, tmp1 = { (SecSince1970)b[i].i, unsetTime };
            TimeIntervalSince1970 * time0 = &tmp0, * time1 = &tmp1;
            result = time0->equals(time1);
         }
         else if(a[i].type.type == blob && b[i].type.type == blob)
         {
            Geometry * geometry = a[i].b;
            result = geometryEquals(geometry, b[i].b);
         }
      }
   }
   return result;
}
