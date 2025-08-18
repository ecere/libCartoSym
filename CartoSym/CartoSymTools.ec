// Utility functions
public import IMPORT_STATIC "ecrt"
public import IMPORT_STATIC "CQL2"

import "CartoSymbolizer"

public Array<String> splitCommaValues(const String s)
{
   Array<String> values { };
   int i, start = 0;
   bool lastWasComma = false;
   if(!strchr(s, ','))
      values.Add(CopyString(s));
   else
   {
      for(i = 0; ; i++)
      {
         char ch = s[i];
         if(!ch || ch == ',')
         {
            int len = i - start;
            String temp = new char[len+1];
            memcpy(temp, s + start, len);
            temp[len] = 0;
            values.Add(temp);
            lastWasComma = true;
            start = i + 1;
            if(!ch) break;
         }
         else if(lastWasComma && ch == ' ')
            start = i+1;
         else
            lastWasComma = false;
      }
   }
   return values;
}

public void setSymbolizerExp(SymbolizerProperties symbolizerProperties, CartoSymbolizerKind mask, CQL2Expression e)
{
   const String idString = evaluator.evaluatorClass.stringFromMask(mask, class(CartoSymbolizer));
   symbolizerProperties.setMember2(class(CartoSymbolizer), idString, mask, true, e, evaluator, class(CartoSymbolizer), none);
}

public void setSymbolizerVal(SymbolizerProperties symbolizerProperties, CartoSymbolizerKind mask, const FieldValue v, Class c)
{
   const String idString = evaluator.evaluatorClass.stringFromMask(mask, class(CartoSymbolizer));
   symbolizerProperties.setMemberValue2(class(CartoSymbolizer), idString, mask, true, v, c, evaluator, class(CartoSymbolizer));
}

public CQL2ExpInstance makeUnitExp(CQL2ExpConstant c, GraphicalUnit unit)
{
   CQL2MemberInit minit { initializer = c };
   CQL2MemberInitList memberInitList { [ minit ] };
   CQL2Instantiation instance
   {
      _class = CQL2SpecName { name = PrintString(unit) },
      members = { [ memberInitList ] }
   };
   return CQL2ExpInstance { instance = instance, expType = eSystem_FindClass(__thisModule, instance._class.name) };
}

public CQL2ExpMember newCSScaleExp()
{
   return CQL2ExpMember
   {
      exp = CQL2ExpIdentifier { identifier = CQL2Identifier { string = CopyString("viz") } };
      member = CQL2Identifier { string = CopyString("sd") };
   };
}

public bool checkScale(CQL2Expression e)
{
   if(e._class == class(CQL2ExpMember))
   {
      CQL2ExpMember member = (CQL2ExpMember)e;
      if(member.member && !strcmp(member.member.string, "sd"))
         return true;
   }
   return false;
}

