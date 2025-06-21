public import IMPORT_STATIC "ecrt"
public import IMPORT_STATIC "CartoSym"

private: // FIXME: Fix this public default after import

static class TagOpenType { public: bool open:1, close:1; };

#define openTag(t)      writeTag(t, { open = true               })
#define closeTag(t)     writeTag(t, {              close = true })
#define openCloseTag(t) writeTag(t, { open = true, close = true })


static Map<CQL2TokenType, const String> operatorsMap
{ [

   // Text Comparison
   { stringContains, "ogc:StringContains"},       // TODO: Reg exp?
   { stringStartsWith, "ogc:StringStartsWith"},     // TODO: Reg exp?
   { stringEndsWith, "ogc:StringEndsWith"},       // TODO: Reg exp?
   { stringNotContains, "ogc:StringNotContains"},    // TODO: Reg exp?
   { stringNotStartsW, "ogc:StringNotStartsWith"},     // TODO: Reg exp?
   { stringNotEndsW, "ogc:StringNotEndsWith"},       // TODO: Reg exp?

   { equal, "ogc:PropertyIsEqualTo" },
   { notEqual, "ogc:PropertyIsNotEqualTo" },
   { smaller, "ogc:PropertyIsSmallerThan" },
   { greater, "ogc:PropertyIsGreaterThan" },
   { smallerEqual, "ogc:PropertyIsLessThanOrEqualTo" },
   { greaterEqual, "ogc:PropertyIsGreaterThanOrEqualTo" },

   // Logical
   { or, "ogc:Or"},
   { and, "ogc:And"},
   { not, "ogc:Not"},
   { in, "ogc:Or"},

   // Arithmetic
   { plus, "ogc:Add" },
   { minus, "ogc:Sub"},
   { multiply, "ogc:Mul"},
   { divide, "ogc:Div"},
   { modulo, "ogc:Mod" }
] };

static struct SLDWriter
{
private:
   File f;
   int indent;
   bool fillExists;
   bool strokeExists;
   bool firstOfFillStroke;
   bool lastOfFillStroke;
   bool metric;

   SymbolsReferenceMode symRefMode;
   const String baseURL;
   Map<String, FeatureDataType> typeMap;

