public import IMPORT_STATIC "ecrt"
public import IMPORT_STATIC "CartoSym"

private: // FIXME: Fix this public default after import

import "mbglParser"
import "gggLevels"    // for metersPerPixelFromLevel() and levelFromScaleDenominator()

#ifdef __MEMGUARD__
#define STRINGIFY(x) #x
#define TOSTRING(x) STRINGIFY(x)
#define CopyString(x) __extension__({String __s; MemoryGuard_PushLoc(__FILE__ ":" TOSTRING(__LINE__)); __s = CopyString(x); MemoryGuard_PopLoc(); __s; })
#endif

enum SplitFillStroke { fillOnly, strokeOnly, either, labelOnly };

static Map<CQL2TokenType, const String> mbTokensString
{ [
   { smallerEqual, "<=" },
   { smaller, "<" },
   { greaterEqual, ">="  },
   { greater, ">"  },
   { equal, "==" },
   { notEqual, "!=" },
   { not, "!" },
   { modulo, "%" },
   { divide, "/" },
   { not, "none" },
   //{ and, "and" },
   { and, "all" },
   { or, "any" },
   //{ or, "or" },
   { in, "in" },
   { stringContains, "match" } //this doesn't yet exist in mbgl
] };

static Map<GraphicalSymbolizerMask, const String> idMap
{ [
   { fill, "fill" },
   { stroke, "line" },
   { fillOpacity, "fill-opacity" },
   { fillColor, "fill-color" },
   //{ fillColor, "fill-outline-color" }, //hm
   { strokeOpacity,  "line-opacity" },
   { strokeColor,  "line-color" },
   { strokeWidth,  "line-width" },
   { image,  "icon-image" },
   //{ size,  "icon-size" }, //not a thing
   { text,  "text-field" },
   { opacity,  "icon-opacity" }, //what about imagery opacity?
   //{ outlineColor,  "text-halo-color" },
   //{ outlineWidth,  "text-halo-width" },
   { fontColor,  "text-color" },
   { fontFace, "text-font" },
   { fontSize, "text-size" },
   { fontOutlineColor, "text-halo-color"},
   { fontOutlineSize, "text-halo-width"},
   { alignment, "text-anchor" }
] };

static Map<String, const String> dashMapMBGL
{ [
   { "sourcelayer", "source-layer" },
   { "fillcolor", "fill-color" },
   { "fillopacity", "fill-opacity" },
   { "linecolor", "line-color" },
   { "lineopacity",  "line-opacity" },
   { "linewidth",  "line-width" },
   { "linegapwidth",  "line-gap-width" },
   { "iconopacity",  "icon-opacity" },
   { "iconimage",  "icon-image" },
   { "iconsize", "icon-size" },
   { "maxzoom",  "maxzoom" },
   { "minzoom",  "minzoom" },
   { "textfield",  "text-field" },
   { "textsize",  "text-size" },
   { "textoffset",  "text-offset" },
   { "textfont",  "text-font" },
   { "texthalocolor",  "text-halo-color" },
   { "texthalowidth",  "text-halo-width" },
   { "texthaloblur",  "text-halo-blur" },
   { "textcolor",  "text-color" },
   { "textanchor",  "text-anchor" },
   { "textvariableanchor", "text-variable-anchor" },
   { "rasteropacity",  "raster-opacity" },
   { "rasterhuerotate",  "raster-hue-rotate" },
   { "rasterbrightnessmin",  "raster-brightness-min" },
   { "rasterbrightnessmax",  "raster-brightness-max" },
   { "rastersaturation",  "raster-saturation" },
   { "rasterfadeduration",  "raster-fade-duration" },
   { "rasterresampling",  "raster-resampling" },
   { "hillshadeilluminationdirection",  "hillshade-illumination-direction" },
   { "hillshadeilluminationanchor",  "hillshade-illumination-anchor" },
   { "hillshadeexaggeration",  "hillshade-exaggeration" },
   { "hillshadeshadowcolor",  "hillshade-shadowcolor" },
   { "hillshadehighlightcolor",  "hillshade-highlight-color" },
   { "hillshadeaccentcolor",  "hillshade-accentcolor" }
] };