public bool getScale(CQL2Expression e, double * minScale, double * maxScale)
{
   bool isScale = false;
   // String s = e.toString(0);

   if(e._class == class(CQL2ExpOperation))
   {
      CQL2ExpOperation expOp = (CQL2ExpOperation)e;
      if(expOp.op != in)
      {
         // CQL2Expression expId = expOp.exp1 && expOp.exp1._class == class(CQL2ExpIdentifier) ? expOp.exp1 : expOp.exp2 && expOp.exp2._class == class(CQL2ExpIdentifier) ? expOp.exp2 : null;
         CQL2Expression member = expOp.exp1 && expOp.exp1._class == class(CQL2ExpMember) ? expOp.exp1 : expOp.exp2 && expOp.exp2._class == class(CQL2ExpMember) ? expOp.exp2 : null;
         CQL2Expression e2 = (expOp.exp1 && (expOp.exp1._class == class(CQL2ExpIdentifier) || expOp.exp1._class == class(CQL2ExpMember))) ?
            expOp.exp2 : (expOp.exp2 && (expOp.exp2._class == class(CQL2ExpIdentifier) || expOp.exp2._class == class(CQL2ExpMember))) ? expOp.exp1 : null;

         // since the tag must be open before entering this scope, can't write and verify scale at the same time!
         // therefore use helper function to assess whether scale exists
         isScale = member ? checkScale(member) : false;

         if(e2)
         {
            if(isScale)
            {
               CQL2ExpConstant expConstant = (CQL2ExpConstant)e2;
               if(expOp.op == smallerEqual || expOp.op == smaller)
                  *maxScale = expConstant.constant.type.type == real ? expConstant.constant.r : expConstant.constant.i;
               else if(expOp.op == greaterEqual || expOp.op == greater)
                  *minScale = expConstant.constant.type.type == real ? expConstant.constant.r : expConstant.constant.i;
            }
            else
               getScale(e2, minScale, maxScale);
         }
         else if(expOp.exp1 && expOp.exp2 && expOp.exp1._class == class(CQL2ExpOperation) && expOp.exp2._class == class(CQL2ExpOperation))
         {
            getScale(expOp.exp1, minScale, maxScale);
            getScale(expOp.exp2, minScale, maxScale);
         }
      }
   }
   return isScale;
}

public CQL2Expression buildFlatFilter(CQL2Expression parentFilter, StylingRule block)
{
   CQL2Expression finalFilter = parentFilter;
   CQL2Expression negFilter = null;

   if(block.nestedRules)
   {
      for(b : block.nestedRules; b._class == class(StylingRule))
      {
         StylingRule sb = (StylingRule)b;
         // AND all the selectors into 're' ("rule expression")
         CQL2Expression re = null;
         for(s : sb.selectors)
         {
            double nMinScale = 0, nMaxScale = 0;
            if(!getScale(s.exp, &nMinScale, &nMaxScale))
               re = re ? CQL2ExpOperation { exp1 = re, op = and, exp2 = s.exp.copy() } : s.exp.copy();
         }
         if(re)
         {
            // OR together 're' with other filters for current rule
            CQL2ExpBrackets brackets { list = { [ re ] } };
            negFilter = negFilter ? CQL2ExpOperation { exp1 = negFilter, op = or, exp2 = brackets } : brackets;
         }
      }

      if(negFilter)
      {
         // Negate the filter and AND together with current rule block filter (already including parent filter)
         negFilter = CQL2ExpOperation { op = not, exp2 = CQL2ExpBrackets { list = { [ negFilter ] } } };
         finalFilter = finalFilter ? CQL2ExpOperation { exp1 = finalFilter, op = and, exp2 = negFilter } : negFilter;
      }
   }
   return finalFilter;
}

public CQL2Expression expressionsFromSelectors(StylingRule b)
{
   double nMinScale = 0, nMaxScale = 0;
   CQL2Expression re = null;

   for(s : b.selectors)
   {
      if(!(getScale(s.exp, &nMinScale, &nMaxScale)))
      {
         re = re ? CQL2ExpOperation { exp1 = re, op = and, exp2 = s.exp.copy() } : s.exp.copy();
      }
   }
   return re;
}

public CQL2Expression getExpInstanceMember(CQL2ExpInstance inst, InstanceMask idMask)
{
   CQL2Expression result = null;
   if(inst._class == class(CQL2ExpInstance))
   {
      CQL2ExpInstance ei = (CQL2ExpInstance)inst;
      if(ei.instance && ei.instance.members)
         result = ei.instance.members.getProperty2(idMask, null);
   }
   return result;
}

public CQL2Expression getRuleBlockInitExp(StylingRule block, InstanceMask idMask)
{
   return block.symbolizer ? block.symbolizer.getProperty(idMask) : null;
}

public CQL2ExpList labelElementsFromBlock(StylingRule block)
{
   CQL2ExpArray ea = (CQL2ExpArray)getRuleBlockInitExp(block, CartoSymbolizerKind::labelElements);
   return ea && ea._class == class(CQL2ExpArray) ? ea.elements : null;
}

