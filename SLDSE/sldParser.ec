public import IMPORT_STATIC "ecrt"
public import IMPORT_STATIC "CartoSym"

private: // FIXME: Fix this public default after import

import "XMLParser"

enum SLDParserState
{
   none,
   namedLayer,
   userStyle,
   featureTypeStyle,
   coverageStyle,
      name,
      description,
         title,
         abstract,
      featureTypeName,
      rule,
         filter,
            and,
               propertyIsEqualTo,
                  propertyName,
                  literal,
                  add,
                  sub,
                  mul,
                  div,
                  function,
               propertyIsNotEqualTo,
               propertyIsLessThan,
               propertyIsGreaterThan,
               propertyIsLessThanOrEqualTo,
               propertyIsGreaterThanOrEqualTo,
               propertyIsNull,
               propertyIsBetween,
            or,  // ?
            not, // ?
         elseFilter, // (everything for filter applies here as well)
         // Styles
         polygonSymbolizer,
            fill,
               graphicFill,
            stroke,
               graphicStroke,
               svgParameter,
         lineSymbolizer,
            geometry,
               propertyNameNonExp,
         pointSymbolizer,
            graphic,
               mark,
                  wellKnownName,
               size,
               displacement,
                  displacementX,
                  displacementY,
               externalGraphic,
                  onlineResource,
                  format,
               rotation,
         rasterSymbolizer,
            opacity,
            overlapBehavior,
            colorMap,
               categorize,
                  lookupValue,
                  rValue,   //'value' is a keyword
                  threshold,
               shadedRelief,
                  reliefFactor,
               interpolate,
                  interpolationPoint,
                     interpolateData,
                     interpolateValue,
            channelSelection,
               grayChannel,
                  sourceChannelName,
                     contrastEnhancement,
                        histogram,
                        gammaValue,
                        normalize,
               redChannel,
               greenChannel,
               blueChannel,
            overlapBehavior,
         textSymbolizer,
            label,
            font,
            labelPlacement,
               pointPlacement,
                  anchorPoint,
                     anchorPointX,
                     anchorPointY,
               linePlacement,
            halo,
               radius,
            vendorOption,
         minScaleDenominator,
         maxScaleDenominator
};

enum SVGParameter
{
   none, fill, fillOpacity, stroke, strokeWidth, strokeOpacity, strokeLineJoin, strokeLineCap, strokeDashArray, strokeDashOffset, fontFamily, fontSize, fontWeight, fontStyle
};

enum UOMState { none, pixel, metre, foot };

enum WellKnownName { none, circle, square, triangle, cross, x }; // NOTE this may be appropriate in GraphicalSymbolizer

static CartoSymEvaluator evaluator { class(CartoSymEvaluator) };

CartoStyle loadSLD(const String fileName, const String layerName, File tmpFile)
{
   CartoStyle sheet = null;
   File f = tmpFile ? tmpFile : FileOpen(fileName, read);
   if(f)
   {
      SLDParser parser;
      uint64 size;
      char * data;
      if(layerName) parser = { layerSource = CopyString(layerName), forceName = true };
      else parser = { forceName = false };
      parser.ruleCount = 0;
      size = f.GetSize();
      data = new byte[size+1];
      f.Read(data, 1, size);
      data[size] = 0;

      // REVIEW: Set up property for global instances?
      evaluator.setFeatureID(-1);

      sheet = { };
      //sheet.list = { };
      //parser.rules = sheet.list; //?
      parser.Parse(data, (int)size);

      sheet.list = { };
      for(r : parser.rules)
         sheet.list.Add(r);

      nestRules(sheet.list);

      delete data;

      delete parser;
      if(!tmpFile) delete f;
   }
   return sheet;
}

static bool replaceExpression(CQL2Expression parentExp, CQL2Expression oldExp, CQL2Expression newExp)
{
   bool result = false;

   if(parentExp._class == class(CQL2ExpBrackets))
   {
      CQL2ExpBrackets br = (CQL2ExpBrackets)parentExp;
      if(br && br.list && br.list.list && br.list.list.count)
      {
         CQL2Expression last = br.list.lastIterator.data;
         if(last == oldExp)
         {
            br.list.RemoveAll();
            br.list.Add(newExp);
            result = true;
         }
         else
            result = replaceExpression(last, oldExp, newExp);
      }
   }
   else if(parentExp._class == class(CQL2ExpOperation))
   {
      CQL2ExpOperation eo = (CQL2ExpOperation)parentExp;
      if(eo.exp1 == oldExp)
      {
         eo.exp1 = newExp;
         result = true;
      }
      else if(eo.exp2 == oldExp)
      {
         eo.exp2 = newExp;
         result = true;
      }
      else
      {
         if(eo.exp1) result = replaceExpression(eo.exp1, oldExp, newExp);
         if(eo.exp2) result |= replaceExpression(eo.exp2, oldExp, newExp);
      }
   }
   return result;
}

class SLDParser : XMLParser
{
   int depth;

   String layerSource;
   bool forceName; //to deal with there not being a layer specified in the sld clearly meant to match a layer according to the sld's name
   bool matchRule;
   Color colorRampValue;

   String fontFamily, fontWeight;
   float fontSize;
   bool catParam, labelColorSet, outlineColorSet;
   double outlineSize, outlineFade;
   // REVIEW: ColorAlpha labelColor, outlineColor;
   double anchorX, anchorY;
   CQL2Expression dispX, dispY;

   CQL2ExpConstant minScale, maxScale;
   CQL2Expression currentExp;
   Array<CQL2Expression> expressions { minAllocSize = 256};
   SLDParserState state;
   Array<SLDParserState> states { minAllocSize = 256 };

   SVGParameter svgParam;
   SLDParserState fillParent, strokeParent, svgParamParent, ruleParent, graphicParent, contrastParent, geomParent, propertyParent, titleParent, ftsParent, displaceParent; // NOTE: We really should have a built-in stack in our XMLParser that handles stacking for everything...
   UOMState uomState;

   String charData;

   StylingRule rule;
   StylingRule rTop;
   bool isElseFilter;
   bool hasElseFilter;
   Array<StylingRule> rules { minAllocSize = 256 };

   SymbolizerProperties stylesList { [ { } ] };

   bool defaultFill, defaultStroke;
   CQL2ExpInstance curFill, curStroke, curFont, curOutline;
   CQL2ExpInstance currentGE;
   CQL2ExpArray labelElements;
   WellKnownName wKN;
   int ruleCount;
   String labelData;
   Array<ValueColor> colorMap;
   Array<ValueOpacity> opacityMap;

   bool ignoreEverything;
   int ignoreDepth;

