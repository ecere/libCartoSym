public import IMPORT_STATIC "EDA" // For FieldValue
public import "expressions"

public import "stringTools"
public import "cql2text.ec"
import "CartoSymHelper"

default:
extern int __ecereVMethodID_class_OnGetDataFromString;
extern int __ecereVMethodID_class_OnGetString;
static __attribute__((unused)) void dummy() { int a = 0; a.OnGetDataFromString(null); a.OnGetString(0,0,0); }
private:

public CQL2Expression parseCQL2Expression(const String string)
{
   CQL2Expression e = null;
   if(string)
   {
      CQL2Lexer lexer { };
      lexer.initString(string);
      e = CQL2Expression::parse(lexer);
      if(lexer.type == lexingError || (lexer.nextToken && lexer.nextToken.type != endOfInput))
         // This is a syntax error
         delete e;
      delete lexer;
   }
   return e;
}

public CartoSymExpression convertCQL2(CQL2Expression c)
{
   CartoSymExpression e = null;
   if(c._class == class(CQL2ExpOperation))
   {
      CQL2ExpOperation expOpCQL2 = (CQL2ExpOperation)c;
      if(expOpCQL2.op == power)
      {
         CartoSymExpIdentifier id { identifier = { string = CopyString("pow") } };
         CartoSymExpCall call { exp = id, arguments = { } };
         CartoSymExpression exp1 = convertCQL2(expOpCQL2.exp1);
         CartoSymExpression exp2 = convertCQL2(expOpCQL2.exp2);
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
            CartoSymExpression leftHand = convertCQL2(expOpCQL2.exp1);
            CartoSymExpression lower = andExpression.exp1 ? convertCQL2(andExpression.exp1) : null;
            CartoSymExpression upper = andExpression.exp2 ? convertCQL2(andExpression.exp2) : null;
            CartoSymExpBrackets brackets
            {
               list = { [ CartoSymExpOperation {
                  op = nb ? or : and,
                  exp1 = CartoSymExpOperation { op = nb ? smaller : greaterEqual, exp1 = leftHand,        exp2 = lower };
                  exp2 = CartoSymExpOperation { op = nb ? greater : smallerEqual, exp1 = leftHand.copy(), exp2 = upper };
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
               CartoSymExpOperation expOp { exp1 = convertCQL2(expOpCQL2.exp1), falseNullComparisons = true };
               expOp.exp2 = CartoSymExpString { string = unescaped };
               if(ci)
                  expOp.exp2 = CartoSymExpCall
                  {
                     exp = CartoSymExpIdentifier { identifier = { string = CopyString("casei") } },
                     arguments = { [ expOp.exp2 ] }
                  };
               if(ai)
                  expOp.exp2 = CartoSymExpCall
                  {
                     exp = CartoSymExpIdentifier { identifier = { string = CopyString("accenti") } },
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
               CartoSymExpCall call
               {
                  exp = CartoSymExpIdentifier { identifier = { string = CopyString("like") } },
                  arguments = { [
                     convertCQL2(expOpCQL2.exp1),
                     convertCQL2(expOpCQL2.exp2)
                  ] }
               };
               e = isNotLike ? CartoSymExpOperation { op = not, exp2 = call, falseNullComparisons = true } : call;
               delete unescaped;
            }
         }
      }
      else if(expOpCQL2.op == notIn)
      {
         CartoSymExpOperation expOp
         {
            op = not,
            exp2 = CartoSymExpBrackets
            {
               list = { [
                  CartoSymExpOperation
                  {
                     op = in,
                     exp1 = convertCQL2(expOpCQL2.exp1),
                     exp2 = convertCQL2(expOpCQL2.exp2)
                  }
               ] }
            },
            falseNullComparisons = true
         };
         e = expOp;
      }
      else
      {
         CartoSymExpOperation expOp { };

         if(expOpCQL2.exp1) expOp.exp1 = convertCQL2(expOpCQL2.exp1);
         if(expOpCQL2.exp2) expOp.exp2 = convertCQL2(expOpCQL2.exp2);

         expOp.op = operatorConversionMap[expOpCQL2.op];
         expOp.falseNullComparisons = !expOpCQL2.isExp;
         e = expOp;
      }
   }
   else if(c._class == class(CQL2ExpIdentifier))
   {
      CQL2ExpIdentifier expIdCQL2 = (CQL2ExpIdentifier)c;
      const String string = expIdCQL2.identifier ? expIdCQL2.identifier.string : null;
      int maxLen = string ? strlen(string) : 0;
      CartoSymExpMember lastMemberExp = null;

      while(maxLen)
      {
         char * dot = RSearchString(string, ".", maxLen, true, false);
         if(dot)
         {
            CartoSymExpMember memberExp;
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
            CartoSymExpIdentifier expId;
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
   else if(c._class == class(CQL2ExpString))
   {
      CQL2ExpString expStrCQL2 = (CQL2ExpString)c;
      CartoSymExpString expStr { };
      expStr.string = CopyString(expStrCQL2.string);
      e = expStr;
   }
   else if(c._class == class(CQL2ExpConstant))
   {
      CQL2ExpConstant expConCQL2 = (CQL2ExpConstant)c;
      CartoSymExpConstant expCon { };
      expCon.constant.OnCopy(expConCQL2.constant);
      e = expCon;
   }
   else if(c._class == class(CQL2ExpBrackets))
   {
      CQL2ExpBrackets brktsCQL2 = (CQL2ExpBrackets)c;
      CartoSymExpBrackets brkts { list = { } };
      for(el : brktsCQL2.list)
         brkts.list.Add(convertCQL2(el));
      e = brkts;
   }
   else if(c._class == class(CQL2ExpArray))
   {
      CQL2ExpArray cql2Array = (CQL2ExpArray)c;
      CartoSymExpArray array { elements = { } };
      for(el : cql2Array.elements)
         array.elements.Add(convertCQL2(el));
      e = array;
   }
   else if(c._class == class(CQL2Tuple))
      e = tupleToPointExpInstance((CQL2Tuple)c);// TOFIX: GeoPoint CartoSymExpInstance is a temporary stand-in for the multi-feature CQL2ExpCall
   else if(c._class == class(CQL2ExpCall))
      e = convertCQL2ExpCall((CQL2ExpCall)c);
   return e;
}

static CartoSymExpression convertCQL2ExpCall(CQL2ExpCall c)
{
   //handle temporal, Geometry, and later other functions
   CartoSymExpression e = null;
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
         CartoSymInstantiation inst = isInterval ? { _class = CartoSymSpecName { name = CopyString("TimeInterval")}} : null;
         CartoSymExpInstance expInst = isInterval ? { instance = inst } : null;
         for(i = 0; i < call.arguments.list.count; i++)
         {
            CQL2Expression arg = call.arguments.list[i];
            if(arg)
            {
               CartoSymExpression dateExp = null;
               String dateString = arg.toString(0);
               int len = strlen(dateString);
               if(dateString[0] == '\'' && dateString[len-1] == '\'')//if(strchr(dateString, 39))
                  dateExp = getDateConstantForInterval(dateString, i == 1);
               else
                  dateExp = CartoSymExpIdentifier { identifier = { string = CopyString(dateString) } };
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
         // CartoSymMemberInitList memberInitList { };
         CartoSymInstantiation subInst { };
         GeometryType gt = !strcmpi(idString, "BBOX") ? bbox : !strcmpi(idString, "POINT") ? point
            : !strcmpi(idString, "POLYGON") ? polygon : !strcmpi(idString, "MULTIPOLYGON") ? multiPolygon
            : !strcmpi(idString, "LINESTRING") ? lineString : !strcmpi(idString, "MULTILINESTRING") ? multiLineString
            : !strcmpi(idString, "MULTIPOINT") ? multiPoint : !strcmpi(idString, "GEOMETRYCOLLECTION") ? geometryCollection : none;
         CartoSymMemberInitList subList {};
         Array<CartoSymExpression> geomArguments {};
         CartoSymMemberInit minit = null;
         for(i = 0; i < call.arguments.list.count; i++)
         {
            CartoSymExpression arg = convertCQL2(call.arguments.list[i]);
            if(arg)
               geomArguments.Add(arg);
         }

         switch(gt)
         {
            case bbox:
            {
               for(i = 0; i < geomArguments.count; i+=2)
               {
                  CartoSymInstantiation pointInst {};
                  CartoSymMemberInitList pointList {};
                  CartoSymMemberInit minit1 { initializer = geomArguments[i].copy() };
                  CartoSymMemberInit minit2 { initializer = geomArguments[i+1].copy() };
                  pointList.Add(minit1);
                  pointList.Add(minit2);
                  pointInst.members = { [ pointList ] };
                  // pointInst._class = CartoSymSpecName { name = CopyString("GeoPoint") }; // Don't set this to avoid Geometry-fication
                  subList.setMember(class(GeoPoint), i == 0 ? "ll" : "ur", 0, true, CartoSymExpInstance { instance = pointInst/*, destType = class(GeoPoint)*/ } );
               }
               subInst._class = CartoSymSpecName { name = CopyString("GeoExtent") };
               //memberInitList.setMember(class(GeoExtent), "bbox", 0, true, CartoSymExpInstance { instance = subInst } );
               break;
            }
            case point:
            {
               e = (CartoSymExpInstance)geomArguments[0].copy();
               // FIXME: This is probably leaking the original POINT?
               ((CartoSymExpInstance)e).instance._class = CartoSymSpecName { name = CopyString("Point") };
               break;
            }
            case multiPoint:
            {
               CartoSymExpArray pointArray { elements = {} };
               CartoSymMemberInit minit;

               for(i = 0; i < geomArguments.count; i++)
               {
                  CartoSymExpBrackets brackets = geomArguments[i]._class == class(CartoSymExpBrackets) ? (CartoSymExpBrackets)geomArguments[i] : null;
                  if(brackets && brackets.list.GetCount())
                     pointArray.elements.Add(brackets.list[0].copy());
                  else
                     pointArray.elements.Add(geomArguments[i].copy());
               }
               minit = { initializer = pointArray };
               subList.Add(minit);
               subInst._class = CartoSymSpecName { name = CopyString("MultiPoint") };
               break;
            }
            case polygon: // NOTE: we may want results to look like Polygon { outer = { points = [ {40, 0}, {40,10}, {50,10}, {50,0}, {40,0} ] })
            {
               // TODO: function out to re-use for multi
               CartoSymExpArray contourArray { };
               for(i = 0; i < geomArguments.count; i++)
               {
                  // pass as copy?
                  CartoSymExpArray polyArray = (CartoSymExpArray)geomArguments[i];
                  setPolygonMemberInitList(polyArray, subList, contourArray, i);
               }
               if(contourArray.elements && contourArray.elements.GetCount())
               {
                  minit = { initializer = contourArray };
                  subList.Add(minit);
               }
               else
                  delete contourArray;
               subInst._class = CartoSymSpecName { name = CopyString("Polygon")};
               break;
            }
            case multiPolygon:
            {
               CartoSymExpArray polygonArray {};
               for(i = 0; i < geomArguments.count; i++)
               {
                  setMultiPolygonMemberInitList(geomArguments[i], polygonArray);
               }
               minit = { initializer = polygonArray };
               subInst._class = CartoSymSpecName { name = CopyString("MultiPolygon")};
               break;
            }
            case lineString:
            {
               CartoSymExpArray pointArray { elements = {} };
               // add points individually to exparray here./
               for(i = 0; i < geomArguments.count; i++)
                  pointArray.elements.Add(geomArguments[i].copy());

               minit = { initializer = pointArray };
               subInst._class = CartoSymSpecName { name = CopyString("LineString") };
               break;
            }
            case multiLineString:
            {
               CartoSymExpArray lineArray { elements = {} };
               for(i = 0; i < geomArguments.count; i++)
               {
                  CartoSymExpArray expArray = geomArguments[i]._class == class(CartoSymExpArray) ? (CartoSymExpArray)geomArguments[i] : null;
                  if(expArray)
                     setMultiLineMemberInitList(expArray, lineArray);
               }
               minit = { initializer = lineArray };
               subInst._class = CartoSymSpecName { name = CopyString("MultiLineString") };
               break;
            }
            case geometryCollection:
            {
               CartoSymExpArray expArray { elements = {} };
               for(i = 0; i < geomArguments.count; i++)
                  expArray.elements.Add(geomArguments[i].copy());

               minit = { initializer = expArray };
               subInst._class = CartoSymSpecName { name = CopyString("GeometryCollection") };
               break;
            }
         }
         //memberInitList.setMember(class(GeometryType), "type", 0, true, CartoSymExpConstant { constant = { i = gt, type = { integer } } });
         //instantiation.members = { [ subList ] }; //memberInitLIst
         if(gt != point)
         {
            if(minit && gt != polygon)
               subList.Add(minit);
            subInst.members = { [ subList ] };
            e = CartoSymExpInstance { instance = subInst }; //instantiation
         }
         else
         {
            delete subInst; delete subList;
         }
         geomArguments.Free(), delete geomArguments;
      }
      else // if(!strcmpi(id.identifier.string, "CASEI") || !strcmpi(id.identifier.string, "ACCENTI"))
      {
         CartoSymExpIdentifier CartoSymId { identifier = { } };
         CartoSymExpCall CartoSymCall { arguments = { } };
         const String mappedString = cql2ToCartoSymshapeTemporalName[idString];
         CartoSymId.identifier.string = mappedString ? CopyString(mappedString) : CopyString(idString);
         CartoSymCall.exp = CartoSymId;
         strlwr(CartoSymId.identifier.string);
         for(i = 0; i < call.arguments.list.count; i++)
         {
            //if(i != 0 || !isIntersects)
               CartoSymCall.arguments.Add(convertCQL2(call.arguments.list[i]));
         }
         e = CartoSymCall;
      }
   }
   return e;
}



static CartoSymExpression tupleToPointExpInstance(CQL2Tuple tuple)
{
   CartoSymExpression e = null;
   CartoSymMemberInitList memberInitList { };
   CartoSymInstantiation instantiation { /*_class = CartoSymSpecName { name = CopyString("GeoPoint") }*/ };
   int i;
   // for(i = tuple.list.count-1; i >= 0; i--)// switch to lat lon -- this is handledin CartoSym.ec now
   for(i = 0; i < tuple.list.count ; i++)
   {
      CartoSymExpression tExp = convertCQL2(tuple.list[i]);
      CartoSymMemberInit minit { initializer = tExp };
      memberInitList.Add(minit);
   }
   instantiation.members = { [ memberInitList ] };
   e = CartoSymExpInstance { instance = instantiation };
   return e;
}

public CQL2Expression convertCartoSymToCQL2(CartoSymExpression c)
{
   CQL2Expression e = null;
   if(c._class == class(CartoSymExpOperation))
   {
      CartoSymExpOperation CartoSymExpOp = (CartoSymExpOperation)c;
      // REVIEW THIS -- Is there really a CartoSym Syntax has DateTime as an identifier?
      CartoSymExpIdentifier id = CartoSymExpOp.exp1 && CartoSymExpOp.exp1._class == class(CartoSymExpIdentifier) ?
         (CartoSymExpIdentifier)CartoSymExpOp.exp1 : null;
      if(id && id.identifier && id.identifier.string && !strcmp(id.identifier.string, "DateTime"))
      {
         CQL2ExpCall expCall { };
         DateTime dt { };
         String expString = CartoSymExpOp.exp2 ? CartoSymExpOp.exp2.toString(0) : null;
         CQL2ExpString timeExp = null;
         char dateString[1024];
         dt.OnGetDataFromString(expString); // since the CartoSym format may be 'year = ', we can't directly use the string
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
      if(CartoSymExpOp.op == stringContains || CartoSymExpOp.op == stringStartsWith || CartoSymExpOp.op == stringEndsWith ||
         CartoSymExpOp.op == stringNotContains || CartoSymExpOp.op == stringNotStartsW || CartoSymExpOp.op == stringNotEndsW)
      {
         bool isNot = CartoSymExpOp.op == stringNotContains || CartoSymExpOp.op == stringNotStartsW || CartoSymExpOp.op == stringNotEndsW;
         CQL2ExpOperation expOp { op = isNot ? notLike : like };
         if(CartoSymExpOp.exp1) expOp.exp1 = convertCartoSymToCQL2(CartoSymExpOp.exp1);
         if(CartoSymExpOp.exp2)
         {
            bool ai = false, ci = false;
            CartoSymExpression exp2 = getExpStringForLike(CartoSymExpOp.exp2, &ai, &ci);

            if(exp2 && exp2._class == class(CartoSymExpString))
            {
               CartoSymExpString expString = (CartoSymExpString)exp2;
               if(expString.string)
               {
                  String s;
                  if(CartoSymExpOp.op == stringContains || CartoSymExpOp.op == stringNotContains)
                     s = PrintString('%', expString.string, '%');
                  else if(CartoSymExpOp.op == stringStartsWith || CartoSymExpOp.op == stringNotStartsW)
                     s = PrintString(expString.string, '%');
                  else
                     s = PrintString('%', expString.string);
                  expOp.exp2 = CQL2ExpString { string = s };

                  if(ci)
                     expOp.exp2 = CQL2ExpCall
                     {
                        exp = CQL2ExpIdentifier { identifier = { string = CopyString("CASEI") } },
                        arguments = { [ expOp.exp2 ] }
                     };
                  if(ai)
                     expOp.exp2 = CQL2ExpCall
                     {
                        exp = CQL2ExpIdentifier { identifier = { string = CopyString("ACCENTI") } },
                        arguments = { [ expOp.exp2 ] }
                     };
               }
            }
         }
         e = expOp;
      }
      else
      {
         CQL2Expression exp2 = CartoSymExpOp.exp2 ? convertCartoSymToCQL2(CartoSymExpOp.exp2) : null;
         // Checks to for NOT BETWEEN / LIKE / IN
         CQL2TokenType exp2Op = none;
         if(CartoSymExpOp.op == not)
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
            CQL2Expression exp1 = CartoSymExpOp.exp1 ? convertCartoSymToCQL2(CartoSymExpOp.exp1) : null;
            CQL2ExpOperation expOp
            {
               op = operatorConversionToCQL2Map[CartoSymExpOp.op],
               exp1 = exp1,
               exp2 = exp2
            };
            e = expOp;
         }
      }
   }
   else if(c._class == class(CartoSymExpIdentifier))
   {
      CartoSymExpIdentifier CartoSymExpId = (CartoSymExpIdentifier)c;
      CQL2ExpIdentifier expId { };
      expId.identifier = { string = CopyString(CartoSymExpId.identifier ? CartoSymExpId.identifier.string : null) };
      e = expId;
   }
   else if(c._class == class(CartoSymExpMember))
   {
      String id = null;
      while(c && c._class == class(CartoSymExpMember))
      {
         CartoSymExpMember memberExp = (CartoSymExpMember)c;
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
      if(c && c._class == class(CartoSymExpIdentifier))
      {
         CartoSymExpIdentifier CartoSymExpId = (CartoSymExpIdentifier)c;
         String idString = CartoSymExpId.identifier ? CartoSymExpId.identifier.string : null;
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
   else if(c._class == class(CartoSymExpString))
   {
      CartoSymExpString CartoSymExpStr = (CartoSymExpString)c;
      CQL2ExpString expStr { };
      expStr.string = CopyString(CartoSymExpStr.string);
      e = expStr;
   }
   else if(c._class == class(CartoSymExpConstant))
   {
      CartoSymExpConstant CartoSymExpCon = (CartoSymExpConstant)c;
      //todo: refactor date part to other function
      if(CartoSymExpCon.constant.type.isDateTime)
      {
         bool isTime = false;
         CQL2Expression dateExp = convertCartoSymToCQL2Date(CartoSymExpCon, &isTime);
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
      {
         CQL2ExpConstant expCon { };
         expCon.constant.OnCopy(CartoSymExpCon.constant);
         e = expCon;
      }
   }
   else if(c._class == class(CartoSymExpBrackets))
   {
      CartoSymExpBrackets CartoSymBrkts = (CartoSymExpBrackets)c;
      CQL2ExpBrackets brkts { list = { } };

      if(CartoSymBrkts.list)
         for(el : CartoSymBrkts.list)
         {
            CQL2Expression sub = convertCartoSymToCQL2(el);
            brkts.list.Add(sub);
         }
      e = brkts;
   }
   else if(c._class == class(CartoSymExpArray))
      e = CartoSymToCQL2Array(c, none, null);
   else if(c._class == class(CartoSymExpCall))
   {
      //handle DATE and TIMESTAMP, and later other functions
      CartoSymExpCall call = (CartoSymExpCall)c;
      CartoSymExpIdentifier id = call.exp && call.exp._class == class(CartoSymExpIdentifier) ? (CartoSymExpIdentifier)call.exp : null;
      String fnName = id && id.identifier ? id.identifier.string : null;
      CartoSymExpList arguments = call.arguments;
      if(fnName && arguments && arguments.list)
      {
         if(!strcmp(fnName, "pow") && arguments.list.count >= 2)
         {
            CQL2ExpOperation expOp
            {
               op = power,
               exp1 = convertCartoSymToCQL2(arguments[0]),
               exp2 = convertCartoSymToCQL2(arguments[1])
            };
            e = expOp;
         }
         else if(!strcmp(fnName, "like") && arguments.list.count >= 2)
         {
            CQL2ExpOperation expOp
            {
               op = like,
               exp1 = convertCartoSymToCQL2(arguments[0]);
               exp2 = convertCartoSymToCQL2(arguments[1]);
            };
            e = expOp; //CQL2ExpBrackets { list = { [ expOp ] } };
         }
         else
         {
            const String mappedString = CartoSymToCQL2shapeTemporalName[id.identifier.string];
            CQL2ExpIdentifier cql2Id { identifier = { string = mappedString ? CopyString(mappedString) : CopyString(id.identifier.string) } };
            CQL2ExpCall cql2Call { exp = cql2Id, arguments = { } };
            //S_* or T_*functions
            if(!mappedString)
               strupr(cql2Id.identifier.string);
            for(a : call.arguments.list)
               cql2Call.arguments.Add(convertCartoSymToCQL2(a));
            e = cql2Call;
         }
      }
   }
   else if(c._class == class(CartoSymExpInstance))
      e = CartoSymInstanceToWKT((CartoSymExpInstance)c, none, null);
   return e;
}

static CQL2Expression CartoSymToCQL2Array(CartoSymExpression c, GeometryType geomType, CQL2ExpList args)
{
   CQL2Expression e = null;
   CartoSymExpArray CartoSymArray = (CartoSymExpArray)c;
   CQL2ExpArray array { elements = { } };

   if(CartoSymArray.elements)
      for(el : CartoSymArray.elements)
      {
         CQL2Expression sub = el._class == class(CartoSymExpInstance) ? CartoSymInstanceToWKT((CartoSymExpInstance)el, geomType, null) : convertCartoSymToCQL2(el);
         if(args)
            args.list.Add(sub);
         else
            array.elements.Add(sub);
      }
   if(!args)
      e = array;
   else
      delete array;
   return e;
}

static CQL2Expression CartoSymInstanceToWKT(CartoSymExpInstance expInstance, GeometryType geomType, CQL2ExpList bboxArgs)
{
   CQL2Expression e = null;
   CartoSymInstantiation instantiation = expInstance.instance;
   CartoSymSpecName specName = (CartoSymSpecName)instantiation._class;
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
      CartoSymMemberInitList members = i;
      for(m : members)
      {
         CartoSymMemberInit mInit = m;
         CartoSymExpression initializer = mInit.initializer;
         if(initializer)
         {
            switch(gt)
            {
               case point: tuple.Add(convertCartoSymToCQL2(mInit.initializer)); break;
               case polygon: CartoSymToWKTPolygons(arguments, initializer); break;
               case multiPolygon:
                  if(initializer._class == class(CartoSymExpArray))
                  {
                     CartoSymExpArray arr = (CartoSymExpArray)initializer;
                     for(el : arr.elements)
                        arguments.list.Add(el._class == class(CartoSymExpInstance) ? CartoSymInstanceToWKT((CartoSymExpInstance)el, polygon, null) : { });
                  }
                  break;
               case lineString: CartoSymToCQL2Array(initializer, point, arguments); break;
               case multiPoint: CartoSymToCQL2Array(initializer, none, arguments); break;
               case multiLineString: CartoSymToCQL2Array(initializer, lineString, arguments); break;
               case geometryCollection: CartoSymToCQL2Array(initializer, none, arguments); break;
               case bbox: CartoSymInstanceToWKT((CartoSymExpInstance)initializer, none, arguments); break;
               default:
               {
                  if(isInterval)
                     arguments.list.Add(convertCartoSymToCQL2Date(initializer, null));
                  else
                     arguments.list.Add(convertCartoSymToCQL2(initializer));
                  break;
               }
            }
         }
      }
   }
   if(geomType == point)
      // REVIEW: CQL2Tuples are not CQL2Expressions -- they do not have val, destType, expType
      //         Potential for bad access.
      e = (CQL2Expression)tuple;
   else if(!bboxArgs)
   {
      CQL2ExpCall cql2ExpCall { arguments = arguments };
      if(specName)
      {
         const String sn = !strcmp(specName.name, "GeoExtent") ? "bbox" : !strcmp(specName.name, "TimeInterval") ? "interval" : specName.name;
            cql2ExpCall.exp = CQL2ExpIdentifier { identifier = { string = strupr(CopyString(sn)) } };
      }
      if(tuple)
         arguments.list.Add((CQL2Expression)tuple);
      e = cql2ExpCall;
   }
   return e;
}

static void CartoSymToWKTPolygons(CQL2ExpList arguments, CartoSymExpression initializer)
{
   // outer contour only (no other contours exist), meaning these are points
   if(initializer._class == class(CartoSymExpArray) && !arguments.list.count)
      arguments.list.Add(CartoSymToCQL2Array(initializer, point, null));
   // inner contours
   else if(initializer._class == class(CartoSymExpArray))
   {
      CartoSymExpArray arr = (CartoSymExpArray)initializer;
      for(x : arr.elements)
      {
         if(x._class == class(CartoSymExpInstance))
            CartoSymToWKTPointArguments(x, arguments);
      }
   }
   // outer contour if inner contours also present
   else if(initializer._class == class(CartoSymExpInstance))
      CartoSymToWKTPointArguments(initializer, arguments);
}

// pass arguments list to get points, maybe there's an alternative
static void CartoSymToWKTPointArguments(CartoSymExpression initializer, CQL2ExpList arguments)
{
   CartoSymInstantiation inst = ((CartoSymExpInstance)initializer).instance;
   for(i : inst.members)
   {
      CartoSymMemberInitList mem = i;
      for(mm : mem)
      {
         CartoSymMemberInit mInit = mm;
         if(mInit.initializer._class == class(CartoSymExpArray))
            arguments.list.Add(CartoSymToCQL2Array(mInit.initializer, point, null));
         else // this should not happen
            arguments.list.Add(convertCartoSymToCQL2(mInit.initializer));
      }
   }
}

CQL2Expression convertCartoSymToCQL2Date(CartoSymExpression CartoSymExp, bool * isT)
{
   CQL2Expression e = null;
   CartoSymExpConstant CartoSymExpCon = CartoSymExp._class == class(CartoSymExpConstant) ? (CartoSymExpConstant)CartoSymExp : null;
   if(CartoSymExpCon && CartoSymExpCon.constant.type.isDateTime)
   {
      DateTime dt = (SecSince1970)CartoSymExpCon.constant.i;
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

static Map<CQL2TokenType, CartoSymTokenType> operatorConversionMap
{ [
   { none, none },
   { smaller, smaller },
   { greater, greater },
   { not, not },
   { or, or },
   { and, and },
   { plus, plus },
   { minus, minus },
   { multiply, multiply },
   { divide, divide },
   { modulo, modulo },
   { equal, equal },
   { notEqual, notEqual },
   { smallerEqual, smallerEqual },
   { greaterEqual, greaterEqual },
   { intDivide, intDivide },
   { power, none }, // Map to pow() function call?
   { between, none }, // Will need special handling
   { notBetween, none }, // Will need special handling
   { like, none },    // Will need special handling
   { notLike, none },    // Will need special handling
   { in, in },
   { notIn, none } // Will need special handling
] };

static Map<CartoSymTokenType, CQL2TokenType> operatorConversionToCQL2Map
{ [
   { none, none },
   { smaller, smaller },
   { greater, greater },
   { not, not },
   { or, or },
   { and, and },
   { plus, plus },
   { minus, minus },
   { multiply, multiply },
   { divide, divide },
   { modulo, modulo },
   { equal, equal },
   { notEqual, notEqual },
   { smallerEqual, smallerEqual },
   { greaterEqual, greaterEqual },
   { intDivide, intDivide },
   { in, in }
] };

static CQL2TokenType opPrec[][9] =
{
   { '^' },
   { '*', '/' , intDivide, '%' },
   { '+', '-' },
   { in },
   { '<', '>', smallerEqual, greaterEqual },
   { equal, notEqual, is, like },
   { and },
   { or, not /* for not between */, between }
};

static define numPrec = sizeof(opPrec) / sizeof(opPrec[0]);

static bool isPrecedence(CQL2TokenType this, int l)
{
   if(this)
   {
      int o;
      for(o = 0; o < sizeof(opPrec[0]) / sizeof(opPrec[0][0]); o++)
      {
         CQL2TokenType op = opPrec[l][o];
         if(this == op)
            return true;
         else if(!op)
            break;
      }
   }
   return false;
}

public class CQL2Identifier : CQL2Node
{
public:
   String string;

   bool isValid()
   {
      if(string && string[0])
      {
         int i, nb;
         unichar ch;

         // NOTE: While we treat false, true, and null as identifiers, we can't support them even double-quoted.
         if(cql2StringTokens[string]) return false; // Avoid conflict with tokens
         for(i = 0; (ch = UTF8GetChar(string + i, &nb)); i += nb)
         {
            if(!(i ? isValidCQL2IdChar(ch) : isValidCQL2IdStart(ch) ))
               return false;
         }
         return true;
      }
      return false;
   }

   void print(File out, int indent, CQL2OutputOptions o)
   {
      // NOTE: according to the spec, can be quoteless also
      bool needsQuotes = string && !isValid();
      if(needsQuotes) out.Print('"');
      out.Print(string);
      if(needsQuotes) out.Print('"');
   }

   CQL2Identifier ::parse(CQL2Lexer lexer)
   {
      lexer.readToken();
      return { string = CopyString(lexer.token.text) };
   }

   CQL2Identifier copy()
   {
      CQL2Identifier id { string = CopyString(string) };
      return id;
   }

   ~CQL2Identifier()
   {
      delete string;
   }
};

// Expressions
public class CQL2Expression : CQL2Node
{
public:
   DataValue val;
   Class destType;
   Class expType;

   //virtual float compute();
   public virtual ExpFlags compute(FieldValue value, ECCSSEvaluator evaluator, ComputeType computeType, Class stylesClass);

   CQL2Expression ::parse(CQL2Lexer lexer)
   {
      //return CQL2ExpConditional::parse(lexer); // do we want this right now?
      CQL2Expression e = CQL2ExpOperation::parse(numPrec-1, lexer);
      if(lexer.type == lexingError ||
         lexer.type == syntaxError ||
         (lexer.nextToken && (lexer.nextToken.type == lexingError || lexer.nextToken.type == syntaxError)))
         delete e;
      return e;
   }
}

 // may eventually represent a class
public class CQL2ExpList : CQL2List<CQL2Expression>
{
public:
   CQL2ExpList ::parse(CQL2Lexer lexer)
   {
      return (CQL2ExpList)CQL2List::parse(class(CQL2ExpList), lexer, CQL2Expression::parse, ',');
   }

   CQL2ExpList copy()
   {
      CQL2ExpList e { };
      for(n : list)
         e.list.Add(n.copy());
      return e;
   }
}

public class CQL2Tuple : CQL2List<CQL2Expression>
{
public:

   CQL2Tuple copy()
   {
      return (CQL2Tuple)CQL2List::copy();
   }
   void print(File out, int indent, CQL2OutputOptions o)
   {
      Iterator<CQL2Expression> it { list };
      while(it.Next())
      {
         it.data.print(out, indent, o);
         if(list.GetNext(it.pointer))
            out.Print(" ");
      }
   }
}

static CQL2Expression parseSimplePrimaryExpression(CQL2Lexer lexer)
{
   if(lexer.peekToken().type == constant)
      return CQL2ExpConstant::parse(lexer);
   else if(lexer.nextToken.type == identifier)
   {
      CQL2ExpIdentifier exp = CQL2ExpIdentifier::parse(lexer);
      /*if(lexer.peekToken().type == '{')
      {
         CQL2SpecName spec { name = CopyString(exp.identifier.string) };
         delete exp;
         return CQL2ExpInstance::parse(spec, lexer);
      }*/
      return exp;
   }
   else if(lexer.nextToken.type == stringLiteral)
      return CQL2ExpString::parse(lexer);
   /*else if(lexer.nextToken.type == '{')
      return CQL2ExpInstance::parse(null, lexer);
   else if(lexer.nextToken.type == '(')
      return CQL2ExpArray::parse(lexer);*/
   else
   {
      // This could happen e.g., at the end of a list with next token being ']'
      return null;
   }
}

static CQL2Expression parsePrimaryExpression(CQL2Lexer lexer)
{
   if(lexer.peekToken().type == '(')
   {
      CQL2ExpList list;
      bool isIn = lexer.token.type == in;

      lexer.readToken();

      list = CQL2ExpList::parse(lexer);
      if(lexer.peekToken().type == ')')
         lexer.readToken();

      if(isIn || (list && (!list.list || !list.list.count || list.list.count > 1)))
         return CQL2ExpArray { elements = list };
      else
         return CQL2ExpBrackets { list = list };
   }
   else
      return parseSimplePrimaryExpression(lexer);
}

static CQL2Expression parsePostfixExpression(CQL2Lexer lexer)
{
   CQL2Expression exp = parsePrimaryExpression(lexer);
   while(exp) //true)
   {
      if(lexer.peekToken().type == '(')
         exp = CQL2ExpCall::parse(exp, lexer);
      else
         break;
   }
   return exp;
}

static CQL2Expression parseTupleOrUnaryExpression(CQL2Lexer lexer)
{
   CQL2Expression exp = null;
   CQL2Tuple tuple = null;
   while((exp = parseUnaryExpression(lexer)))
   {
      CQL2TokenType type = lexer.peekToken().type;
      if(type == CQL2Token::constant || type == CQL2Token::identifier || type == CQL2Token::stringLiteral || (lexer.wktContext > 0 && type.isUnaryOperator))
      {
         if(!tuple)
            tuple = { };
         tuple.Add(exp);
      }
      else if(tuple)
         tuple.Add(exp);
      else
         break;
   }
   return tuple ? (CQL2Expression)tuple : exp;
}

static CQL2Expression parseUnaryExpression(CQL2Lexer lexer)
{
   lexer.peekToken();
   if(lexer.nextToken.type.isUnaryOperator)
   {
      CQL2TokenType tokenType;
      CQL2Expression exp2;

      lexer.readToken();
      tokenType = lexer.token.type;
      exp2 = parseUnaryExpression(lexer);
      if(tokenType == minus && exp2 && exp2._class == class(CQL2ExpConstant))
      {
         CQL2ExpConstant c = (CQL2ExpConstant)exp2;
         if(c.constant.type.type == integer)
            c.constant.i *= -1;
         else
            c.constant.r *= -1;
         return c;
      }
      else
         return CQL2ExpOperation { op = tokenType, exp2 = exp2 };
   }
   else
      return parsePostfixExpression(lexer);
}

public class CQL2ExpConstant : CQL2Expression
{
public:
   FieldValue constant;

   void print(File out, int indent, CQL2OutputOptions o)
   {
      Class type = destType ? destType : expType;  // NOTE: Color expType get converted to integer during compute()...
      if(constant.type.format == hex && (type == class(int64) || type == class(int)))
         type = null;
      else if(type == class(double) || type == class(float))
         type = null;
      // TODO: Review for 32 bit and big-endian..
      else if(type && expType && (expType != class(int64) && expType != class(uint64)) && strcmp(type.dataTypeString, expType.dataTypeString))
         type = null;

      if(type)
      {
         const char *(* onGetString)(void *, void *, char *, void *, ObjectNotationType *) = type._vTbl[__ecereVMethodID_class_OnGetString];
         char tempString[1024];
         ObjectNotationType on = econ;
         const String s = onGetString(type, &constant.i, tempString, null, &on);
         if(s && (constant.type.format != hex || on == none))  // This (&& on == none) will force hex output for colors instead of expanded r, g, b
         {
            // TODO: Really need to clarify these rules here about adding brackets...
            bool addCurlies = on != none && type.type != systemClass && type.type != enumClass;
            if(addCurlies) out.Print("{ ");
            out.Print(s);
            if(addCurlies) out.Print(" }");
         }
         else if(constant.type.format == hex)
         {
            char number[64];
            sprintf(number,
               (__runtimePlatform == win32) ? "0x%06I64X" : "0x%06llX",
               constant.i);
            out.Print(number);
         }
         else
            out.Print(constant);
      }
      else out.Print(constant);
   }

   CQL2ExpConstant ::parse(CQL2Lexer lexer)
   {
      CQL2ExpConstant result = null;
      CQL2Token token = lexer.readToken();
      // check token, if starts with quote or contains comma... parse to know type, integer string etc,... set i s or r
      // no text here, use CQL2expstring

      if(isdigit(token.text[0]))
      {
         int multiplier = 1;
         int len = strlen(token.text);

         if(token.text[len-1] == 'K') multiplier = 1000;
         else if(token.text[len-1] == 'M') multiplier = 1000000;

         if(strchr(token.text, '.') ||
            ((token.text[0] != '0' || token.text[1] != 'x') && (strchr(token.text, 'E') || strchr(token.text, 'e'))))
         {
            result = { constant = { r = strtod(token.text, null) * multiplier, type.type = real } };
            if(strchr(token.text, 'E') || strchr(token.text, 'e'))
               result.constant.type.format = exponential;
         }
         else
         {
            result = { constant = { i = strtoll(token.text, null, 0) * multiplier, type.type = integer} };
            if(strstr(token.text, "0x"))
               result.constant.type.format = hex;
            else if(strstr(token.text, "b"))
               result.constant.type.format = binary;
            else if(token.text[0] == '0' && isdigit(token.text[1]))
               result.constant.type.format = octal;
         }
      }
      return result;
   }

   CQL2ExpConstant copy()
   {
      CQL2ExpConstant e { constant = constant, expType = expType, destType = destType };
      if(e.constant.type.type == text && e.constant.type.mustFree)
         e.constant.s = CopyString(e.constant.s);
      return e;
   }

   ~CQL2ExpConstant()
   {
      if(constant.type.mustFree == true && constant.type.type == text )
         delete constant.s;
   }
}

public class CQL2ExpString : CQL2Expression
{
public:
   String string;

   void print(File out, int indent, CQL2OutputOptions o)
   {
      String buf = copyEscapeCQL2(string);
      out.Print('\'', buf, '\'');
      delete buf;
   }

   CQL2ExpString ::parse(CQL2Lexer lexer)
   {
      int len;
      String s;
      lexer.readToken();
      len = strlen(lexer.token.text)-2;  // len source string length for UnescapeCString()
      s = new char[len+1];
      len = UnescapeCQL2String(s, lexer.token.text+1, len);
      s = renew s char[len+1];
      // memcpy(s, lexer.token.text+1, len);
      // s[len] = 0;
      return { string = s };
   }

   CQL2ExpString copy()
   {
      CQL2ExpString e { string = CopyString(string), expType = expType, destType = destType };
      return e;
   }

   ~CQL2ExpString()
   {
      delete string;
   }
}

public class CQL2ExpIdentifier : CQL2Expression
{
public:
   CQL2Identifier identifier;
   int fieldID;

   CQL2ExpIdentifier copy()
   {
      CQL2ExpIdentifier e
      {
         identifier = identifier.copy(),
         fieldID = fieldID, // TOCHECK: Should we copy fieldID here ?
         expType = expType, destType = destType
      };
      return e;
   }

   void print(File out, int indent, CQL2OutputOptions o)
   {
      identifier.print(out, indent, o);
   }

   CQL2ExpIdentifier ::parse(CQL2Lexer lexer)
   {
      return { identifier = CQL2Identifier::parse(lexer) };
   }

   CQL2ExpIdentifier()
   {
      fieldID = -1;
   }

   ~CQL2ExpIdentifier()
   {
      delete identifier;
   }
}

public class CQL2ExpOperation : CQL2Expression
{
public:
   CQL2TokenType op;
   CQL2Expression exp1, exp2;
   bool isExp;

   CQL2ExpOperation copy()
   {
      CQL2ExpOperation e
      {
         op = op,
         exp1 = exp1 ? exp1.copy() : null,
         exp2 = exp2 ? exp2.copy() : null,
         expType = expType, destType = destType
      };
      return e;
   }

   void print(File out, int indent, CQL2OutputOptions o)
   {
      CQL2ExpIdentifier exp2Id = exp2 && exp2._class == class(CQL2ExpIdentifier) ? (CQL2ExpIdentifier)exp2 : null;
      if(exp1) { exp1.print(out, indent, o); if(exp2) out.Print(" "); }
      if((op == equal || op == notEqual) && exp2Id && exp2Id.identifier && exp2Id.identifier.string && !strcmpi(exp2Id.identifier.string, "null"))
         out.Print(op == equal ? "IS" : "IS NOT");
      else
         op.print(out, indent, o);
      if(exp2) { if(exp1) out.Print(" "); exp2.print(out, indent, o); }
   }

   CQL2Expression ::parse(int prec, CQL2Lexer lexer)
   {
      CQL2Expression exp = (prec > 0) ? parse(prec-1, lexer) : parseTupleOrUnaryExpression(lexer);
      while(isPrecedence(lexer.peekToken().type, prec))
      {
         CQL2TokenType op = lexer.readToken().type;
         if(exp || op.isUnaryOperator)
         {
            if(op == not)
            {
               op = lexer.peekToken().type;
               if(op == between || op == like || op == in)
               {
                  CQL2ExpOperation expOp { exp1 = exp, op = op == between ? notBetween : op == like ? notLike : notIn };
                  lexer.readToken();
                  expOp.exp2 = (prec > 0) ? parse(prec-1, lexer) : parseUnaryExpression(lexer);
                  exp = expOp;
               }
               else
                  // Syntax error
                  delete exp;
            }
            else
            {
               CQL2ExpOperation expOp { exp1 = exp, op = op };
               if(op == is)
               {
                  if(lexer.peekToken().type == not)
                  {
                     expOp.op = notEqual;
                     lexer.readToken();
                  }
                  else
                     expOp.op = equal;
                  expOp.isExp = true;
               }
               expOp.exp2 = (prec > 0) ? parse(prec-1, lexer) : parseUnaryExpression(lexer);
               exp = expOp;
               if(!expOp.exp2)
                  delete exp; // Syntax error: missing 2nd operand
            }
         }
         else
            // Syntax error: binary operator with only right operand
            delete exp;
      }
      return exp;
   }

   ~CQL2ExpOperation()
   {
      delete exp1;
      delete exp2;
   }
}

 // for subexpression
public class CQL2ExpBrackets : CQL2Expression
{
public:
   CQL2ExpList list;

   void print(File out, int indent, CQL2OutputOptions o)
   {
      out.Print("(");
      if(list) list.print(out, indent, o);
      out.Print(")");
   }

   CQL2ExpBrackets copy()
   {
      return CQL2ExpBrackets { list = list.copy(), expType = expType, destType = destType };
   }

   ~CQL2ExpBrackets()
   {
      delete list;
   }
}

 // for function
public class CQL2ExpCall : CQL2Expression
{
public:
   CQL2Expression exp;
   CQL2ExpList arguments;

   void print(File out, int indent, CQL2OutputOptions o)
   {
      if(exp) exp.print(out, indent, o);
      out.Print("(");
      if(arguments) arguments.print(out, indent, o);
      out.Print(")");
   }

   CQL2ExpCall copy()
   {
      CQL2ExpCall e { exp = exp.copy(), arguments = arguments.copy(), expType = expType, destType = destType };
      return e;
   }

   CQL2ExpCall ::parse(CQL2Expression e, CQL2Lexer lexer)
   {
      /* NOTE: for WKT types, increment a wktContext counter variable, and decrement once we get out
      then the unaryOperator check in parseTupleOrPostfix would only be considered if that is > 0*/
      CQL2ExpCall exp;
      bool isWKT = false;
      String str = e.toString(0);
      lexer.readToken();

      if(!strcmpi(str, "polygon") || !strcmpi(str, "point") || !strcmpi(str, "bbox") ||
         !strcmpi(str, "lineString") || !strcmpi(str, "multipolygon") || !strcmpi(str, "multipoint") ||
         !strcmpi(str, "multilinestring"))
      {
         isWKT = true;
         lexer.wktContext++;
      }
      exp = CQL2ExpCall { exp = e, arguments = CQL2ExpList::parse(lexer) };
      if(lexer.peekToken().type == ')')
         lexer.readToken();
      if(isWKT)
         lexer.wktContext--;
      delete str;
      return exp;
   }

   ~CQL2ExpCall()
   {
      delete exp;
      delete arguments;
   }
}

public class CQL2ExpArray : CQL2Expression
{
public:
   CQL2ExpList elements;
   Array array;

   CQL2ExpArray copy()
   {
      CQL2ExpArray e { elements = elements.copy(), expType = expType, destType = destType };
      return e;
   }

   CQL2ExpArray ::parse(CQL2Lexer lexer)
   {
      // Currently handled by parsePrimaryExpression() instead
      CQL2ExpArray exp { };
      lexer.readToken();
      exp.elements = CQL2ExpList::parse(lexer);
      if(lexer.peekToken().type == ')')
         lexer.readToken();
      return exp;
   }

   void print(File out, int indent, CQL2OutputOptions o)
   {
      Class type = expType ? expType : destType;
      ClassTemplateArgument * a = type ? &type.templateArgs[0] : null;
      Class et = a ? a->dataTypeClass : null;
      int count = elements ? elements.GetCount() : 0;

      if(!count || !et || (et.type != structClass && et.type != normalClass))
      {
         out.Print("(");
         if(elements) elements.print(out, indent, o);
         out.Print(")");
      }
      else
      {
         int i = 0;

         out.PrintLn("(");
         indent++;
         for(e : elements)
         {
            printIndent2(indent, out);
            e.print(out, indent, o);
            if(++i < count) out.Print(",");
            out.PrintLn("");
         }
         indent--;
         printIndent2(indent, out);
         out.Print(")");
      }
   }

   ~CQL2ExpArray()
   {
      delete elements;
      delete array;
   }
}

// S_* and T_* function name map to avoid unnecessarily long !strcmp checks
Map<String, const String> CartoSymToCQL2shapeTemporalName
{ [
   //spatial
   { "intersects", "S_INTERSECTS" },
   { "equals", "S_EQUALS" },
   { "crosses", "S_CROSSES" },
   { "contains", "S_CONTAINS" },
   { "within", "S_WITHIN" },
   { "disjoint", "S_DISJOINT" },
   { "touches", "S_TOUCHES" },
   { "overlaps", "S_OVERLAPS" },
   //temporal function
   { "t_after", "T_AFTER" },
   { "t_before", "T_BEFORE" },
   { "t_equals", "T_EQUALS" },
   { "t_intersects", "T_INTERSECTS" },
   { "t_contains", "T_CONTAINS" },
   { "t_disjoint", "T_DISJOINT" },
   { "t_during", "T_DURING" },
   { "t_finishedby", "T_FINISHEDBY" },
   { "t_finishes", "T_FINISHES" },
   { "t_meets", "T_MEETS" },
   { "t_metby", "T_METBY" },
   { "t_overlappedby", "T_OVERLAPPEDBY" },
   { "t_overlaps", "T_OVERLAPS" },
   { "t_startedby", "T_STARTEDBY" },
   { "t_starts", "T_STARTS" }
] };

// S_* and T_* function name map to avoid unnecessarily long !strcmp checks
Map<String, const String> cql2ToCartoSymshapeTemporalName
{ [
   //spatial
   { "S_INTERSECTS", "intersects" },
   { "S_EQUALS", "equals" },
   { "S_CROSSES", "crosses" },
   { "S_CONTAINS", "contains" },
   { "S_WITHIN", "within" },
   { "S_DISJOINT", "disjoint"  },
   { "S_TOUCHES", "touches" },
   { "S_OVERLAPS", "overlaps" },
   //temporal
   { "T_AFTER", "t_after" },
   { "T_BEFORE", "t_before" },
   { "T_EQUALS", "t_equals" },
   { "T_INTERSECTS", "t_intersects" },
   { "T_CONTAINS", "t_contains"},
   { "T_DISJOINT", "t_disjoint" },
   { "T_DURING", "t_during" },
   { "T_FINISHEDBY", "t_finishedby"},
   { "T_FINISHES", "t_finishes" },
   { "T_MEETS", "t_meets" },
   { "T_METBY", "t_metby" },
   { "T_OVERLAPPEDBY", "t_overlappedby"},
   { "T_OVERLAPS", "t_overlaps" },
   { "T_STARTEDBY", "t_startedby" },
   { "T_STARTS", "t_starts" }
] };