static struct MBGLWriter
{
private:
   File f;
   Array<MBGLLayersJSONData> layers;
   bool lcLayers, stringInts, lcFields;
   const String sourceName;

   void free()
   {
      // layers are freed by MBGLLayersJSONData
      //if(layers) { layers.Free(); delete layers; }
   }

   static MapboxGLJSONData getMBGLFromCartoSym(CartoStyle sheet, MapboxGLJSONData mb, Map<String, FeatureDataType> typeMap)
   {
      CartoSymEvaluator evaluator { class(CartoSymEvaluator) };//ECCSSEEvaluator { };
      CartoStyle bSheet = sheet.bind(evaluator, class(CartoSymbolizer), null);

      evaluator.setFeatureID(-1);
      mb.layers = layers = { };

      if(bSheet && bSheet.list)
      {
         CartoSymbolizer defSym = null;
         CartoExpFlags flg = 0;

         for(r : bSheet.list; r._class == class(StylingRule))
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
         }

         // First pass (not labels)
         for(r : bSheet.list; r._class == class(StylingRule))
         {
            StylingRule rule = (StylingRule)r;
            const String rid = rule.id ? rule.id.string : null;
            if(rid)
            {
               FeatureDataType type = rid && typeMap ? typeMap[rid] : { none };
               String id = CopyString(rid);
               if(lcLayers) strlwr(id);
               if(type.type == none)
                  type = { type = vector, vectorType = polygons };
               applyRuleBlock(rule, defSym, null, type, id, 0, 0, null, false, true);
               delete id;
            }
         }

         // Labels pass at the end
         for(r : bSheet.list; r._class == class(StylingRule))
         {
            StylingRule rule = (StylingRule)r;
            const String rid = rule.id ? rule.id.string : null;
            if(rid)
            {
               FeatureDataType type = rid && typeMap ? typeMap[rid] : { none };
               String id = CopyString(rid);
               if(lcLayers) strlwr(id);
               if(type.type == none)
                  type = { type = vector, vectorType = polygons };
               applyRuleBlock(rule, defSym, null, type, id, 0, 0, null, true, true);
               delete id;
            }
         }

         delete defSym;
      }
      delete bSheet;
      return mb;
   }

   static void applyRuleBlock(StylingRule block, CartoSymbolizer inheritedSymbolizer, CQL2Expression parentFilter, FeatureDataType type,
      const String id, double parentMinScale, double parentMaxScale, StylingRule labelElementsBlock, bool labelsPass,
      bool topRule)
   {
      CartoSymbolizer sym = inheritedSymbolizer ? inheritedSymbolizer.copy() : { };
      GraphicalSymbolizerMask m = 0xffffffffffffffff;
      CartoSymEvaluator evaluator { class(CartoSymEvaluator) };
      CQL2Expression filter = parentFilter ? parentFilter.copy() : null;
      CQL2Expression finalFilter = null;
      double minScale = 0, maxScale = 0;
      CartoExpFlags flg = sym.flags;

      evaluator.setFeatureID(-1);

      flg.resolved = false;
      m = (GraphicalSymbolizerMask)block.apply(sym, m, evaluator, &flg, true);
      sym.flags = flg;

      // TODO: For now this does not yet support adding to elements (+=)
      if(((CartoSymbolizerMask)block.mask).labelElements)
         labelElementsBlock = block;

      if(block.selectors)
      {
         for(l : block.selectors)
            if(!getScale(l.exp, &minScale, &maxScale))
               filter = filter ? CQL2ExpOperation { exp1 = filter, op = and, exp2 = l.exp.copy() } : l.exp.copy();
      }

      minScale = minScale && parentMinScale ? Max(minScale, parentMinScale) : minScale ? minScale : parentMinScale ? parentMinScale : 0;
      maxScale = maxScale && parentMaxScale ? Min(maxScale, parentMaxScale) : maxScale ? maxScale : parentMaxScale ? parentMaxScale : 0;

      if(sym && sym.visibility)
      {
         finalFilter = buildFlatFilter(filter, block);
         if(type.type == vector)
         {
            // NOTE: We are currently skipping generating strokes/fills to allow a rule overlapping with siblings conditions
            //       only labels based on a filter...
            bool onlyLabel = sym.label && sym.label.elements && sym.label.elements.GetCount() && !topRule &&
               !(block.symbolizer && (block.symbolizer.mask & (CartoSymbolizerKind::fill | CartoSymbolizerKind::stroke)));

            // TODO: marker support once in use (markers will be ordered in layer order, before labels)
            Array<GraphicalElement> elements = sym.label ? (Array<GraphicalElement>)sym.label.elements : null;
            if(!labelsPass && !onlyLabel && (type.vectorType == polygons || type.vectorType == lines))
            {
               if(type.vectorType == polygons && sym.fill.opacity)
               {
                  MBGLLayersJSONData fillLayer
                  {
                     id = PrintString("layer", layers.count, "_", id, "_fill"), source = CopyString(sourceName), sourcelayer = CopyString(id),
                     type = CopyString("fill"),
                     filter = { type = { type = nil } }
                  };
                  applyFilter(finalFilter, fillLayer, minScale, maxScale, stringInts, lcFields);
                  applyFill(fillLayer, sym);
                  layers.Add(fillLayer);
               }
               if(sym.stroke.opacity && sym.stroke.width)
               {
                  MBGLLayersJSONData lineLayer
                  {
                     id = PrintString("layer", layers.count, "_", id, "_line"), source = CopyString(sourceName), sourcelayer = CopyString(id),
                     type = CopyString("line"),
                     filter = { type = { type = nil } }
                  };
                  applyFilter(finalFilter, lineLayer, minScale, maxScale, stringInts, lcFields);
                  applyLine(lineLayer, sym);
                  layers.Add(lineLayer);
               }
            }
            else if(labelsPass && elements && elements.count)
            {
               CQL2List<CQL2Expression> elementsExps = (sym.flags.record && labelElementsBlock && labelElementsBlock.symbolizer) ?
                  labelElementsFromBlock(labelElementsBlock) : null;
               Iterator<CQL2Expression> it { (void *) elementsExps };
               MBGLLayersJSONData symbolLayer
               {
                  id = PrintString("layer", layers.count, "_", id, "_symbol"), source = CopyString(sourceName), sourcelayer = CopyString(id),
                  type = CopyString("symbol");
                  filter = { type = { type = nil } };
               };

               applyFilter(finalFilter, symbolLayer, minScale, maxScale, stringInts, lcFields);
               layers.Add(symbolLayer);

               for(e : elements)
               {
                  GraphicalElement element = e;
                  // If we have expression-based elements, we iterate them in parallel...
                  CQL2ExpInstance elExp = elementsExps ? (it.Next(), (CQL2ExpInstance)it.data) : null;

                  if(element && element._class == class(Text))
                  {
                     Text text = (Text)element;

                     if(symbolLayer.layout && symbolLayer.layout.textfield.type.type)
                     {
                        // We already have a text layer, create a new one
                        symbolLayer =
                        {
                           id = PrintString("layer", layers.count, "_", id, "_symbol"), source = CopyString(sourceName), sourcelayer = CopyString(id),
                           type = CopyString("symbol");
                           filter = { type = { type = nil } };
                        };
                        applyFilter(finalFilter, symbolLayer, minScale, maxScale, stringInts, lcFields);
                        layers.Add(symbolLayer);
                     }
                     applyText(symbolLayer, text, elExp, stringInts, lcFields);
                  }
                  else if(element && element._class == class(Image))
                  {
                     Image image = (Image)element;

                     if(symbolLayer.layout && symbolLayer.layout.iconimage.type.type != nil)
                     {
                        // We already have an icon layer, create a new one
                        symbolLayer =
                        {
                           id = PrintString("layer", layers.count, "_", id, "_symbol"), source = CopyString(sourceName), sourcelayer = CopyString(id),
                           type = CopyString("symbol");
                           filter = { type = { type = nil } };
                        };
                        applyFilter(finalFilter, symbolLayer, minScale, maxScale, stringInts, lcFields);
                        layers.Add(symbolLayer);
                     }
                     applyIcon(symbolLayer, image, elExp);
                  }
               }
            }
         }
         else if(!labelsPass && type.type == raster)
         {
            MBGLLayersJSONData rasterLayer
            {
               id = PrintString("layer", layers.count, "_", id, "_raster"), source = CopyString("rasterSource"), // TODO: multiple sources
               type = CopyString("raster"),
               filter = { type = { type = nil } }
            };
            applyFilter(finalFilter, rasterLayer, minScale, maxScale, stringInts, lcFields);
            applyRaster(rasterLayer, sym);
            layers.Add(rasterLayer);
         }
         else if(!labelsPass && type.type == coverage)
         {
            // TODO: Check whether a hillshading style is being applied
            // TOCHECK: Symbolization for other types of coverages ?
            /* FIXME: No useful styling is currently being saved, and this breaks Mapbox readiness without a terrain source
            MBGLLayersJSONData hillshadeLayer
            {
               id = PrintString("layer", layers.count, "_", id, "_hillshade"), source = CopyString("elevationSource"), // TODO: multiple sources
               type = CopyString("hillshade"),
               filter = { type = { type = nil } }
            };
            applyFilter(finalFilter, hillshadeLayer, minScale, maxScale, stringInts, lcFields);
            applyHillshade(hillshadeLayer, sym);
            layers.Add(hillshadeLayer);
            */
         }
      }
      else
         finalFilter = filter;

      // Create layers for sub-rules
      if(block.nestedRules)
         for(b : block.nestedRules; b._class == class(StylingRule))
         {
            StylingRule rule = (StylingRule)b;
            applyRuleBlock(rule, sym, filter, type, id, minScale, maxScale, labelElementsBlock, labelsPass, false);
         }

      delete finalFilter;

      delete sym;
   }

   static void applyFill(MBGLLayersJSONData layer, CartoSymbolizer symbolizer)
   {
      if(!layer.paint) layer.paint = { };

      (&layer.paint.fillcolor)->OnFree();
      *&layer.paint.fillcolor = MBGLFilterValue { s = colorToHex((Color)symbolizer.fill.color), type = { text, mustFree = true } };
      layer.paint.fillopacity = { { real }, r = symbolizer.fill.opacity };
   }

   static void applyLine(MBGLLayersJSONData layer, CartoSymbolizer symbolizer)
   {
      GraphicalUnit widthUnit = symbolizer.stroke.widthUnit;

      if(!layer.paint) layer.paint = { };

      layer.paint.lineopacity = { type = { real }, r = symbolizer.stroke.opacity };
      (&layer.paint.linecolor)->OnFree();
      *&layer.paint.linecolor = MBGLFilterValue { s = colorToHex((Color)symbolizer.stroke.color), type = { text, mustFree = true } };

      // Value indicates the width of the inner gap ?
      if(symbolizer.stroke.casing.width)
         layer.paint.linegapwidth = MBGLFilterValue { type = { type = real }, r = symbolizer.stroke.casing.width };

      if(widthUnit == meters)
      {
         Array<MBGLFilterValue> stepArray { };
         Array<MBGLFilterValue> zoomArray { };
         int i;

         stepArray.Add(MBGLFilterValue { type = { type = text }, s = CopyString("step")});
         zoomArray.Add(MBGLFilterValue { type = { type = text }, s = CopyString("zoom")});
         stepArray.Add(MBGLFilterValue { type = { type = array }, b = zoomArray });
         stepArray.Add(MBGLFilterValue { type = { type = integer }, i = 1 });

         for(i = 6; i <= 18; i++)   // GMC levels
         {
            double mpp = metersPerPixelFromLevel(i-2);
            double size = ((int)((symbolizer.stroke.width / mpp) * 100 + 0.5) / 100.0);
            if(size > 1)
            {
               stepArray.Add(MBGLFilterValue { type = { type = integer }, i = i });
               stepArray.Add(MBGLFilterValue { type = { type = real }, r = size });
            }
         }
         layer.paint.linewidth = MBGLFilterValue { type = { type = array }, b = stepArray };
      }
      else if(symbolizer.stroke.widthUnit == pixels)
         layer.paint.linewidth = MBGLFilterValue { type = { type = real }, r = symbolizer.stroke.width };
   }

   static void applyText(MBGLLayersJSONData layer, Text textElement, CQL2ExpInstance elExp, bool stringInts, bool lcFields)
   {
      GEFont font = textElement.font;
      Alignment2D al = textElement.alignment;
      float x = textElement.position2D.x, y = textElement.position2D.y;
      MBGLFilterValue tf { };

      if(!layer.layout) layer.layout = { };
      if(!layer.paint) layer.paint = { };

      if(textElement.text)
         tf = { type = { type = text, mustFree = true }, s = CopyString(textElement.text) };
      else if(elExp)
      {
         CQL2Expression textExp = getExpInstanceMember(elExp, TextSymbolizerKind::text);
         if(textExp)
         {
            if(textExp._class == class(CQL2ExpIdentifier))
            {
               // brackets for attributes/expression based elements{ZI005_FNA}
               CQL2ExpIdentifier idExp = (CQL2ExpIdentifier)textExp;
               CQL2Identifier id = idExp ? idExp.identifier : null;
               tf = { type = { type = text, mustFree = true }, s = PrintString("{", id ? id.string : "(null)", "}") };
               if(lcFields) strlwr(tf.s);
            }
            else
               filterValueFromExp(tf, textExp, stringInts, lcFields);
         }
      }
      if(tf.type.type != nil)
         layer.layout.textfield = tf;

      layer.paint.textcolor.OnFree();
      layer.paint.textcolor = { type = { text, mustFree = true }, s = colorToHex(font ? (Color)font.color : black) };

      (&layer.paint.texthalocolor)->OnFree();
      *&layer.paint.texthalocolor = MBGLFilterValue { type = { text, mustFree = true }, s = colorToHex(font ? (Color)font.outline.color : white) };


      if(font && font.size > 0)
         layer.layout.textsize = MBGLFilterValue { type = { type = real }, r = textElement.font.size * 96.0 / 72.0 };
      if(font && font.outline.size > 0)
         layer.paint.texthalowidth = { type = { real }, r = font.outline.size };

      if(font && (font.face || font.italic || font.bold))
         layer.layout.textfont = { type = { array, mustFree = true },
           a = { [ { type = { text, mustFree = true }, s =
            PrintString(
               font.face ? font.face : "Arial Unicode MS",
               font.bold ? " Bold" : "",
               font.italic ? " Italic" : "")
         } ] } };

      if(x || y)
      {
         double fontSize = layer.layout.textsize.r;
         double empp = 72.0 / (fontSize * 96.0);
         layer.layout.textoffset = MBGLFilterValue {
            type = { array }, a = Array<FieldValue> { [
               FieldValue { type = { real }, r = x * empp },
               FieldValue { type = { real }, r = y * empp }
            ] }
         };
      }

      if(al != { center, middle })
      {
         const String s = null;
              if(al.horzAlign == left   && al.vertAlign == middle) s = "left";
         else if(al.horzAlign == right  && al.vertAlign == middle) s = "right";
         else if(al.horzAlign == center && al.vertAlign == top)    s = "top";
         else if(al.horzAlign == center && al.vertAlign == bottom) s = "bottom";
         else if(al.horzAlign == left   && al.vertAlign == top)    s = "top-left";
         else if(al.horzAlign == right  && al.vertAlign == top)    s = "top-right";
         else if(al.horzAlign == left   && al.vertAlign == bottom) s = "bottom-left";
         else if(al.horzAlign == right  && al.vertAlign == bottom) s = "bottom-right";
         layer.layout.textanchor = { type = { text, mustFree = true }, s = CopyString(s) };
      }
   }

   static void applyIcon(MBGLLayersJSONData layer, Image image, CQL2ExpInstance elExp)
   {
      double scaling = ((int)((double)image.scaling * 100 + 0.5)) / 100.0;

      if(!layer.layout) layer.layout = { };
      if(!layer.paint) layer.paint = { };

      if(image.image.path && image.image.path[0])
      {
         char tmp[2048];
         GetLastDirectory(image.image.path, tmp);
         StripExtension(tmp);
         layer.layout.iconimage.OnFree();
         layer.layout.iconimage = { type = {text, true}, s = CopyString(tmp) };
      }
      layer.paint.iconopacity = { type = { real }, r = image.opacity };
      if(scaling != 1.0)
         layer.layout.iconsize = { type = { real }, r = scaling };
   }

   static void applyRaster(MBGLLayersJSONData layer, CartoSymbolizer symbolizer)
   {
      if(!layer.layout) layer.layout = { };
      if(!layer.paint) layer.paint = { };
      //layer.paint.rasteropacity = symbolizer.opacity;
      /*
         raster

         visibility              Layout   (visible), none   Whether this layer is displayed.
         raster-opacity          Paint    0..1 (1)          The opacity at which the image will be drawn.
         raster-hue-rotate       Paint    degrees (0)       Rotates hues around the color wheel.
         raster-brightness-min   Paint    0..1 (0)          Increase or reduce the brightness of the image. The value is the minimum brightness.
         raster-brightness-max   Paint    0..1 (1)          Increase or reduce the brightness of the image. The value is the maximum brightness.
         raster-saturation       Paint    -1..1 (0)         Increase or reduce the saturation of the image.
         raster-contrast         Paint    -1..1 (0)         Increase or reduce the contrast of the image.
         raster-resampling       Paint    linear, nearest   The resampling/interpolation method to use for overscaling, also known as texture magnification filter
         raster-fade-duration    Paint    >= 0  (300)       ms duration when a new tile is added.
      */
   }

   /*static void applyHillshade(MBGLLayersJSONData layer, CartoSymbolizer symbolizer)
   {
         hillshade

         visibility                          Layout   (visible), none
         hillshade-illumination-direction    Paint.   (335) 0..359 (Clockwise ?)
            The direction of the light source used to generate the hillshading with 0 as the top of the viewport
            if hillshade-illumination-anchor is set to viewport and due north if hillshade-illumination-anchor is set to map.
         hillshade-illumination-anchor       Paint    map, (viewport)
         hillshade-exaggeration              Paint    0.5 (0..1)  Intensity of the hillshade
         hillshade-shadow-color              Paint    (#000000)   The shading color of areas that face away from the light source.
         hillshade-highlight-color           Paint    (#FFFFFF)   The shading color of areas that faces towards the light source.
         hillshade-accent-color              Paint    (#000000)   The shading color used to accentuate rugged terrain like sharp cliffs and gorges.
   }
   */

   static bool filterValueFromExp(MBGLFilterValue value, CQL2Expression e, bool stringInts, bool lcFields)
   {
      bool result = false;

      value = { type = { type = nil } };
      if(e)
      {
         Array<MBGLFilterValue> filterVals { };

         processExpression(e, filterVals);

         if(filterVals.count > 0)
         {
            value.b = filterVals;
            value.type.type = array;
            result = true;
         }
         else
            delete filterVals;
      }
      return result;
   }

   static void applyFilter(CQL2Expression e, MBGLLayersJSONData layer, double minScale, double maxScale,
      bool stringInts, bool lcFields)
   {
      MBGLFilterValue value;
      if(filterValueFromExp(value, e, stringInts, lcFields))
         layer.filter = value;

      if(maxScale) layer.minzoom = levelFromScaleDenominator(maxScale) + 2;
      if(minScale) layer.maxzoom = levelFromScaleDenominator(minScale) + 2;
   }

   static Array<MBGLFilterValue> processExpression(CQL2Expression e, Array<MBGLFilterValue> filterVals)
   {
      if(e._class == class(CQL2ExpOperation))
      {
         CQL2ExpOperation opExp = (CQL2ExpOperation)e;
         if(
            (opExp.exp1 && opExp.exp1._class == class(CQL2ExpIdentifier)) ||
            (opExp.exp2 && opExp.exp2._class == class(CQL2ExpIdentifier)) ||
            (opExp.exp1 && opExp.exp1._class == class(CQL2ExpMember)) ||
            (opExp.exp2 && opExp.exp2._class == class(CQL2ExpMember)))
         {
            CQL2ExpIdentifier identifier =
               opExp.exp1 && opExp.exp1._class == class(CQL2ExpIdentifier) ?
                  (CQL2ExpIdentifier)opExp.exp1 : opExp.exp2 && opExp.exp2._class == class(CQL2ExpIdentifier) ?
                  (CQL2ExpIdentifier)opExp.exp2 : null;
            CQL2ExpMember member =
               opExp.exp1 && opExp.exp1._class == class(CQL2ExpMember) ?
                  (CQL2ExpMember)opExp.exp1 : opExp.exp2 && opExp.exp2._class == class(CQL2ExpMember) ?
                  (CQL2ExpMember)opExp.exp2 : null;
            if(member && !strcmp(member.member.string, "sd"))
               ;// This is now handled by getScale()
            else if(identifier)
            {
               Array<MBGLFilterValue> getVals { };
               CQL2Expression expVal = (opExp.exp2 && opExp.exp2._class != class(CQL2ExpIdentifier)) ? opExp.exp2 : opExp.exp1;
               filterVals.Add(MBGLFilterValue { type = { type = text }, s = CopyString(mbTokensString[opExp.op])}); //negativeBlock ? CopyString("!=") :

               processExpression(identifier, getVals);
               filterVals.Add(MBGLFilterValue { type = { type = array }, b = getVals });

               if(expVal)
               {
                  if(expVal._class == class(CQL2ExpBrackets))
                  {
                     CQL2ExpBrackets brkts = (CQL2ExpBrackets)expVal;
                     Array<MBGLFilterValue> inVals { };
                     for(el : brkts.list)
                        processExpression(el, inVals);

                     filterVals.Add(MBGLFilterValue { type = { type = array }, b = inVals });
                  }
                  else
                     processExpression(expVal, filterVals);
               }
            }
         }
         else
         {
            Array<MBGLFilterValue> expVals1 = null, expVals2 = null;

            if(opExp.exp1)
            {
               bool sameLevel = (opExp.exp1._class == class(CQL2ExpOperation) &&
                  ((CQL2ExpOperation)opExp.exp1).op == opExp.op && (opExp.op == or || opExp.op == and));
               processExpression(opExp.exp1, sameLevel ? filterVals : (expVals1 = { }));
            }

            if(opExp.exp2)
               processExpression(opExp.exp2, (expVals2 = { }));

            if((expVals1 && expVals2) || (opExp.op != and && opExp.op != or))
               filterVals.Add(MBGLFilterValue { type = { type = text }, s = CopyString(mbTokensString[opExp.op])});
            if(expVals1) filterVals.Add(MBGLFilterValue { type = { type = array }, b = expVals1 });
            if(expVals2) filterVals.Add(MBGLFilterValue { type = { type = array }, b = expVals2 });
         }
      }
      else if(e._class == class(CQL2ExpString))
      {
         CQL2ExpString expString = (CQL2ExpString)e; // NULL string?
         filterVals.Add(MBGLFilterValue { type = { type = text }, s = CopyString(expString.string)});

      }
      else if(e._class == class(CQL2ExpConstant))
      {
         CQL2ExpConstant constant = (CQL2ExpConstant)e;
         MBGLFilterValue fVal { };
         // also check string later
         fVal.type.type = constant.constant.type.type == integer ? integer : real;

         if(fVal.type.type == integer)
         {
            fVal.i = constant.constant.i;
            if(stringInts)
            {
               fVal.s = PrintString(constant.constant.i);
               fVal.type = { type = text, mustFree = true };
            }
         }
         else fVal.r = constant.constant.r;
         filterVals.Add(fVal);
      }
      else if(e._class == class(CQL2ExpIdentifier))
      {
         CQL2ExpIdentifier identifier = (CQL2ExpIdentifier)e;
         String s = CopyString(identifier.identifier.string);
         if(lcFields) strlwr(s);
         filterVals.Add({ type = { type = text, mustFree = true }, s = CopyString("get") });
         filterVals.Add({ type = { type = text, mustFree = true }, s = s });
      }
      else if(e._class == class(CQL2ExpBrackets))
      {
         CQL2ExpBrackets brkts = (CQL2ExpBrackets)e;

         for(el : brkts.list)
            processExpression(el, filterVals);

      }
      return filterVals;
   }

};

