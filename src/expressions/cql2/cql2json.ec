//cql2json set up classes as with geojsonfeature
//https://github.com/opengeospatial/styles-and-symbology/blob/main/1-core/schemas/CartoSym-JSON.schema.json
//https://github.com/opengeospatial/ogcapi-features/blob/master/cql2/standard/schema/cql2.json

// CQL2JSON Support

public import IMPORT_STATIC "ecere"
public import IMPORT_STATIC "EDA" // For FieldValue
public import "expressions"
import "CartoSymHelper"
import "geoJSON"

public CartoSymExpression parseCQL2JSONExpression(const String string)
{
   CartoSymExpression result = null;
   if(string)
   {
      TempFile f { buffer = (byte *)string, size = strlen(string) };
      result = parseCQL2JSONExpressionFile(f);
      f.StealBuffer();
      delete f;
   }
   return result;
}

public CartoSymExpression parseCQL2JSONExpressionFile(File f)
{
   CartoSymExpression result = null;
   if(f)
   {
      JSONParser parser { f = f };
      FieldValue jsonDoc {};
      if(parser.GetObject(class(FieldValue), (void**)&jsonDoc) == success)
         result = convertCQL2JSON(jsonDoc);

      jsonDoc.OnFree();
      delete parser;
   }
   return result;
}

// fieldvalue contains the json document
static CartoSymExpression convertCQL2JSON(FieldValue value)
{
   CartoSymExpression result = null;

   switch(value.type.type)
   {
      case integer:
      case real:
      {
         CartoSymExpConstant expConstant { constant = { value.type } }; //OnCopy instead?

         if(value.type.type == integer)
            expConstant.constant.i = value.i;
         else
            expConstant.constant.r = value.r;
         result = expConstant;
         break;
      }
      case text:
      {
         result = CartoSymExpString { string = CopyString(value.s) };
         break;
      }
      case array:
      {
         Array<FieldValue> values = (Array<FieldValue>)value.a;
         CartoSymExpArray array { elements = {} };
         for(v : values)
         {
            CartoSymExpression e = convertCQL2JSON(v);
            array.elements.Add(e);
         }
         result = array;
         break;
      }
      case map:
      {
         result = convertCQL2JSONMap(value);
         break;
      }
      case blob:
      {
         break;
      }
      case nil:
      {
         result = CartoSymExpIdentifier { identifier = { string = CopyString("null") } };
         break;
      }
   }
   return result;
}

enum CQL2JSONSpecialOperationType { none, function, like, between, isNull };

