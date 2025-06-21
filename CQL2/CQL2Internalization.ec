// This module adapts the CQL2 expressions for use with the evaluator directly
public import IMPORT_STATIC "ecrt"
public import IMPORT_STATIC "SFGeometry"

private:

import "CQL2Expressions"

public CQL2Expression convertToInternalCQL2(CQL2Expression c)
{
   CQL2Expression e = null;
   if(c._class == class(CQL2ExpString) || c._class == class(CQL2ExpConstant) ||
      c._class == class(CQL2ExpMember) || c._class == class(CQL2ExpIndex) ||
      c._class == class(CQL2ExpInstance) || c._class == class(CQL2ExpConditional) )
      e = c.copy();
   else if(c._class == class(CQL2ExpOperation))
   {
      CQL2ExpOperation expOpCQL2 = (CQL2ExpOperation)c;
      if(expOpCQL2.op == power)
      {
         CQL2ExpIdentifier id { identifier = { string = CopyString("pow") } };
         CQL2ExpCall call { exp = id, arguments = { } };
         CQL2Expression exp1 = convertToInternalCQL2(expOpCQL2.exp1);
         CQL2Expression exp2 = convertToInternalCQL2(expOpCQL2.exp2);
         call.arguments.Add(exp1);
         call.arguments.Add(exp2);
         e = call;
      }
      else if(expOpCQL2.op == between || expOpCQL2.op == notBetween)
      {
         bool nb = expOpCQL2.op == notBetween;
         CQL2ExpOperation andExpression =
            expOpCQL2.exp2 && expOpCQL2.exp2._class == class(CQL2ExpOperation) ?
            (CQL2ExpOperation)expOpCQL2.exp2 : null;
         if(expOpCQL2.exp1 && andExpression)
         {
            CQL2Expression leftHand = convertToInternalCQL2(expOpCQL2.exp1);
            CQL2Expression lower = andExpression.exp1 ? convertToInternalCQL2(andExpression.exp1) : null;
            CQL2Expression upper = andExpression.exp2 ? convertToInternalCQL2(andExpression.exp2) : null;
            CQL2ExpBrackets brackets
            {
               list = { [ CQL2ExpOperation {
                  op = nb ? or : and,
                  exp1 = CQL2ExpOperation { op = nb ? smaller : greaterEqual, exp1 = leftHand,        exp2 = lower };
                  exp2 = CQL2ExpOperation { op = nb ? greater : smallerEqual, exp1 = leftHand.copy(), exp2 = upper };
                  falseNullComparisons = true;
               } ] }
            };
            e = brackets;
         }
      }
      else if((expOpCQL2.op == like || expOpCQL2.op == notLike) && expOpCQL2.exp2)
      {
         CQL2ExpString expString = null;
         CQL2Expression exp2 = expOpCQL2.exp2;
         bool ai = false, ci = false;

         while(exp2 && exp2._class == class(CQL2ExpCall))
         {
            CQL2ExpCall cc = (CQL2ExpCall)exp2;
            const String id = cc.exp && ((CQL2ExpIdentifier)cc.exp).identifier ? ((CQL2ExpIdentifier)cc.exp).identifier.string : null;
            if(id && cc.arguments && cc.arguments.GetCount() >= 1)
            {
                     if(!strcmpi(id, "accenti")) ai = true, exp2 = cc.arguments[0];
                else if(!strcmpi(id, "casei"))  ci = true, exp2 = cc.arguments[0];
                else
                  break;
            }
            else
               break;
         }

         if(exp2 && exp2._class == class(CQL2ExpString))
         {
            expString = (CQL2ExpString)exp2;
         }

         if(expString)
         {
            const String s = expString.string;
            bool quoted = false;
            bool foundQ = false, startP = false, endP = false, middleP = false;
            bool isNotLike = expOpCQL2.op == notLike;
            String unescaped = s ? getLikeStringPattern(s, &quoted, &foundQ, &startP, &endP, &middleP) : null;

            if(s && !foundQ && !middleP)
            {
               CQL2ExpOperation expOp { exp1 = convertToInternalCQL2(expOpCQL2.exp1), falseNullComparisons = true };
               expOp.exp2 = CQL2ExpString { string = unescaped };
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

               expOp.op = (startP && endP) ?
                  (isNotLike ? stringNotContains : stringContains) :
                  startP ? (isNotLike ? stringNotEndsW : stringEndsWith) :
                  endP ? (isNotLike ? stringNotStartsW : stringStartsWith) :
                  (isNotLike ? notEqual : equal);
               e = expOp;
            }
            else
            {
               CQL2ExpCall call
               {
                  exp = CQL2ExpIdentifier { identifier = { string = CopyString("like") } },
                  arguments = { [
                     convertToInternalCQL2(expOpCQL2.exp1),
                     convertToInternalCQL2(expOpCQL2.exp2)
                  ] }
               };
               e = isNotLike ? CQL2ExpOperation { op = not, exp2 = call, falseNullComparisons = true } : call;
               delete unescaped;
            }
         }
      }
      else if(expOpCQL2.op == notIn)
      {
         CQL2ExpOperation expOp
         {
            op = not,
            exp2 = CQL2ExpBrackets
            {
               list = { [
                  CQL2ExpOperation
                  {
                     op = in,
                     exp1 = convertToInternalCQL2(expOpCQL2.exp1),
                     exp2 = convertToInternalCQL2(expOpCQL2.exp2)
                  }
               ] }
            },
            falseNullComparisons = true
         };
         e = expOp;
      }
      else
      {
         CQL2ExpOperation expOp { };

         if(expOpCQL2.exp1) expOp.exp1 = convertToInternalCQL2(expOpCQL2.exp1);
         if(expOpCQL2.exp2) expOp.exp2 = convertToInternalCQL2(expOpCQL2.exp2);

         expOp.op = expOpCQL2.op;
         expOp.falseNullComparisons = !expOpCQL2.isExp;
         e = expOp;
      }
   }
   else if(c._class == class(CQL2ExpIdentifier))
   {
      CQL2ExpIdentifier expIdCQL2 = (CQL2ExpIdentifier)c;
      const String string = expIdCQL2.identifier ? expIdCQL2.identifier.string : null;
      int maxLen = string ? strlen(string) : 0;
      CQL2ExpMember lastMemberExp = null;

      while(maxLen)
      {
         char * dot = RSearchString(string, ".", maxLen, true, false);
         if(dot)
         {
            CQL2ExpMember memberExp;
            int len = maxLen - (int)(dot - string);
            char * s = new char[len + 1];
            memcpy(s, dot + 1, len);
            s[len] = 0;

            memberExp = { member = { string = s } };
            if(lastMemberExp)
               lastMemberExp.exp = memberExp;
            else
               e = memberExp;

            lastMemberExp = memberExp;
            maxLen = (int)(dot - string) - 1;
         }
         else
         {
            CQL2ExpIdentifier expId;
            char * s;
            dot = strchr(string, '.');
            if(dot)
            {
               int len = (int)(dot - string);
               s = new char[len + 1];
               memcpy(s, string, len);
               s[len] = 0;
            }
            else
               s = CopyString(string);

            expId = { identifier = { string = s } };
            if(lastMemberExp)
               lastMemberExp.exp = expId;
            else
               e = expId;

            maxLen = 0;
         }
      }
   }
   else if(c._class == class(CQL2ExpBrackets))
   {
      e = convertCQL2Brackets((CQL2ExpBrackets)c, false);
   }
   else if(c._class == class(CQL2ExpArray))
   {
      CQL2ExpArray cql2Array = (CQL2ExpArray)c;
      CQL2ExpArray array { elements = { } };
      for(el : cql2Array.elements)
         array.elements.Add(convertToInternalCQL2(el));
      e = array;
   }
   else if(c._class == class(CQL2Tuple))
      e = tupleToPointExpInstance((CQL2Tuple)c);// TOFIX: GeoPoint CQL2ExpInstance is a temporary stand-in for the multi-feature CQL2ExpCall
   else if(c._class == class(CQL2ExpCall))
      e = convertCQL2ExpCall((CQL2ExpCall)c);
   return e;
}

