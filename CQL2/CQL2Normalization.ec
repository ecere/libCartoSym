// This module adapts the CQL2 expressions for writing to standard CQL2,
// including converting geometry to WKT representation with parentheses (as CQL2ExpCall)
public import IMPORT_STATIC "ecrt"
public import IMPORT_STATIC "SFGeometry"
public import IMPORT_STATIC "SFCollections"  // For TemporalOptions

private:

import "CQL2Expressions"
                                                                // Use false for standard CQL2-Text/WKT
public CQL2Expression cql2FromGeometry(const Geometry geometry, bool forComputation)
{
   CQL2Expression result;
   CQL2ExpInstance instance { instData = (void *)geometry, instanceFlags = { resolved = true }, expType = class(Geometry) };
   buildInstanceFromInstData(instance, null, null);
   instance.instData = null;

   if(forComputation)
      result = instance;
   else
   {
      result = normalizeCQL2(instance);
      delete instance;
   }
   return result;
}

public CQL2Expression normalizeCQL2(CQL2Expression c)
{
   CQL2Expression e = null;

   if(c._class == class(CQL2ExpIdentifier) || c._class == class(CQL2ExpString))
      e = c.copy();
   else if(c._class == class(CQL2ExpOperation))
   {
      CQL2ExpOperation cql2ExpOp = (CQL2ExpOperation)c;
      // REVIEW THIS -- Is there really a CS Syntax has DateTime as an identifier?
      CQL2ExpIdentifier id = cql2ExpOp.exp1 && cql2ExpOp.exp1._class == class(CQL2ExpIdentifier) ?
         (CQL2ExpIdentifier)cql2ExpOp.exp1 : null;
      if(id && id.identifier && id.identifier.string && !strcmp(id.identifier.string, "DateTime"))
      {
         CQL2ExpCall expCall { };
         DateTime dt { };
         String expString = cql2ExpOp.exp2 ? cql2ExpOp.exp2.toString(0) : null;
         CQL2ExpString timeExp = null;
         char dateString[1024];
         dt.OnGetDataFromString(expString); // since the CSCSS format may be 'year = ', we can't directly use the string
         expCall.arguments = {};
         if(dt.hour || dt.minute || dt.second)
         {
            expCall.exp = CQL2ExpIdentifier { identifier = { string = CopyString("TIMESTAMP")}};
            sprintf(dateString, "%04d-%02d-%02dT%02d:%02d:%02dZ" , dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second);
         }
         else
         {
            expCall.exp = CQL2ExpIdentifier { identifier = { string = CopyString("DATE")}};
            sprintf(dateString, "%04d-%02d-%02d" , dt.year, dt.month, dt.day);
         }
         timeExp = { string = CopyString(dateString) };
         expCall.arguments.Add(timeExp);
         e = expCall;
         delete expString;
      }
      else
      // ---------
      if(cql2ExpOp.op == stringContains || cql2ExpOp.op == stringStartsWith || cql2ExpOp.op == stringEndsWith ||
         cql2ExpOp.op == stringNotContains || cql2ExpOp.op == stringNotStartsW || cql2ExpOp.op == stringNotEndsW)
      {
         bool isNot = cql2ExpOp.op == stringNotContains || cql2ExpOp.op == stringNotStartsW || cql2ExpOp.op == stringNotEndsW;
         CQL2ExpOperation expOp { op = isNot ? notLike : like };
         if(cql2ExpOp.exp1) expOp.exp1 = normalizeCQL2(cql2ExpOp.exp1);
         if(cql2ExpOp.exp2)
         {
            bool ai = false, ci = false;
            CQL2Expression exp2 = getExpStringForLike(cql2ExpOp.exp2, &ai, &ci);

            if(exp2 && exp2._class == class(CQL2ExpString))
            {
               CQL2ExpString expString = (CQL2ExpString)exp2;
               if(expString.string)
               {
                  String s;
                  if(cql2ExpOp.op == stringContains || cql2ExpOp.op == stringNotContains)
                     s = PrintString('%', expString.string, '%');
                  else if(cql2ExpOp.op == stringStartsWith || cql2ExpOp.op == stringNotStartsW)
                     s = PrintString(expString.string, '%');
                  else
                     s = PrintString('%', expString.string);
                  expOp.exp2 = CQL2ExpString { string = s };

                  if(ci)
                     expOp.exp2 = CQL2ExpCall
                     {
                        exp = CQL2ExpIdentifier { identifier = { string = CopyString("casei") } },
                        arguments = { [ expOp.exp2 ] }
                     };
                  if(ai)
                     expOp.exp2 = CQL2ExpCall
                     {
                        exp = CQL2ExpIdentifier { identifier = { string = CopyString("accenti") } },
                        arguments = { [ expOp.exp2 ] }
                     };
               }
            }
         }
         e = expOp;
      }
      else
      {
         CQL2Expression exp2 = cql2ExpOp.exp2 ? normalizeCQL2(cql2ExpOp.exp2) : null;
         // Checks to for NOT BETWEEN / LIKE / IN
         CQL2TokenType exp2Op = none;
         if(cql2ExpOp.op == not)
         {
            if(exp2._class == class(CQL2ExpBrackets))
            {
               // Remove the extra bracket from !({exp1} IN {exp2}) for NOT IN
               CQL2ExpBrackets brkts = (CQL2ExpBrackets)exp2;
               CQL2Expression be = brkts.list ? brkts.list[0] : null;
               if(be && be._class == class(CQL2ExpOperation))
               {
                  exp2Op = ((CQL2ExpOperation)be).op;
                  if(exp2Op == like || exp2Op == between || exp2Op == in)
                  {
                     brkts.list.TakeOut(be);
                     delete exp2;
                     exp2 = be;
                  }
               }
            }
            else if(exp2._class == class(CQL2ExpOperation))
            {
               exp2Op = ((CQL2ExpOperation)exp2).op;
            }
         }
         if(exp2Op == like || exp2Op == between || exp2Op == in)
         {
            ((CQL2ExpOperation)exp2).op = exp2Op == like ? notLike : exp2Op == between ? notBetween : notIn;
            e = exp2;
         }
         else
         {
            CQL2Expression exp1 = cql2ExpOp.exp1 ? normalizeCQL2(cql2ExpOp.exp1) : null;
            CQL2ExpOperation expOp
            {
               op = cql2ExpOp.op,
               exp1 = exp1,
               exp2 = exp2
            };
            e = expOp;
         }
      }
   }
   else if(c._class == class(CQL2ExpMember))
   {
      String id = null;
      while(c && c._class == class(CQL2ExpMember))
      {
         CQL2ExpMember memberExp = (CQL2ExpMember)c;
         if(memberExp.member)
         {
            if(id)
            {
               String newID = PrintString(memberExp.member.string, ".", id);
               delete id;
               id = newID;
            }
            else
               id = CopyString(memberExp.member.string);
         }
         c = memberExp.exp;
      }
      if(c && c._class == class(CQL2ExpIdentifier))
      {
         CQL2ExpIdentifier cql2ExpId = (CQL2ExpIdentifier)c;
         String idString = cql2ExpId.identifier ? cql2ExpId.identifier.string : null;
         if(id)
         {
            String newID = PrintString(idString, ".", id);
            delete id;
            id = newID;
         }
         else
            id = CopyString(idString);
      }
      e = CQL2ExpIdentifier { identifier = { string = id } };
   }
   else if(c._class == class(CQL2ExpConstant))
   {
      CQL2ExpConstant cql2ExpCon = (CQL2ExpConstant)c;
      //todo: refactor date part to other function
      if(cql2ExpCon.constant.type.isDateTime)
      {
         bool isTime = false;
         CQL2Expression dateExp = normalizeCQL2Date(cql2ExpCon, &isTime);
         CQL2ExpCall expCall
         {
            exp = CQL2ExpIdentifier
            {
               identifier = { string = CopyString(isTime ? "TIMESTAMP" : "DATE") }
            },
            arguments = { [ dateExp ] }
         };
         e = expCall;
      }
      else
         e = c.copy();
   }
   else if(c._class == class(CQL2ExpBrackets))
   {
      CQL2ExpBrackets cscssBrkts = (CQL2ExpBrackets)c;
      CQL2ExpBrackets brkts { list = { } };

      if(cscssBrkts.list)
         for(el : cscssBrkts.list)
         {
            CQL2Expression sub = normalizeCQL2(el);
            brkts.list.Add(sub);
         }
      e = brkts;
   }
   else if(c._class == class(CQL2ExpArray))
   {
      e = normalizeCQL2Array((CQL2ExpArray)c, none, null);
   }
   else if(c._class == class(CQL2ExpCall))
   {
      //handle DATE and TIMESTAMP, and later other functions
      CQL2ExpCall call = (CQL2ExpCall)c;
      CQL2ExpIdentifier id = call.exp && call.exp._class == class(CQL2ExpIdentifier) ? (CQL2ExpIdentifier)call.exp : null;
      String fnName = id && id.identifier ? id.identifier.string : null;
      CQL2ExpList arguments = call.arguments;
      if(fnName && arguments && arguments.list)
      {
         if(!strcmp(fnName, "pow") && arguments.list.count >= 2)
         {
            CQL2ExpOperation expOp
            {
               op = power,
               exp1 = normalizeCQL2(arguments[0]),
               exp2 = normalizeCQL2(arguments[1])
            };
            e = expOp;
         }
         else if(!strcmp(fnName, "like") && arguments.list.count >= 2)
         {
            CQL2ExpOperation expOp
            {
               op = like,
               exp1 = normalizeCQL2(arguments[0]);
               exp2 = normalizeCQL2(arguments[1]);
            };
            e = expOp; //CQL2ExpBrackets { list = { [ expOp ] } };
         }
         else
         {
            CQL2ExpIdentifier cql2Id { identifier = { string = CopyString(id.identifier.string) } };
            CQL2ExpCall cql2Call { exp = cql2Id, arguments = { } };
            //S_*, T_* or A_* functions
            strupr(cql2Id.identifier.string);
            for(a : call.arguments.list)
               cql2Call.arguments.Add(normalizeCQL2(a));
            e = cql2Call;
         }
      }
   }
   else if(c._class == class(CQL2ExpInstance))
      e = normalizeWKT((CQL2ExpInstance)c, none, null);
   return e;
}