static CartoSymExpression convertCQL2JSONMap(FieldValue value)
{
   CartoSymExpression result = null;
   MapIterator<String, FieldValue> it { map = value.m };

   if(it.Index("property", false))
   {
      FieldValue v = it.data;
      if(v.type.type == text)
      {
         char * id = v.s, * dot = strchr(id, '.');

         if(dot) *dot = 0;
         result = CartoSymExpIdentifier { identifier = { string = CopyString(id) } };

         while(dot)
         {
            id = dot + 1;
            result = CartoSymExpMember { exp = result, member = { string = CopyString(id) } };
            dot = strchr(id, '.');
            if(dot) *dot = 0;
         }
      }
   }
   else if(it.Index("timestamp", false) || it.Index("date", false))
   {
      FieldValue v = it.data;
      if(v.type.type == text)
      {
         DateTime dt {};
         dt.OnGetDataFromString(v.s);
         result = CartoSymExpConstant { constant = { type = { integer, isDateTime = true }, i = (int64)(SecSince1970)dt }};
      }
   }
   else if(it.Index("interval", false))
   {
      FieldValue v = it.data;
      if(v.type.type == array && v.a.count == 2)
      {
         CartoSymInstantiation inst { _class = CartoSymSpecName { name = CopyString("TimeInterval")}};
         CartoSymExpInstance expInst { instance = inst };
         bool i;
         for(i = false; i <= true; i++)
         {
            CartoSymExpression dateExp = null;
            if(v.a[i].type.type == text)
            {
               String dateString = v.a[i].s;
               dateExp = getDateConstantForInterval(dateString, i);
            }
            else if(v.a[i].type.type == map) // property
               dateExp = convertCQL2JSON(v.a[i]);
            if(dateExp)
               expInst.setMember(i == 0 ? "start" : "end", 0, true, dateExp );
         }
         result = expInst;
      }
   }
   else if(it.Index("op", false))
   {
      FieldValue opValue = it.data; // make case insensitive?
      FieldValue argsValue { };
      Array<FieldValue> args = (it.Index("args", false) && (argsValue = it.data, argsValue.type.type == array)) ? argsValue.a : null;
      CQL2JSONTokenType jt = opValue.type.type == text ? cql2JSONStringTokens[opValue.s] : CQL2JSONTokenType::none;
      CQL2JSONSpecialOperationType opType = none;
      CartoSymTokenType op = jsonOperatorConversionMap[jt];

      if(opValue.type.type == text && opValue.s && (op == none || op == endOfInput))
      {
         // REVIEW: Couldn't we just default top opType = function?
         if((op == none || op == endOfInput) && !opValue.s[1])
         {
            switch(opValue.s[0])
            {
               case '=': op = equal; break;
               case '<': op = smaller; break;
               case '>': op = greater; break;
               case '+': op = plus; break;
               case '-': op = minus; break;
               case '*': op = multiply; break;
               case '/': op = divide; break;

               case '^': opType = function; break;
               // TODO: conditionals (supported in CartoSym-JSON as an extension)
            }
         }
         else if(!strcmpi(opValue.s, "isNull"))
            opType = isNull;
         else if(!strcmpi(opValue.s, "like"))
            opType = like;
         else if(!strcmpi(opValue.s, "between"))
            opType = between;
         else
            opType = function;
      }
      if(opType == function)
      {
         CartoSymExpCall expCall { };
         const String fn = functionMap[opValue.s];
         if(!fn)
            fn = opValue.s;
         expCall.exp = CartoSymExpIdentifier { identifier = { string = strlwr(CopyString(fn)) } };

         result = expCall;
         if(args && args.count) // Some function may not take any arguments
         {
            int i = 0;
            CartoSymExpList arguments { };

            expCall.arguments = arguments;

            for(i = 0; i < args.count && result; i++)
            {
               CartoSymExpression argExp = convertCQL2JSON(args[i]);
               if(argExp)
                  arguments.Add(argExp);
               else
               {
                  result = null;
                  break;
               }
            }
            if(!result)
               delete expCall;
         }
      }
      else if(opType == between)
      {
         if(args && args.count == 3)
         {
            CartoSymExpression e = convertCQL2JSON(args[0]);
            CartoSymExpBrackets betweenExp { list = { [
               CartoSymExpOperation {
                  exp1 = CartoSymExpOperation {
                     exp1 = e, op = greaterEqual, falseNullComparisons = true,
                     exp2 = convertCQL2JSON(args[1]) },
                  op = and,
                  exp2 = CartoSymExpOperation {
                     exp1 = e.copy(), op = smallerEqual, falseNullComparisons = true,
                     exp2 = convertCQL2JSON(args[2]) }
            } ] } };
            result = betweenExp;
         }
      }
      else if(opType == like)
      {
         if(args && args.count == 2)
            result = convertCQL2JSONLikeOp(args);
      }
      else if(opType == isNull)
      {
         if(args.count == 1)
         {
            CartoSymExpOperation expOp {
               exp1 = convertCQL2JSON(args[0]),
               op = equal,
               exp2 = CartoSymExpIdentifier { identifier = { string = CopyString("null") } }
            };
            result = expOp;
         }
      }
      else if(args && args.count && args.count <= 2) // All operators have at least one argument
      {
         CartoSymExpression e0 = convertCQL2JSON(args[0]);
         CartoSymExpression e1 = args.count > 1 ? convertCQL2JSON(args[1]) : null;

         if(!e0 || (!e1 && args.count > 1))
            delete e0, delete e1;
         else
         {
            CartoSymExpOperation expOp { op = op };
            if(args.count == 2)
               expOp.exp1 = e0;
            else if(op == not && e0._class == class(CartoSymExpOperation))
               e0 = CartoSymExpBrackets { list = { [ e0 ] } };  // TODO: bracket and/or
            // TODO: Handle notEqual etc. ?
            expOp.exp2 = e1 ? e1 : e0;
            result = expOp;
         }
      }
   }
   else if(it.Index("bbox", false))
   {
      FieldValue coordinates = it.data;
      Array<double> bboxArray = (Array<double>)buildDoubleArrayFromFV(coordinates, 1);
      // FIXME: We eventually will want to support 3-dimensional BBoxes with 6 values
      if(bboxArray && bboxArray.count == 4)
      {
         GeoExtent extent;
         Array<double> p1a { [ bboxArray[0], bboxArray[1] ] };
         Array<double> p2a { [ bboxArray[2], bboxArray[3] ] };
         GeoPoint p1 {};
         GeoPoint p2 {};
         Geometry * geometry = new0 Geometry[1];
         generatePointFromCoordinates(p1, p1a, 0, 0, null, false, null, 0, null);
         generatePointFromCoordinates(p2, p2a, 0, 0, null, false, null, 0, null);
         extent = { p1, p2 };
         geometry->type = bbox;
         geometry->bbox = extent;
         delete p1a; delete p2a;
         result = CartoSymExpInstance { instData = geometry, instanceFlags = { resolved = true }, expType = class(Geometry) };
         buildInstanceFromInstData(result, null, null);
      }
      delete bboxArray;
   }
   else if(it.Index("type", false))
   {
      FieldValue v = it.data;
      const String idString = v.type.type == text ? v.s : null;
      GeometryType gt = !strcmpi(idString, "POINT") ? point : !strcmpi(idString, "POLYGON") ? polygon
                      : !strcmpi(idString, "MULTIPOLYGON") ? multiPolygon : !strcmpi(idString, "LINESTRING") ? lineString
                      : !strcmpi(idString, "MULTILINESTRING") ? multiLineString : !strcmpi(idString, "MULTIPOINT") ? multiPoint
                      : !strcmpi(idString, "GEOMETRYCOLLECTION") ? geometryCollection : none;
      if(gt != none && it.Index(gt == geometryCollection ? "geometries" : "coordinates", false))
         result = convertCQL2JSONGeometry(gt, it.data);
   }
   return result;
}

