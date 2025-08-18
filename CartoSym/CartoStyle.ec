public import IMPORT_STATIC "ecrt"
public import IMPORT_STATIC "CQL2"

private:

public class CartoStyle
{
   ~CartoStyle()
   {
      if(list) list.Free(), delete list;
   }

public:
   StyleBlockList list;
                                    // Returns first rule block intersecting mask and containing name
   StylingRule findRule(InstanceMask mask, const String name)
   {
      if(this && list)
      {
         for(b : list; b._class == class(StylingRule))
         {
            StylingRule sb = (StylingRule)b;
            StylingRule block = sb.findRule(mask, name);
            if(block)
               return block;
         }
      }
      return null;
   }

   //NOTE this ignores selectors!
   bool changeStyle(const String layerID, InstanceMask mask, const FieldValue value, Class stylesClass, CQL2Evaluator evaluator,
      bool isNested, Class unitClass)
   {
      bool result = false;
      StylingRule block = findRule(mask, layerID);
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
   void removeProperty(const String id, InstanceMask mask)
   {
      StylingRule block = findRule(mask, id);
      if(block)
      {
         block.symbolizer.removeProperty(mask);
      }
   }

   CartoStyle bind(CQL2Evaluator evaluator, Class stylesClass, const String name)
   {
      CartoStyle result = null;
      if(this && list)
      {
         for(b : list; b._class == class(StylingRule))
         {
            StylingRule sb = (StylingRule)b;
            StylingRule block = sb.bind(evaluator, stylesClass, name);
            if(block)
            {
               if(!result) result = { list = { } };
               result.list.Add(block);
            }
         }
      }
      return result;
   }

   bool resolve(CQL2Evaluator evaluator, Class stylesClass)
   {
      bool result = false;
      if(this && list)
      {
         for(b : list; b._class == class(StylingRule))
         {
            StylingRule sb = (StylingRule)b;
            result = sb.resolve(evaluator, stylesClass);
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

   CartoStyle ::loadFile(File f)
   {
      bool result = true;
      StyleBlockList list = null;
      if(f)
      {
         CQL2Lexer lexer { };
         lexer.initFile(f);
         list = StyleBlockList::parse(lexer);
         if(lexer.type == lexingError ||
            lexer.type == syntaxError ||
            (lexer.nextToken && (lexer.nextToken.type != endOfInput)))
         {
#ifdef _DEBUG
            if(lexer.type == lexingError)
               PrintLn("CartoSym-CSS Lexing Error at line ", lexer.pos.line, ", column ", lexer.pos.col);
            else
               PrintLn("CartoSym-CSS Syntax Error: Unexpected token ", lexer.nextToken.type,
                  lexer.nextToken.text ? lexer.nextToken.text : "",
                  " at line ", lexer.pos.line, ", column ", lexer.pos.col);
#endif
            delete list;
            result = false;
         }

         delete lexer;
      }
      return result ? CartoStyle { list = list ? list : { } } : null;
   }

   CartoStyle ::load(const String fileName)
   {
      CartoStyle result = null;
      File f = fileName ? FileOpen(fileName, read) : null;
      if(f)
      {
         result = loadFile(f);
         delete f;
      }
      return result;
   }

   CartoStyle ::loadString(const String s)
   {
      CartoStyle result = null;
      if(s)
      {
         TempFile tmp { buffer = (byte *)s, size = strlen(s) };
         result = loadFile(tmp);
         tmp.StealBuffer();
         delete tmp;
      }
      return result;
   }

   CartoStyle copy()
   {
      CartoStyle sheet { list = list.copy() };
      return sheet;
   }
}

// This is a semi-colon-separated list
public class SymbolizerProperties : CQL2InstInitList
{
public:
   SymbolizerProperties ::parse(CQL2Lexer lexer)
   {
      SymbolizerProperties list = null;
      while(true)
      {
         CQL2MemberInitList e = CQL2MemberInitList::parse(lexer);
         if(e)
         {
            if(!list) list = SymbolizerProperties { };
            list.Add(e);
         }
         else
            break;

         if(lexer.peekToken().type == identifier)
         {
            CQL2Token t;
            int a = lexer.pushAmbiguity();
            lexer.readToken();
            t = lexer.peekToken();
            lexer.popAmbiguity(a);
            if(t.type == '[' || t.type == '{' || t.type == '}')
               break;
            lexer.peekToken();
         }

         if(lexer.nextToken.type == '[' || lexer.nextToken.type == '{' || lexer.nextToken.type == '}' ||
            !lexer.nextToken.type)
            break;
      }
      return list;
   }
}

public class StylingRuleSelector : CQL2Node
{
public:
   CQL2Expression exp;

   ~StylingRuleSelector()
   {
      delete exp;
   }

   StylingRuleSelector ::parse(CQL2Lexer lexer)
   {
      StylingRuleSelector selector = null;
      CQL2Expression e;
      if(lexer.peekToken().type == '[')
         lexer.readToken();
      e = CQL2Expression::parse(lexer);
      if(e)
         selector = { exp = e };
      if(lexer.peekToken().type == ']')
         lexer.readToken();
      return selector;
   }

   void print(File out, int indent, CQL2OutputOptions o)
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

public class SelectorList : CQL2List<StylingRuleSelector>
{
public:
   SelectorList ::parse(CQL2Lexer lexer)
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
         if(lexer.nextToken.type == identifier ||
            lexer.nextToken.type == '{' || lexer.nextToken.type == '}' || !lexer.nextToken.type)
            break;
      }
      return list;
   }

   void print(File out, int indent, CQL2OutputOptions o)
   {
      CQL2List::print(out, indent, o);
   }

   void printSep(File out)
   {

   }
}

public class StyleBlockList : CQL2List<StyleBlock>
{
   // TODO: Optimization Maps per re-used attributes of values -> relevant nested rules

public:
   StyleBlockList ::parse(CQL2Lexer lexer)
   {
      return (StyleBlockList)CQL2List::parse(class(StyleBlockList), lexer, StyleBlock::parse, 0);
   }
   InstanceMask mask;

   void print(File out, int indent, CQL2OutputOptions o)
   {
      CQL2List::print(out, indent, o);
   }

   void printSep(File out)
   {
   }

   InstanceMask apply(void * object, InstanceMask m, CQL2Evaluator evaluator, ExpFlags * flg)
   {
      Link it = list.last;
      //Iterator<StylingRule> it { list };
      while(m && it) //it.Prev())
      {
         StylingRule block = (StylingRule)(uint64)it.data;
         InstanceMask bm = block.mask & m;
         if(bm)
            m = block.apply(object, m, evaluator, flg, false);
         it = it.prev;
      }
      return m;
   }

   InstanceMask apply2(void * object, InstanceMask m, CQL2Evaluator evaluator, ExpFlags * flg, InstanceMask * fm)
   {
      Link it = list.last;
      //Iterator<StylingRule> it { list };
      while(m && it) //it.Prev())
      {
         StylingRule block = (StylingRule)(uint64)it.data;
         if(block._class == class(StylingRule))
         {
            InstanceMask bm = block.mask & m;
            if(bm)
               m = block.apply2(object, m, evaluator, flg, false, fm);
         }
         it = it.prev;
      }
      return m;
   }
}

public class StyleBlock : CQL2Node
{
   class_no_expansion;
public:

   StyleBlock ::parse(CQL2Lexer lexer)
   {
      lexer.peekToken();

      if(lexer.nextToken.type == '[' || lexer.nextToken.type == identifier || lexer.nextToken.type == '{')
         return StylingRule::parse(lexer);
      else if(lexer.nextToken.type == '.')
         return StyleMetadata::parse(lexer);
      return null;
   }
}

public class StyleMetadata : StyleBlock
{
   class_no_expansion;
public:

   CQL2Identifier type;
   CQL2ExpString value;

   StyleBlock ::parse(CQL2Lexer lexer)
   {
      if(lexer.nextToken.type == '.')
      {
         lexer.readToken();

         lexer.peekToken();
         if(lexer.nextToken.type == identifier)
         {
            CQL2Identifier type = CQL2Identifier::parse(lexer);

            if(type)
            {
               lexer.peekToken();

               if(lexer.nextToken.type == stringLiteral)
                  return StyleMetadata { type = type, value = CQL2ExpString::parse(lexer) };
               else
                  delete type;
            }
         }
      }
      return null;
   }

   void print(File out, int indent, CQL2OutputOptions o)
   {
      out.Print(".");
      type.print(out, indent, o);
      out.Print(" ");
      value.print(out, indent, o);
      out.PrintLn("");
   }

   ~StyleMetadata()
   {
      delete value;
   }
}

public class StylingRule : StyleBlock
{
   class_no_expansion;
public:
   StyleBlockList nestedRules;
   SelectorList selectors;
   // REVIEW: Did we intend to support a list of identifiers? (rules applying to multiple layers?)
   CQL2Identifier id;
   SymbolizerProperties symbolizer;
   InstanceMask mask;

   StylingRule ::parse(CQL2Lexer lexer)
   {
      lexer.peekToken();

      if(lexer.nextToken.type == '[' || lexer.nextToken.type == identifier || lexer.nextToken.type == '{')
      {
         StylingRule block { };

         if(lexer.peekToken().type == identifier)
            block.id = CQL2Identifier::parse(lexer);

         if(lexer.peekToken().type == '[')
            block.selectors = SelectorList::parse(lexer);

         if(lexer.peekToken().type == '{')
            lexer.readToken();

         if(lexer.peekToken().type == identifier)
            block.symbolizer = SymbolizerProperties::parse(lexer);

         lexer.peekToken();
         if(lexer.nextToken.type == '[' || lexer.nextToken.type == identifier || lexer.nextToken.type == '{')
            block.nestedRules = StyleBlockList::parse(lexer);

         if(lexer.peekToken().type == '}')
            lexer.readToken();
         return block;
      }
      return null;
   }

   // Returns first rule block intersecting mask and containing name
   StylingRule findRule(InstanceMask mask, const String name)
   {
      if(id && id.string && name && strcmpi(id.string, name))
         return null;

      if(symbolizer && symbolizer.GetCount())
      {
         for(s : symbolizer)
         {
            for(m : s)
            {
               CQL2MemberInit mInit = m;
               InstanceMask sm = mInit.stylesMask;
               if(sm & mask)
                  return this;
            }
         }
      }

      if(nestedRules)
      {
         for(b : nestedRules; b._class == class(StylingRule))
         {
            StylingRule sb = (StylingRule)b;
            StylingRule block = sb.findRule(mask, name);
            if(block)
               return sb;
         }
      }
      return null;
   }

   private StylingRule bind(CQL2Evaluator evaluator, Class stylesClass, const String name)
   {
      StylingRule result = null;
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
            CQL2Expression e = convertToInternalCQL2(s.exp); // REVIEW: Automatically internalizing here... os.exp.copy();
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
         StylingRule block { selectors = newSelectors };
         InstanceMask mask = 0;
         if(id) block.id = { string = CopyString(id.string) };
         if(symbolizer)
         {
            SymbolizerProperties newSymbolizer { };
            for(s : symbolizer)
            {
               CQL2MemberInitList style = s;
               CQL2MemberInitList newStyle { };
               for(m : style)
               {
                  CQL2MemberInit member = m.copy();
                  /*ExpFlags flags = */member.precompute(stylesClass, stylesClass, 0, null, evaluator);  // TODO: Consider these flags
                  newStyle.Add(member);
                  newSymbolizer.mask |= member.stylesMask;
               }
               newSymbolizer.Add(newStyle);
            }
            block.symbolizer = newSymbolizer;
            mask |= newSymbolizer.mask;
         }

         if(nestedRules)
         {
            for(b : nestedRules; b._class == class(StylingRule))
            {
               StylingRule sb = (StylingRule)b;
               StylingRule nb = sb.bind(evaluator, stylesClass, name);
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

   private bool resolve(CQL2Evaluator evaluator, Class stylesClass)
   {
      bool result = false;
      if(selectors)
      {
         // TODO: Per-record flags for selectors?
         for(s : selectors)
         {
            FieldValue value { };
            CQL2Expression e = s.exp;
            ExpFlags flags = e.compute(value, evaluator, preprocessing, stylesClass);
            if(flags.resolved)
            {
               e = simplifyResolved(value, e);
               s.exp = e;
               //delete e; // NOTE: viz.sd operations were being deleted when resolved
            }
         }
      }

      if(symbolizer)
      {
         for(s : symbolizer)
         {
            CQL2MemberInitList style = s;
            for(m : style)
            {
               CQL2MemberInit member = m;
               // passing stylesClass here just passes irrelevant CartoSymbolizer class, but the others are not yet bound
               member.precompute(stylesClass, stylesClass, 0, null, evaluator);  // TODO: Consider these flags
               symbolizer.mask |= member.stylesMask;
            }
         }
         this.mask |= symbolizer.mask;
      }

      if(nestedRules)
      {
         for(b : nestedRules; b._class == class(StylingRule))
         {
            StylingRule sb = (StylingRule)b;
            sb.resolve(evaluator, stylesClass);
            nestedRules.mask |= sb.mask;
         }
         mask |= nestedRules.mask;
      }
      result = true;

      return result;
   }

   CQL2Expression getProperty(InstanceMask mask)
   {
      return symbolizer ? symbolizer.getProperty(mask) : null;
   }


   void setStyle(Class c, const String idString, InstanceMask msk, bool createSubInstance, CQL2Expression expression,
      CQL2Evaluator evaluator, Class stylesClass)
   {
      if(msk)
      {
         if(!symbolizer) symbolizer = { };
         symbolizer.setMember2(c, idString, msk, createSubInstance, expression, evaluator, stylesClass, none);
         mask |= msk;
      }
   }

   void setStyleEx(Class c, const String idString, InstanceMask msk, bool createSubInstance, CQL2Expression expression,
      CQL2Evaluator evaluator, Class stylesClass, CQL2TokenType tt)
   {
      if(msk)
      {
         if(!symbolizer) symbolizer = { };
         symbolizer.setMember2(c, idString, msk, createSubInstance, expression, evaluator, stylesClass, tt);
         mask |= msk;
      }
   }

   // NOTE: isNested means this is a nested rule, and we want to set top.sub = as opposed to top = { sub = }
   bool changeStyle(InstanceMask msk, const FieldValue value, Class c, CQL2Evaluator evaluator, bool isNested, Class unitClass)
   {
      if(msk)
      {
         if(!symbolizer) symbolizer = { };
         if(symbolizer.changeProperty(msk, value, c, evaluator, isNested, unitClass))
         {
            mask |= msk;
            return true;
         }
      }
      return false;
   }

   void removeProperty(InstanceMask msk)
   {
      if(this)
      {
         symbolizer.removeProperty(msk);
      }
   }

   void print(File out, int indent, CQL2OutputOptions o)
   {
      const char * ln = o.dbgOneLiner ? " " : "\n";

      if(o.skipEmptyBlocks &&
         (!symbolizer || !symbolizer.list.first) &&
         (!nestedRules || !nestedRules.list.count))
         return;

      out.Print(ln);
      if(!o.dbgOneLiner) printIndent(indent, out);
      if(id)
         id.print(out, indent, o);

      if(selectors)
         selectors.print(out, indent, o);

      if(id || selectors)
      {
         out.Print(ln);
         if(!o.dbgOneLiner) printIndent(indent, out);
      }
      out.Print("{", ln);
      indent++;

      if(symbolizer)
      {
         Iterator<CQL2MemberInitList> it { symbolizer };
         while(it.Next())
         {
            CQL2MemberInitList list = it.data;

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

   ~StylingRule()
   {
      delete selectors;
      delete id;
      delete symbolizer;
      delete nestedRules;
   }

   StylingRule copy()
   {
      StylingRule b = null;

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
         if(symbolizer)
         {
            b.symbolizer = { mask = symbolizer.mask };
            for(n : symbolizer)
               b.symbolizer.Add(n.copy());
         }
      }
      return b;
   }

   // This should return the mask of symbolization properties which could be different based on exp flags...
   private InstanceMask apply2(void * object, InstanceMask m, CQL2Evaluator evaluator, ExpFlags * flg, bool ignoreSelectors, InstanceMask * fm)
   {
      InstanceMask result = m;
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
            CQL2Expression e = sel.exp; // ? sel.exp.copy() : null;
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
         InstanceMask nfm = 0;
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
            Link itStyle = symbolizer ? symbolizer.list.last : null;
            while(itStyle)
            {
               CQL2MemberInitList initList = (CQL2MemberInitList)(uintptr)itStyle.data;
               Link itMember = initList.list.last;
               while(itMember)
               {
                  CQL2MemberInit member = (CQL2MemberInit)itMember.data;
                  CQL2Expression e = member.initializer;
                  InstanceMask sm = member.stylesMask;
                  ExpFlags f = 0;

                  if(apply)
                  {
                     // since the stylesMask for the CQL2MemberInit in a += scenario could repeat, subsequent elements will be filtered out here with the mask logic
                     // TODO: retrieve the masks from the initializer?
                     /*if(member.assignType == addAssign && e._class == class(CQL2ExpInstance))
                     {
                        CQL2ExpInstance inst = (CQL2ExpInstance)e;
                        CQL2SpecName spec = (CQL2SpecName)inst.instance._class;
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
   public /*private static*/ InstanceMask apply(void * object, InstanceMask m, CQL2Evaluator evaluator, ExpFlags * flg, bool ignoreSelectors)
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
            CQL2Expression e = sel.exp; // ? sel.exp.copy() : null;
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
            //Iterator<CQL2MemberInitList> itStyle { styles };
            Link itStyle = symbolizer ? symbolizer.list.last : null;
            while(itStyle) //.Prev())
            {
               CQL2MemberInitList initList = (CQL2MemberInitList)(uintptr)itStyle.data;
               //Iterator<CQL2MemberInit> itMember { itStyle.data };
               Link itMember = initList.list.last;
               while(itMember) //.Prev())
               {
                  CQL2MemberInit member = (CQL2MemberInit)itMember.data;
                  CQL2Expression e = member.initializer;
                  InstanceMask sm = member.stylesMask;
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

   private static void ::applyStyle(void * object, InstanceMask mSet, CQL2Evaluator evaluator, CQL2Expression e, ExpFlags * flg, int unitVal, CQL2TokenType assignType)
   {
      CQL2ExpInstance inst = null;
      CQL2ExpArray arr = null;
      CQL2ExpConditional cond = null;
      int unit = unitVal;
      subclass(CQL2Evaluator) evaluatorClass = evaluator.evaluatorClass;

      if(e)
      {
         inst = e._class == class(CQL2ExpInstance) ? (CQL2ExpInstance)e : null;
         arr = e._class == class(CQL2ExpArray) ? (CQL2ExpArray)e : null;
         cond = e._class == class(CQL2ExpConditional) ? (CQL2ExpConditional)e : null;
      }

      // REVIEW: Shouldn't the expType be what indicate the unit?
      // special handling for conditional with potential unitClass as a compute on conditional would not yield the unit
      if(cond && cond.condition)
      {
         CQL2Expression lastExp = cond.expList ? cond.expList.lastIterator.data : null;
         if((lastExp && lastExp._class == class(CQL2ExpInstance)) ||
            (cond.elseExp && cond.elseExp._class == class(CQL2ExpInstance)))
         {
            FieldValue condValue {};
            ExpFlags flagsCond = cond.condition.compute(condValue, evaluator, runtime, e.destType);
            if(flagsCond.resolved && condValue.i)
            {
               inst = lastExp._class == class(CQL2ExpInstance) ? (CQL2ExpInstance)lastExp : null;
            }
            else if(flagsCond.resolved && cond.elseExp && cond.elseExp._class == class(CQL2ExpInstance))
            {
               inst = (CQL2ExpInstance)cond.elseExp;
            }
         }
      }
      if(inst && inst.instance)
      {
         CQL2SpecName spec = (CQL2SpecName)inst.instance._class;
         String n = spec ? spec.name : null;
         if(n && !strcmpi(n, "Meters"))     // TODO: make this generic
         {
            unit = 1; // meters
            /*e = null;
            for(i : inst.instance.members)
            {
               CQL2MemberInitList members = i;
               for(m : members)
               {
                  CQL2MemberInit mInit = m;
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
               for(e : arr.elements; e._class == class(CQL2ExpInstance))
               {
                  CQL2ExpInstance expInstance = (CQL2ExpInstance)e;
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

   private static void ::applyInstanceStyle(void * object, InstanceMask mask, CQL2ExpInstance inst,
      CQL2Evaluator evaluator, ExpFlags * flg, int unit)
   {
      if(inst)
      {
         CQL2InstInitList instMembers = inst.instance.members;
         List<CQL2MemberInitList> membersInitList = instMembers ? instMembers.list : null;
         Link i;
         for(i = membersInitList ? membersInitList.first : null; i; i = i.next)
         {
            CQL2MemberInitList members = (CQL2MemberInitList)(uintptr)i.data;
            List<CQL2MemberInit> membersList = members.list;
            Link m;
            for(m = membersList.first; m; m = m.next)
            {
               CQL2MemberInit mInit = (CQL2MemberInit)(uintptr)m.data;
               if(mInit.initializer)
               {
                  InstanceMask sm = mInit.stylesMask;
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