static CQL2Expression normalizeCQL2Array(CQL2ExpArray a, GeometryType geomType, CQL2ExpList args)
{
   CQL2Expression e = null;
   CQL2ExpArray array { elements = { } };

   if(a.elements)
      for(el : a.elements)
      {
         CQL2Expression e = el, a;
         if(e._class == class(CQL2ExpInstance))
         {
            a = normalizeWKT((CQL2ExpInstance)el, geomType, null);
         }
         else
            a = normalizeCQL2(el);
         if(args)
            args.list.Add(a);
         else
            array.elements.Add(a);
      }
   if(!args)
      e = array;
   else
      delete array;
   return e;
}

static CQL2Expression normalizeCQL2Date(CQL2ExpConstant dateExp, bool * isT)
{
   CQL2Expression e = null;
   if(dateExp && dateExp.constant.type.isDateTime)
   {
      DateTime dt = (SecSince1970)dateExp.constant.i;
      bool isTime = dt.hour || dt.minute || dt.second;
      TemporalOptions tOptions
      {
         year = true, month = true, day = true,
         hour = isTime, minute = isTime, second = isTime
      };
      e = CQL2ExpString { string = printTime(tOptions, dt) };
      if(isT) *isT = isTime;
   }
   return e;
}

static CQL2Expression normalizeWKT(CQL2ExpInstance expInstance, GeometryType geomType, CQL2ExpList bboxArgs)
{
   CQL2Instantiation instantiation = expInstance.instance;
   CQL2Expression e = null;
   CQL2SpecName specName = instantiation._class;
   CQL2ExpList arguments = null;
   CQL2Tuple tuple = null;
   GeometryType gt = geomType;
   bool geomRelated = false, isInterval = false;

   if(specName && specName.name)
   {
      const String sn = specName.name;
      if(!strcmp(sn, "Point"))
         gt = point;
      else if(!strcmp(sn, "Polygon"))
         gt = polygon;
      else if(!strcmp(sn, "LineString"))
         gt = lineString;
      else if(!strcmp(sn, "MultiPoint"))
         gt = multiPoint;
      else if(!strcmp(sn, "MultiLineString"))
         gt = multiLineString;
      else if(!strcmp(sn, "MultiPolygon"))
         gt = multiPolygon;
      else if(!strcmp(sn, "GeometryCollection"))
         gt = geometryCollection;
      else if(!strcmp(sn, "GeoExtent"))
         gt = bbox;
      else if(!strcmp(sn, "PolygonContour") || !strcmp(sn, "GeoPoint"))
         geomRelated = true;
      else if(!strcmp(sn, "TimeInterval"))
         isInterval = true;
   }
   else
      gt = geomType;

   if(gt == none && !bboxArgs && (!specName || geomRelated)) gt = point;

   if(gt == point)
      tuple = { };
   if(geomType != point)
      arguments = bboxArgs ? bboxArgs : { };

   for(i : instantiation.members)
   {
      CQL2MemberInitList members = i;
      for(m : members)
      {
         CQL2MemberInit mInit = m;
         CQL2Expression initializer = mInit ? mInit.initializer : null;
         if(initializer)
         {
            CQL2ExpInstance iInstance = initializer._class == class(CQL2ExpInstance) ? (CQL2ExpInstance)initializer : null;
            CQL2ExpArray iArray = initializer._class == class(CQL2ExpArray) ? (CQL2ExpArray)initializer : null;
            CQL2ExpConstant iConstant = initializer._class == class(CQL2ExpConstant) ? (CQL2ExpConstant)initializer : null;

            switch(gt)
            {
               case point: tuple.Add(normalizeCQL2(mInit.initializer)); break;
               case polygon:
                  // REVIEW: Clarify why initializer for polygon can be either Array or Instance
                  if(initializer._class == class(CQL2ExpArray))
                  {
                     normalizeWKTPolygonsArray((CQL2ExpArray)initializer, arguments);
                  }
                  else if(initializer._class == class(CQL2ExpInstance))
                  {
                     // outer contour if inner contours also present
                     normalizeWKTPointArguments((CQL2ExpInstance)initializer, arguments);
                  }
                  break;
               case multiPolygon:
                  if(iArray)
                  {
                     for(el : iArray.elements)
                     {
                        CQL2Expression e;
                        if(el._class == class(CQL2ExpInstance))
                        {
                           CQL2ExpInstance element = (CQL2ExpInstance)el;
                           e = normalizeWKT(element, polygon, null);
                        }
                        else
                           e = { };
                        arguments.list.Add(e);
                     }
                  }
                  break;
               // FIXME: Passing this 'arguments' parmaeter is a messy pattern
               case lineString:
                  if(iArray)
                     normalizeCQL2Array(iArray, point, arguments);
                  break;
               case multiPoint:
                  if(iArray)
                     normalizeCQL2Array(iArray, none, arguments);
                  break;
               case multiLineString:
                  if(iArray)
                     normalizeCQL2Array(iArray, lineString, arguments);
                  break;
               case geometryCollection:
                  if(iArray)
                     normalizeCQL2Array(iArray, none, arguments);
                  break;
               case bbox:
                  if(iInstance)
                     normalizeWKT(iInstance, none, arguments);
                  break;
               default:
               {
                  CQL2Expression e;
                  if(isInterval && iConstant)
                     e = normalizeCQL2Date(iConstant, null);
                  else
                     e = normalizeCQL2(initializer);
                  arguments.list.Add(e);
                  break;
               }
            }
         }
      }
   }
   if(geomType == point)
   {
      // REVIEW: CQL2Tuples are not CQL2Expressions -- they do not have val, destType, expType
      //         Potential for bad access.
      e = (CQL2Expression)tuple;
   }
   else if(!bboxArgs)
   {
      CQL2ExpCall cql2ExpCall { arguments = arguments };
      if(specName)
      {
         const String sn = !strcmp(specName.name, "GeoExtent") ? "bbox" : !strcmp(specName.name, "TimeInterval") ? "interval" : specName.name;
            cql2ExpCall.exp = CQL2ExpIdentifier { identifier = { string = strupr(CopyString(sn)) } };
      }
      if(tuple)
      {
         arguments.list.Add((CQL2Expression)tuple);
      }
      e = cql2ExpCall;
   }
   return e;
}

// FIXME: These functions are messy
static void normalizeWKTPolygonsArray(CQL2ExpArray arr, CQL2ExpList arguments)
{
   // outer contour only (no other contours exist), meaning these are points
   if(!arguments.list.count)
      arguments.list.Add(normalizeCQL2Array(arr, point, null));
   // inner contours
   else
   {
      for(x : arr.elements)
      {
         if(x._class == class(CQL2ExpInstance))
            normalizeWKTPointArguments((CQL2ExpInstance)x, arguments);
      }
   }
}

// pass arguments list to get points, maybe there's an alternative
static void normalizeWKTPointArguments(CQL2ExpInstance initializer, CQL2ExpList arguments)
{
   CQL2Instantiation inst = initializer.instance;
   for(i : inst.members)
   {
      CQL2MemberInitList mem = i;
      for(mm : mem)
      {
         CQL2MemberInit mInit = mm;
         CQL2Expression e = mInit ? mInit.initializer : null, a;
         if(e._class == class(CQL2ExpArray))
         {
            a = normalizeCQL2Array((CQL2ExpArray)e, point, null);
         }
         else // this should not happen
            a = normalizeCQL2(e);
         arguments.list.Add(a);
      }
   }
}