static CartoSymExpression convertCQL2JSONLikeOp(Array<FieldValue> args)
{
   CartoSymExpression result = null;
   CartoSymExpression e1 = convertCQL2JSON(args[0]), e2 = convertCQL2JSON(args[1]);
   bool ai = false, ci = false;
   CartoSymExpString expString = (CartoSymExpString)getExpStringForLike(e2, &ai, &ci);

   if(expString && expString._class == class(CartoSymExpString))
   {
      const String s = expString.string;
      bool quoted = false, foundQ = false, startP = false, endP = false, middleP = false;
      String unescaped = s ? getLikeStringPattern(s, &quoted, &foundQ, &startP, &endP, &middleP) : null;

      if(s && !foundQ && !middleP)
      {
         CartoSymExpOperation expOp { exp1 = e1, falseNullComparisons = true, exp2 = CartoSymExpString { string = unescaped } };
         if(ci)
            expOp.exp2 = CartoSymExpCall
            {
               exp = CartoSymExpIdentifier { identifier = { string = CopyString("casei") } }, arguments = { [ expOp.exp2 ] }
            };
         if(ai)
            expOp.exp2 = CartoSymExpCall
            {
               exp = CartoSymExpIdentifier { identifier = { string = CopyString("accenti") } }, arguments = { [ expOp.exp2 ] }
            };

         expOp.op = (startP && endP) ? stringContains : startP ? stringEndsWith : endP ? stringStartsWith : equal;
         result = expOp;
      }
      else
         delete unescaped;
   }

   if(!result)
   {
      // Fallback approach
      CartoSymExpCall expCall
      {
         exp = CartoSymExpIdentifier { identifier = { string = CopyString("like") } },
         arguments = { [ e1, e2 ] }
      };
      result = expCall;
   }
   return result;
}