public bool writeMBGLFile(CartoStyle sheet, File f, const String styleName, Map<String, FeatureDataType> typeMap,
   const String sourceName, MapboxGLSourceData sourceData, const String sprite, bool lcLayers, bool lcFields, bool stringInts)
{
   bool result = true;
   MBGLWriter writer
   {
      f = f,
      sourceName = sourceName,
      lcLayers = lcLayers,
      lcFields = lcFields,
      stringInts = stringInts
   };
   MapboxGLJSONData mb
   {
      version = 8;
      name = CopyString(styleName);
      sources = { [
         {
            sourceName,
            sourceData
         }
      ] };
      sprite = CopyString(sprite);
   };
   //not sure sprite and sources will be touched

   // load mb w/ cmss
   writer.getMBGLFromCartoSym(sheet, mb, typeMap);

   //what about writing meta info?
   //WriteMBGLObject(f, mb._class, mb, writer.indent);
   result = WriteJSONObjectMapped(f, mb._class, mb, 0, dashMapMBGL);

   delete mb.sources;   // Avoir deleting input sourceData
   delete mb;

   writer.free();

   return result;
}

public bool writeMBGL(CartoStyle sheet, const String fileName, Map<String, FeatureDataType> typeMap,
   const String sourceName, MapboxGLSourceData sourceData, const String sprite, bool lcLayers, bool lcFields, bool stringInts)
{
   bool result = false;
   File f = FileOpen(fileName, write);
   if(f)
   {
      String name = CopyString(fileName);
      StripExtension(name);

      result = writeMBGLFile(sheet, f, name, typeMap, sourceName, sourceData, sprite, lcLayers, lcFields, stringInts);

      delete name;
      delete f;
   }
   return result;
}

String colorToHex(Color color)
{
   char hex[100];
   sprintf(hex, "#%02x%02x%02x", color.r, color.g, color.b);
   return CopyString(hex);
}