   void ProcessKeyword(const String keyWord)
   {
      switch(state)
      {
         case none:
            if(openingTag)
            {
               ftsParent = state;
               if(!strcmpi(keyWord, "FeatureTypeStyle") || !strcmpi(keyWord, "se:FeatureTypeStyle") || !strcmpi(keyWord, "sld:FeatureTypeStyle"))
               { state = featureTypeStyle; depth = xmlDepth; }
               else if(!strcmpi(keyWord, "CoverageStyle") || !strcmpi(keyWord, "se:CoverageStyle")){ state = coverageStyle; depth = xmlDepth; }
               else if(!strcmpi(keyWord, "NamedLayer") || !strcmpi(keyWord, "se:NamedLayer") || !strcmpi(keyWord, "sld:NamedLayer"))
               { state = namedLayer; depth = xmlDepth; }
               else depth = xmlDepth;
            }
            break;
         case namedLayer:
            if(openingTag)
            {
               if(!strcmpi(keyWord, "Name") || !strcmpi(keyWord, "se:Name") || !strcmpi(keyWord, "sld:Name"))
               { state = name; depth = xmlDepth; }
               else if(!strcmpi(keyWord, "UserStyle") || !strcmpi(keyWord, "se:UserStyle") || !strcmpi(keyWord, "sld:UserStyle"))
               { state = userStyle; depth = xmlDepth; }
               else if(!strcmpi(keyWord, "FeatureTypeStyle") || !strcmpi(keyWord, "se:FeatureTypeStyle") || !strcmpi(keyWord, "sld:FeatureTypeStyle"))
               { state = featureTypeStyle; depth = xmlDepth; }
            }
            break;
         case name: //name of layer (alias) or group layer when in NamedLayer
            if(closingTag && xmlDepth == depth - 1) { state = namedLayer; depth = xmlDepth; }
            break;
         case userStyle:
            if(openingTag)
            {
               titleParent = state; ftsParent = state;
               if(!strcmpi(keyWord, "Title") || !strcmpi(keyWord, "se:Title")) { state = title; depth = xmlDepth; }
               else if(!strcmpi(keyWord, "Abstract") || !strcmpi(keyWord, "se:Abstract")) { state = abstract; depth = xmlDepth; }
               else if(!strcmpi(keyWord, "FeatureTypeStyle") || !strcmpi(keyWord, "se:FeatureTypeStyle") || !strcmpi(keyWord, "sld:FeatureTypeStyle"))
               { state = featureTypeStyle; depth = xmlDepth; }
            }
            if(closingTag && xmlDepth == depth - 1) { state = namedLayer; depth = xmlDepth; }
            break;
         case coverageStyle:
         case featureTypeStyle:
            if(openingTag)
            {
               ruleParent = state;
               rTop = null;
               hasElseFilter = false;

               if(!strcmpi(keyWord, "Description") || !strcmpi(keyWord, "se:Description")) { state = description; depth = xmlDepth; } //skip
               else if(!strcmpi(keyWord, "FeatureTypeName") || !strcmpi(keyWord, "se:FeatureTypeName") || !strcmpi(keyWord, "sld:FeatureTypeName"))
               { state = featureTypeName; depth = xmlDepth; }
               else if(!strcmpi(keyWord, "Rule") || !strcmpi(keyWord, "se:Rule") || !strcmpi(keyWord, "sld:Rule"))
               {
                  /*currentExp = CQL2ExpOperation
                  {
                     exp1 = CQL2ExpIdentifier { identifier = CQL2Identifier { name = CopyString("source.title") } },
                     op = equal,
                     exp2 = CQL2ExpConstant { constant = { { text, mustFree = true }, s = CopyString(layerSource) } }
                  };
                  rule = { filter = currentExp };*/
                  // lets try this
                  matchRule = false;
                  for(r : rules)
                  {
                     // NOTE: since the ElseFilter is the last rule of a given layer in sld, this will not be true
                     if(layerSource && r.id && !strcmp(layerSource, r.id.string) ) //&& r.selectors.list.count == 0
                     {
                        rule = { symbolizer = { } };
                        if(!r.nestedRules)
                           r.nestedRules = { };
                        incref rule;
                        rTop = r;
                        //r.nestedRules.Add(rule);
                        matchRule = true;
                        break;
                     }
                  }
                  if(!matchRule)
                  {
                     ruleCount++;
                     rTop = { id = CQL2Identifier { string = layerSource ? CopyString(layerSource) : null }, symbolizer = { } };
                     rules.Add(rTop);
                     incref rTop;
                     rule = { symbolizer = { } };
                     incref rule;
                     rTop.symbolizer.changeProperty(zOrder, { type.type = integer, i = ruleCount }, class(GraphicalSymbolizer), evaluator, false, null);
                     //rTop.nestedRules.Add(rule);
                  }
                  state = rule;
                  depth = xmlDepth;
               }
            }
            if(closingTag && xmlDepth == depth - 1)
            {
               state = ftsParent;
               depth = xmlDepth;
               rTop = null;
            }
            break;
         case description:
         {
            if(openingTag)
            {
               titleParent = state;
               if(!strcmpi(keyWord, "Title") || !strcmpi(keyWord, "se:Title")) { state = title; depth = xmlDepth; }
               else if(!strcmpi(keyWord, "Abstract") || !strcmpi(keyWord, "se:Abstract")) { state = abstract; depth = xmlDepth; }
            }
            if(closingTag && xmlDepth == depth - 1) { state = featureTypeStyle; depth = xmlDepth; }
            break;
         }
         case featureTypeName:     //??? identifies 'feature type' usually omitted if style applies to all features in layer
            if(closingTag && xmlDepth == depth - 1) { state = featureTypeStyle; depth = xmlDepth; }
            break;
         case rule:
            if(openingTag)
            {
               int symLen = strlen(keyWord) - 10;
               if(!strcmpi(keyWord, "Filter") || !strcmpi(keyWord, "ogc:Filter"))
               {
                  currentExp = CQL2ExpOperation { op = none }; state = filter; depth = xmlDepth;
                  isElseFilter = false;
               }
               else if(!strcmpi(keyWord, "ElseFilter") || !strcmpi(keyWord, "se:ElseFilter") ||
                  !strcmpi(keyWord, "ElseFilter/") || !strcmpi(keyWord, "se:ElseFilter/"))    // TOCHECK: Shoudln't / be removed by XMLParser already?
               {
                  isElseFilter = true;
                  // Move the ElseFilter rule at the top for now for rules priority to handle it (TO TEST / VERIFY)
                  /*if(rules.count > 1)
                  {
                     memmove(rules.array+1, rules.array, (rules.count-1) * sizeof(StylingRule));
                     rules[0] = rule;
                  }*/
               }
               else if(symLen > 0 && !strcmpi(keyWord+symLen, "Symbolizer"))
               {
                  char * uom = null;

                  if(!strcmpi(keyWord, "PolygonSymbolizer") || !strcmpi(keyWord, "se:PolygonSymbolizer") || !strcmpi(keyWord, "sld:PolygonSymbolizer"))
                  { state = polygonSymbolizer; depth = xmlDepth; }
                  else if(!strcmpi(keyWord, "LineSymbolizer") || !strcmpi(keyWord, "se:LineSymbolizer") || !strcmpi(keyWord, "sld:LineSymbolizer"))
                  { state = lineSymbolizer; depth = xmlDepth; }
                  else if(!strcmpi(keyWord, "RasterSymbolizer") || !strcmpi(keyWord, "se:RasterSymbolizer") || !strcmpi(keyWord, "sld:RasterSymbolizer"))
                  { state = rasterSymbolizer; depth = xmlDepth; }
                  else if(!strcmpi(keyWord, "TextSymbolizer") || !strcmpi(keyWord, "se:TextSymbolizer") || !strcmpi(keyWord, "sld:TextSymbolizer"))
                  {
                     CQL2SpecName specName { name = CopyString("Text") };
                     CQL2ExpInstance textInst { instance = { _class = specName } };

                     if(!labelElements)
                        labelElements = { elements = { } };

                     labelElements.elements.Add(textInst);
                     currentGE = textInst;

                     state = textSymbolizer; depth = xmlDepth;
                  }
                  else if(!strcmpi(keyWord, "PointSymbolizer") || !strcmpi(keyWord, "se:PointSymbolizer") || !strcmpi(keyWord, "sld:PointSymbolizer"))
                  {
                     // we don't yet know what this is -- assuming Image for now...
                     CQL2SpecName specName { name = CopyString("Image") };
                     CQL2ExpInstance imageInst { instance = { _class = specName } };

                     if(!labelElements)
                        labelElements = { elements = { } };

                     labelElements.elements.Add(imageInst);
                     currentGE = imageInst;

                     // NOTE marker not well supported, all treated as Labels for now
                     state = pointSymbolizer; depth = xmlDepth;
                  }

                  while(GetWord())
                  {
                     if(!strcmpi(keyWord, "uom"))
                     {
                        GetWord();
                        uom = CopyString(keyWord);
                     }
                  }
                  if(uom && SearchString(uom,0,"metre",false,false))
                     uomState = metre;
                  else
                     uomState = pixel;

               }
               else if(!strcmpi(keyWord, "MinScaleDenominator") || !strcmpi(keyWord, "sld:MinScaleDenominator") || !strcmpi(keyWord, "se:MinScaleDenominator")) { state = minScaleDenominator; depth = xmlDepth; }
               else if(!strcmpi(keyWord, "MaxScaleDenominator") || !strcmpi(keyWord, "sld:MaxScaleDenominator") || !strcmpi(keyWord, "se:MaxScaleDenominator")) { state = maxScaleDenominator; depth = xmlDepth; }
            }
            if(closingTag && xmlDepth == depth - 1)
            {
               Iterator<CQL2MemberInitList> it { stylesList };
               if(labelElements)
               {
                  setSymbolizerExp(stylesList, CartoSymbolizerKind::labelElements, labelElements);
                  labelElements = null;
               }

               it.Next();
               while(it.pointer)
               {
                  IteratorPointer next = it.container.GetNext(it.pointer);
                  CQL2MemberInitList i = it.data;
                  if(i && i.list.count > 0)
                     rule.symbolizer.Add(i);
                  else
                     delete i;
                  it.Remove();
                  it.pointer = next;
               }
               rule.symbolizer.mask |= stylesList.mask;
               rule.mask |= stylesList.mask;

               if(layerSource && rTop && !rTop.id)
                  rTop.id = { string = CopyString(layerSource) };

               if(minScale || maxScale)
               {
                  if(!rule.selectors) rule.selectors = { };
                  if(maxScale)
                  {
                     CQL2ExpOperation e { exp1 = newCSScaleExp(), op = smallerEqual, exp2 = maxScale };
                     rule.selectors.Insert(null, { exp = e });
                     maxScale = null;
                  }
                  if(minScale)
                  {
                     CQL2ExpOperation e { exp1 = newCSScaleExp(), op = greaterEqual, exp2 = minScale };
                     rule.selectors.Insert(null, StylingRuleSelector { exp = e });
                     minScale = null;
                  }
               }

               // elseFilter rule
               if(isElseFilter || !rule.selectors) // No filter for raster symbolizer?
               {
                  Iterator<CQL2MemberInitList> it { rule.symbolizer };
                  // Combine, rather than replace styles?
                  if(!rTop.symbolizer) rTop.symbolizer = { };
                  it.Next();
                  while(it.pointer)
                  {
                     IteratorPointer next = it.container.GetNext(it.pointer);
                     rTop.symbolizer.Add(it.data);
                     it.Remove();
                     it.pointer = next;
                  }
                  rTop.symbolizer.mask |= rule.symbolizer.mask;
                  rTop.mask |= rule.mask;
                  delete rule.symbolizer;
                  hasElseFilter = true;
                  isElseFilter = false;
               }
               else
               {
                  // if a matching filter exists (which should only be the case for overlapping stroke) then add stroke styles to existing as casing
                  bool match = false;
                  String ruleSelString = rule.selectors.toString(0);
                  for(r : rTop.nestedRules; r._class == class(StylingRule))
                  {
                     StylingRule rb = (StylingRule)r;
                     String s = rb.selectors.toString(0);
                     if(!strcmp(s, ruleSelString))
                     {
                        bool rbLabels = rb.symbolizer.mask & CartoSymbolizerKind::labelElements ? true : false;
                        bool ruleLabels = rule.symbolizer.mask & CartoSymbolizerKind::labelElements ? true : false;
                        bool rbStroke = rb.symbolizer.mask & CartoSymbolizerKind::stroke ? true : false;
                        bool ruleStroke = rule.symbolizer.mask & CartoSymbolizerKind::stroke ? true : false;
                        if(!rbLabels && !ruleLabels && rbStroke && ruleStroke)
                        {
                           match = true;
                           addCasingOverlap(rb, rule);
                           delete s;
                           break;
                        }
                        else if(rbLabels && ruleLabels)
                        {
                           // Combine label elements into a single rule
                           CQL2ExpArray array = (CQL2ExpArray)rb.symbolizer.getProperty2(labelElements, null);
                           CQL2ExpArray a = (CQL2ExpArray)rule.symbolizer.getProperty2(labelElements, null);
                           if(array && a)
                           {
                              if(array._class == class(CQL2ExpArray) && a._class == class(CQL2ExpArray) && a.elements && a.elements.GetCount())
                              {
                                 Iterator<CQL2Expression> it { a.elements };

                                 if(!array.elements) array.elements = { };
                                 while(it.Next())
                                 {
                                    CQL2Expression e = it.data;
                                    array.elements.Add(e);
                                    it.Remove();
                                 }
                              }

                              match = true;
                              break;
                           }
                        }
                     }
                     delete s;
                  }

                  if(match)
                     delete rule;
                  else
                  {
                     if(!rTop.nestedRules)
                        rTop.nestedRules = { };
                     rTop.nestedRules.Add(rule);
                  }

                  // If we do not have an else filter, this layer is not visible unless it matches a nested rule
                  if(!hasElseFilter && rTop.nestedRules)
                  {
                     // Add visibility = false to rTop rule block
                     setSymbolizerVal(rTop.symbolizer, visibility, { { integer }, i = bool::false }, class(bool));

                     // Add visibility = true to rTop's nested rules
                     if(rTop.nestedRules)
                        for(nr : rTop.nestedRules; nr._class == class(StylingRule))
                        {
                           StylingRule nRule = (StylingRule)nr;
                           setSymbolizerVal(nRule.symbolizer, visibility, { { integer }, i = bool::true }, class(bool));
                        }
                  }

                  rule = null;
                  delete ruleSelString;
               }

               delete rule;
               stylesList.Add({ });
               stylesList.mask = 0;

               if(labelElements)
               {
                  labelElements.elements.Free();
                  delete labelElements;
               }

               state = ruleParent;//featureTypeStyle;
               depth = xmlDepth;
            }
            break;
         case filter:
         case label:    // TODO: How to handle property or values for everything?
         case and:
         case or:
         case not:
         case propertyIsEqualTo:
         case propertyIsNotEqualTo:
         case propertyIsLessThan:
         case propertyIsGreaterThan:
         case propertyIsLessThanOrEqualTo:
         case propertyIsGreaterThanOrEqualTo:
         case propertyIsNull:
         case propertyIsBetween:
         case propertyName:
         case literal:
         case add:
         case sub:
         case mul:
         case div:
         case function:
         {
            SLDParserState s = none;

            if(!strcmpi(keyWord, "And") || !strcmpi(keyWord, "ogc:And"))
               s = and;
            else if(!strcmpi(keyWord, "Or") || !strcmpi(keyWord, "ogc:Or"))
               s = or;
            else if(!strcmpi(keyWord, "Not") || !strcmpi(keyWord, "ogc:Not"))
               s = not;
            else if(!strcmpi(keyWord, "PropertyIsEqualTo") || !strcmpi(keyWord, "ogc:PropertyIsEqualTo"))
               s = propertyIsEqualTo;
            else if(!strcmpi(keyWord, "PropertyIsNotEqualTo") || !strcmpi(keyWord, "ogc:PropertyIsNotEqualTo"))
               s = propertyIsNotEqualTo;
            else if(!strcmpi(keyWord, "PropertyIsLessThan") || !strcmpi(keyWord, "ogc:PropertyIsLessThan"))
               s = propertyIsLessThan;
            else if(!strcmpi(keyWord, "PropertyIsGreaterThan") || !strcmpi(keyWord, "ogc:PropertyIsGreaterThan"))
               s = propertyIsGreaterThan;
            else if(!strcmpi(keyWord, "PropertyIsGreaterThanOrEqualTo") || !strcmpi(keyWord, "ogc:PropertyIsGreaterThanOrEqualTo"))
               s = propertyIsGreaterThanOrEqualTo;
            else if(!strcmpi(keyWord, "PropertyIsLessThanOrEqualTo") || !strcmpi(keyWord, "ogc:PropertyIsLessThanOrEqualTo"))
               s = propertyIsLessThanOrEqualTo;
            else if(!strcmpi(keyWord, "PropertyIsNull") || !strcmpi(keyWord, "ogc:PropertyIsNull"))
               s = propertyIsNull;
            else if(!strcmpi(keyWord, "PropertyIsBetween") || !strcmpi(keyWord, "ogc:PropertyIsBetween"))
               s = propertyIsBetween;
            else if(!strcmpi(keyWord, "PropertyName") || !strcmpi(keyWord, "ogc:PropertyName"))
               s = propertyName;
            else if(!strcmpi(keyWord, "Literal") || !strcmpi(keyWord, "ogc:Literal"))
               s = literal;
            else if(!strcmpi(keyWord, "Add") || !strcmpi(keyWord, "ogc:Add"))
               s = add;
            else if(!strcmpi(keyWord, "Sub") || !strcmpi(keyWord, "ogc:Sub"))
               s = sub;
            else if(!strcmpi(keyWord, "Mul") || !strcmpi(keyWord, "ogc:Mul"))
               s = mul;
            else if(!strcmpi(keyWord, "Div") || !strcmpi(keyWord, "ogc:Div"))
               s = div;
            else if(!strcmpi(keyWord, "Filter") || !strcmpi(keyWord, "ogc:Filter"))
               s = filter;
            else if(!strcmpi(keyWord, "Label") || !strcmpi(keyWord, "se:Label") || !strcmpi(keyWord, "sld:Label"))
               s = label;
            else if(!strcmpi(keyWord, "Function") || !strcmpi(keyWord, "ogc:Function"))
               s = function;

            if(s != none)
            {
               if(openingTag)
               {
                  CQL2Expression thisExp = null;
                  switch(s)
                  {
                     case propertyIsEqualTo:                thisExp = CQL2ExpOperation { op = equal };             break;
                     case propertyIsNotEqualTo:             thisExp = CQL2ExpOperation { op = notEqual };          break;
                     case propertyIsLessThan:               thisExp = CQL2ExpOperation { op = smaller };           break;
                     case propertyIsGreaterThan:            thisExp = CQL2ExpOperation { op = greater };           break;
                     case propertyIsGreaterThanOrEqualTo:   thisExp = CQL2ExpOperation { op = greaterEqual };      break;
                     case propertyIsLessThanOrEqualTo:      thisExp = CQL2ExpOperation { op = smallerEqual };      break;
                     case propertyIsNull:
                        thisExp = CQL2ExpOperation { op = equal, exp2 =  CQL2ExpConstant { constant = { { nil } } } };  break;
                     case propertyIsBetween:
                        thisExp = CQL2ExpOperation { op = and, exp1 = CQL2ExpOperation { op = greater },
                           exp2 = CQL2ExpOperation { op = smaller } };                                             break;
                     case and:                              thisExp = CQL2ExpOperation { op = and } ;              break;
                     case or:                               thisExp = CQL2ExpOperation { op = or } ;               break;
                     case not:                              thisExp = CQL2ExpOperation { op = not } ;              break;
                     case literal:                          thisExp = CQL2ExpConstant { };                         break;
                     case propertyName:                     thisExp = CQL2ExpIdentifier { };                       break;
                     case add:                              thisExp = CQL2ExpOperation { op = plus };              break;
                     case sub:                              thisExp = CQL2ExpOperation { op = minus };             break;
                     case mul:                              thisExp = CQL2ExpOperation { op = multiply };          break;
                     case div:                              thisExp = CQL2ExpOperation { op = divide };            break;
                     case function:
                     {
                        String functionName = null;
                        depth = xmlDepth;
                        while(GetWord())
                        {
                           if(!strcmpi(keyWord, "name"))
                           {
                              if(GetWord())
                              {
                                 delete functionName;
                                 functionName = CopyString(keyWord);
                              }
                           }
                        }
                        if(functionName && !strcmpi(functionName, "in"))
                           thisExp = CQL2ExpOperation { op = in };
                        else
                        {
                           if(functionName)
                           {
                                   if(!strcmpi(functionName, "strToUpperCase")) { delete functionName; functionName = CopyString("strupr"); }
                              else if(!strcmpi(functionName, "strToLowerCase")) { delete functionName; functionName = CopyString("strlwr"); }
                           }
                           thisExp = CQL2ExpCall { exp = CQL2ExpIdentifier { identifier = CQL2Identifier { string = CopyString(functionName) } } };
                        }
                        delete functionName;
                        break;

                     }
                  }

                  if(currentExp && currentExp._class == class(CQL2ExpOperation))
                  {
                     CQL2ExpOperation opExp = (CQL2ExpOperation)currentExp;
                     CQL2Expression e = thisExp;
                     bool changeOps = state == not || (state == and && s == or) || (state == or && (s == and || s == filter || s == label)) || (state == function && s == literal);

                     if(changeOps && !opExp.exp2)
                        e = CQL2ExpBrackets { list = CQL2ExpList { [ e ] } };

                     if(!changeOps && !opExp.exp1)
                        opExp.exp1 = thisExp;
                     else if(opExp.exp2)
                     {
                        if(changeOps && state == function)
                        {
                           ((CQL2ExpBrackets)opExp.exp2).list.Add(thisExp);
                        }
                        else
                           opExp.exp2 = CQL2ExpOperation { exp1 = opExp.exp2, op = opExp.op, exp2 = e };
                     }
                     else
                        opExp.exp2 = e;
                  }
                  else if(currentExp && currentExp._class == class(CQL2ExpCall))
                  {
                     CQL2ExpCall callExp = (CQL2ExpCall)currentExp;
                     CQL2Expression e = thisExp;
                     if(e)
                     {
                        if(!callExp.arguments) callExp.arguments = { };
                        if(!e._refCount)
                           incref e;  // FIXME: Missing a refcount here?
                        incref e;
                        callExp.arguments.Add(e);
                     }
                  }

                  expressions.Add(currentExp);
                  states.Add(state);

                  state = s;
                  currentExp = thisExp;

                  depth = xmlDepth;
               }
               if(closingTag && xmlDepth == depth - 1 && state == s)
               {
                  if(states.size > 0)
                  {
                     switch(s)
                     {
                        case literal:
                        {
                           bool isString = false;
                           CQL2ExpConstant cExp = (CQL2ExpConstant)currentExp;
                           if(strchr(charData, '.') || (isdigit(charData[0]) && SearchString(charData, 0, "e", false, false)))
                           {
                              String as = null;
                              double d = strtod(charData, &as);
                              if(as && *as == 0) //good!
                                 cExp.constant = { { real }, r = d };
                              else isString = true;
                           }
                           else
                           {
                              String as = null;
                              int i = strtol(charData, &as, 0);
                              if(as && *as == 0)
                                 cExp.constant = { { integer }, i = i };
                              else if(!strcmpi(charData, "true"))
                                 cExp.constant = { { integer }, i = 1 }, cExp.destType = class(bool);
                              else if(!strcmpi(charData, "false"))
                                 cExp.constant = { { integer }, i = 0 }, cExp.destType = class(bool);
                              else
                                 isString = true;
                           }
                           if(isString)
                           {
                              // Update reference to this current expression...
                              // Perhaps such referencing could be done in closing tags instead to avoid this whole mess?
                              CQL2Expression parentExp = expressions.count ? expressions[expressions.count-1] : null;
                              CQL2ExpString sExp { string = CopyString(charData) };

                              if(parentExp)
                                 replaceExpression(parentExp, currentExp, sExp);

                              delete currentExp;

                              currentExp = sExp;
                           }
                           charData = null;
                           break;
                        }
                        case propertyName: ((CQL2ExpIdentifier)currentExp).identifier = { string = CopyString(charData) } ; charData = null; break;
                     }

                     state = states[states.size-1];
                     states.size--;

                     currentExp = expressions[expressions.size-1];

                     expressions.size--;
                  }
                  else
                  {
                     if(state == filter)
                     {
                        if(currentExp && !rule.selectors) rule.selectors = { };
                        addExpSelectors(rule.selectors, currentExp);
                        state = rule;
                     }
                     if(state == label)
                     {
                        if(currentGE)
                        {
                           if(currentExp && currentExp._class == class(CQL2ExpOperation))
                           {
                              CQL2ExpOperation e = (CQL2ExpOperation)currentExp;
                              if(e.op == none)
                              {
                                 currentExp = e.exp1;
                                 e.exp1 = null;
                                 delete e;
                              }
                           }
                           if(!currentExp && labelData)
                           {
                              char * start = labelData, * end;
                              while(isspace(*start)) start++;
                              end = start;
                              while(*end && !isspace(*end)) end++;
                              *end = 0;
                              currentExp = CQL2ExpString { string = CopyString(start) };
                              delete labelData;
                           }
                           if(currentExp)
                              currentGE.setMember("text", text, true, currentExp);
                        }
                        else
                           delete currentExp;

                        state = textSymbolizer;
                        delete labelData;
                     }
                     currentExp = null;
                  }
                  depth = xmlDepth;
               }
            }
            else if(openingTag)
            {
               ignoreEverything = true; // skip ahead for unhandled tags
               ignoreDepth = depth;
               depth = xmlDepth;
            }
            else if(ignoreEverything && ignoreDepth == xmlDepth)
            {
               ignoreEverything = false;
               depth = xmlDepth; // TODO: Verify/test this...
            }
            break;
         }
         case minScaleDenominator:
         case maxScaleDenominator:
            if(closingTag && xmlDepth == depth - 1)
            {
               if(charData)
               {
                  CQL2ExpConstant c { constant = { { real }, r = strtod(charData, null) } };
                  if(state == minScaleDenominator)
                     minScale = c;
                  else
                     maxScale = c;
               }
               state = rule;
               depth = xmlDepth;
            }
            break;
         case polygonSymbolizer:
         case lineSymbolizer:
         case textSymbolizer:
         //case pointSymbolizer:
         //case rasterSymbolizer:
            if(openingTag)
            {
               if(!strcmpi(keyWord, "Fill") || !strcmpi(keyWord, "se:Fill") || !strcmpi(keyWord, "sld:Fill"))
               {
                  fillParent = state;
                  curFill = { expType = class(Fill) };
                  defaultFill = true;
                  state = fill; depth = xmlDepth;
               }
               else if(!strcmpi(keyWord, "Stroke") || !strcmpi(keyWord, "se:Stroke") || !strcmpi(keyWord, "sld:Stroke"))
               {
                  strokeParent = state;
                  curStroke = { expType = class(Stroke) };
                  defaultStroke = true;
                  state = stroke; depth = xmlDepth;
               }
               //else if(!strcmpi(keyWord, "Displacement") || !strcmpi(keyWord, "se:Displacement")) { state = displacement; depth = xmlDepth; }
               //else if(!strcmpi(keyWord, "PerpendicularOffset") || !strcmpi(keyWord, "se:PerpendicularOffset")) { state = perpendicularOffset; depth = xmlDepth; } // in uoms, draw geometry smaller or larger
               else if(!strcmpi(keyWord, "Label") || !strcmpi(keyWord, "se:Label") || !strcmpi(keyWord, "sld:Label"))
               { currentExp = CQL2ExpOperation { op = none }; state = label; depth = xmlDepth; }
               else if(!strcmpi(keyWord, "Geometry") || !strcmpi(keyWord, "se:Geometry")) { geomParent = state; state = geometry; depth = xmlDepth; } //center text
               else if(!strcmpi(keyWord, "Font") || !strcmpi(keyWord, "se:Font") || !strcmpi(keyWord, "sld:Font"))
               {
                  // TOCHECK: Should this already set font on Text GE?
                  if(!curFont)
                     curFont = { expType = class(GEFont) };
                  state = font; depth = xmlDepth;
               } //center text
               else if(!strcmpi(keyWord, "LabelPlacement") || !strcmpi(keyWord, "se:LabelPlacement") || !strcmpi(keyWord, "sld:LabelPlacement")) { state = labelPlacement; depth = xmlDepth; } //center text
               else if(!strcmpi(keyWord, "Halo") || !strcmpi(keyWord, "se:Halo") || !strcmpi(keyWord, "sld:Halo"))
               {
                  curOutline = { expType = class(Outline) };
                  curOutline.setMemberValue2("size", fontOutlineSize, true, { { real }, r = 1.0 }, class(double), evaluator, class(Text)); // Default to an outline size of 1...
                  state = halo; depth = xmlDepth;
               }
               else if(!strcmpi(keyWord, "VendorOption") || !strcmpi(keyWord, "se:VendorOption")) { state = vendorOption; depth = xmlDepth; } //center text
            }
            if(closingTag && xmlDepth == depth - 1)
            {
               if(state == textSymbolizer)
               {
                  if(currentGE)
                  {
                     Alignment2D textAlignment { };

                     if(anchorX == 0.5 && anchorY == 0.5)
                        textAlignment = { horzAlign = center, vertAlign = middle };
                     else if(anchorX == 1.0 && anchorY == 1.0)
                        textAlignment = { horzAlign = right, vertAlign = top};
                     else if(anchorX == 0.0 && anchorY == 0.0)
                        textAlignment = { horzAlign = left, vertAlign = bottom};
                     else if(anchorX == 0.0 && anchorY == 0.5)
                        textAlignment = { horzAlign = left, vertAlign = middle};
                     else if(anchorX == 0.5 && anchorY == 0.0)
                        textAlignment = { horzAlign = center, vertAlign = bottom};
                     else if(anchorX == 1.0 && anchorY == 0.0)
                        textAlignment = { horzAlign = right, vertAlign = bottom};
                     else if(anchorX == 1.0 && anchorY == 0.5)
                        textAlignment = { horzAlign = right, vertAlign = middle};
                     else if(anchorX == 0.0 && anchorY == 1.0)
                        textAlignment = { horzAlign = left, vertAlign = top};
                     else if(anchorX == 0.5 && anchorY == 1.0)
                        textAlignment = { horzAlign = center, vertAlign = top};
                     else if(anchorX == 0.5 && anchorY == 0.0)
                        textAlignment = { horzAlign = center, vertAlign = bottom};
                     {
                        // Always set alignment because CMSS currently defaults to top/left for point geometry (reconsider?)
                        CQL2ExpInstance alignmentInst { expType = class(Alignment2D) };
                        ObjectNotationType on = econ;
                        VAlignment va = textAlignment.vertAlign;
                        HAlignment ha = textAlignment.horzAlign;
                        const String sva = va.OnGetString(null, null, &on);
                        const String sha = ha.OnGetString(null, null, &on);
                        alignmentInst.setMember2("horzAlign", alignmentHorzAlign, true,
                           CQL2ExpIdentifier { identifier = { string = CopyString(sha) } }, evaluator, class(Text), none);
                        alignmentInst.setMember2("vertAlign", alignmentVertAlign, true,
                           CQL2ExpIdentifier { identifier = { string = CopyString(sva) } }, evaluator, class(Text), none);
                        currentGE.setMember2("alignment", alignment, true, alignmentInst, evaluator, class(Text), none);
                     }

                     if(curFont)
                     {
                        currentGE.setMember("font", font, true, curFont);
                        curFont = null;
                     }
                  }
                  currentGE = null;
                  anchorX = 0.5, anchorY = 0.5;
               }
               state = rule; depth = xmlDepth;
            }
            break;
         case pointSymbolizer:
            if(openingTag)
            {
               graphicParent = state;
               if(!strcmpi(keyWord, "Graphic") || !strcmpi(keyWord, "sld:Graphic") || !strcmpi(keyWord, "se:Graphic")) { wKN = none; state = graphic; depth = xmlDepth; }
               else if(!strcmpi(keyWord, "Geometry") || !strcmpi(keyWord, "se:Geometry") || !strcmpi(keyWord, "sld:Geometry")) { geomParent = state; state = geometry; depth = xmlDepth; }  //use centroid if line/area/raster
            }
            if(closingTag && xmlDepth == depth - 1)
            {
               currentGE = null;
               anchorX = 0.5, anchorY = 0.5;

               state = rule; depth = xmlDepth;
            }
            break;
          case rasterSymbolizer:
            if(openingTag)
            {
               //graphicParent = state;
               //if(!strcmpi(keyWord, "Graphic")) { state = graphic; depth = xmlDepth; }    //maybe
               if(!strcmpi(keyWord, "Opacity") || !strcmpi(keyWord, "se:Opacity")  || !strcmpi(keyWord, "sld:Opacity")) { state = opacity; depth = xmlDepth; }
               else if(!strcmpi(keyWord, "ChannelSelection") || !strcmpi(keyWord, "se:ChannelSelection")) { state = channelSelection; depth = xmlDepth; }
               else if(!strcmpi(keyWord, "ColorMap") || !strcmpi(keyWord, "se:ColorMap")) { state = colorMap; depth = xmlDepth; }
               else if(!strcmpi(keyWord, "ShadedRelief") || !strcmpi(keyWord, "se:ShadedRelief"))
               {
                  // Start with 1.0 default in case no ReliefFactor specified
                  rTop.symbolizer.changeProperty(hillShadingFactor, { { real }, r = 1.0 }, class(CartoSymbolizer), evaluator, false, class(double));
                  rTop.symbolizer.changeProperty(hillShadingSunAzimuth, { { real }, r = 45.0 }, class(CartoSymbolizer), evaluator, false, class(double));
                  rTop.symbolizer.changeProperty(hillShadingSunElevation, { { real }, r = 60.0 }, class(CartoSymbolizer), evaluator, false, class(double));
                  state = shadedRelief; depth = xmlDepth;
               }
               else if(!strcmpi(keyWord, "ContrastEnhancement") || !strcmpi(keyWord, "se:ContrastEnhancement")) { state = contrastEnhancement; depth = xmlDepth; }
               //else if(!strcmpi(keyWord, "OverlapBehavior")) { state = overlapBehavior; depth = xmlDepth; }
            }
            if(closingTag && xmlDepth == depth - 1) { state = rule; depth = xmlDepth; }
            break;
         case shadedRelief:
            if(openingTag)
            {
               if(!strcmpi(keyWord, "ReliefFactor") || !strcmpi(keyWord, "se:ReliefFactor")) { state = reliefFactor; depth = xmlDepth; }
            }
            if(closingTag && xmlDepth == depth - 1) { state = rule; depth = xmlDepth; }
            break;
         case reliefFactor:
            if(closingTag && xmlDepth == depth - 1)
            {
               if(charData)
               {
                  double d = strtod(charData,null);
                  rTop.symbolizer.changeProperty(hillShadingFactor, { { real }, r = d }, class(CartoSymbolizer), evaluator, false, class(double));
               }
               state = shadedRelief; depth = xmlDepth;
            }
            break;
         case fill:
            if(openingTag)
            {
               svgParamParent = state;
               if(!strcmpi(keyWord, "SvgParameter") || !strcmpi(keyWord, "se:SvgParameter") || !strcmpi(keyWord, "sld:SvgParameter")
               || !strcmpi(keyWord, "CssParameter") || !strcmpi(keyWord, "se:CssParameter") || !strcmpi(keyWord, "sld:CssParameter"))
               {
                  state = svgParameter; depth = xmlDepth;
                  while(GetWord())
                  {
                     // TOCHECK: fill-opacity vs. opacity ?
                     if(!strcmpi(keyWord, "fill-opacity") || !strcmpi(keyWord, "opacity")) svgParam = fillOpacity;
                     else if(!strcmpi(keyWord, "fill")) svgParam = fill;
                  }
               }
               else if(!strcmpi(keyWord, "GraphicFill") || !strcmpi(keyWord, "se:GraphicFill") || !strcmpi(keyWord, "sld:GraphicFill"))
               { state = graphicFill; depth = xmlDepth; }
            }
            if(closingTag && xmlDepth == depth - 1)
            {
               if(curFill)
               {
                  switch(fillParent)
                  {
                     case polygonSymbolizer:
                        if(!defaultFill)
                           setSymbolizerExp(stylesList, fill, curFill);
                        break;
                     case mark:
                        if(!defaultFill)
                           currentGE.setMember("fill", fill, true, curFill);
                        break;
                     case textSymbolizer:
                     {                                                       // TODO: Review this usage of fillColor directly in Fill
                        CQL2Expression colorExp = curFill.getMemberByIDs([ "color" ]);
                        if(colorExp)
                           curFont.setMember("color", fontColor, true, colorExp.copy());
                        delete curFill;
                        break;
                     }
                     case halo:
                     {                                                       // TODO: Review this usage of fillColor directly in Fill
                        CQL2Expression colorExp = curFill.getMemberByIDs([ "color" ]);
                        CQL2Expression opacityExp = curFill.getMemberByIDs([ "opacity" ]);
                        if(colorExp)
                           curOutline.setMember("color", fontOutlineColor, true, colorExp.copy());
                        curOutline.setMember("opacity", fontOutlineOpacity, true,
                           opacityExp ? opacityExp.copy() : CQL2ExpConstant { constant = { type = { real }, r = 1.0 } });
                        delete curFill;
                        break;
                     }
                  }
               }
               curFill = null;
               state = fillParent;
               depth = xmlDepth;
            }
            break;
         case stroke:
            if(openingTag)
            {
               svgParamParent = state;
               if(!strcmpi(keyWord, "SvgParameter") || !strcmpi(keyWord, "se:SvgParameter") || !strcmpi(keyWord, "sld:SvgParameter")||
                  !strcmpi(keyWord, "CssParameter") || !strcmpi(keyWord, "se:CssParameter") || !strcmpi(keyWord, "sld:CssParameter"))
               {
                  state = svgParameter; depth = xmlDepth;
                  while(GetWord())
                  {
                          if(!strcmpi(keyWord, "stroke-width")) svgParam = strokeWidth;
                     else if(!strcmpi(keyWord, "stroke-opacity")) svgParam = strokeOpacity;
                     else if(!strcmpi(keyWord, "stroke-linejoin")) svgParam = strokeLineJoin; //mitre, round, bevel
                     else if(!strcmpi(keyWord, "stroke-linecap")) svgParam = strokeLineCap; //flat/butt, round, square
                     else if(!strcmpi(keyWord, "stroke-dasharray")) svgParam = strokeDashArray;
                     else if(!strcmpi(keyWord, "stroke-dashoffset")) svgParam = strokeDashOffset;
                     else if(!strcmpi(keyWord, "stroke")) svgParam = stroke;
                     else if(!strcmpi(keyWord, "font-family")) svgParam = fontFamily;
                     else if(!strcmpi(keyWord, "font-size")) svgParam = fontSize;
                     else if(!strcmpi(keyWord, "font-weight")) svgParam = fontWeight;
                     else if(!strcmpi(keyWord, "font-style")) svgParam = fontStyle;
                  }

               }
               else if(!strcmpi(keyWord, "GraphicStroke") || !strcmpi(keyWord, "se:GraphicStroke") || !strcmpi(keyWord, "sld:GraphicStroke"))
               { state = graphicStroke; depth = xmlDepth; }
            }
            if(closingTag && xmlDepth == depth - 1)
            {
               if(curStroke)
               {
                  switch(strokeParent)
                  {
                     case polygonSymbolizer:
                     case lineSymbolizer:
                        if(!defaultStroke)
                           setSymbolizerExp(stylesList, stroke, curStroke);
                        break;
                     case mark:
                        if(!defaultStroke)
                           currentGE.setMember("stroke", stroke, true, curStroke);
                        break;
                  }
               }
               curStroke = null;
               state = strokeParent;
               depth = xmlDepth;
            }
            break;
         case font:
            if(openingTag)
            {
               svgParamParent = state;
               if(!strcmpi(keyWord, "SvgParameter") || !strcmpi(keyWord, "se:SvgParameter") || !strcmpi(keyWord, "CssParameter") || !strcmpi(keyWord, "sld:CssParameter"))
               {
                  state = svgParameter; depth = xmlDepth;
                  while(GetWord())
                  {
                          if(!strcmpi(keyWord, "font-family")) svgParam = fontFamily;
                     else if(!strcmpi(keyWord, "font-size")) svgParam = fontSize;
                     else if(!strcmpi(keyWord, "font-weight")) svgParam = fontWeight;
                     else if(!strcmpi(keyWord, "font-style")) svgParam = fontStyle;
                  }
               }
            }
            if(closingTag && xmlDepth == depth - 1)
            {
               state = textSymbolizer;
               depth = xmlDepth;
            }
            break;
         /*case graphicFill:
            if(openingTag)
            {
               graphicParent = state;
               if(!strcmpi(keyWord, "Graphic") || !strcmpi(keyWord, "se:Graphic")) { state = graphic; depth = xmlDepth; }
            }
            if(closingTag && xmlDepth == depth - 1)
            {
               //rule   //apply graphic stipple?
               state = svgParamParent;//featureTypeStyle;
               depth = xmlDepth;
            }
            break;*/
         case graphicStroke:
            if(openingTag)
            {
               graphicParent = state;
               if(!strcmpi(keyWord, "Graphic") || !strcmpi(keyWord, "se:Graphic") || !strcmpi(keyWord, "sld:Graphic")) { state = graphic; depth = xmlDepth; }
               //else if(!strcmpi(keyWord, "InitialGap") || !strcmpi(keyWord, "se:InitialGap")) { state = initialGap; depth = xmlDepth; }
               //else if(!strcmpi(keyWord, "Gap") || !strcmpi(keyWord, "se:Gap")) { state = gap; depth = xmlDepth; }
            }
            if(closingTag && xmlDepth == depth - 1)
            {
               //rule   //apply repeated linear graphic?
               state = svgParamParent;//featureTypeStyle;
               depth = xmlDepth;
            }
            break;
         case graphic:
            if(openingTag)
            {
               displaceParent = state;
               if(!strcmpi(keyWord, "Mark") || !strcmpi(keyWord, "se:Mark") || !strcmpi(keyWord, "sld:Mark")) { state = mark; depth = xmlDepth; }
               else if(!strcmpi(keyWord, "ExternalGraphic") || !strcmpi(keyWord, "se:ExternalGraphic") || !strcmpi(keyWord, "sld:ExternalGraphic")) { state = externalGraphic; depth = xmlDepth; }
               else if(!strcmpi(keyWord, "Size") || !strcmpi(keyWord, "se:Size") || !strcmpi(keyWord, "sld:Size")) { state = size; depth = xmlDepth; }
               else if(!strcmpi(keyWord, "Displacement") || !strcmpi(keyWord, "se:Displacement") || !strcmpi(keyWord, "sld:Displacement"))
               { state = displacement; depth = xmlDepth; }    //actually should use same enum as polygonSym and check parent
               //else if(!strcmpi(keyWord, "Opacity") || !strcmpi(keyWord, "se:Opacity")) { state = opacity; depth = xmlDepth; }
               //else if(!strcmpi(keyWord, "Rotation") || !strcmpi(keyWord, "se:Rotation")) { state = rotation; depth = xmlDepth; }
               else if(!strcmpi(keyWord, "AnchorPoint") || !strcmpi(keyWord, "se:AnchorPoint") || !strcmpi(keyWord, "sld:AnchorPoint"))
               { state = anchorPoint; depth = xmlDepth; }
            }
            if(closingTag && xmlDepth == depth - 1)
            {
               // TODO: fix this up
               CQL2SpecName specName { name = wKN == none ? CopyString("Image") : CopyString(wellKnownTypeStringMap[wKN]) };
               currentGE.instance._class = specName;
               displaceParent = none;
               state = graphicParent;
               depth = xmlDepth;
            }
            break;
         case mark:  //how to handle the simple self-closing element for externalgraphic?
            if(openingTag)
            {
               // new instance here?
               if(!strcmpi(keyWord, "WellKnownName") || !strcmpi(keyWord, "se:WellKnownName") || !strcmpi(keyWord, "sld:WellKnownName"))
               { state = wellKnownName; depth = xmlDepth; }  //get png
               else if(!strcmpi(keyWord, "Fill") || !strcmpi(keyWord, "se:Fill") || !strcmpi(keyWord, "sld:Fill"))
               {
                  curFill = { expType = class(Fill) };
                  defaultFill = true;
                  state = fill;
                  fillParent = mark; depth = xmlDepth;
               }
               else if(!strcmpi(keyWord, "Stroke") || !strcmpi(keyWord, "se:Stroke") || !strcmpi(keyWord, "sld:Stroke"))
               {
                  curStroke = { expType = class(Stroke) };
                  defaultStroke = true;
                  state = stroke;
                  strokeParent = mark; depth = xmlDepth;
               }
            }
            if(closingTag && xmlDepth == depth - 1)
            { state = graphic; depth = xmlDepth; }
            break;
         case externalGraphic:
            if(openingTag)
            {
               //will need to test
               if(!strcmpi(keyWord, "OnlineResource") || !strcmpi(keyWord, "se:OnlineResource") || !strcmpi(keyWord, "sld:OnlineResource"))
               {
                  if(currentGE)
                  {
                     char * onlineResource = null;
                     depth = xmlDepth;
                     while(GetWord())
                     {
                        if(!strcmpi(keyWord, "xlink:href")) { GetWord(); onlineResource = CopyString(keyWord); }
                     }
                     if(SearchString(onlineResource, 0, "file://", false, false) == onlineResource)
                        currentGE.setMember("image.path", imagePath, true, CQL2ExpString { string = CopyString(onlineResource + 7) });
                     else if(SearchString(onlineResource, 0, "http://", false, false) == onlineResource ||
                             SearchString(onlineResource, 0, "https://", false, false) == onlineResource)
                        currentGE.setMember("image.url", imageUrl, true, CQL2ExpString { string = CopyString(onlineResource) });
                     else
                        currentGE.setMember("image.id", imageId, true, CQL2ExpString { string = CopyString(onlineResource) });
                  }
               }
               else if(!strcmpi(keyWord, "Format") || !strcmpi(keyWord, "se:Format") || !strcmpi(keyWord, "sld:Format"))
               { state = format; depth = xmlDepth; }

               //do we care about the image format being specified here?
               //else if(!strcmpi(keyWord, "Format") || !strcmpi(keyWord, "se:Format")) { state = format; depth = xmlDepth; }
            }
            if(closingTag && xmlDepth == depth - 1) { state = graphic; depth = xmlDepth; }
            break;
         case format:
         {
            if(closingTag && xmlDepth == depth - 1) { state = externalGraphic; depth = xmlDepth; }
            break;
         }
         case labelPlacement:
            if(openingTag)
            {
               if(!strcmpi(keyWord, "PointPlacement") || !strcmpi(keyWord, "se:PointPlacement") || !strcmpi(keyWord, "sld:PointPlacement"))
               { state = pointPlacement; depth = xmlDepth; }
               else if(!strcmpi(keyWord, "LinePlacement") || !strcmpi(keyWord, "se:LinePlacement") || !strcmpi(keyWord, "sld:LinePlacement"))
               { state = linePlacement; depth = xmlDepth; }
            }
            if(closingTag && xmlDepth == depth - 1) { state = textSymbolizer; depth = xmlDepth; }
            break;
         case linePlacement:
         case pointPlacement:
            if(openingTag)
            {
               if(!strcmpi(keyWord, "AnchorPoint") || !strcmpi(keyWord, "se:AnchorPoint") || !strcmpi(keyWord, "sld:AnchorPoint"))
               { state = anchorPoint; depth = xmlDepth; }
               else if(!strcmpi(keyWord, "Displacement") || !strcmpi(keyWord, "se:Displacement") || !strcmpi(keyWord, "sld:Displacement"))
               { displaceParent = state; state = displacement; depth = xmlDepth; }
               //else if(!strcmpi(keyWord, "Rotation") || !strcmpi(keyWord, "se:Rotation")) { state = rotation; depth = xmlDepth; }
            }
            if(closingTag && xmlDepth == depth - 1) { state = labelPlacement; depth = xmlDepth; }
            break;
         case anchorPoint:
            if(openingTag)
            {
               if(!strcmpi(keyWord, "AnchorPointX") || !strcmpi(keyWord, "se:AnchorPointX") || !strcmpi(keyWord, "sld:AnchorPointX"))
               { state = anchorPointX; depth = xmlDepth; }
               else if(!strcmpi(keyWord, "AnchorPointY") || !strcmpi(keyWord, "se:AnchorPointY") || !strcmpi(keyWord, "sld:AnchorPointY"))
               { state = anchorPointY; depth = xmlDepth; }
            }
            if(closingTag && xmlDepth == depth - 1)
            {
               state = pointPlacement; depth = xmlDepth;
            }
            break;
         case anchorPointX:
         case anchorPointY:
            if(closingTag && xmlDepth == depth - 1)
            {
               // TODO: Review all this -- default point is 0.5, 0.5 but it is reset to 0, 0?
               //default point is 0.5, 0.5 I don't think we handle exact distance just orientation except with LabelMarker?
               double d = strtod(charData,null);
               if(state == anchorPointX) anchorX = d;
               else { anchorY = d; }
               state = anchorPoint; depth = xmlDepth;
            }
            break;
         case halo: // looks like we should add everything to the label when textSymbolizer closes
            if(openingTag)
            {
               // new instance for outline
               if(!strcmpi(keyWord, "Radius") || !strcmpi(keyWord, "se:Radius") || !strcmpi(keyWord, "sld:Radius")) { state = radius; depth = xmlDepth; }
               else if(!strcmpi(keyWord, "Fill") || !strcmpi(keyWord, "se:Fill") || !strcmpi(keyWord, "sld:Fill")) { state = fill; curFill = { expType = class(Fill) }; fillParent = halo; depth = xmlDepth; }
            }
            if(closingTag && xmlDepth == depth - 1)
            {
               if(curOutline && currentGE)
               {
                  if(!curFont) curFont = { expType = class(GEFont) };
                  curFont.setMember("outline", fontOutline, true, curOutline);
               }
               state = textSymbolizer; depth = xmlDepth;
            }
            break;
         case radius:
            if(closingTag && xmlDepth == depth - 1)
            {
               CQL2ExpConstant constant { };
               double rad = (charData && charData[0]) ? strtod(charData, null) : 1.0;
               //if(charData) outlineSize = rad;
               constant.constant = { type.type = real, r = rad };
               if(curOutline)
                  curOutline.setMember("size", fontOutlineSize, true, constant);
               state = halo;
               depth = xmlDepth;
            }
            break;
         case vendorOption:
            if(closingTag && xmlDepth == depth - 1) { state = textSymbolizer; depth = xmlDepth; }
            break;
         case geometry:
            /*if(openingTag)
            {
               //can't use the same propertyName enumerator as expressions
               if(!strcmpi(keyWord, "PropertyName") || !strcmpi(keyWord, "ogc:PropertyName")) { state = propertyNameNonExp; depth = xmlDepth; }
            }*/
            if(closingTag && xmlDepth == depth - 1) { state = geomParent; depth = xmlDepth; }
            break;
         case propertyNameNonExp:
            if(closingTag && xmlDepth == depth - 1)
            {
               /*String transform;
               if(charData) transform = CopyString(charData);
               if(transform && geomParent == polygonSymbolizer) //will any of these be supported?
               else if(transform && geomParent == lineSymbolizer)
                  //"centerline" creates epsilon from point, line from polygon outline or coverage outline
               else if(transform && geomParent == pointSymbolizer)
               else if(transform && geomParent == textSymbolizer)*/
                //centroid
               state = propertyParent;
               depth = xmlDepth;
            }
            break;
         case svgParameter:
            if(closingTag && xmlDepth == depth - 1)
            {
               switch(svgParam)
               {
                  case fill:
                  case stroke:
                  {
                     Color col = (charData && charData[0] == '#') ? strtol(charData + 1, null, 16) : black;
                     CQL2ExpConstant constExp { constant = { i = col, type = { type = integer, format = color /*hex*/ } } };
                     if(svgParam == fill && col != white) defaultFill = false;
                     else if(svgParam == stroke && col != black) defaultStroke = false;

                     if(svgParam == fill) curFill.setMember("color", fillColor, true, constExp);
                     else
                     {
                        // handle special case where overlapping strokes in same filter represent casing
                        // FIXME: This probably won't work. Do all this in processing step at the end to combine 2 rules.
                        if(curStroke.getMemberByIDs([ "stroke", "color" ]))
                           curStroke.setMember("casing.color", strokeCasingColor, true, constExp);
                        else
                           curStroke.setMember("color", strokeColor, true, constExp);
                     }
                     break;
                  }
                  case fillOpacity:
                  case strokeOpacity:
                  {
                     double o = charData ? strtod(charData, null) : 1;
                     CQL2ExpConstant constant { constant = { r = o, type.type = real } };
                     if(svgParam == fillOpacity && o != 1.0) defaultFill = false;
                     else if(svgParam == strokeOpacity && o != 1.0) defaultStroke = false;

                     if(svgParam == fillOpacity) curFill.setMember("opacity", fillOpacity, true, constant);
                     else
                     {
                        // handle special case where overlapping strokes in same filter represent casing
                        // FIXME: This probably won't work. Do all this in processing step at the end to combine 2 rules.
                        if(curStroke.getMemberByIDs([ "stroke", "opacity" ]))
                           curStroke.setMember("casing.opacity", strokeCasingOpacity, true, constant);
                        else
                           curStroke.setMember("opacity", strokeOpacity, true, constant);
                     }
                     break;
                  }
                  case strokeWidth:
                  {
                     float width = charData ? (float)strtod(charData,null) : 1;
                     CQL2ExpConstant c { constant = { type = { real }, r = width } };
                     CQL2Expression e = c;
                     GraphicalUnit unit = (uomState == metre) ? meters : (uomState == foot) ? feet : pixels;
                     if(unit != pixels)
                     {
                        e = makeUnitExp(c, unit);
                        defaultStroke = false;
                     }
                     else if(width != 1)
                        defaultStroke = false;

                     // handle special case where overlapping strokes in same filter represent casing
                     // FIXME: This probably won't work. Do all this in processing step at the end to combine 2 rules.
                     if(curStroke.getMemberByIDs([ "stroke", "width" ]))
                        curStroke.setMember("casing.width", strokeCasingWidth, true, e);
                     else
                        curStroke.setMember("width", strokeWidth, true, e);
                     break;
                  }
                  case fontFamily:
                  {
                     CQL2ExpString string { string = charData ? CopyString(charData) : CopyString("Arial Unicode MS") };
                     // Until we have proper font substitution...
                     if(!SearchString(string.string, 0, "Arial", false, false))
                     {
                        delete string.string;
                        string.string = CopyString("Noto");
                     }
                     else
                     {
                        delete string.string;
                        string.string = CopyString("Arial Unicode MS");
                     }

                     curFont.setMember("face", fontFace, true, string);
                     break;
                  }
                  case fontSize:
                  {
                     double size = charData ? ((int)(strtod(charData, null) * 72 / 96 * 100 + 0.5) / 100.0) : 10;
                     CQL2ExpConstant constant { constant = { type.type = real, r = size } };
                     curFont.setMember("size", fontSize, true, constant);
                     break;
                  }
                  case fontWeight:
                  {
                     if(charData)
                     {
                        const String s = !strcmpi(charData, "bold") ? "true" : "false";
                        CQL2ExpIdentifier id { identifier = { string = CopyString(s) } };
                        curFont.setMember("bold", fontBold, true, id);
                     }
                     break;
                  }
                  case fontStyle:
                  {
                     if(charData)
                     {
                        const String s = !strcmpi(charData, "italic") ? "true" : "false";
                        CQL2ExpIdentifier id { identifier = { string = CopyString(s) } };
                        curFont.setMember("italic", fontItalic, true, id);
                     }
                     break;
                  }
               }
               svgParam = none;
               state = svgParamParent;
               depth = xmlDepth;
            }
            break;
         case wellKnownName:
            if(closingTag && xmlDepth == depth - 1)
            {
               String symType = CopyString(charData);
               symType[0] = (char)toupper(symType[0]);
               wKN = wellKnownTypeMap[symType]; // interim solution
               state = mark;
               depth = xmlDepth;
            }
            break;
         case size:   //need to handle metric
            if(closingTag && xmlDepth == depth - 1)
            {
               // Assume 32x32 icons for now...
               double sz, origSize = 32;
               CQL2ExpString p = currentGE && currentGE.instance && currentGE.instance.members ?
                  (CQL2ExpString)currentGE.instance.members.getProperty2(imageUrl, null) : null;
               // TOCHECK: getMemberByIDs() doesn't do get inside instance?
               // CQL2ExpString p = currentGE ? (CQL2ExpString)currentGE.getMemberByIDs([ "image", "url" ]) : null;
               if(p && p._class == class(CQL2ExpString) && p.string && strstr(p.string, "static/mapstorestyle/sprites/"))
                  origSize = 64; // These are bigger...

               sz = charData ? strtod(charData, null) : origSize;
               if(currentGE)
               {
                  CQL2ExpConstant constant { constant = { type.type = real, r = sz / origSize } };
                  currentGE.setMember("scaling", scaling, true, constant);
               }
               state = graphic;
               depth = xmlDepth;
            }
            break;
         case displacement:
            if(openingTag)
            {
               if(!strcmpi(keyWord, "DisplacementX") || !strcmpi(keyWord, "se:DisplacementX") || !strcmpi(keyWord, "sld:DisplacementX"))
               { state = displacementX; depth = xmlDepth; }
               else if(!strcmpi(keyWord, "DisplacementY") || !strcmpi(keyWord, "se:DisplacementY") || !strcmpi(keyWord, "sld:DisplacementY"))
               { state = displacementY; depth = xmlDepth; }
            }
            if(closingTag && xmlDepth == depth - 1)
            {
               if(currentGE && (dispX || dispY))
               {
                  CQL2ExpInstance pointInst { };
                  if(dispX) pointInst.setMember("x", 0, true, dispX);
                  if(dispY) pointInst.setMember("y", 0, true, dispY);
                  currentGE.setMember("position2D", position, true, pointInst);
                  dispX = null; dispY = null;
               }
               delete dispX;
               delete dispY;
               state = displaceParent; depth = xmlDepth;
            }
            break;
         case displacementX:
         case displacementY:
            if(closingTag && xmlDepth == depth - 1)
            {
               if(charData)
               {
                  GraphicalUnit unit = (uomState == metre) ? meters : (uomState == foot) ? feet : pixels;
                  CQL2ExpConstant c { constant = { r = strtod(charData, null), type.type = real } };
                  CQL2Expression e = c;
                  if(unit != pixels)
                     e = makeUnitExp(c, unit);

                  if(state == displacementX)
                     dispX = e;
                  else
                     dispY = e;
               }
               state = displacement;
               depth = xmlDepth;
            }
            break;
         /*case rotation:   //graphic rotation, label rotation
            if(closingTag && xmlDepth == depth - 1)
            {
               double rotation = charData ? strtod(charData,null) : 1;
               //rule graphic rotation
               state = graphic;
               depth = xmlDepth;
            }
            break;*/
         case opacity:
            if(closingTag && xmlDepth == depth - 1)
            {
               if(currentGE)
                  setSymbolizerVal(stylesList, opacity, { { real }, r = charData ? strtod(charData, null) : 1.0 }, class(double));
               state = rasterSymbolizer;
               depth = xmlDepth;
            }
            break;
         case colorMap:
            if(openingTag && (!strcmpi(keyWord, "ColorMapEntry") || !strcmpi(keyWord, "se:ColorMapEntry")))
            {
               if(!strcmpi(keyWord, "Categorize")) { state = categorize; depth = xmlDepth; }
               else if(!strcmpi(keyWord, "Interpolate")) { state = interpolate; depth = xmlDepth; }

               //svgParamParent = state;
               else if(!strcmpi(keyWord, "ColorMapEntry") || !strcmpi(keyWord, "se:ColorMapEntry") || !strcmpi(keyWord, "CssParameter") || !strcmpi(keyWord, "sld:CssParameter"))
               {
                  double quantity = 0;
                  int curEntry = Max( colorMap ? colorMap.count : 0, opacityMap ? opacityMap.count : 0);
                  while(GetWord())
                  {
                     if(!strcmpi(keyWord, "quantity"))
                     {
                        if(GetWord())
                           quantity = strtod(keyWord, null);

                        if(colorMap)   { colorMap.size   = curEntry + 1; colorMap[curEntry].value = quantity; }
                        if(opacityMap) { opacityMap.size = curEntry + 1; opacityMap[curEntry].value = quantity; }
                     }
                     else if(!strcmpi(keyWord, "color"))
                     {
                        Color col = black;
                        if(GetWord() && keyWord[0] == '#')
                           col = strtol(keyWord + 1, null, 16);
                        if(!colorMap) colorMap = { };
                        colorMap.size = curEntry + 1;
                        colorMap[curEntry].color = col;
                        colorMap[curEntry].value = quantity;
                     }
                     else if(!strcmpi(keyWord, "opacity"))
                     {
                        double opacity = 1.0;
                        if(GetWord()) opacity = strtod(keyWord, null);
                        if(!opacityMap) opacityMap = { };
                        opacityMap.size = curEntry + 1;
                        opacityMap[curEntry].opacity = opacity;
                        opacityMap[curEntry].value = quantity;
                     }
                     else if(!strcmpi(keyWord, "label"))
                     {
                        GetWord();
                         // TODO: (for legend?)
                     }
                  }
               }
            }
            if(closingTag && xmlDepth == depth - 1)
            {
               state = rasterSymbolizer; depth = xmlDepth;
               if(colorMap)
               {
                  rTop.symbolizer.changeProperty(colorMap, { { blob }, b = colorMap }, class(CartoSymbolizer), evaluator, false, class(Array<ValueColor>));
                  delete colorMap;
               }
               if(opacityMap)
               {
                  rTop.symbolizer.changeProperty(opacityMap, { { blob }, b = opacityMap }, class(CartoSymbolizer), evaluator, false, class(Array<ValueOpacity>));
                  delete opacityMap;
               }
            }
            break;
         case channelSelection:
            if(openingTag)
            {
               if(!strcmpi(keyWord, "GrayChannel") || !strcmpi(keyWord, "se:GrayChannel")) { state = grayChannel; depth = xmlDepth; }
               else if(!strcmpi(keyWord, "BlueChannel")) { state = blueChannel; depth = xmlDepth; }
               else if(!strcmpi(keyWord, "GreenChannel")) { state = greenChannel; depth = xmlDepth; }
               else if(!strcmpi(keyWord, "RedChannel")) { state = redChannel; depth = xmlDepth; }
            }
            if(closingTag && xmlDepth == depth - 1) { state = rasterSymbolizer; depth = xmlDepth; }
            break;
         case grayChannel:
         case blueChannel:
         case greenChannel:
         case redChannel:
            if(openingTag)
            {
               if(!strcmpi(keyWord, "SourceChannelName") || !strcmpi(keyWord, "se:SourceChannelname")) { contrastParent = state; state = sourceChannelName; depth = xmlDepth; }
               if(!strcmpi(keyWord, "ContrastEnhancement")) { contrastParent = state; state = contrastEnhancement; depth = xmlDepth; }
            }
            if(closingTag && xmlDepth == depth - 1) { state = channelSelection; depth = xmlDepth; }
            break;
         case sourceChannelName:
            if(closingTag && xmlDepth == depth - 1) { state = contrastParent; depth = xmlDepth; }
            break;
         case contrastEnhancement:
            if(openingTag)
            {
               //if(!strcmpi(keyWord, "Normalize/")) { rule.contrast = 1.0; depth = xmlDepth; }    //increases raster contrast to max
               //else if(!strcmpi(keyWord, "GammaValue")) { state = gammaValue; depth = xmlDepth; }
               //else if(!strcmpi(keyWord, "Histogram/")) { state = gammaValue; depth = xmlDepth; }
            }
            if(closingTag && xmlDepth == depth - 1) { state = contrastParent; depth = xmlDepth; }
            break;
         case gammaValue:
            if(closingTag && xmlDepth == depth - 1)
            {
               // double brightCol = charData ? strtod(charData,null) : 1;
               /*
               if(contrastParent == grayChannel)
               { if(charData) rule.brightness = (float)brightCol; }//float value
               if(contrastParent == blueChannel)
               { if(charData) rule.rasterColor.color.b = (byte)Max(0, Min(255, (int)(brightCol * 255))); } //alter brightness???

               if(contrastParent == greenChannel)
               { if(charData) rule.rasterColor.color.g = (byte)Max(0, Min(255, (int)(brightCol * 255))); }//alter brightness???

               if(contrastParent == redChannel)
               { if(charData) rule.rasterColor.color.r = (byte)Max(0, Min(255, (int)(brightCol * 255))); }//alter brightness???
               */
               state = contrastEnhancement;
               depth = xmlDepth;
            }
            break;
         case categorize:
            if(openingTag)
            {
               //if(!strcmpi(keyWord, "LookupValue"))
               if(!strcmpi(keyWord, "Value")) { state = rValue; depth = xmlDepth; }
               else if(!strcmpi(keyWord, "Threshold")) { state = threshold; depth = xmlDepth; }
               while(GetWord())
               {
                  if(!strcmpi(keyWord, "fallBackValue")) catParam = true;  //if SE implementation does not support function.. relevant?
                  else catParam = false;
               }
            }
            if(closingTag && xmlDepth == depth - 1) { state = colorMap; depth = xmlDepth; }
            break;
         case rValue:
         case threshold:
            if(closingTag && xmlDepth == depth - 1)
            {
               if(charData)
               {
                  if(charData[0] == '#' && state == rValue)
                  {
                     Color color = strtol(charData + 1,null,16); // charData ? strtol(charData + 1,null,16); : black;
                     colorRampValue = color;
                  }
                  else if(state == threshold)
                  {
                     // int thresh = strtol(charData,null,0); //altitute vs threshold?
                     //rule.elevationColorMap.Add( {thresh,colorRampValue} );
                     colorRampValue = 0;
                  }
               }
               state = categorize;
               depth = xmlDepth;
            }
            break;
         case title:
         case abstract:
            if(closingTag && xmlDepth == depth - 1) { state = titleParent; depth = xmlDepth; }
            break;
      }
   }