public int64 getStylesInt(StylingRule inhRule, CartoSymbolizerKind kind, int64 defaultValue)
{
   int64 v = defaultValue;
   if(inhRule && inhRule.symbolizer)
   {
      CQL2Expression e = inhRule.symbolizer.getProperty2(kind, null);
      if(e)
      {
         v = 0;
         if(e._class == class(CQL2ExpConstant))
         {
            CQL2ExpConstant cExp = (CQL2ExpConstant)e;
            if(cExp.constant.type.type == real)
               v = (int64)cExp.constant.r;
            else if(cExp.constant.type.type == integer)
               v = cExp.constant.i;
         }
      }
   }
   return v;
}

static CartoSymEvaluator evaluator { class(CartoSymEvaluator), featureID = -1 };

public void * getStylesBlob(StylingRule inhRule, CartoSymbolizerKind kind)
{
   if(inhRule && inhRule.symbolizer)
   {
      CQL2Expression e = inhRule.symbolizer.getProperty2(kind, null);
      if(e)
      {
         FieldValue value { };
         e.compute(value, evaluator, preprocessing, class(CartoSymbolizer));
         e.compute(value, evaluator, runtime, class(CartoSymbolizer));
         return value.b;
      }
   }
   return null;
}

public double getStylesFloat(StylingRule inhRule, CartoSymbolizerKind kind, double defaultValue, GraphicalUnit * unit)
{
   double v = defaultValue;
   if(unit) *unit = pixels;
   if(inhRule && inhRule.symbolizer)
   {
      Class uc = null;
      CQL2Expression e = inhRule.symbolizer.getProperty2(kind, &uc);
      if(e)
      {
         v = 0;
         if(e._class == class(CQL2ExpConstant))
         {
            CQL2ExpConstant cExp = (CQL2ExpConstant)e;
            if(cExp.constant.type.type == real)
               v = cExp.constant.r;
            else if(cExp.constant.type.type == integer)
               v = cExp.constant.i;
         }
         if(uc && uc == class(Meters))
            *unit = meters;
      }
   }
   return v;
}

public Color getStylesColor(StylingRule inhRule, CartoSymbolizerKind kind, Color defaultValue)
{
   Color v = defaultValue;
   if(inhRule && inhRule.symbolizer)
   {
      CQL2Expression e = inhRule.symbolizer.getProperty2(kind, null);
      if(e)
      {
         v = 0;
         if(e._class == class(CQL2ExpConstant))
         {
            CQL2ExpConstant cExp = (CQL2ExpConstant)e;
            if(cExp.constant.type.type == integer)
            {
               v = (Color)cExp.constant.i;
            }
         }
      }
   }
   return v;
}