static CartoSymExpression convertCQL2JSONGeometry(GeometryType gt, const FieldValue coordinatesOrGeomtries)
{
   CartoSymExpression result = null;
   bool valid = false;
   Geometry * geometry = new0 Geometry[1];
   int i;

   switch(gt)
   {
      case multiPolygon:
      {
         Array<Array<Array<Array<double>>>> multiPolyArray = (Array<Array<Array<Array<double>>>>)buildDoubleArrayFromFV(coordinatesOrGeomtries, 4);
         if(multiPolyArray)
         {
            Array<Polygon> polys { size = multiPolyArray.count };
            for(i = 0; i < multiPolyArray.count; i++)
            {
               Array<Array<Array<double>>> polygon = multiPolyArray[i];
               Polygon * poly = &polys[i];
               generatePolygonFromCoordinates(poly, polygon, false, null, 0, null);
               delete polygon;
            }
            geometry->type = multiPolygon;
            geometry->multiPolygon = polys;
            geometry->subElementsNotFreed = true;  // REVIEW: This was needed to avoid crash
            delete multiPolyArray;
            valid = true;
         }
         break;
      }
      case polygon:
      {
         Array<Array<Array<double>>> polygonsArray = (Array<Array<Array<double>>>)buildDoubleArrayFromFV(coordinatesOrGeomtries, 3);
         if(polygonsArray)
         {
            generatePolygonFromCoordinates(geometry->polygon, polygonsArray, false, null, 0, null);
            geometry->type = polygon;
            geometry->subElementsNotFreed = true;  // REVIEW: This was needed to avoid crash
            delete polygonsArray;
            valid = true;
         }
         break;
      }
      case lineString:
      {
         Array<Array<double>> lineArray = (Array<Array<double>>)buildDoubleArrayFromFV(coordinatesOrGeomtries, 2);
         if(lineArray)
         {
            generateLineStringFromCoordinates(geometry->lineString, lineArray, false, null, 0, null);
            geometry->type = lineString;
            geometry->subElementsNotFreed = true;  // REVIEW: This was needed to avoid crash

            delete lineArray;
            valid = true;
         }
         break;
      }
      case multiLineString:
      {
         Array multiLineArray = buildDoubleArrayFromFV(coordinatesOrGeomtries, 3);
         if(multiLineArray)
         {
            Array<LineString> lines { size = multiLineArray.count };
            for(i = 0; i < multiLineArray.count; i++)
            {
               Array<Array<double>> lineString = (Array<Array<double>>)multiLineArray[i];
               generateLineStringFromCoordinates(lines[i], lineString, false, null, 0, null);
               delete lineString;
            }
            geometry->type = multiLineString;
            geometry->multiLineString = lines;
            geometry->subElementsNotFreed = true;  // REVIEW: This was needed to avoid crash
            delete multiLineArray;
            valid = true;
         }
         break;
      }
      case point:
      {
         Array<double> pointArray = (Array<double>)buildDoubleArrayFromFV(coordinatesOrGeomtries, 1);
         if(pointArray && pointArray.count >= 2)
         {
            generatePointFromCoordinates(geometry->point, pointArray, 0, 0, null, false, null, 0, null);
            geometry->type = point;
            valid = true;
         }
         delete pointArray;
         break;
      }
      case multiPoint:
      {
         Array<Array<double>> pointsArray = (Array<Array<double>>)buildDoubleArrayFromFV(coordinatesOrGeomtries, 2);
         if(pointsArray)
         {
            Array<GeoPoint> points { size = pointsArray.count };
            for(i=0; i<pointsArray.count;i++)
            {
               Array<double> point = pointsArray[i];
               if(point && point.count >= 2)
                  generatePointFromCoordinates(points[i], point, i, 0, null, false, null, 0, null);
               delete point;
            }
            geometry->type = multiPoint;
            geometry->multiPoint = points;
            geometry->subElementsNotFreed = true;  // REVIEW: This was needed to avoid crash
            delete pointsArray;
            valid = true;
         }
         break;
      }
      case geometryCollection:
      {
         Array<FieldValue> collectionArray = coordinatesOrGeomtries.type.type == array ? coordinatesOrGeomtries.a : null;
         if(collectionArray)
         {
            Array<Geometry> geomCollection { size = collectionArray.count };
            // CartoSymExpArray collectionExpArray { elements = {} };
            for(i = 0; i < collectionArray.count; i++)
            {
               CartoSymExpression geomExp = convertCQL2JSON(collectionArray[i]);
               if(geomExp && geomExp._class == class(CartoSymExpInstance))
               {
                  // should always enter here
                  CartoSymExpInstance instExp = (CartoSymExpInstance)geomExp;
                  Geometry * geom = instExp.instData;
                  if(geom) geomCollection[i] = *geom;
                  instExp.instData = null; // only instData at collection level?
                  delete geomExp;
                  //collectionExpArray.elements.Add(geomExp);
               }
               delete geomExp;
            }
            geometry->geometryCollection = geomCollection;
            geometry->type = geometryCollection;
            geometry->subElementsNotFreed = true;  // REVIEW: This was needed to avoid crash
            valid = true;
         }
      }
   }
   if(valid)
   {
      result = CartoSymExpInstance { instData = geometry, instanceFlags = { resolved = true }, expType = class(Geometry) };
      buildInstanceFromInstData(result, null, null);
   }
   else
      delete geometry;
   return result;
}

