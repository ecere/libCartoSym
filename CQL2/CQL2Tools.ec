public import IMPORT_STATIC "ecrt"
public import IMPORT_STATIC "SFGeometry"
public import IMPORT_STATIC "SFCollections" // For earliestTime / latestTime

private:

import "CQL2Expressions"

//used by CQL2Internalization and CQL2-JSON
String getLikeStringPattern(const String s, bool * quoted, bool * foundQ, bool * startP, bool * endP, bool * middleP)
{
   int i, j = 0;
   char ch;
   String unescaped = new char[strlen(s)+1];
   for(i = 0; (ch = s[i]); i++)
   {
      if(ch == '\\')
         *quoted = !*quoted;
      else if(!*quoted)
      {
         if(ch == '%')
         {
            if(i == 0) *startP = true;
            else if(s[i+1]) { *middleP = true; break; }
            else *endP = true;
         }
         else if(ch == '_')
            *foundQ = true;
         else
            unescaped[j++] = ch;
      }
      else
      {
         unescaped[j++] = ch;
         *quoted = false;
      }
   }
   unescaped[j] = 0;
   return unescaped;
}

// used by cql2expressions->convertCSToCQL2() and cql2json
CQL2Expression getExpStringForLike(CQL2Expression e, bool * ai, bool * ci)
{
   CQL2Expression exp2 = e;
   while(exp2 && exp2._class == class(CQL2ExpCall))
   {
      CQL2ExpCall cc = (CQL2ExpCall)exp2;
      const String id = cc.exp && ((CQL2ExpIdentifier)cc.exp).identifier ? ((CQL2ExpIdentifier)cc.exp).identifier.string : null;
      if(id && cc.arguments && cc.arguments.GetCount() >= 1)
      {
               if(!strcmpi(id, "accenti")) *ai = true, exp2 = cc.arguments[0];
          else if(!strcmpi(id, "casei"))  *ci = true, exp2 = cc.arguments[0];
          else
            break;
      }
      else
         break;
   }
   return exp2;
}

CQL2Expression getDateConstantForInterval(const String dateString, bool isEnd)
{
   CQL2Expression result = null;
   if(dateString)
   {
      FieldValue val { type = { integer, isDateTime = true } };
      CQL2ExpConstant constExp { };
      // FIXME: This function should not take something either quoted or not
      if(strcmp(dateString, "'..'") && strcmp(dateString, ".."))
      {
         DateTime dt { };
         dt.OnGetDataFromString(dateString);
         val.i = (SecSince1970)dt;
      }
      else
         val.i = isEnd ? latestTime : earliestTime;
      constExp.constant = val;
      result = constExp;
   }
   return result;
}

// used by cql2expressions and cql2json
void setPolygonMemberInitList(CQL2ExpArray expArray, CQL2MemberInitList polyList, CQL2ExpArray contourArray, int index)
{
   if(expArray && polyList)
   {
      CQL2MemberInit minit { initializer = expArray.copy() };
      CQL2MemberInitList contourList {}; CQL2Instantiation contourInst {};
      contourList.Add(minit);
      contourInst.members = { [ contourList ] };

      if(index  == 0) // OUTER
      {
         CQL2MemberInit contourMinit { initializer = CQL2ExpInstance { instance = contourInst } };
         polyList.Add(contourMinit);
      }
      else // array of inner
      {
         if(!contourArray.elements) contourArray.elements = {};
         contourArray.elements.Add(CQL2ExpInstance { instance = contourInst });
      }
   }
}

void setMultiPolygonMemberInitList(CQL2Expression polyExp, CQL2ExpArray polygonArray)
{
   if(polyExp && polygonArray)
   {
      int j;
      CQL2MemberInitList polygonList {}; CQL2Instantiation polygonInst {};
      CQL2ExpArray contourArray { };
      CQL2ExpBrackets expBrackets = polyExp._class == class(CQL2ExpBrackets) ? (CQL2ExpBrackets)polyExp : null;
      CQL2ExpArray expArray = polyExp._class == class(CQL2ExpArray) ? (CQL2ExpArray)polyExp : null;

      if(expBrackets)
         for(j = 0; j < expBrackets.list.GetCount(); j++)
         {
            CQL2ExpArray subArray = (CQL2ExpArray)expBrackets.list[j];
            setPolygonMemberInitList(subArray, polygonList, contourArray, j);
         }
      if(expArray)
         for(j = 0; j < expArray.elements.GetCount(); j++)
         {
            CQL2ExpArray subArray = (CQL2ExpArray)expArray.elements[j];
            setPolygonMemberInitList(subArray, polygonList, contourArray, j);
         }
      if(contourArray.elements && contourArray.elements.GetCount())
      {
         CQL2MemberInit cMinit { initializer = contourArray };
         polygonList.Add(cMinit);
      }
      else
         delete contourArray;

      polygonInst.members = { [ polygonList ] };
      if(!polygonArray.elements) polygonArray.elements = {};
      polygonArray.elements.Add(CQL2ExpInstance { instance = polygonInst });
   }
}

void setMultiLineMemberInitList(CQL2Expression expArray, CQL2ExpArray lineArray)
{
   if(expArray && lineArray && lineArray.elements)
   {
      CQL2MemberInitList lineList {}; CQL2Instantiation lineInst {};
      CQL2MemberInit subMinit { initializer = expArray.copy() };
      lineList.Add(subMinit);
      lineInst.members = { [ lineList ] };
      lineArray.elements.Add(CQL2ExpInstance { instance = lineInst });
   }
}