public void addExpSelectors(SelectorList selectors, CQL2Expression e)
{
   CQL2ExpOperation expOp = (CQL2ExpOperation)e;
   if(e._class == class(CQL2ExpBrackets))
   {
      CQL2ExpBrackets expBr = (CQL2ExpBrackets)e;
      addExpSelectors(selectors, expBr.list.lastIterator.data);
      expBr.list.RemoveAll();
      delete expBr;
   }
   else if(e._class == class(CQL2ExpOperation) && (expOp.op == and || expOp.op == none))
   {
      if(expOp.exp1) { addExpSelectors(selectors, expOp.exp1); expOp.exp1 = null; }
      if(expOp.exp2) { addExpSelectors(selectors, expOp.exp2); expOp.exp2 = null; }
      delete expOp;
   }
   else
   {
      // TODO: Move this to generic expression simplification function?
      if(e._class == class(CQL2ExpOperation) && expOp.op == equal && expOp.exp2)
      {
         CQL2ExpIdentifier expID = expOp.exp2._class == class(CQL2ExpIdentifier) ? (CQL2ExpIdentifier)expOp.exp2 : null;
         CQL2ExpConstant expC = expOp.exp2._class == class(CQL2ExpConstant) ? (CQL2ExpConstant)expOp.exp2 : null;
         bool isTrue = (expID && expID.identifier && expID.identifier.string && !strcmpi(expID.identifier.string, "true")) || (expC && expC.constant.type.type == integer && expC.constant.i == 1);
         // Simplify 'in (a,b) = true'
         if(isTrue && expOp.exp1._class == class(CQL2ExpOperation) &&
            ((CQL2ExpOperation)expOp.exp1).op == in)
         {
            e = expOp.exp1;
            delete expOp.exp2;
            expOp = (CQL2ExpOperation)e;
         }
      }

      if(expOp._class == class(CQL2ExpOperation) && expOp.op == in && expOp.exp2._class == class(CQL2ExpBrackets) && ((CQL2ExpBrackets)expOp.exp2).list)
      {
         CQL2ExpList eList = ((CQL2ExpBrackets)expOp.exp2).list;
         if(eList.list && eList.list.count == 1)
         {
            // Simplify in single item to =
            CQL2Expression first = eList[0];
            eList.list.RemoveAll();
            expOp.op = equal;
            delete expOp.exp2;
            expOp.exp2 = first;
         }

      }

      // Convert e.g. FEATCODE = 123 | FEATCODE = 234 | FEATCODE = 345 into FEATCODE in (123, 234, 345)
      while(expOp._class == class(CQL2ExpOperation) && expOp.op == or &&
         expOp.exp1 && expOp.exp2 &&
         expOp.exp1._class == class(CQL2ExpOperation) && expOp.exp2._class == class(CQL2ExpOperation))
      {
         CQL2ExpOperation e1 = (CQL2ExpOperation)expOp.exp1, e2 = (CQL2ExpOperation)expOp.exp2;
         String lExp, rExp;
         bool same;
         CQL2ExpOperation * orRepExp = null; // Multiple OR combinations are quite tricky.
                                             // This is the address of the expression we will need
                                             // to replace by its own right-hand side operand (exp2)

         if(e1.op != equal && e1.op != in) break;  // If we don't have either an equal or an 'in' on the left side we abort

         // We need to dig in to deep left-hand side operand of the deepest OR. Remember where 'e2' came from.
         if(e2.op == or)
         {
            orRepExp = (CQL2ExpOperation *)&expOp.exp2;
         }
         while(e2.op == or)
         {
            CQL2ExpOperation lastE2 = e2;

            e2 = (CQL2ExpOperation)e2.exp1;
            if(e2._class != class(CQL2ExpOperation))
               break;
            if(e2.op == or)
            {
               orRepExp = (CQL2ExpOperation *)&lastE2.exp1;
            }
         }

         // If we don't have an e2 expression suitable to be replaced by an 'in',
         // or either e1 or e2 doesn't have a proper lef-thand side (of the equal) operand we give up
         if(e2._class != class(CQL2ExpOperation) || e2.op != equal || !e2.exp2 || !e1.exp1 || !e2.exp1)
            break;

         // Compare the left-hand side expression of e1 and e2 to make sure they're the same
         lExp = e1.exp1.toString(0);
         rExp = e2.exp1.toString(0);
         same = !strcmp(lExp, rExp);
         delete lExp;
         delete rExp;

         if(!same)
            break;

         if(e1.op == in)
         {
            // e1 is already an 'in' expression (either originally, or as a result of this replacement loop)
            CQL2ExpBrackets br = (CQL2ExpBrackets)e1.exp2;
            if(br._class != class(CQL2ExpBrackets)) break; // exp2 should always be a brackets expression

            br.list.Add(e2.exp2); // Add the new value from e2 to the list
            e2.exp2 = null;

            if(e2 != expOp.exp2)
            {
               *orRepExp = (CQL2ExpOperation)orRepExp->exp2; // We are inside a deep OR, get rid of one level
            }
            else
            {
               expOp.exp1 = null;
               expOp.exp2 = null;
               delete expOp;
               // e1 is our resulting 'in' expression
               e = expOp = e1;
               delete e2;
            }
         }
         else
         {
            // We have equality checks on each side of an OR suitable to be replaced by an 'in'
            CQL2ExpBrackets br { list = {} };
            CQL2ExpOperation inExp { exp1 = e1.exp1, op = in, exp2 = br };

            br.list.Add(e1.exp2);
            br.list.Add(e2.exp2);
            if(e2 != expOp.exp2)
            {
               *orRepExp = (CQL2ExpOperation)orRepExp->exp2; // We are inside a deep OR, get rid of one level
               expOp.exp1 = inExp; // Plug the in expression on the left-hand side of the top-level OR expression
            }
            else
            {
               e1.exp1 = null;
               e1.exp2 = null;
               e2.exp2 = null;
               delete e1;
               delete e2;
               expOp.exp1 = null;
               expOp.exp2 = null;
               delete expOp;
               // inExp is our resulting 'in' expression
               e = expOp = inExp;
            }
         }
      }

      selectors.Add({ exp = e });
   }
}