Map<const String, const String> functionMap
{ [
   { "s_equals", "equals" },
   { "s_contains", "contains" },
   { "s_crosses", "crosses" },
   { "s_disjoint", "disjoint" },
   { "s_intersects", "intersects" },
   { "s_touches", "touches" },
   { "s_within" , "within" },
   { "^", "pow" }
] };


/*static */Map<String, CQL2JSONTokenType> cql2JSONStringTokens
{ [
   { "<=", smallerEqual },
   { ">=", greaterEqual },
   { "is", is },
   { "<>", notEqual },
   { "not", not },
   { "and", and },
   { "or", or },
   { "in", in },
   { "isNull", isNull },
   { "between", between },
   { "like", like },
   { "div", intDivide }
] };

public enum CQL2JSONTokenType
{
   // Core Tokens
   none = 9999,
   syntaxError = 3000,
   lexingError = 2000,
   identifier = 1000,
   constant,
   stringLiteral,

   endOfInput = 0, // FIXME (enum values with escaped char) '\0',

   // Comparison
   smaller = '<',
   greater = '>',
   equal = '=',

   // Arithmetic
   plus = '+',
   minus = '-',
   multiply = '*',
   divide = '/',
   power = '^',
   modulo = '%',

   /////////////////////////////////
   comma = ',',

   openParenthesis = '(',
   closeParenthesis = ')',

   openBracket = '[',
   closeBracket = ']',

   // Multi char symbols
   notEqual = 256,   // <>
   smallerEqual,     // <=
   greaterEqual,     // >=
   not,
   or,
   and,
   is,
   in,
   between,
   like,
   intDivide,
   isNull
   ;
};


static Map<CQL2JSONTokenType, CartoSymTokenType> jsonOperatorConversionMap
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
   { like, none },    // Will need special handling
   { in, in }
] };

static Array buildDoubleArrayFromFV(const FieldValue value, int depth)
{
   Array result = null;
   if(value && value.type.type == array && value.a && value.a._class == class(Array<FieldValue>))
   {
      Array<FieldValue> a = (Array<FieldValue>)value.a;
      Class c =
         depth == 4 ? class(Array<Array<Array<Array<double>>>>) :
         depth == 3 ? class(Array<Array<Array<double>>>) :
         depth == 2 ? class(Array<Array<double>>) :
                      class(Array<double>);
      int i;

      result = eInstance_New(c);
      result.size = a.count;
      for(i = 0; i < a.count; i++)
      {
         if(depth > 1)
         {
            ((Array<Array>)result)[i] = buildDoubleArrayFromFV(a[i], depth - 1);
         }
         else
         {
            ((Array<double>)result)[i] = a[i].type.type == real ? a[i].r : a[i].type.type == integer ? a[i].i : 0;
         }
      }
   }
#ifdef _DEBUG
   else
      PrintLn("WARNING: Unexpected input building double array");
#endif
   return result;
}

/*
static int getArrayDepth(const FieldValue value)
{
   return value.type.type == array && value.a ?
      1 + (value.a.count ? getArrayDepth(value.a[0]) : 0) :
      0;
}
*/