void buildInstanceFromInstData(CQL2Expression e, Geometry * collectionGeom, CQL2ExpArray collectionExpArray)
{
   if(e && e._class == class(CQL2ExpInstance))
   {
      CQL2ExpInstance expInst = (CQL2ExpInstance)e;
      Class expType = expInst.expType;
      if(expType == class(Geometry))
      {
         Geometry * geom = collectionGeom ? collectionGeom : (Geometry *)expInst.instData;
         CQL2MemberInit minit = null;
         CQL2Instantiation inst { };
         CQL2MemberInitList subList {};
         GeometryType gt = geom->type;
         int i;
         switch(gt)
         {
            case point:
            {
               GeoPoint point = geom->point;
               CQL2Expression pointExp = tupleOrPointToExpInstance(null, point);
               expInst.instance = ((CQL2ExpInstance)pointExp).instance.copy();
               delete pointExp; // we want to keep the instData in expInst
               expInst.instance._class = CQL2SpecName { name = CopyString("Point")};
               break;
            }
            case lineString:
            {
               LineString line = geom->lineString;
               CQL2ExpArray linePointArray = buildExpArrayFromPoints((Array<GeoPoint>)line.points, false);
               minit = { initializer = linePointArray };
               inst._class = CQL2SpecName { name = CopyString("LineString") };
               break;
            }
            case polygon:
            {
               Polygon polygon = geom->polygon;
               CQL2ExpArray innerArray {};
               Array<PolygonContour> contours = (Array<PolygonContour>)polygon.getContours();

               inst._class = CQL2SpecName { name = CopyString("Polygon")};
               for(i = 0; i < contours.count; i++)
               {
                  CQL2ExpArray contourPointArray = buildExpArrayFromPoints((Array<GeoPoint>)contours[i].points, true);
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
               CQL2ExpArray polygonsArray {};
               int j;
               inst._class = CQL2SpecName { name = CopyString("MultiPolygon")};
               for(i = 0; i < polygons.count; i++)
               {
                  Array<PolygonContour> contours = (Array<PolygonContour>)polygons[i].getContours();
                  CQL2ExpArray polyArrayExp { elements = {}};
                  for(j = 0; j < contours.count; j++)
                  {
                     CQL2ExpArray contourPointArray  = buildExpArrayFromPoints((Array<GeoPoint>)contours[j].points, true);
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
               CQL2ExpArray lineArray { elements = {} };
               inst._class = CQL2SpecName { name = CopyString("MultiLineString") };
               for(i = 0; i < lines.count; i++)
               {
                  CQL2ExpArray linePointArray = buildExpArrayFromPoints((Array<GeoPoint>)lines[i].points, false);
                  if(linePointArray)
                     setMultiLineMemberInitList(linePointArray, lineArray);
               }
               minit = { initializer = lineArray };
               break;
            }
            case multiPoint:
            {
               Array<GeoPoint> points = (Array<GeoPoint>)geom->multiPoint;
               CQL2ExpArray pointExpArray = buildExpArrayFromPoints(points, false);
               inst._class = CQL2SpecName { name = CopyString("MultiPoint") };
               minit = { initializer = pointExpArray };
               break;
            }
            case bbox:
            {
               GeoExtent extent = geom->bbox;
               CQL2Expression ptExp1 = tupleOrPointToExpInstance(null, extent.ll);
               CQL2Expression ptExp2 = tupleOrPointToExpInstance(null, extent.ur);
               inst._class = CQL2SpecName { name = CopyString("GeoExtent")};
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
                  CQL2ExpArray expArray { elements = {} };
                  for(i = 0; i < geometryColl.count; i++)
                  {
                     CQL2ExpInstance subExpInst { instanceFlags = { resolved = true }, expType = class(Geometry) };
                     buildInstanceFromInstData(subExpInst, &geometryColl[i], null);
                     expArray.elements.Add(subExpInst);
                  }
                  minit = { initializer = expArray };
               }
               inst._class = CQL2SpecName { name = CopyString("GeometryCollection") };
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

CQL2Expression tupleOrPointToExpInstance(CQL2Tuple tuple, GeoPoint point)
{
   CQL2Expression e = null;
   if(tuple || point != null)
   {
      CQL2MemberInitList memberInitList { };
      CQL2Instantiation instantiation { };
      int i, count = tuple ? tuple.list.count : 2;
      for(i = 0; i < count ; i++)
      {
         CQL2Expression tExp = tuple ? convertToInternalCQL2(tuple.list[i]) : CQL2ExpConstant { constant = { type = { real }, r = i == 0 ? point.lon : point.lat } };
         CQL2MemberInit minit { initializer = tExp };
         memberInitList.Add(minit);
      }
      instantiation.members = { [ memberInitList ] };
      e = CQL2ExpInstance { instance = instantiation };
   }
   return e;
}

CQL2ExpArray buildExpArrayFromPoints(Array<GeoPoint> points, bool addFirstPoint)
{
   CQL2ExpArray expArray = null;
   if(points && points.count)
   {
      expArray = { elements = {} };
      for(p : points)
      {
         CQL2Expression pointExp = tupleOrPointToExpInstance(null, p);
         expArray.elements.Add(pointExp);
      }
      if(addFirstPoint)
      {
         CQL2Expression pointExp = tupleOrPointToExpInstance(null, points[0]);
         expArray.elements.Add(pointExp);
      }
   }
   return expArray;
}