// NOTE: This assumes no order-dependent overrides
public void nestRules(StyleBlockList list)
{
   Iterator<StyleBlock> it { list };
   while(true)
   {
      int selectorsCount = 0;
      String ruleSelector = null;   // Set if not all rules match first selector
      while(true)
      {
         String firstSelector = null;
         int nr = 0;

         it.pointer = null;
         while(it.Next())
         {
            StyleBlock b = it.data;
            if(b && b._class == class(StylingRule))
            {
               StylingRule block = (StylingRule)b;
               if(block.selectors && block.selectors.GetCount() > selectorsCount)
               {
                  String s = block.selectors[selectorsCount].toString(0);
                  if(!firstSelector)
                     firstSelector = s;
                  else
                  {
                     bool same = !strcmp(s, firstSelector);
                     delete s;
                     if(!same) break;
                  }
                  nr++;
               }
               else
                  break;
            }
         }
         if(firstSelector && nr > 1 && (!it.pointer || !selectorsCount))
         {
            if(it.pointer)
               ruleSelector = firstSelector;
            else
               delete firstSelector;
            selectorsCount++;
         }
         else
         {
            delete firstSelector;
            break;
         }
      }

      if(selectorsCount)
      {
         StylingRule block { };
         bool firstRule = true;

         block.nestedRules = { };

         it.pointer = null;
         it.Next();
         while(it.pointer)
         {
            IteratorPointer next = it.container.GetNext(it.pointer);
            StyleBlock b = it.data;
            if(b && b._class == class(StylingRule))
            {
               StylingRule bRule = (StylingRule)b;
               Iterator<StylingRuleSelector> its { bRule.selectors };
               int i;
               bool process = true;

               for(i = 0; i < selectorsCount; i++)
               {
                  StylingRuleSelector selector = (its.Next(), its.data);

                  if(ruleSelector) // Processing only some rules...
                  {
                     String s = selector.toString(0);
                     process = !strcmp(s, ruleSelector);
                     delete s;
                  }

                  if(process)
                  {
                     its.Remove();
                     if(firstRule)
                     {
                        if(!block.selectors)
                           block.selectors = { };
                        block.selectors.Add(selector);
                     }
                     else
                        delete selector;
                  }
               }

               if(process)
               {
                  list.Remove(it.pointer);
                  block.nestedRules.Add(bRule);
                  firstRule = false;
               }
            }
            it.pointer = next;
         }
         list.Add(block);
      }
      else
         break;
   }

   it.pointer = null;
   while(it.Next())
   {
      StyleBlock b = it.data;
      if(b && b._class == class(StylingRule))
      {
         StylingRule block = (StylingRule)b;
         if(block.nestedRules)
            nestRules(block.nestedRules);

      }
   }
}