   void ProcessCharacterData(const char * data)
   {
      switch(state)
      {
         case featureTypeName:
         case name:
         {
            if(!forceName)
            {
               delete layerSource;
               layerSource = CopyString(data);
            }
            break;
         }
         case label:
         {
            labelData = CopyString(data);
            break;
         }   //LabelString { "format('This is city %s of state %s', `NAME`, `STATE`)" }  --like this
         case propertyName:
         case literal:
         case svgParameter:
         case opacity:
         case size:
         case radius:
         //case sourceChannelName:
         case gammaValue:
         case rValue:
         case threshold:
         case propertyNameNonExp:
         case anchorPointX:
         case anchorPointY:
         case displacementX:
         case displacementY:
         case minScaleDenominator:
         case maxScaleDenominator:
         case polygonSymbolizer:
         case lineSymbolizer:
         case pointSymbolizer:
         case textSymbolizer:
         case wellKnownName:
         case reliefFactor:
            delete charData;
            charData = CopyString(data);
            break;
      }
   }
};

// in SLD, the main stroke rule comes 2nd, and the casing width is the difference between this and the first
// the new block here is not in the styles list. Modify stroke/casing in existing 'casing' block
void addCasingOverlap(StylingRule workingBlock, StylingRule newBlock)
{
   CQL2Expression e = workingBlock.symbolizer.getProperty(ShapeSymbolizerKind::stroke); //getProperty2
   CQL2Expression eT = newBlock.symbolizer.getProperty(ShapeSymbolizerKind::stroke);
   if(e && eT && e._class == class(CQL2ExpInstance) && eT._class == class(CQL2ExpInstance))
   {
      CQL2ExpInstance inst = (CQL2ExpInstance)e;
      CQL2ExpInstance targetInst = (CQL2ExpInstance)eT;
      CQL2Expression widthExpWork = inst.getMemberByIDs([ "width" ]);
      CQL2Expression widthExpNew = targetInst.getMemberByIDs([ "width" ]);
      CQL2Expression colorExp = inst.getMemberByIDs([ "color" ]);
      CQL2Expression colorExpNew = targetInst.getMemberByIDs([ "color" ]);
      CQL2Expression opacityExp = inst.getMemberByIDs([ "opacity" ]);
      CQL2Expression opacityExpNew = targetInst.getMemberByIDs([ "opacity" ]);
      CQL2ExpInstance casingInst { };
      if(widthExpWork && widthExpNew)
      {
         FieldValue constant { { real } };
         CQL2ExpConstant c1 = null, c2 = null;
         bool meters = false;
         // units
         if(widthExpWork._class == class(CQL2ExpInstance) && widthExpNew._class == class(CQL2ExpInstance))
         {
            CQL2MemberInitList memberInitList = (CQL2MemberInitList)((CQL2ExpInstance)widthExpWork).instance.members[0];
            CQL2MemberInit m1 = memberInitList[0];
            CQL2MemberInitList memberInitList2 = (CQL2MemberInitList)((CQL2ExpInstance)widthExpNew).instance.members[0];
            CQL2MemberInit m2 = memberInitList2[0];
            c1 = (CQL2ExpConstant)m1.initializer;
            c2 = (CQL2ExpConstant)m2.initializer;
            meters = true; // Assume meters for now...
         }
         else
         {
            c1 = (CQL2ExpConstant)widthExpWork;
            c2 = (CQL2ExpConstant)widthExpNew;
         }
         constant.r = (c1 && c2) ? (c1.constant.r - c2.constant.r) : 1;
         casingInst.setMemberValue("width", strokeCasingWidth, true, constant, meters ? class(Meters) : class(double));
         inst.setMember("width", strokeWidth, true, widthExpNew.copy());
      }
      if(colorExp && colorExpNew)
      {
         casingInst.setMember("color", strokeCasingColor, true, colorExp.copy());
         inst.setMember("color", strokeColor, true, colorExpNew.copy());
      }
      if(opacityExp && opacityExpNew)
      {
         casingInst.setMember("opacity", strokeCasingOpacity, true, opacityExp.copy());
         inst.setMember("opacity", strokeOpacity, true, opacityExpNew.copy());
      }
      inst.setMember("casing", strokeCasing, true, casingInst);
   }
}

// this may eventually be appropriate in GraphicalSymbolizer, testing WellKnownTYpe
Map<const String, WellKnownName> wellKnownTypeMap
{ [
   { "Circle", circle },
   { "Square", square },
   { "Triangle", triangle },
   { "Cross", cross },
   { "X", x }
] };

Map<WellKnownName, const String> wellKnownTypeStringMap
{ [
   { circle, "Circle" },
   { square, "Square" },
   { triangle, "Triangle" },
   { cross, "Cross" },
   { x, "X" }
] };