static CQL2Expression convertCQL2ExpCall(CQL2ExpCall c)
{
   //handle temporal, Geometry, and later other functions
   CQL2Expression e = null;
   CQL2ExpCall call = c;
   CQL2ExpIdentifier id = call.exp._class == class(CQL2ExpIdentifier) ? (CQL2ExpIdentifier)call.exp : null;
   if(id && id.identifier && id.identifier.string)
   {
      // convert all to TimeInterval, leave 'end' unset for non-intervals
      int i;
      const String idString = id.identifier.string;
      bool isInterval = !strcmpi(idString, "INTERVAL");
      if(!strcmpi(idString, "DATE") || !strcmpi(idString, "TIMESTAMP") || isInterval)
      {
         CQL2Instantiation inst = isInterval ? { _class = CQL2SpecName { name = CopyString("TimeInterval")}} : null;
         CQL2ExpInstance expInst = isInterval ? { instance = inst } : null;
         for(i = 0; i < call.arguments.list.count; i++)
         {
            CQL2Expression arg = call.arguments.list[i];
            if(arg)
            {
               CQL2Expression dateExp = null;
               String dateString = arg.toString(0);
               int len = strlen(dateString);
               if(dateString[0] == '\'' && dateString[len-1] == '\'')//if(strchr(dateString, 39))
                  dateExp = getDateConstantForInterval(dateString, i == 1);
               else
                  dateExp = CQL2ExpIdentifier { identifier = { string = CopyString(dateString) } };
               delete dateString;
               if(call.arguments.list.count == 1)
                  e = dateExp;
               else
                  expInst.setMember(i == 0 ? "start" : "end", 0, true, dateExp );
            }
         }
         if(isInterval)
            e = expInst;
      }
      else if(!strcmpi(idString, "BBOX") || !strcmpi(idString, "POLYGON") || !strcmpi(idString, "POINT")
         || !strcmpi(idString, "MULTIPOLYGON") || !strcmpi(idString, "MULTIPOINT")
         || !strcmpi(idString, "LINESTRING") || !strcmpi(idString, "MULTILINESTRING")
         || !strcmpi(idString, "GEOMETRYCOLLECTION"))
      {
         // CQL2MemberInitList memberInitList { };
         CQL2Instantiation subInst { };
         GeometryType gt = !strcmpi(idString, "BBOX") ? bbox : !strcmpi(idString, "POINT") ? point
            : !strcmpi(idString, "POLYGON") ? polygon : !strcmpi(idString, "MULTIPOLYGON") ? multiPolygon
            : !strcmpi(idString, "LINESTRING") ? lineString : !strcmpi(idString, "MULTILINESTRING") ? multiLineString
            : !strcmpi(idString, "MULTIPOINT") ? multiPoint : !strcmpi(idString, "GEOMETRYCOLLECTION") ? geometryCollection : none;
         CQL2MemberInitList subList {};
         Array<CQL2Expression> geomArguments {};
         CQL2MemberInit minit = null;
         for(i = 0; i < call.arguments.list.count; i++)
         {
            CQL2Expression arg = convertToInternalCQL2(call.arguments.list[i]);
            if(arg)
               geomArguments.Add(arg);
         }

         switch(gt)
         {
            case bbox:
            {
               for(i = 0; i < geomArguments.count; i+=2)
               {
                  CQL2Instantiation pointInst {};
                  CQL2MemberInitList pointList {};
                  CQL2MemberInit minit1 { initializer = geomArguments[i].copy() };
                  CQL2MemberInit minit2 { initializer = geomArguments[i+1].copy() };
                  pointList.Add(minit1);
                  pointList.Add(minit2);
                  pointInst.members = { [ pointList ] };
                  // pointInst._class = CQL2SpecName { name = CopyString("GeoPoint") }; // Don't set this to avoid Geometry-fication
                  subList.setMember(class(GeoPoint), i == 0 ? "ll" : "ur", 0, true, CQL2ExpInstance { instance = pointInst/*, destType = class(GeoPoint)*/ } );
               }
               subInst._class = CQL2SpecName { name = CopyString("GeoExtent") };
               //memberInitList.setMember(class(GeoExtent), "bbox", 0, true, CQL2ExpInstance { instance = subInst } );
               break;
            }
            case point:
            {
               e = (CQL2ExpInstance)geomArguments[0].copy();
               // FIXME: This is probably leaking the original POINT?
               ((CQL2ExpInstance)e).instance._class = CQL2SpecName { name = CopyString("Point") };
               break;
            }
            case multiPoint:
            {
               CQL2ExpArray pointArray { elements = {} };
               CQL2MemberInit minit;

               for(i = 0; i < geomArguments.count; i++)
               {
                  CQL2ExpBrackets brackets = geomArguments[i]._class == class(CQL2ExpBrackets) ? (CQL2ExpBrackets)geomArguments[i] : null;
                  if(brackets && brackets.list.GetCount())
                     pointArray.elements.Add(brackets.list[0].copy());
                  else
                     pointArray.elements.Add(geomArguments[i].copy());
               }
               minit = { initializer = pointArray };
               subList.Add(minit);
               subInst._class = CQL2SpecName { name = CopyString("MultiPoint") };
               break;
            }
            case polygon: // NOTE: we may want results to look like Polygon { outer = { points = [ {40, 0}, {40,10}, {50,10}, {50,0}, {40,0} ] })
            {
               // TODO: function out to re-use for multi
               CQL2ExpArray contourArray { };
               for(i = 0; i < geomArguments.count; i++)
               {
                  // pass as copy?
                  CQL2ExpArray polyArray = (CQL2ExpArray)geomArguments[i];
                  setPolygonMemberInitList(polyArray, subList, contourArray, i);
               }
               if(contourArray.elements && contourArray.elements.GetCount())
               {
                  minit = { initializer = contourArray };
                  subList.Add(minit);
               }
               else
                  delete contourArray;
               subInst._class = CQL2SpecName { name = CopyString("Polygon")};
               break;
            }
            case multiPolygon:
            {
               CQL2ExpArray polygonArray {};
               for(i = 0; i < geomArguments.count; i++)
               {
                  setMultiPolygonMemberInitList(geomArguments[i], polygonArray);
               }
               minit = { initializer = polygonArray };
               subInst._class = CQL2SpecName { name = CopyString("MultiPolygon")};
               break;
            }
            case lineString:
            {
               CQL2ExpArray pointArray { elements = {} };
               // add points individually to exparray here./
               for(i = 0; i < geomArguments.count; i++)
                  pointArray.elements.Add(geomArguments[i].copy());

               minit = { initializer = pointArray };
               subInst._class = CQL2SpecName { name = CopyString("LineString") };
               break;
            }
            case multiLineString:
            {
               CQL2ExpArray lineArray { elements = {} };
               for(i = 0; i < geomArguments.count; i++)
               {
                  CQL2ExpArray expArray = geomArguments[i]._class == class(CQL2ExpArray) ? (CQL2ExpArray)geomArguments[i] : null;
                  if(expArray)
                     setMultiLineMemberInitList(expArray, lineArray);
               }
               minit = { initializer = lineArray };
               subInst._class = CQL2SpecName { name = CopyString("MultiLineString") };
               break;
            }
            case geometryCollection:
            {
               CQL2ExpArray expArray { elements = {} };
               for(i = 0; i < geomArguments.count; i++)
                  expArray.elements.Add(geomArguments[i].copy());

               minit = { initializer = expArray };
               subInst._class = CQL2SpecName { name = CopyString("GeometryCollection") };
               break;
            }
         }
         //memberInitList.setMember(class(GeometryType), "type", 0, true, CQL2ExpConstant { constant = { i = gt, type = { integer } } });
         //instantiation.members = { [ subList ] }; //memberInitLIst
         if(gt != point)
         {
            if(minit && gt != polygon)
               subList.Add(minit);
            subInst.members = { [ subList ] };
            e = CQL2ExpInstance { instance = subInst }; //instantiation
         }
         else
         {
            delete subInst; delete subList;
         }
         geomArguments.Free(), delete geomArguments;
      }
      else // if(!strcmpi(id.identifier.string, "CASEI") || !strcmpi(id.identifier.string, "ACCENTI"))
      {
         CQL2ExpIdentifier cscssId { identifier = { } };
         CQL2ExpCall cscssCall { arguments = { } };
         bool isArray = !strcmpi(idString, "A_CONTAINS") || !strcmpi(idString, "A_EQUALS") ||
            !strcmpi(idString, "A_OVERLAPS") || !strcmpi(idString, "A_CONTAINEDBY"); // NOTE: keep arrays containing 1 element as expArray, not expBracket
         cscssId.identifier.string = CopyString(idString);
         cscssCall.exp = cscssId;
         strlwr(cscssId.identifier.string);
         for(i = 0; i < call.arguments.list.count; i++)
         {
            //if(i != 0 || !isIntersects)
            CQL2Expression arg = call.arguments.list[i];
            CQL2Expression converted = (isArray && arg._class == class(CQL2ExpBrackets)) ? convertCQL2Brackets((CQL2ExpBrackets)arg, true) : convertToInternalCQL2(arg);
            cscssCall.arguments.Add(converted);
         }
         e = cscssCall;
      }
   }
   return e;
}

static CQL2Expression convertCQL2Brackets(CQL2ExpBrackets brktsCQL2, bool isArray)
{
   CQL2Expression e = null;
   CQL2ExpBrackets brkts = !isArray ? { list = { } } : null;
   CQL2ExpArray expArray = isArray ? { elements = { } } : null;
   for(el : brktsCQL2.list)
   {
      if(isArray) expArray.elements.Add(convertToInternalCQL2(el));
      else brkts.list.Add(convertToInternalCQL2(el));
   }
   e = isArray ? expArray : brkts;
   return e;
}

CQL2Expression tupleToPointExpInstance(CQL2Tuple tuple)
{
   CQL2Expression e = null;
   CQL2MemberInitList memberInitList { };
   CQL2Instantiation instantiation { /*_class = CQL2SpecName { name = CopyString("GeoPoint") }*/ };
   int i;

   for(i = 0; i < tuple.list.count ; i++)
   {
      CQL2Expression tExp = convertToInternalCQL2(tuple.list[i]);
      CQL2MemberInit minit { initializer = tExp };
      memberInitList.Add(minit);
   }
   instantiation.members = { [ memberInitList ] };
   e = CQL2ExpInstance { instance = instantiation };
   return e;
}