bool extractIdentifiers(Container<const CIString> identifiers, CQL2Expression e, bool avoidDuplicates)
{
   bool result = false;
   if(e)
   {
      if(e && e._class == class(CQL2ExpBrackets))
      {
         CQL2ExpBrackets brkt = (CQL2ExpBrackets)e;
         for(b : brkt.list)
            result |= extractIdentifiers(identifiers, b, avoidDuplicates);
      }
      else if(e && e._class == class(CQL2ExpInstance))
      {
         CQL2ExpInstance inst = (CQL2ExpInstance)e;
         if(inst && inst.instance)
         {
            for(i : inst.instance.members)
            {
               CQL2MemberInitList members = i;
               for(m : members)
               {
                  CQL2MemberInit mInit = m;
                  if(mInit.initializer)
                     result |= extractIdentifiers(identifiers, mInit.initializer, avoidDuplicates);
               }
            }
         }
      }
      else if(e && e._class == class(CQL2ExpConditional))
      {
         CQL2ExpConditional cond = (CQL2ExpConditional)e;

         result |= extractIdentifiers(identifiers, cond.elseExp, avoidDuplicates);
         result |= extractIdentifiers(identifiers, cond.condition, avoidDuplicates);

         if(cond.expList)
            for(ce : cond.expList)
               result |= extractIdentifiers(identifiers, ce, avoidDuplicates);
      }
      else if(e && e._class == class(CQL2ExpList))
      {
         CQL2ExpList list = (CQL2ExpList)e;
         for(l : list)
            result |= extractIdentifiers(identifiers, l, avoidDuplicates);
      }
      else if(e && e._class == class(CQL2ExpCall))
      {
         CQL2ExpCall call = (CQL2ExpCall)e;
         // REVIEW: Is this ever the desired outcome to look up the function identifiers? if(call.exp)
            // result |= extractIdentifiers(identifiers, call.exp, avoidDuplicates);
         if(call.arguments)
            for(a : call.arguments)
               result |= extractIdentifiers(identifiers, a, avoidDuplicates);
      }
      if(e._class == class(CQL2ExpOperation))
      {
         CQL2ExpOperation expOp = (CQL2ExpOperation)e;
         result |= extractIdentifiers(identifiers, expOp.exp1, avoidDuplicates);
         result |= extractIdentifiers(identifiers, expOp.exp2, avoidDuplicates);
      }
                                                      // Avoid including function identifiers
      else if(e._class == class(CQL2ExpIdentifier) && e.expType != class(GlobalFunction))
      {
         CQL2ExpIdentifier identifier = (CQL2ExpIdentifier)e;
         const String s = identifier.identifier ? identifier.identifier.string : null;
         if(!avoidDuplicates || (s && !identifiers.Find(s)))
         {
            identifiers.Add(s);
            result = true;
         }
      }
   }
   return result;
}