   void writeRulePass(StylingRule block, CQL2Expression filter, double minScale, double maxScale,
      FeatureDataType type, CartoSymbolizer sym, StylingRule labelElementsBlock, CartoExpFlags flg,
      bool isCasing, bool hasCasing, bool onlyLabel)
   {
      openTag("se:Rule");
      if(!filter && !isCasing)
         openCloseTag("se:ElseFilter");
      else
      {
         // Build a negation filter of nested rules
         CQL2Expression negFilter = null;

         if(block.nestedRules)
         {
            double nMinScale = 0, nMaxScale = 0;

            for(b : block.nestedRules; b._class == class(StylingRule))
            {
               StylingRule sb = (StylingRule)b;
               // AND all the selectors into 're' ("rule expression")
               CQL2Expression re = null;
               for(s : sb.selectors)
               {
                  if(!(getScale(s.exp, &nMinScale, &nMaxScale)))
                  {
                     re = re ? CQL2ExpOperation { exp1 = re, op = and, exp2 = s.exp.copy() } : s.exp.copy();
                  }
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
               filter = filter ? CQL2ExpOperation { exp1 = filter, op = and, exp2 = negFilter } : negFilter;
            }
         }

         if(filter)
         {
            openTag("ogc:Filter");
            writeExpression(filter, none);
            closeTag("ogc:Filter");
         }

         if(minScale || maxScale)
            writeScale(minScale, maxScale);
      }
      writeSymbolizer(sym, type, labelElementsBlock, flg, isCasing, hasCasing, onlyLabel, block);
      closeTag("se:Rule");
   }

   bool writeRuleBlock(StylingRule block, CartoSymbolizer inheritedSymbolizer, CQL2Expression parentFilter,
      FeatureDataType type, double parentMinScale, double parentMaxScale, StylingRule labelElementsBlock, CartoExpFlags eFlags,
      bool topRule)
   {
      CartoSymbolizer sym = inheritedSymbolizer ? inheritedSymbolizer.copy() : { };
      GraphicalSymbolizerMask m = 0xffffffffffffffff;
      CartoExpFlags flg = eFlags;
      CartoSymEvaluator evaluator { class(CartoSymEvaluator) };
      double minScale = 0, maxScale = 0;
      CQL2Expression filter = parentFilter ? parentFilter.copy() : null;

      evaluator.setFeatureID(-1);

      flg.resolved = false;

      m = (GraphicalSymbolizerMask)block.apply(sym, m, evaluator, &flg, true);
      // TODO: For now this does not yet support adding to elements (+=)
      if(((CartoSymbolizerMask)block.mask).labelElements)
         labelElementsBlock = block;

      //if(m) inheritedSymbolizer.applyDefaults(m);
      sym.flags = flg;

      if(block.selectors)
      {
         for(l : block.selectors)
            if(!(getScale(l.exp, &minScale, &maxScale)))
               filter = filter ? CQL2ExpOperation { exp1 = filter, op = and, exp2 = l.exp.copy() } : l.exp.copy();
      }

      minScale = minScale && parentMinScale ? Max(minScale, parentMinScale) : minScale ? minScale : parentMinScale ? parentMinScale : 0;
      maxScale = maxScale && parentMaxScale ? Min(maxScale, parentMaxScale) : maxScale ? maxScale : parentMaxScale ? parentMaxScale : 0;

      {
         FieldValue value { };
         filter.compute(value, evaluator, preprocessing, class(CartoSymbolizer));
         value.OnFree();
      }

      if(block.nestedRules)
      {
         for(b : block.nestedRules; b._class == class(StylingRule))
         {
            writeRuleBlock((StylingRule)b, sym, filter, type, minScale, maxScale, labelElementsBlock, flg, false);
         }
      }

      // Avoid creating a rule with no symbolizer for points
      if(type.type == vector && type.vectorType == points && (!sym.label || !sym.label.elements.GetCount()))
         delete sym;

      if(sym && sym.visibility)
      {
         bool hasCasing = false;
         // NOTE: We are currently skipping generating strokes/fills to allow a rule overlapping with siblings conditions
         //       only labels based on a filter...
         bool onlyLabel = sym.label && sym.label.elements && sym.label.elements.GetCount() && !topRule &&
            !(block.symbolizer && (block.symbolizer.mask & (CartoSymbolizerKind::fill | CartoSymbolizerKind::stroke)));
         if(!onlyLabel && type.type == vector && type.vectorType != points &&
            sym.stroke.width && sym.stroke.casing.width && sym.stroke.casing.opacity)
         {
            hasCasing = true;
            writeRulePass(block, filter, minScale, maxScale, type, sym, labelElementsBlock, flg, true, true, false);
         }
         writeRulePass(block, filter, minScale, maxScale, type, sym, labelElementsBlock, flg, false, hasCasing, onlyLabel);
      }
      delete filter;
      delete sym;
      return true;
   }

   bool writeList(StyleBlockList list)
   {
      CartoSymbolizer defSym = null;
      CartoExpFlags flg = 0;
      bool specificLayers = false;

      for(r : list; r._class == class(StylingRule))
      {
         StylingRule rule = (StylingRule)r;
         const String id = rule.id ? rule.id.string : null;
         if(!id)
         {
            GraphicalSymbolizerMask m = 0xffffffffffffffff;
            CartoSymEvaluator evaluator { class(CartoSymEvaluator) };
            evaluator.setFeatureID(-1);
            if(!defSym) defSym = { };
            flg.resolved = false;
            (GraphicalSymbolizerMask)rule.apply(defSym, m, evaluator, &flg, true);
         }
         else
            specificLayers = true;
      }
      if(!specificLayers && list.GetCount())
      {
         // No name to specify for generic style and NamedLayer required a Name
         f.Puts("   <sld:UserLayer>\n");
      }

      for(r : list; r._class == class(StylingRule))
      {
         StylingRule rule = (StylingRule)r;
         const String id = rule.id ? rule.id.string : null;
         if(id)
         {
            FeatureDataType type = id && typeMap ? typeMap[id] : { none };
            if(type.type == none) type = { type = vector, vectorType = polygons };

            f.Puts("   <sld:NamedLayer>\n");
            f.Print("     <se:Name>", id, "</se:Name>\n");
            f.Puts("     <sld:UserStyle>\n");
            f.Puts("       <se:FeatureTypeStyle>\n");
            indent = 5;
            writeRuleBlock(rule, defSym, null, type, 0, 0, null, flg, true);
            f.Puts("       </se:FeatureTypeStyle>\n");
            f.Puts("     </sld:UserStyle>\n");
            f.Puts("   </sld:NamedLayer>\n");
         }
         else
         {
            FeatureDataType type { type = vector, vectorType = polygons };
            StylingRule b = rule;
            CartoSymbolizerKind m = (CartoSymbolizerKind)b.mask;

            f.Puts("     <sld:UserStyle>\n");
            f.Puts("       <se:FeatureTypeStyle>\n");
            indent = 5;

            if((CartoSymbolizerKind)m & CartoSymbolizerKind::marker)
               type = { vector, vectorType = points };
            else if(m & CartoSymbolizerKind::hillShading || m & CartoSymbolizerKind::colorChannels || m & CartoSymbolizerKind::singleChannel)
               type = { coverage };
            else if(m & CartoSymbolizerKind::fill)
               type = { vector, vectorType = polygons };
            else if(m & CartoSymbolizerKind::stroke)
               type = { vector, vectorType = lines };

            writeRuleBlock(rule, defSym, null, type, 0, 0, null, flg, true);
            f.Puts("       </se:FeatureTypeStyle>\n");
            f.Puts("     </sld:UserStyle>\n");
         }
      }
      if(!specificLayers && list.GetCount())
      {
         f.Puts("   </sld:UserLayer>\n");
      }
      return false;
   }

   void writeScale(double minScale, double maxScale)
   {
      if(minScale)
         writeIndent(), f.Print("<se:MinScaleDenominator>", minScale, "</se:MinScaleDenominator>\n");
      if(maxScale)
         writeIndent(), f.Print("<se:MaxScaleDenominator>", maxScale, "</se:MaxScaleDenominator>\n");
   }

   bool writeExpression(CQL2Expression e, CQL2TokenType parentOp ) //double * minScale, double * maxScale
   {
      bool isScale = false;

      if(e._class == class(CQL2ExpOperation))
      {
         CQL2ExpOperation expOp = (CQL2ExpOperation)e;
         bool newTag = expOp.op != parentOp;
         //if(newTag) openTag(opString);
         if(expOp.op == in)
         {
            // NOTE: since SLD SE does not currently support the 'IN' operator, use a succession of ORs
            if(newTag) openTag("ogc:Or");
            if(expOp.exp1 && expOp.exp2 && expOp.exp2._class == class(CQL2ExpBrackets))
            {
               CQL2ExpBrackets expBrackets = (CQL2ExpBrackets)expOp.exp2;
               //expBrackets.compute(value, null, runtime);

               for(l : expBrackets.list)
               {
                  openTag(operatorsMap[equal]);
                  /*isScale = */writeExpression(expOp.exp1, expOp.op);
                  writeExpression(l, equal);
                  closeTag(operatorsMap[equal]);
               }
            }
            if(newTag) closeTag("ogc:Or");
         }
         else
         {
            const String opString = operatorsMap[expOp.op];
            CQL2Expression op1 = expOp.exp1, op2 = expOp.exp2;
            CQL2Expression member =
               op1 && op1._class == class(CQL2ExpMember) ? op1 :
               op2 && op2._class == class(CQL2ExpMember) ? op2 : null;

            // since the tag must be open before entering this scope, can't write and verify scale at the same time!
            // therefore use helper function to assess whether scale exists
            isScale = member ? checkScale(member) : false;
            if(!isScale)
            {
               if(newTag)
                  openTag(opString);
               if(op1 && op2 && op1._class == class(CQL2ExpOperation) && op2._class == class(CQL2ExpOperation))
               {
                  writeExpression(op1, expOp.op);
                  writeExpression(op2, expOp.op);
               }
               else
               {
                  // TODO: Treat enumeration values as literals rather than properties
                  CQL2Expression op1IdOrMember = op1 && (op1._class == class(CQL2ExpIdentifier) || op1._class == class(CQL2ExpMember)) ? op1 : null;
                  CQL2Expression op2IdOrMember = op2 && (op2._class == class(CQL2ExpIdentifier) || op2._class == class(CQL2ExpMember)) ? op2 : null;

                  if(op1IdOrMember && op2 && !op2IdOrMember)
                  {
                     writeExpression(op1, expOp.op);
                     writeExpression(op2, expOp.op);
                  }
                  else if(op2IdOrMember && op1 && !op1IdOrMember && (expOp.op == equal || expOp.op == notEqual))
                  {
                     // Swap to have property first for commutative operators
                     writeExpression(op2, expOp.op);
                     writeExpression(op1, expOp.op);
                  }
                  else if(op2)
                  {
                     // REVIEW: This may generate non-property first operands
                     if(op1)
                        writeExpression(op1, expOp.op);
                     else if(expOp.op == minus)
                     {
                        writeIndent();
                        f.Print("<ogc:Literal>0</ogc:Literal>\n");
                     }
                     if(op1 && op1.expType && !op2.destType)
                        op2.destType = op1.expType;
                     writeExpression(op2, expOp.op);
                  }
                  else
                  {
      #ifdef _DEBUG
                     PrintLn("WARNING (SLD): Unhandled case");
      #endif
                  }
               }
               if(newTag)
                  closeTag(opString);
            }
         }
      }
      else if(e._class == class(CQL2ExpMember))
      {
         CQL2ExpMember member = (CQL2ExpMember)e;
         if(member.member && !strcmp(member.member.string, "sd"))
            isScale = true;
         else
         {
            // REVIEW: Write members as properties for now?
            String s = member.toString(0);
            writeIndent();
            f.Print("<ogc:PropertyName>", s, "</ogc:PropertyName>\n");
            delete s;
         }
      }
      else if(e._class == class(CQL2ExpIdentifier))
      {
         CQL2ExpIdentifier expId = (CQL2ExpIdentifier)e;
         Class c = expId.expType ? expId.expType : expId.destType;
         writeIndent();
         if(c && c.type == enumClass)
            f.Print("<ogc:Literal>", expId.identifier.string, "</ogc:Literal>\n");
         else
            f.Print("<ogc:PropertyName>", expId.identifier.string, "</ogc:PropertyName>\n");
      }
      else if(e._class == class(CQL2ExpString))
      {
         CQL2ExpString str = (CQL2ExpString)e;
         writeIndent();
         f.Print("<ogc:Literal>", str.string, "</ogc:Literal>\n");
      }
      else if(e._class == class(CQL2ExpConstant))
      {
         CQL2ExpConstant expConstant = (CQL2ExpConstant)e;
         writeIndent();
         f.Puts("<ogc:Literal>");
         switch(expConstant.constant.type.type)
         {
            case text:    f.Print(expConstant.constant.s); break;
            case real:    f.Print(expConstant.constant.r); break;
            case integer: f.Print(expConstant.constant.i); break;
         }
         f.Puts("</ogc:Literal>\n");
      }
      else if(e._class == class(CQL2ExpBrackets))
      {
         CQL2ExpBrackets expBrackets = (CQL2ExpBrackets)e;
         isScale |= writeExpression(expBrackets.list.lastIterator.data, none);
      }
      return isScale;
   }

   void writeIndent()
   {
      int i;
      for(i = 0; i < indent; i++)
         f.Puts("  ");
   }

   void writeTag(const String elementTag, TagOpenType openType)
   {
      if(openType.close && !openType.open) --indent;
      writeIndent();
      if(openType.open && !openType.close) ++indent;
      f.Print("<", openType.close && !openType.open ? "/" : "", elementTag, openType.open && openType.close ? "/" : "", ">\n");
   }

   void writeHexColor(Color color)
   {
      f.Printf("#%02x%02x%02x", color.r, color.g, color.b);
   }

   void writeSymbolizer(CartoSymbolizer symbolizer, FeatureDataType type, StylingRule labelElementsBlock, CartoExpFlags eFlags,
      bool isCasing, bool hasCasing, bool onlyLabel, StylingRule symBlock)
   {
      // write tags and such in the ifs
      if(type.type == vector)
      {
         CSLabel label = symbolizer.label;
         GraphicalUnit widthUnit = symbolizer.stroke.widthUnit;

         if(!onlyLabel && (type.vectorType == polygons || type.vectorType == lines))
         {
            const String closingTag;
            if(type.vectorType == polygons && (isCasing || !hasCasing))
            {
               const String tag =
                  widthUnit == meters ? "se:PolygonSymbolizer uom=\"http://www.opengeospatial.org/se/units/metre\"" :
                  widthUnit == feet   ? "se:PolygonSymbolizer uom=\"http://www.opengeospatial.org/se/units/foot\"" :
                                        "se:PolygonSymbolizer";
               openTag(tag);
               openTag("se:Fill");
               writeIndent();
               f.Print("<se:SvgParameter name=\"fill\">");
               writeHexColor(symbolizer.fill.color);
               f.Puts("</se:SvgParameter>\n");
               writeIndent();
               f.Print("<se:SvgParameter name=\"fill-opacity\">", symbolizer.fill.opacity, "</se:SvgParameter>\n");
               closeTag("se:Fill");
               closingTag = "se:PolygonSymbolizer";
            }
            else
            {
               const String tag =
                  widthUnit == meters ? "se:LineSymbolizer uom=\"http://www.opengeospatial.org/se/units/metre\"" :
                  widthUnit == feet   ? "se:LineSymbolizer uom=\"http://www.opengeospatial.org/se/units/foot\"" :
                                        "se:LineSymbolizer";
               openTag(tag);
               closingTag = "se:LineSymbolizer";
            }

            if(symbolizer.stroke.width)
            {
               if(isCasing) //symbolizer.stroke.casing.width)
               {
                  GraphicalUnit casingUnit = symbolizer.stroke.casing.widthUnit;
                  double cWidth = symbolizer.stroke.casing.width;
                  double ctWidth = 0;
                  if(casingUnit == widthUnit)
                     ctWidth = symbolizer.stroke.width + 2*cWidth;
                  else if(casingUnit == pixels && widthUnit == meters)
                     ctWidth = symbolizer.stroke.width + 2*cWidth;      // At ~GGG level 15: 1 m / pixels
                  if(ctWidth)
                  {
                     openTag("se:Stroke");
                     writeIndent();
                     f.Print("<se:SvgParameter name=\"stroke\">");
                     writeHexColor(symbolizer.stroke.casing.color);
                     f.Puts("</se:SvgParameter>\n");
                     writeIndent();
                     f.Print("<se:SvgParameter name=\"stroke-width\">", ctWidth, "</se:SvgParameter>\n");
                     writeIndent();
                     f.Print("<se:SvgParameter name=\"stroke-opacity\">", symbolizer.stroke.casing.opacity, "</se:SvgParameter>\n");
                     closeTag("se:Stroke");

                     //closeTag(closingTag);

                     /*
                     openTag(widthUnit == meters ?
                        "se:LineSymbolizer uom=\"http://www.opengeospatial.org/se/units/metre\"" : "se:LineSymbolizer");
                     closingTag = "se:LineSymbolizer";
                     */
                  }
               }
               else
               {
                  openTag("se:Stroke");
                  writeIndent();
                  f.Print("<se:SvgParameter name=\"stroke\">");
                  writeHexColor(symbolizer.stroke.color);
                  f.Puts("</se:SvgParameter>\n");
                  writeIndent();
                  f.Print("<se:SvgParameter name=\"stroke-width\">", symbolizer.stroke.width, "</se:SvgParameter>\n");
                  writeIndent();
                  f.Print("<se:SvgParameter name=\"stroke-opacity\">", symbolizer.stroke.opacity, "</se:SvgParameter>\n");
                  closeTag("se:Stroke");
               }
            }

            closeTag(closingTag);
         }
                     // label for any vectortype
         if(!isCasing && label)
         {
            CQL2List<CQL2Expression> elements = null;
            Iterator<CQL2Expression> it { };
            if(eFlags.record && labelElementsBlock && labelElementsBlock.symbolizer)
               elements = labelElementsFromBlock(labelElementsBlock);

            it.container = (void *)elements;
            for(e : label.elements; e) // REVIEW: How does null elements end up here from MBGL import?
            {
               GraphicalElement element = e;
               // If we have expression-based elements, we iterate them in parallel...
               CQL2ExpInstance elExp = elements ? (it.Next(), (CQL2ExpInstance)it.data) : null;
               if(element.type == text) //class(Text))
               {
                  Text textElement = (Text)element;
                  GraphicalUnit dispUnit = pixels; // TODO: Displacement specified in meters? Font units?
                  const String tag =
                     dispUnit == meters ? "se:TextSymbolizer uom=\"http://www.opengeospatial.org/se/units/metre\"" :
                     dispUnit == feet   ? "se:TextSymbolizer uom=\"http://www.opengeospatial.org/se/units/foot\"" :
                                          "se:TextSymbolizer";
                  openTag(tag);

                  // NOTE: Anywhere SE specifies 'ParameterValueType', either directly a value or an expression is valid
                  //       In this case the <ogc:Literal> is not required
                  // TODO: Support this generically for more than only Label text!
                  if(textElement.text)
                  {
                     writeIndent(); f.Print("<se:Label>"); // openTag("se:Label");
                     f.Print(textElement.text);    // TODO: Escaping?
                     f.PrintLn("</se:Label>"); // closeTag("se:Label");
                  }
                  else if(elExp)
                  {
                     CQL2Expression textExp = getExpInstanceMember(elExp, TextSymbolizerKind::text);
                     if(textExp)
                     {
                        openTag("se:Label");
                        writeExpression(textExp, 0);
                        closeTag("se:Label");
                     }
                  }
                  if(textElement.font)
                  {
                     openTag("se:Font");

                     //paramName = svgTextMap[(TextSymbolizerKind)targetStylesMask];
                     writeIndent();
                     f.Print("<se:SvgParameter name=\"font-family\">", textElement.font.face, "</se:SvgParameter>\n");
                     writeIndent();
                                                                     // Font size must be converted from points to pixels
                     f.Print("<se:SvgParameter name=\"font-size\">", textElement.font.size * 96 / 72, "</se:SvgParameter>\n");
                     writeIndent();
                     f.Print("<se:SvgParameter name=\"font-style\">", CopyString(textElement.font.italic ? "italic" : "normal"), "</se:SvgParameter>\n");
                     writeIndent();
                     f.Print("<se:SvgParameter name=\"font-weight\">", CopyString(textElement.font.bold ? "bold" : "normal"), "</se:SvgParameter>\n");

                     closeTag("se:Font");
                  }
                  // alignment and offset right here

                  if(!(textElement.alignment.horzAlign == unset && textElement.alignment.vertAlign == unset) || !(textElement.position2D.x == 0 && textElement.position2D.y ==0))
                  {
                     openTag("se:LabelPlacement");
                     if(type.vectorType == lines) openTag("se:LinePlacement");
                     else openTag("se:PointPlacement");
                     if(!(textElement.alignment.horzAlign == unset && textElement.alignment.vertAlign == unset))
                     {
                        double x = 0.5, y = 0.5;
                        switch(textElement.alignment.horzAlign)
                        {
                           case unset:
                           case center: break;
                           case left: x = 0; break;
                           case right: x = 1; break;
                        }
                        switch(textElement.alignment.vertAlign)
                        {
                           case unset:
                           case baseLine:
                           case middle: break;
                           case bottom: y = 0; break;
                           case top: y = 1; break;
                        }
                        openTag("se:AnchorPoint");
                        //++indent;
                        writeIndent();
                        f.Print("<se:AnchorPointX>", x, "</se:AnchorPointX>\n");
                        writeIndent();
                        f.Print("<se:AnchorPointY>", y, "</se:AnchorPointY>\n");
                        closeTag("se:AnchorPoint");
                     }
                     if(!(textElement.position2D.x == 0 && textElement.position2D.y ==0))
                     {
                        float ox = textElement.position2D.x, oy = textElement.position2D.y;
                        openTag("se:Displacement");
                        //++indent;
                        writeIndent();
                        f.Print("<se:DisplacementX>", ox, "</se:DisplacementX>\n");
                        writeIndent();
                        f.Print("<se:DisplacementY>", oy, "</se:DisplacementY>\n");
                        closeTag("se:Displacement");
                     }
                     // rotation?
                     //  <Rotation>-45</Rotation>
                     if(type.vectorType == lines) closeTag("se:LinePlacement");
                     else closeTag("se:PointPlacement");
                     closeTag("se:LabelPlacement");
                  }

                  openTag("se:Fill");
                  writeIndent();
                  f.Print("<se:SvgParameter name=\"fill\">");
                  writeHexColor(textElement.font.color);
                  f.Print("</se:SvgParameter>\n");
                  //writeIndent();
                  //f.Print("<SvgParameter name=\"font-family\">", textElement.font.opacity, "</SvgParameter>\n");
                  closeTag("se:Fill");
                  openTag("se:Halo");
                  openTag("se:Fill");
                  writeIndent();
                  f.Print("<se:SvgParameter name=\"fill\">");
                  writeHexColor(textElement.font.outline.color);
                  f.Puts("</se:SvgParameter>\n");
                  //writeIndent();
                  closeTag("se:Fill");
                  writeIndent();
                  {
                     float radius = textElement.font.outline.size;
                     f.Print("<se:Radius>", radius, "</se:Radius>\n");
                  }
                  //writeStyle(class(Outline), svgTextMap[TextSymbolizerKind::fontOutlineSize], FieldValue { type.type = real, r = textElement.font.outline.size });
                  closeTag("se:Halo"); // TOCHECK: This was missing?
                  closeTag("se:TextSymbolizer");
               }
               else if(element.type == image)
               {
                  Image image = (Image)element;
                  const String path = image.image.path;
                  const String id = image.image.id;
                  const String ext = image.image.ext;
                  const String url = image.image.url;
                  const String t = null;
                  if(url || path || id)
                  {
                     char defExt[MAX_LOCATION];
                     char tmp[2048];
                     const String tag =
                        image.unit == meters ? "se:PointSymbolizer uom=\"http://www.opengeospatial.org/se/units/metre\"" :
                        image.unit == feet   ? "se:PointSymbolizer uom=\"http://www.opengeospatial.org/se/units/foot\"" :
                                               "se:PointSymbolizer";

                     openTag(tag);
                     openTag("se:Graphic");

                     if((!symRefMode && url) || symRefMode.url)
                     {
                        if(url)
                        {
                           t = url;
                           if(!ext)
                           {
                              GetExtension(url, defExt);
                              if(defExt[0]) ext = defExt;
                           }
                        }
                        else
                        {
                           strcpy(tmp, baseURL ? baseURL : "/resources/");
                           if(path)
                           {
                              char tmp2[MAX_LOCATION];
                              GetLastDirectory(path, tmp2);
                              PathCat(tmp, tmp2);

                              if(!ext)
                              {
                                 GetExtension(tmp2, defExt);
                                 if(defExt[0]) ext = defExt;
                              }
                           }
                           else
                              strcatf(tmp, "%s.", id, ext ? ext : "png");
                           t = tmp;
                        }
                     }
                     else if((!symRefMode && id) || symRefMode.id)
                     {
                        if(id)
                           t = id;
                        else
                        {
                           GetLastDirectory(path ? path : url, tmp);
                           if(!ext)
                           {
                              GetExtension(tmp, defExt);
                              if(defExt[0]) ext = defExt;
                           }

                           StripExtension(tmp);
                           t = tmp;
                        }
                     }
                     else if((!symRefMode && path) || symRefMode.localFile)
                     {
                        if(path)
                        {
                           strcpy(tmp, "file://");
                           strcat(tmp, path);
                           t = tmp;

                           if(!ext)
                           {
                              GetExtension(path, defExt);
                              if(defExt[0]) ext = defExt;
                           }
                        }
                        else if(url)
                        {
                           if(!strncmp(url, "file://", 7))
                              t = url;
                           else
                           {
                              char tmp2[MAX_LOCATION];
                              GetLastDirectory(url, tmp2);
                              GetExtension(tmp2, defExt);
                              if(!ext && defExt[0]) ext = defExt;

                              strcpy(tmp, "file://");
                              strcat(tmp, tmp2);
                              if(!defExt[0])
                                 strcatf(tmp, ".%s", ext ? ext : "png");
                              t = tmp;
                           }
                        }
                        else if(id)
                        {
                           sprintf(tmp, "file://%s.%s", id, ext ? ext : "png");
                           t = tmp;
                        }
                     }
                     if(!ext)
                        ext = "png";

                     openTag("se:ExternalGraphic");
                     writeIndent();
                     f.Print("<se:OnlineResource xmlns:xlink=\"http://www.w3.org/1999/xlink\" xlink:type=\"simple\" xlink:href=\"", t, "\"/>\n");
                     writeIndent();

                     if(ext[0])
                     {
                        f.Print("<se:Format>");
                        if(!strcmp(ext, "png"))
                           f.Print("image/png");
                        else if(!strcmp(ext, "svg"))
                           f.Print("image/svg");
                        else if(!strcmp(ext, "svg"))
                            f.Print(ext);
                        f.Print("</se:Format>\n");
                     }
                     closeTag("se:ExternalGraphic");

                     writeIndent();
                     // 32x32 PNG version of those SVG, we should have a scaling of 28.0/32
                     f.Print("<se:Size>", image.scaling * 32, "</se:Size>\n"); // where do we get this?
                     closeTag("se:Graphic");
                     closeTag("se:PointSymbolizer");
                  }
               }
               else if(e.type == shape)
               {
                  // TODO:
                  //Shape shape = (Shape)e; // marker

               }
            }
         }
      }
      else
      {
         SymbolizerProperties symProps = symBlock ? symBlock.symbolizer: null;
         CQL2Expression singleChannelExp = symProps ? symBlock.symbolizer.getProperty(singleChannel) : null;
         CQL2Expression colorChannelsRExp = symProps ? symBlock.symbolizer.getProperty(colorChannelsR) : null;
         CQL2Expression colorChannelsGExp = symProps ? symBlock.symbolizer.getProperty(colorChannelsG) : null;
         CQL2Expression colorChannelsBExp = symProps ? symBlock.symbolizer.getProperty(colorChannelsB) : null;

         openTag("se:RasterSymbolizer");

         //<OverlapBehavior>
         if(symbolizer.opacity) // which?
         {
            writeIndent();
            f.Print("<se:Opacity>", symbolizer.opacity, "</se:Opacity>\n");
         }

         if(singleChannelExp || colorChannelsRExp || colorChannelsGExp || colorChannelsBExp)
         {
            openTag("se:ChannelSelection");
            if(singleChannelExp)
            {
               String s = singleChannelExp.toString(0);
               openTag("se:GrayChannel");
               writeIndent();
               f.Print("<se:SourceChannelName>", s, "</se:SourceChannelName>\n");
               closeTag("se:GrayChannel");
               delete s;
            }
            if(colorChannelsRExp)
            {
               String s = colorChannelsRExp.toString(0);
               openTag("se:RedChannel");
               writeIndent();
               f.Print("<se:SourceChannelName>", s, "</se:SourceChannelName>\n");
               closeTag("se:RedChannel");
               delete s;
            }
            if(colorChannelsGExp)
            {
               String s = colorChannelsGExp.toString(0);
               openTag("se:GreenChannel");
               writeIndent();
               f.Print("<se:SourceChannelName>", s, "</se:SourceChannelName>\n");
               closeTag("se:GreenChannel");
               delete s;
            }
            if(colorChannelsBExp)
            {
               String s = colorChannelsBExp.toString(0);
               openTag("se:BlueChannel");
               writeIndent();
               f.Print("<se:SourceChannelName>", s, "</se:SourceChannelName>\n");
               closeTag("se:BlueChannel");
               delete s;
            }
            closeTag("se:ChannelSelection");
         }
         if(symbolizer.colorMap)
         {
            openTag("se:ColorMap");
            for(c : symbolizer.colorMap)
            {
               writeIndent();
               // it seems opacity map would be written here inline in tandem with color?
               f.Print("<se:ColorMapEntry color=\"");
               writeHexColor(c.color);
               f.Print("\" quantity=\"", c.value, "\"/>\n");
               //<ColorMapEntry color="#EEBE2F" quantity="-300" label="label" opacity="0"/>
            }
            closeTag("se:ColorMap");
         }
         if(symbolizer.hillShading.colorMap || symbolizer.hillShading.factor)
         {
            openTag("se:ShadedRelief");
            writeIndent();
            f.Print("<se:ReliefFactor>", symbolizer.hillShading.factor, "</se:ReliefFactor>\n");
            writeIndent();
            f.Print("<se:BrightnessOnly> False </se:BrightnessOnly>\n");
            closeTag("se:ShadedRelief");
         }

         closeTag("se:RasterSymbolizer");
      }
   }
};


bool writeSLD(CartoStyle sheet, const String fileName, Map<String, FeatureDataType> typeMap, SymbolsReferenceMode refMode, const String baseURL)
{
   bool result = false;
   File f = FileOpen(fileName, write);
   if(f)
   {
      result = writeSLDFile(sheet, f, typeMap, refMode, baseURL);
      delete f;
   }
   return result;
}

bool writeSLDFile(CartoStyle sheet, File f, Map<String, FeatureDataType> typeMap, SymbolsReferenceMode refMode, const String baseURL)
{
   bool result = true;

   SLDWriter writer { f = f, symRefMode = refMode, baseURL = baseURL, typeMap = typeMap };
   //const String title = null;
   //Iterator<StylingRule> it { sheet.list };
   /*AVLTree<String> layers { };

   // Figure out title here for now... TODO: Handle style sheet describing multiple layers
   for(rule : sheet.list)
   {
      //const String title = null;
      layers.Add(rule.id.string);
   }*/
   CartoSymEvaluator evaluator { class(CartoSymEvaluator) };
   CartoStyle bSheet;

   evaluator.setFeatureID(-1);

   bSheet = sheet.bind(evaluator, class(CartoSymbolizer), null);

   f.Puts("<?xml version=\"1.0\" encoding=\"utf-8\"?>\n");
   f.Puts("<sld:StyledLayerDescriptor\n");
   f.Puts("   xmlns=\"http://www.opengis.net/sld\"\n");
   f.Puts("   xmlns:sld=\"http://www.opengis.net/sld\"\n");
   f.Puts("   xmlns:se=\"http://www.opengis.net/se\"\n");
   f.Puts("   xmlns:ogc=\"http://www.opengis.net/ogc\"\n");
   f.Puts("   xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\"\n");
   f.Puts("   xmlns:gml=\"http://www.opengis.net/gml\"\n");
   f.Puts("   xmlns:xlink=\"http://www.w3.org/1999/xlink\"\n");
   f.Puts("   xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\"\n");
   f.Puts("   xsi:schemaLocation=\"http://www.opengis.net/sld http://schemas.opengis.net/sld/1.1/StyledLayerDescriptor.xsd\"\n");
   f.Puts("   version=\"1.1.0\">\n");

   if(bSheet && bSheet.list)
      writer.writeList(bSheet.list);
   //writer.writeTag("sld:StyledLayerDescriptor", { close = true });
   f.Puts("</sld:StyledLayerDescriptor>\n");

   delete bSheet;

   return result;
}

static Map<GraphicalSymbolizerMask, const String> svgMap
{ [
   { opacity, "fill-opacity" }
   //{ visibility, }

] };

static Map<ShapeSymbolizerKind, const String> svgShapesMap
{ [
   { fill, "fill" },
   { fillColor, "fill" },
   //{ color, "fill" }, //every color is a "fill" in sld
   { stroke, "stroke" },
   { strokeColor, "stroke" },
   { fillOpacity, "fill-opacity" },
   { strokeOpacity,  "stroke-opacity" },
   //{ width,  "stroke-width" },
   { strokeWidth,  "stroke-width" }
] };

static Map<TextSymbolizerKind, const String> svgTextMap
{ [
   { fontFace,  "font-family" },
   { fontSize,  "font-size" }, //?
   { fontBold,  "font-weight" },
   { fontItalic,  "font-style" },
   { fontColor, "fill" },
   { fontOutlineColor,  "stroke" }, //gets the halo tag
   { fontOutlineSize, "stroke-width" }
] };
