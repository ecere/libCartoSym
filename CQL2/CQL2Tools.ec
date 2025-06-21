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