bool extractIdentifierValue(CQL2Expression e, const String id, FieldValue v)
{
   bool result = false;
   if(e)
   {
      if(e && e._class == class(CQL2ExpBrackets))
      {
         CQL2ExpBrackets brkt = (CQL2ExpBrackets)e;
         for(b : brkt.list; !result)
            result = extractIdentifierValue(b, id, v);
      }
      else if(e && e._class == class(CQL2ExpInstance))
      {
         CQL2ExpInstance inst = (CQL2ExpInstance)e;
         if(inst && inst.instance)
         {
            for(i : inst.instance.members; !result)
            {
               CQL2MemberInitList members = i;
               for(m : members; !result)
               {
                  CQL2MemberInit mInit = m;
                  if(mInit.initializer)
                     result = extractIdentifierValue(mInit.initializer, id, v);
               }
            }
         }
      }
      else if(e && e._class == class(CQL2ExpConditional))
      {
         CQL2ExpConditional cond = (CQL2ExpConditional)e;

         result = extractIdentifierValue(cond.elseExp, id, v);
         if(!result)
            result = extractIdentifierValue(cond.condition, id, v);

         if(!result && cond.expList)
            for(ce : cond.expList; !result)
               result = extractIdentifierValue(ce, id, v);
      }
      else if(e && e._class == class(CQL2ExpList))
      {
         CQL2ExpList list = (CQL2ExpList)e;
         for(l : list; !result)
            result = extractIdentifierValue(l, id, v);
      }
      else if(e && e._class == class(CQL2ExpCall))
      {
         CQL2ExpCall call = (CQL2ExpCall)e;
         if(call.exp)
            result = extractIdentifierValue(call.exp, id, v);
         if(!result && call.arguments)
            for(a : call.arguments; !result)
               result |= extractIdentifierValue(a, id, v);
      }
      if(e._class == class(CQL2ExpOperation))
      {
         CQL2ExpOperation expOp = (CQL2ExpOperation)e;
         bool r1 = extractIdentifierValue(expOp.exp1, id, v);
         bool r2 = extractIdentifierValue(expOp.exp2, id, v);
         if(r1 && expOp.exp2 && expOp.exp2._class == class(CQL2ExpConstant) && expOp.op == '=')
         {
            CQL2ExpConstant c = (CQL2ExpConstant)expOp.exp2;
            v = c.constant;
            result = true;
         }
         else if(r2 && expOp.exp1 && expOp.exp1._class == class(CQL2ExpConstant) && expOp.op == '=')
         {
            CQL2ExpConstant c = (CQL2ExpConstant)expOp.exp1;
            v = c.constant;
            result = true;
         }
         else if(expOp.op == and)
            result = r1 || r2;
      }
      else if(e._class == class(CQL2ExpIdentifier))
      {
         CQL2ExpIdentifier identifier = (CQL2ExpIdentifier)e;
         const String s = identifier.identifier ? identifier.identifier.string : null;
         if(s && !strcmpi(id, s))
            result = true;
      }
   }
   return result;
}

//public String getSceneIDFromExp(CQL2Expression e)
/*
CQL2Expression extractSceneExpFromFilter(CQL2Expression e)
{
   CQL2Expression result = null;
   removeSceneExp(e, result);
   return result;
}*/

bool removeSceneExp(CQL2Expression e)
{
   bool result = false;
   CQL2ExpOperation expOp = e._class == class(CQL2ExpOperation) ? (CQL2ExpOperation)e : null;
   if(expOp)
   {
      if(expOp.exp1 && expOp.exp1._class == class(CQL2ExpOperation))
      {
         result = removeSceneExp(expOp.exp1);
         if(result)
         {
            delete expOp.exp1;
            result = false;
         }
      }
      else if(expOp.exp2 && expOp.exp2._class == class(CQL2ExpOperation))
      {
         result = removeSceneExp(expOp.exp2);
         if(result)
         {
            delete expOp.exp2;
            result = false;
         }
      }
      else
      {
         CQL2ExpString expStr = (expOp.exp2 && expOp.exp2._class == class(CQL2ExpString)) ? (CQL2ExpString)expOp.exp2 : null;
         CQL2ExpMember member = (expOp.exp1 && expOp.exp1._class == class(CQL2ExpMember)) ? (CQL2ExpMember)expOp.exp1 : null;
         // NOTE other operators done elsewhere? should this return an array of ids?
         if(member && expStr)
         {
            CQL2Identifier memID = member.member;
            CQL2ExpIdentifier identifier = (CQL2ExpIdentifier)member.exp;
            if(!strcmp(memID.string, "id") && !strcmp(identifier.identifier.string, "scene") && expOp.op == equal)
               result = true;
         }
      }
   }
   return result;
}