// move to CartoSymHelper
static void buildInstanceFromInstData(CartoSymExpression e, Geometry * collectionGeom, CartoSymExpArray collectionExpArray)
{
   if(e && e._class == class(CartoSymExpInstance))
   {
      CartoSymExpInstance expInst = (CartoSymExpInstance)e;
      Class expType = expInst.expType;
      if(expType == class(Geometry))
      {
         Geometry * geom = collectionGeom ? collectionGeom : (Geometry *)expInst.instData;
         CartoSymMemberInit minit = null;
         CartoSymInstantiation inst { };
         CartoSymMemberInitList subList {};
         GeometryType gt = geom->type;
         int i;
         switch(gt)
         {
            case point:
            {
               GeoPoint point = geom->point;
               CartoSymExpression pointExp = tupleOrPointToExpInstance(null, point);
               expInst.instance = ((CartoSymExpInstance)pointExp).instance.copy();
               delete pointExp; // we want to keep the instData in expInst
               expInst.instance._class = CartoSymSpecName { name = CopyString("Point")};
               break;
            }
            case lineString:
            {
               LineString line = geom->lineString;
               CartoSymExpArray linePointArray = buildExpArrayFromPoints(line._points, false);
               minit = { initializer = linePointArray };
               inst._class = CartoSymSpecName { name = CopyString("LineString") };
               break;
            }
            case polygon:
            {
               Polygon polygon = geom->polygon;
               CartoSymExpArray innerArray {};
               inst._class = CartoSymSpecName { name = CopyString("Polygon")};
               for(i = 0; i < polygon.contours.count; i++)
               {
                  CartoSymExpArray contourPointArray = buildExpArrayFromPoints(polygon.contours[i]._points, true);
                  setPolygonMemberInitList(contourPointArray, subList, innerArray, i);
                  delete contourPointArray; // function copies
               }
               if(innerArray.elements && innerArray.elements.GetCount())
               {
                  minit = { initializer = innerArray };
                  subList.Add(minit);
               }
               else
                  delete innerArray;
               break;
            }
            case multiPolygon:
            {
               Array<Polygon> polygons = (Array<Polygon>)geom->multiPolygon;
               CartoSymExpArray polygonsArray {};
               int j;
               inst._class = CartoSymSpecName { name = CopyString("MultiPolygon")};
               for(i = 0; i < polygons.count; i++)
               {
                  CartoSymExpArray polyArrayExp { elements = {}};
                  for(j = 0; j < polygons[i].contours.count; j++)
                  {
                     CartoSymExpArray contourPointArray  = buildExpArrayFromPoints(polygons[i].contours[j]._points, true);
                     polyArrayExp.elements.Add(contourPointArray);
                  }
                  setMultiPolygonMemberInitList(polyArrayExp, polygonsArray);
               }
               minit = { initializer = polygonsArray };
               break;
            }
            case multiLineString:
            {
               Array<LineString> lines = (Array<LineString>)geom->multiLineString;
               CartoSymExpArray lineArray { elements = {} };
               inst._class = CartoSymSpecName { name = CopyString("MultiLineString") };
               for(i = 0; i < lines.count; i++)
               {
                  CartoSymExpArray linePointArray = buildExpArrayFromPoints(lines[i]._points, false);
                  if(linePointArray)
                     setMultiLineMemberInitList(linePointArray, lineArray);
               }
               minit = { initializer = lineArray };
               break;
            }
            case multiPoint:
            {
               Array<GeoPoint> points = (Array<GeoPoint>)geom->multiPoint;
               CartoSymExpArray pointExpArray = buildExpArrayFromPoints(points, false);
               inst._class = CartoSymSpecName { name = CopyString("MultiPoint") };
               minit = { initializer = pointExpArray };
               break;
            }
            case bbox:
            {
               GeoExtent extent = geom->bbox;
               CartoSymExpression ptExp1 = tupleOrPointToExpInstance(null, extent.ll);
               CartoSymExpression ptExp2 = tupleOrPointToExpInstance(null, extent.ur);
               inst._class = CartoSymSpecName { name = CopyString("GeoExtent")};
               subList.setMember(class(GeoPoint), "ll", 0, true, ptExp1);
               subList.setMember(class(GeoPoint), "ur", 0, true, ptExp2);
               break;
            }
            case geometryCollection:
            {
               Array<Geometry> geometryColl = (Array<Geometry>)geom->geometryCollection;
               if(collectionExpArray)
                  minit = { initializer = collectionExpArray };
               else
               {
                  CartoSymExpArray expArray { elements = {} };
                  for(i = 0; i < geometryColl.count; i++)
                  {
                     CartoSymExpInstance subExpInst { instanceFlags = { resolved = true }, expType = class(Geometry) };
                     buildInstanceFromInstData(subExpInst, &geometryColl[i], null);
                     expArray.elements.Add(subExpInst);
                  }
                  minit = { initializer = expArray };
               }
               inst._class = CartoSymSpecName { name = CopyString("GeometryCollection") };
            }
            break;
         }
         if(gt != point)
         {
            if(minit && gt != polygon)
               subList.Add(minit);
            inst.members = { [ subList ] };
            expInst.instance = inst;
         }
         else
         {
            delete inst; delete subList;
         }
      }
   }
}
