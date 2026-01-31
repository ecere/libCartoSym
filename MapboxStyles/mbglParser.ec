public import IMPORT_STATIC "ecrt"
public import IMPORT_STATIC "CartoSym"

private: // FIXME: Fix this public default after import

#include <math.h>

import "gggLevels"  // For scaleDenominatorFromLevel()

public int64 verbalRound(int64 value)
{
   int64 rounding = 10000000000;
   while(rounding > 1)
   {
      if(value > rounding)
      {
         value = ((int64)((value + rounding / 4.0f) / (rounding/2))) * (rounding/2);
         break;
      }
      rounding /= 10;
   }
   return value;
}

public int64 verbalRound2(int64 value, int factor)
{
   int64 rounding = 10000000000;
   while(rounding > 1)
   {
      if(value > rounding)
      {
         value = ((int64)((value + rounding / (2.0f * factor)) / (rounding/factor))) * (rounding/factor);
         break;
      }
      rounding /= 10;
   }
   return value;
}

// Returns false if number is changed to numerator
public bool roundScale(double * denum)
{
   if(*denum >= 1)
   {
      *denum = verbalRound2((int64)(*denum + 0.5), 10);
      return true;
   }
   else
   {
      *denum = verbalRound((int64)(1.0 / *denum + 0.5));
      return false;
   }
}

private /*static*/ struct ColorRGB { float r, g, b; };

enum ColorParseMode { none, hex, alphaOnly };

public struct MBGLSpriteSymbol
{
   int width, height;
   int x, y;
   int pixelRatio;
   Array<int> content;
   Array<Array<int>> stretchX, stretchY;

   void OnFree()
   {
      delete content;
      if(stretchX) stretchX.Free(), delete stretchX;
      if(stretchY) stretchY.Free(), delete stretchY;
   }
};

// REVIEW: Can we use FieldValue directly now?
public struct MBGLFilterValue : FieldValue
{
private:

   void OnFree()
   {
      // FIXME: Should use 'array'
      if(type.type == array)
      {
         Array<MBGLFilterValue> params = (Array<MBGLFilterValue>)a;
         if(params) params.Free();
         delete params;
      }
      else if(type.type == text)
         delete s;
   }
public:

   bool OnGetDataFromString(const char * string)
   {
      bool result;

      if(string[0] == '[')
      {
         TempFile f { };
         ECONParser parser { f };
         Array<MBGLFilterValue> values = null;
         f.buffer = (byte *)string;
         f.size = strlen(string);

         result = parser.GetObject(class(Array<MBGLFilterValue>), &values) == success;
         if(result)
         {
            // FIXME: Should use 'array'
            type = { type = array };
            a = (Array<FieldValue>)values;
         }
         f.StealBuffer();
         delete f;
         delete parser;
      }
      else
         result = FieldValue::OnGetDataFromString(string);
      return result;
   }

   // how to write in JSON?
   /*
         char tempString[1024] = "";
         ObjectNotationType onType = none; //json
         const char * string = anchor.OnGetString(tempString, null, &onType);
         something = string;
   */

   #define MBGL_MAX_FILTER_STRING_BUFFER_LEN 16384
   // WARNING: This expects a MBGL_MAX_FILTER_STRING_BUFFER_LEN minimum tempString buffer
   const char * OnGetString(char * tempString, void * fieldData, ObjectNotationType * onType)
   {
      switch(type.type)
      {
         case text:
            if(s)
               EscapeCString(tempString, MAX_F_STRING, s, { writeQuotes = true, escapeDoubleQuotes = true });
            else
               strcpy(tempString, "null");
            break;
         case real: sprintf(tempString, "%f", r); break;
         case integer: sprintf(tempString, FORMAT64D, i); break;
         case array:   // FIXME: Should use 'array'
         {
            // TODO: Improve OnGetString() to support returning dynamic memory that must be freed
            //       as well as explicit buffer limits
            if(a)
            {
               // NOTE: Assuming that a MBGLFilterValue is only used in a single export process...
               ZString string { allocType = heap };
               int x = 0;
               Array<MBGLFilterValue> params = (Array<MBGLFilterValue>)a;
               //if(strlen(s) == 0) sprintf(s, "{ ");
               string.concat("[ ");
               //if(onType && *onType == json)
               for(x = 0; x < params.count; x++)
               {
                  char tmpChr[MBGL_MAX_FILTER_STRING_BUFFER_LEN];
                  const char * thisString = params[x].OnGetString(tmpChr, null, null);
                  //params.count
                  string.concatf(thisString);
                  if(x < params.count-1)
                     string.concat(", ");
               }
               string.concat(" ]");
#ifdef _DEBUG
               {
                  int l = strlen(string._string);
                  if(string._string && l > MBGL_MAX_FILTER_STRING_BUFFER_LEN-1)
                  {
                     PrintLn("ASSERTION FAILED: MBGL Filter value too long");
                     puts(string._string);
                  }
               }
#endif
               strncpy(tempString, string._string, MBGL_MAX_FILTER_STRING_BUFFER_LEN-1);
               tempString[MBGL_MAX_FILTER_STRING_BUFFER_LEN-1] = 0;
               delete string;
               return tempString;
            }
            else
               sprintf(tempString, "null");
            break;
         }
         default:
#ifdef _DEBUG
            PrintLn("WARNING: unhandled field type: ", (int)type.type);
#endif
            break;
      }
      return tempString;
   }
};

public class MapboxGLSourceData
{
   int tileSize;
public:
   String type;
   String url;
   Array<String> tiles;
   int maxzoom;
   property int tileSize
   {
      get { return tileSize; }
      set { tileSize = value; }
      isset { return tileSize != 0; }
   }
   const String geoDataClass; // REVIEW: We may or may not be adding this for GeoPackage Styles extension

   ~MapboxGLSourceData()
   {
      delete type;
      delete url;
   }
}

public class MapboxGLJSONData
{
private:
   double zoom;
   String id;

   ~MapboxGLJSONData()
   {
      if(layers) { layers.Free(); delete layers; }
      delete name;
      delete sprite;
      delete glyphs;
      delete id;
      if(sources) sources.Free(), delete sources;
      center.OnFree();
   }

public:
   int version;
   String name;
   Map<String, MapboxGLSourceData> sources;
   String sprite;
   String glyphs;
   FieldValue center;

   property double zoom
   {
      get { return zoom; }
      set { zoom = value; }
      isset { return zoom != 0; }
   }

   property String id
   {
      set { delete id; if(value) id = CopyString(value); }
      get { return this ? id : null; }
      isset { return id != null; }
   };

   property FieldValue owner
   {
      // TODO:
      set { }
      get { value = { }; /*return null;*/ }
      isset { return false; }
   };

   property FieldValue metadata
   {
      // TODO:
      set { }
      get { value = { }; /*return null;*/ }
      isset { return false; }
   };

   property FieldValue center
   {
      isset { return center.type.type && center.type.type != nil ; }
   };

   Array<MBGLLayersJSONData> layers;
}

public class MBGLLayersJSONData
{
private:
   double minzoom;
   double maxzoom;
   MBGLFilterValue filter;

   ~MBGLLayersJSONData()
   {
      delete id;
      delete source;
      delete sourcelayer;
      delete layout;
      delete paint;
      delete type;
      filter.OnFree();
   }

   void process(StylingRule rule, bool useSprite, Map<String, Size> symbolSizes)
   {
      const String type = this ? this.type : null;
      if(rule && type)
      {
         MBGLPaintJSONData paint = this.paint;
         MBGLLayoutJSONData layout = this.layout;

         // NOTE: These were handled from the wrong place... just in case to import bad files -- Do we still need this? We should probably use OnCopy()?
         if(layout && *&layout.textcolor.type.type != nil && (paint && *&paint.textcolor.type.type == nil)) paint.textcolor = layout.textcolor;
         if(layout && *&layout.texthalowidth.type.type != nil && (paint && *&paint.texthalowidth.type.type == nil)) paint.texthalowidth = layout.texthalowidth;
         if(layout && *&layout.texthaloblur && !*&paint.texthaloblur) paint.texthaloblur = layout.texthaloblur;
         if(layout && *&layout.texthalocolor.type != 0 && *&layout.texthalocolor.type.type != nil) paint.texthalocolor = layout.texthalocolor;

         if(!strcmpi(type, "fill"))
            processFill(rule);
         else if(!strcmpi(type, "line"))
            processLine(rule);
         else if(!strcmpi(type, "symbol") || !strcmpi(type, "circle"))
            processSymbol(rule, symbolSizes);
         else if(!strcmpi(type, "raster") || !strcmpi(type, "raster-dem"))
            processRaster(rule);
         else if(!strcmpi(type, "hillshade"))
            processHillshade(rule);
      }
   }

   void processFill(StylingRule stylingRule)
   {
      MBGLPaintJSONData paint = this.paint;
      // Fill
      if(paint)
      {
         StylingRule rule = null;
         CQL2ExpInstance instance { };
         CQL2Expression fillColorExp = null;
         // nested rule for min/maxzoom
         rule = minMaxZoomNestedRule(stylingRule);
         if(!rule.symbolizer) rule.symbolizer = { };

         if(paint.fillcolor.type.type != nil && paint.fillcolor.type.type != 0)
            fillColorExp = convertMBGLExp(paint.fillcolor, false, false, ColorParseMode::hex);

         if((paint.fillopacity.type.type != nil && paint.fillopacity.type.type != 0) || (paint.fillcolor.type.type != nil && paint.fillcolor.type.type != 0))
         {
            CQL2Expression fillOpacityExp = paint.fillopacity.type.type != nil && paint.fillopacity.type.type != 0 ? convertMBGLExp(paint.fillopacity, false, false, none) : null;
            // multiply with colorAlpha
            if(paint.fillcolor.type.type != nil && paint.fillcolor.type.type != 0)
            {
               CQL2Expression alphaExp = convertMBGLExp(paint.fillcolor, false, false, alphaOnly);
               fillOpacityExp = fillOpacityExp ? CQL2ExpOperation { exp1 = fillOpacityExp, op = multiply, exp2 = alphaExp } : alphaExp;
            }
            if(fillOpacityExp)
               instance.setMember("opacity", fillOpacity, true, fillOpacityExp);
         }
         if(paint.fillpattern.type.type != nil && paint.fillpattern.type.type != 0)
         {
            //NOTE: paint.fillpattern not yet supported -- fall back to 50% opacity and some default fil colors
            instance.setMember("opacity", fillOpacity, true, CQL2ExpConstant { constant = { { real }, r = 0.5 } });
            if(!fillColorExp)
            {
               Color color = white;
               if(paint.fillpattern.type.type == text)
               {
                  const String pattern = paint.fillpattern.s;
                       if(strstr(pattern, "grassland")) color = 0xB0E8BE;
                  else if(strstr(pattern, "sand"))      color = 0xCEC9BC;
                  else if(strstr(pattern, "drainage"))  color = 0x366708;
                  else if(strstr(pattern, "glacier"))   color = 0xB0EEF0;
                  else if(strstr(pattern, "marsh"))     color = 0x758F61;
                  else if(strstr(pattern, "swamp"))     color = 0x6D7344;
                  fillColorExp = CQL2ExpConstant { constant = { { integer, format = FieldValueFormat::color }, color } };
               }
            }
         }

         if(fillColorExp)
         {
            CQL2ExpInstance strokeInst { };
            CQL2Expression lineColorExp = null;
            instance.setMember("color", fillColor, true, fillColorExp);
            // by default outline should be the same color as fill as per mbgl spec. Width default?
            if(paint.filloutlinecolor.type.type == nil || paint.filloutlinecolor.type.type == 0)
               lineColorExp = fillColorExp.copy();
            else
               lineColorExp = convertMBGLExp(paint.filloutlinecolor, false, false, ColorParseMode::hex);

            // REVIEW: Is actual outline always set after the fill?
            strokeInst.setMember("color", strokeColor, true, lineColorExp);
            setSymbolizerExp(rule.symbolizer, stroke, strokeInst);
         }
         setSymbolizerExp(rule.symbolizer, fill, instance);
      }
   }

   void processLine(StylingRule stylingRule)
   {
      // NOTE: for interpolation, use Meters in case of width, but for color/opacity set expression WIP
      // TOFIX: temporarily use the first color in the steps
      StylingRule rule = null;
      MBGLPaintJSONData paint = this.paint;
      // Stroke
      CQL2ExpInstance instance = null, instanceParent = null;
      CQL2Expression findExp = null, casingExp = null, fillExp = null;
      CQL2MemberInit swSet = null;
      bool isCasing = (paint.linegapwidth.type.type != nil && paint.linegapwidth.type.type != 0);
      //NOTE: use temporary fix for big unwanted values for unsupported line-patterns
      bool isPattern = paint.linepattern.type.type != nil && paint.linepattern.type.type != 0;
      bool isCenterline = false;
      // bool doNothing = false;

      // nested rule for min/maxzoom
      rule = minMaxZoomNestedRule(stylingRule);
      if(!rule.symbolizer) rule.symbolizer = { };

      findExp = stylingRule.symbolizer.getProperty(ShapeSymbolizerKind::stroke);
      if(!findExp) findExp = rule.symbolizer.getProperty(ShapeSymbolizerKind::stroke);
      casingExp = stylingRule.getProperty(ShapeSymbolizerKind::strokeCasing); //cl
      if(!casingExp) casingExp = rule.getProperty(ShapeSymbolizerKind::strokeCasing); //cl
      fillExp = stylingRule.symbolizer.getProperty(ShapeSymbolizerKind::fill);
      if(!fillExp) fillExp = rule.symbolizer.getProperty(ShapeSymbolizerKind::fill);
      if(findExp && !fillExp)
      {
         CQL2Expression wMem = ((CQL2ExpInstance)findExp).getMemberByIDs([ "width" ]);
         CQL2Expression cMem = ((CQL2ExpInstance)findExp).getMemberByIDs([ "color" ]);
         //CQL2Expression oMem = ((CQL2ExpInstance)findExp).getMemberByIDs([ "opacity" ]);
         isCenterline = /*casingExp != null*/!isCasing && (wMem || cMem); //|| oMem); // this will work up to 3 layers, possible extras in some layers discarded?
         if(isCenterline) isCasing = false;
      }
      swSet = rule.symbolizer.findDeepProperty(GraphicalSymbolizerMask::strokeWidth);
      instance = findExp && !(isCasing || isCenterline)? (CQL2ExpInstance)findExp : { };
      //if(findExp && (isCasing || isCenterline) && (minzoom || maxzoom))
         //rule.setStyle(class(CartoSymbolizer), isCenterline ? "stroke.center" : isCasing ? "stroke.casing" : "stroke", isCenterline ? strokeCenter : isCasing ? strokeCasing : stroke, false, instance, evaluator, class(CartoSymbolizer));
      //else
      {
         /*if(isCasing || isCenterline)
         {
            instanceParent = findExp ? (CQL2ExpInstance)findExp : {};
            if(findExp)
               instanceParent.setMember(isCenterline ? "center" : "casing", isCenterline ? strokeCenter : strokeCasing, true, instance);
            else if(isCasing)
               instanceParent.setMember("opacity", strokeOpacity, true, CQL2ExpConstant { constant = { r = 0.0, type = { real } } });
         }*/
         if(!(findExp || casingExp))
         {
            if(!isCasing)
            {
               SymbolizerProperties sl = rule.symbolizer.copy();
               rule.symbolizer.Free();
               setSymbolizerExp(rule.symbolizer, stroke, instanceParent ? instanceParent : instance);
               for(s : sl.list)
                  rule.symbolizer.Add(s);
            }
            //if(isCasing)
               //setSymbolizerExp(rule.symbolizer, strokeCasing, instance);
         }
      }
      //if(!doNothing)
      {
         if(paint.linecolor.type.type != nil && paint.linecolor.type.type != 0)
         {
            CQL2Expression lineColorExp = null;
            if(paint.linecolor.type.type != nil)
               lineColorExp = convertMBGLExp(paint.linecolor, false, false, ColorParseMode::hex);
            if(lineColorExp)
               rule.setStyle(class(CartoSymbolizer), isCenterline ? "stroke.center.color" : isCasing ? "stroke.casing.color" : "stroke.color", isCenterline ? strokeCenterColor : isCasing ? strokeCasingColor : strokeColor, false, lineColorExp, evaluator, class(CartoSymbolizer));
               //instance.setMember("color", isCasing ? strokeCasingColor : isCenterline ? strokeCenterColor : strokeColor, true, lineColorExp);
         }
         else if(isPattern)
         {
            Color col = lightGray;
            CQL2ExpConstant colConst { constant = { { integer, format = color /*hex*/ }, i = col } };
            //instance.setMember("color", isCasing ? strokeCasingColor : isCenterline ? strokeCenterColor : strokeColor, true, colConst);
            rule.setStyle(class(CartoSymbolizer), isCenterline ? "stroke.center.color" : isCasing ? "stroke.casing.color" : "stroke.color", isCenterline ? strokeCenterColor : isCasing ? strokeCasingColor : strokeColor, false, colConst, evaluator, class(CartoSymbolizer));
         }
         if((paint.lineopacity.type.type != nil && paint.lineopacity.type.type != 0) || (paint.linecolor.type.type != nil && paint.linecolor.type.type != 0))
         {
            CQL2Expression lineOpacityExp = paint.lineopacity.type.type != nil && paint.lineopacity.type.type != 0 ? convertMBGLExp(paint.lineopacity, false, false, none) : null;
            // multiply with colorAlpha
            if(paint.linecolor.type.type != nil && paint.linecolor.type.type != 0)
            {
               CQL2Expression alphaExp = convertMBGLExp(paint.linecolor, false, false, alphaOnly);
               lineOpacityExp = lineOpacityExp ? CQL2ExpOperation { exp1 = lineOpacityExp, op = multiply, exp2 = alphaExp } : alphaExp;
            }
            if(lineOpacityExp) //instance.setMember("opacity", isCasing ? strokeCasingOpacity : isCenterline ? strokeCenterOpacity : strokeOpacity, true, lineOpacityExp);
               rule.setStyle(class(CartoSymbolizer), isCenterline ? "stroke.center.opacity" : isCasing ? "stroke.casing.opacity" : "stroke.opacity", isCenterline ? strokeCenterOpacity : isCasing ? strokeCasingOpacity : strokeOpacity, false, lineOpacityExp, evaluator, class(CartoSymbolizer));
         }
         else if(findExp && !(isCasing || isCenterline))
            rule.setStyle(class(CartoSymbolizer), "stroke.opacity", strokeOpacity, false, CQL2ExpConstant { constant = { r = 1.0, type = { real } } }, evaluator, class(CartoSymbolizer));
         if(paint.linewidth.type.type != nil && paint.linewidth.type.type != 0)
         {
            // NOTE: in mbgl, linegapwidth is equivalent to the first layer regular line that the casing layer overlaps, with line-width in the casing layer representing the casing width
            // the presence of linegapwidth indicates that it's an overlapping casing layer.. there maybe more than one, currently supporting simple case
            CQL2Expression lineWidthExp = isCasing ? convertCasingWidth(paint.linewidth, paint.linegapwidth) : convertWidth(paint.linewidth, isPattern);
            if(lineWidthExp)
            {
               if(!swSet || (isCasing || isCenterline))
                  rule.setStyle(class(CartoSymbolizer), isCenterline ? "stroke.center.width" : isCasing ? "stroke.casing.width" : "stroke.width", isCenterline ? strokeCenterWidth : isCasing ? strokeCasingWidth : strokeWidth, false, lineWidthExp, evaluator, class(CartoSymbolizer));
               if(isCasing)
               {
                  CQL2Expression newWidth = convertWidth(paint.linewidth, isPattern);
                  if(newWidth)
                     rule.setStyle(class(CartoSymbolizer), "stroke.width", strokeWidth, false, newWidth, evaluator, class(CartoSymbolizer));
               }
            }
               //instance.setMember("width", isCasing ? strokeCasingWidth : isCenterline ? strokeCenterWidth : strokeWidth, true, lineWidthExp);
         }
      }
   }

      /*
      if(useSprite)
      {
         // NOTE: Sprites are available as http://vtp2018.s3-eu-west-1.amazonaws.com/static/mapstorestyle/sprites/sprites.png
         // Cut them up with Bitmap::Grab() as named symbols according to info in
         // http://vtp2018.s3-eu-west-1.amazonaws.com/static/mapstorestyle/sprites/sprites.png
         if(spriteData && iconImgExp && iconImgExp._class == class(CQL2ExpString))    // && mb.sprite &&
         {
            char path[100];
            TempFile tmp { };
            Bitmap bitmapSplit { }; //TOFIX: conditional expressions for symbols?
            MBGLSpriteSymbol spriteSymbol = spriteData.spriteSymbols[((CQL2ExpString)iconImgExp).string];//[*(String *)&layout.iconimage.s];
            bitmapSplit.Grab(bitmapSrc, spriteSymbol.x, spriteSymbol.y);
            sprintf(path, "File://%p", tmp);
            bitmapSplit.Save(path, "png", null);
            tmp.Seek(0, start);
            pathExp = CQL2ExpString { string = CopyString(path) };
            delete bitmapSplit;
         }
      }
      */

   void hotSpotFromIconAnchor(const MBGLFilterValue iconAnchor, Pointf hotSpot)
   {
      // REVIEW: icon-anchor could probably be a complex expression?
      const String s = iconAnchor != null && iconAnchor.type.type == text ? iconAnchor.s : null;

      if(!s ||!strcmp(s, "center"))       hotSpot = { 0.5, 0.5 };
      else if(!strcmp(s, "right"))        hotSpot = { 1.0, 0.5 };
      else if(!strcmp(s, "left"))         hotSpot = { 0.0, 0.5 };
      else if(!strcmp(s, "top"))          hotSpot = { 0.5, 0.0 };
      else if(!strcmp(s, "top-left"))     hotSpot = { 0.0, 0.0 };
      else if(!strcmp(s, "top-right"))    hotSpot = { 1.0, 0.0 };
      else if(!strcmp(s, "bottom"))       hotSpot = { 0.5, 1.0 };
      else if(!strcmp(s, "bottom-left"))  hotSpot = { 0.0, 1.0 };
      else if(!strcmp(s, "bottom-right")) hotSpot = { 1.0, 1.0 };
      else                                hotSpot = { 0.5, 0.5 };
   }

   CQL2ExpInstance setupImage(bool isCircle, Pointf imageHotSpot, CQL2Expression * rSymbolExp)
   {
      CQL2ExpInstance imageInst = null;
      CQL2Expression iconImgExp = isCircle ?
         CQL2ExpString { string = CopyString("routeMarker-local") } : // Work around for Dot labels/marker not working yet
         convertMBGLExp(layout.iconimage, false, false, none);
      if(iconImgExp)
      {
         // TODO: Set path for more complex expressions as well?
         CQL2Expression pathExp = iconImgExp._class == class(CQL2ExpString) ?
            CQL2ExpString { string = PrintString("symbols/", ((CQL2ExpString)iconImgExp).string, ".png") } : null;
         CQL2ExpInstance imResourceInst { instance = { } };

         imageInst = { instance = { _class = { name = CopyString("Image") } } };
         if(pathExp) imResourceInst.setMember("path", imagePath, true, pathExp);
         imResourceInst.setMember("id", imageId, true, iconImgExp);
         imageInst.setMember("image", image, true, imResourceInst);

         if(!isCircle)
         {
            CQL2Expression iconSizeExp = layout.iconsize.type.type != nil ? convertMBGLExp(layout.iconsize, false, false, none) : null;
            CQL2Expression iconOffsetExp = layout.iconoffset.type.type != nil ? convertMBGLExp(layout.iconoffset, false, false, none) : null;
            if(iconSizeExp)
               imageInst.setMember("scaling", scaling, true, iconSizeExp);

            if(iconOffsetExp)
            {
               if(iconOffsetExp._class == class(CQL2ExpBrackets) && ((CQL2ExpBrackets)iconOffsetExp).list.GetCount() == 2)
               {
                  CQL2ExpBrackets brackets = (CQL2ExpBrackets)iconOffsetExp;
                  CQL2ExpInstance pointInst { };
                  pointInst.setMember("x", 0, true, brackets.list[0]);
                  pointInst.setMember("y", 0, true, brackets.list[1]);
                  imageInst.setMember("position2D", position, true, pointInst);
               }
               else
                  delete iconOffsetExp; // REVIEW: Can we just set the offset directly?
            }
         }
         {
            // REVIEW: Possibility for complex icon-anchor expressions?
            CQL2ExpInstance hotSpotInst { };
            hotSpotFromIconAnchor(isCircle ? null : &layout.iconanchor, imageHotSpot);
            hotSpotInst.setMember("x", 0, true, CQL2ExpConstant { constant = { { real }, r = imageHotSpot.x } });
            hotSpotInst.setMember("y", 0, true, CQL2ExpConstant { constant = { { real }, r = imageHotSpot.y } });
            imageInst.setMember("hotSpot", hotSpot, true, hotSpotInst);
            if(isCircle)
            {
               CQL2Expression tintExp = (paint.circlecolor.type.type != nil && paint.circlecolor.type.type != 0) ? convertMBGLExp(paint.circlecolor, false, false, hex) : null;
               CQL2Expression blackTintExp = (paint.circlestrokecolor.type.type != nil && paint.circlestrokecolor.type.type != 0) ? convertMBGLExp(paint.circlestrokecolor, false, false, hex) : null;
               if(tintExp || blackTintExp)
               {
                  Color btCol = white;
                  if(!blackTintExp) blackTintExp = CQL2ExpConstant { constant = { { integer }, i = btCol } };
                  imageInst.setMember("tint", tint, true, tintExp);
                  imageInst.setMember("blackTint", blackTint, true, blackTintExp);
               }
            }
         }
         if(rSymbolExp) *rSymbolExp = iconImgExp;
      }
      return imageInst;
   }

   CQL2Expression setupTextContent(CQL2Expression textPart, CQL2Expression transformExp)
   {
      if(textPart._class == class(CQL2ExpString))
      {
         CQL2ExpString es = (CQL2ExpString)textPart;
         if(es.string && es.string[0] == '{') // '}' // FIXME: The IDE is confused by that bracket character
         {
            // Supporting single pair of brackets for attributes...
            CQL2Identifier id { string = removeDoubleQuotesOrBrackets(es.string) };
            delete textPart;
            textPart = CQL2ExpIdentifier { identifier = id };
         }
      }
      if(transformExp)
      {
         if(transformExp._class == class(CQL2ExpString))
         {
            const String trString = ((CQL2ExpString)transformExp).string;
            if(trString)
            {
               // REVIEW: Is this working ?
               const String fn = !strcmp(trString, "uppercase") ? "strupr" : !strcmp(trString, "lowercase") ? "strlwr" : null;
               if(fn)
                  textPart = CQL2ExpCall { exp = CQL2ExpIdentifier { identifier = CQL2Identifier { string = CopyString(fn) } }, arguments = CQL2ExpList { [ textPart ] } };
            }
         }
      }
      return textPart;
   }

   CQL2Expression setupFontSize(CQL2Expression * rTextSizeExp)
   {
      CQL2Expression textSizeExp = layout.textsize.type.type != nil && layout.textsize.type.type != 0 ?
         convertMBGLExp(layout.textsize, false, false, none) : null;
      CQL2Expression ptSize;

      if(textSizeExp)
         // Converting pixels into points
         // REVIEW: Make sure constant expresions get simplified to a single constant
         //         -- this is when we still want to do the rounding with ((int)(em * 100 + 0.5)) / 100.0
         ptSize = CQL2ExpOperation
         {
            exp1 = CQL2ExpBrackets { list = { [ textSizeExp ] } },
            op = multiply,
            exp2 = CQL2ExpConstant { constant = { { real }, r = 0.75 /* 96/72*/ } }
         };
      else
      {
         // Default to 12 pt font (16 pixels)
         textSizeExp = CQL2ExpConstant { constant = { { real }, r = 16 } };
         ptSize = CQL2ExpConstant { constant = { { real }, r = 12 } };
      }
      if(rTextSizeExp) *rTextSizeExp = textSizeExp; // Also used for position
      return ptSize;
   }

   CQL2Expression setupFontFace(CQL2Expression * bold, CQL2Expression * italic)
   {
      CQL2Expression face = null;
      *bold = null, *italic = null;
      if(layout.textfont.type.type == array && layout.textfont.a && layout.textfont.a.count)
      {
         Array<FieldValue> a = layout.textfont.a;
         bool isBold = false, isItalic = false;
         if(a[0].type.type == text && a[0].s)
         {
            const String t = a[0].s;
            if(!strcmp(t, "step")) // REVIEW: other complex expression types to support?
            {
               CQL2Expression cmssExp = convertMBGLExp(layout.textfont, false, false, none);
               if(cmssExp) // Right now we can only use a single font, index the first one
                  // REVIEW: Process expressions to simplify them and keep only first element?
                  face = CQL2ExpIndex {
                     exp = CQL2ExpBrackets { list = { [ cmssExp ] } },
                     index = { [ CQL2ExpConstant { constant = { { integer }, i = 0 } } ] } };
            }
            else
            {
               // NOTE: RBT styles sometimes use [ "literal", [ ... ] ] and sometimes [ ... ] directly
               if(!strcmp(t, "literal") && a.count > 1 && a[1].type.type == array)
                  a = a[1].a, t = a && a.count && a[0].type.type == text ? a[0].s : null;
               if(t)
               {
                  // Using Arial Unicode for Arial until we have proper per-glyph font substitution...
                  String font = CopyString(!strcmp(t, "Arial") ? "Arial Unicode MS" : t);

                  // REVIEW: Is this the best way to get to use those installed single-weight NGA Topo / Noto Sans fonts ?
                  if(SearchString(font, 0, "NGATopo_", false, false))
                  {
                     isBold = strstr(font, " Bold") || strstr(font, "_bld") || strstr(font, "_bi");
                     isItalic = strstr(font, " Italic") || strstr(font, "_ita") || strstr(font, "_bi");
                     delete font, font = CopyString("NGATopo Cn");
                  }
                  else if(SearchString(font, 0, "NotoSans", false, false))
                  {
                     isBold = strstr(font, " Bold") || strstr(font, "_bld") || strstr(font, "_bi");
                     isItalic = strstr(font, " Italic") || strstr(font, "_ita") || strstr(font, "_bi");
                     delete font, font = CopyString("Noto Sans");
                  }
                  face = CQL2ExpString { string = font };
               }
            }
         }

         // NOTE: If we were to set face to a single-weight (already bold/italic) font, we do not need to set bold separately
         *bold = isBold ? CQL2ExpIdentifier { identifier = { string = CopyString("true") } } : null;
         *italic = isItalic ? CQL2ExpIdentifier { identifier = { string = CopyString("true") } } : null;
      }
      return face;
   }

   CQL2ExpInstance setupFontOutline()
   {
      CQL2ExpInstance outline = null;
      MBGLPaintJSONData paint = this.paint;

      // Outline
      if(paint.texthaloblur ||
         (paint.texthalocolor.type.type != 0 && paint.texthalocolor.type.type != nil) ||
         (paint.texthalowidth.type.type != 0 && paint.texthalowidth.type.type != nil))
      {
         CQL2Expression size = paint.texthalowidth.type.type != nil ?
            convertMBGLExp(paint.texthalowidth, false, false, none) : null;
         CQL2Expression color = paint.texthalocolor.type.type == text ?
            getColorHexConstant(removeDoubleQuotesOrBrackets(paint.texthalocolor.s), hex) : null;

         outline = { };
         // REVIEW: CQL2Expression fadeExp = paint.texthaloblur ? convertMBGLExp(paint.texthaloblur, false, false, none) : null;
         if(size) outline.setMember("size", fontOutlineSize, true, size);
         if(color) outline.setMember("color", fontOutlineColor, true, color);
         // REVIEW: if(fadeExp) outlineInst.setMember("fade", fontOutlineFade, true, fadeExp);

         // NOTE: rgba values of text-halo-color may indicate opacity...
         outline.setMember("opacity", fontOutlineOpacity, true, CQL2ExpConstant { constant = { r = 1.0, type = { real } } });
      }
      return outline;
   }

   CQL2ExpInstance setupTextFont(CQL2Expression * rTextSizeExp)
   {
      CQL2ExpInstance fontInstance = null;
      MBGLPaintJSONData paint = this.paint;

      if(paint)
      {
         CQL2Expression bold, italic, face = setupFontFace(&bold, &italic);
         CQL2Expression ptSize = setupFontSize(rTextSizeExp);
         //REVIEW: Why different color handling? getColorHexConstant() for outline color vs. convertMBGLExp() here
         CQL2Expression color = paint.textcolor.type.type != nil ?
            convertMBGLExp(paint.textcolor, false, false, hex) : null;
         CQL2ExpInstance outline = setupFontOutline();

         fontInstance = { };
         if(face) fontInstance.setMember("face", fontFace, true, face);
         if(bold) fontInstance.setMember("bold", fontBold, true, bold);
         if(italic) fontInstance.setMember("italic", fontItalic, true, italic);
         if(ptSize) fontInstance.setMember("size", fontSize, true, ptSize);
         if(outline) fontInstance.setMember("outline", fontOutline, true, outline);
         if(color) fontInstance.setMember("color", fontColor, true, color);
      }
      else
         *rTextSizeExp = null;
      return fontInstance;
   }

   // Returned alignment will be { unset, unset } if complex expression
   CQL2ExpInstance setupTextAlignment(Alignment2D * alignment, CQL2Expression * rHAlignExp, CQL2Expression * rVAlignExp)
   {
      CQL2ExpInstance alignmentExp { };
      // Text Alignment (from text-variable-anchor or text-anchor)
      //symbol-placement must be 'point'
      bool complexExpAlignment = false;
      CQL2Expression hAlignExp, vAlignExp;
      bool usingStops = false;

      //"center", "left", "right", "top", "bottom", "top-left", "top-right", "bottom-left", "bottom-right". Defaults to "center"
      const String a = null;
      if(layout.textvariableanchor.type.type == text)
         a = layout.textvariableanchor.s;
      else if(layout.textvariableanchor.type.type == map)
      {
         for(e : layout.textvariableanchor.m)
         {
            const String key = &e;
            if(key && !strcmp(key, "stops"))
            {
               /*
               FieldValue fv = e;
               // Select left is present, first otherwise
               if(fv.type.type == text)
               {
                  const String string = e.s;
                  bool isLeft = string && !strcmp(string, "left");
                  if(!a || isLeft)
                  {
                     a = string;
                     if(isLeft) break;
                  }
               }
               */

               complexExpAlignment = true;
               usingStops = true;
            }
         }
      }
      else if(layout.textvariableanchor.type.type == array)
      {
         for(e : layout.textvariableanchor.a)
         {
            FieldValue fv = e;
            // Select left is present, first otherwise
            if(fv.type.type == text)
            {
               const String string = e.s;
               bool isLeft = string && !strcmp(string, "left");
               if(!a || isLeft)
               {
                  a = string;
                  if(isLeft) break;
               }
            }
            else
               complexExpAlignment = true;
         }
      }
      else
      {
         // REVIEW: Complex text variable anchor
         if(layout.textvariableanchor.type.type == text)
            a = layout.textanchor.s;
      }

      if(complexExpAlignment)
      {
         CQL2Expression variableAchor = convertMBGLExp(layout.textvariableanchor, false, false, none);
         if(usingStops)
         {
            /* Here we want to turn e.g.
					"stops": [
						[ 0, [ "bottom-left", "top-left", "bottom-right", "top-right", "left", "right", "bottom", "top" ] ],
						[ 15, [ "bottom" ] ]
					]
            into
               hAlignExp = (viz.sd > 50000) ? left : center
               vAlignExp = middle

            and in this case we would set
               *alignment = { unset, center }
            because only the horizontal alignment is scale-dependent
            */
         }

         *alignment = { unset, unset };
         hAlignExp = substituteExpValues(variableAchor, mbglAlignmentToHAlign);
         vAlignExp = substituteExpValues(variableAchor, mbglAlignmentToVAlign);

         delete variableAchor;
      }
      else
      {
         ObjectNotationType on = econ;
         HAlignment ha;
         VAlignment va;

              if(!a || !strcmp(a, "center")) *alignment = { center, middle };
         else if(!strcmp(a, "left"))         *alignment = { left, middle };
         else if(!strcmp(a, "right"))        *alignment = { right, middle };
         else if(!strcmp(a, "top"))          *alignment = { center, top };
         else if(!strcmp(a, "bottom"))       *alignment = { center, bottom };
         else if(!strcmp(a, "top-left"))     *alignment = { left, top };
         else if(!strcmp(a, "top-right"))    *alignment = { right, top };
         else if(!strcmp(a, "bottom-left"))  *alignment = { left, bottom };
         else if(!strcmp(a, "bottom-right")) *alignment = { right, bottom };

         ha = alignment->horzAlign; // FIXME: eC warnings calling OnGetString() directly on bit class members
         va = alignment->vertAlign;
         hAlignExp = CQL2ExpIdentifier { identifier = { string = CopyString(ha.OnGetString(null, null, &on)) } };
         vAlignExp = CQL2ExpIdentifier { identifier = { string = CopyString(va.OnGetString(null, null, &on)) } };
      }
      if(rHAlignExp) *rHAlignExp = hAlignExp;
      if(vAlignExp) *rVAlignExp = vAlignExp;
      alignmentExp.setMember("horzAlign", alignmentHorzAlign, true, hAlignExp);
      alignmentExp.setMember("vertAlign", alignmentVertAlign, true, vAlignExp);
      return alignmentExp;
   }

   void setupTextIconOffset(CQL2Expression * offsetFromIconX, CQL2Expression * offsetFromIconY,
      Alignment2D alignment, int dirX, int dirY, CQL2Expression dirXExp, CQL2Expression dirYExp,
      const Pointf imageHotSpot, CQL2Expression symbolExp, Map<String, Size> symbolSizes)
   {
      CQL2ExpString symbolExpString = symbolExp._class == class(CQL2ExpString) ? (CQL2ExpString)symbolExp : null;
      const String symbolString = symbolExpString ? symbolExpString.string : null;
      bool complexHAlignment = alignment.horzAlign == unset;
      bool complexVAlignment = alignment.vertAlign == unset;
      bool setXOffset = complexHAlignment || (alignment.horzAlign != center && imageHotSpot.x != (alignment.horzAlign == left ? 1 : 0));
      bool setYOffset = complexVAlignment || (alignment.vertAlign != middle && imageHotSpot.y != (alignment.vertAlign == top  ? 1 : 0));
      Size symbolSize { }; // = symbolString ? symbolSizes[symbolString] : { }; // FIXME: This is broken
      MapIterator<String, Size> it { map = symbolSizes };

      if(!symbolExpString && symbolExp._class == class(CQL2ExpConditional))
      {
         CQL2ExpConditional cond = (CQL2ExpConditional)symbolExp;
         if(cond.expList.firstIterator.data._class == class(CQL2ExpString))
         {
            symbolExpString = (CQL2ExpString)cond.expList.firstIterator.data;
         }
         else if(cond.elseExp._class == class(CQL2ExpString))
         {
            symbolExpString = (CQL2ExpString)cond.elseExp;
         }
         symbolString = symbolExpString ? symbolExpString.string : null;
      }

      if(symbolString && it.Index(symbolString, false))
      {
         const Size * size = (const Size *)it.GetData();
         symbolSize = *size; // FIXME: this is broken? -- it.data;
         //TOFIX: substitute the symbol IDs for their dimension when dealing with a complex symbolExp
      }

      // If text is not center-aligned and we have an icon, we need to move it away by ((1,1)-hotSpot) * symbolSize * direction
      if(setXOffset)
      {
         if(complexHAlignment)
         {
            float w = (1-imageHotSpot.x) * symbolSize.w;
            if(w)
               *offsetFromIconX = CQL2ExpOperation { exp1 = CQL2ExpBrackets { list = { [ dirXExp.copy() ] } }, op = multiply, exp2 = CQL2ExpConstant { constant = { { real }, r = w } } };
         }
         else if(!symbolString)
         {
            // FIXME:
         }
         else
         {
            // Simple alignment & symbol: constant offset
            float w = (1-imageHotSpot.x) * symbolSize.w * dirX;
            if(w)
               *offsetFromIconX = CQL2ExpConstant { constant = { { real }, r = w } };
         }
      }

      if(setYOffset)
      {
         if(complexVAlignment)
         {
            // FIXME:
            float h = (1-imageHotSpot.y) * symbolSize.h;
            if(h)
               *offsetFromIconY = CQL2ExpOperation { exp1 = CQL2ExpBrackets { list = { [ dirYExp.copy() ] } }, op = multiply, exp2 = CQL2ExpConstant { constant = { { real }, r = h } } };
         }
         else if(!symbolString)
         {
            // FIXME:
         }
         else
         {
            // Simple alignment & symbol: constant offset
            float h = (1-imageHotSpot.y) * symbolSize.h * dirY;
            if(h)
               *offsetFromIconY = CQL2ExpConstant { constant = { { real }, r = h } };
         }
      }
   }

   void setupTextRadialOffset(CQL2Expression * textOffsetX, CQL2Expression * textOffsetY,
      Alignment2D alignment, int dirX, int dirY, CQL2Expression dirXExp, CQL2Expression dirYExp, CQL2Expression textSizeExp, int totalTextElements)
   {
      // Text position offset from text-radial-offset
      CQL2Expression textRadOffsetExp = convertMBGLExp(layout.textradialoffset, false, false, none); // REVIEW: Can this ever fail?
      if(textRadOffsetExp) // REVIEW: Should always use brackets if not already brackets, constant, identifier, string or function call
                           //         Use a function e.g. ensureBrackets()
         textRadOffsetExp = CQL2ExpBrackets { list = { [ textRadOffsetExp ] } };
      if(textRadOffsetExp)
      {
         //bool complexHAlignment = alignment.horzAlign == unset;
         //bool complexVAlignment = alignment.vertAlign == unset;
         // Text tadial offset is r * (dirX, dirY) * textSize (in pixels)
         //if(complexHAlignment)
         {
            // FIXME:
         }
         if(dirX || (dirXExp && (dirXExp._class != class(CQL2ExpConstant) || ((CQL2ExpConstant)dirXExp).constant.i != 0)))
            *textOffsetX = CQL2ExpOperation {
               exp1 = CQL2ExpOperation {
                  exp1 = textRadOffsetExp.copy(),
                  op = multiply, exp2 = dirXExp ? dirXExp.copy() : CQL2ExpConstant { constant = { { integer }, i = dirX } } },
               op = multiply,
               exp2 = textSizeExp.copy() };

         //if(complexVAlignment)
         {
            // FIXME:
         }
         if(dirY || (dirYExp && (dirYExp._class != class(CQL2ExpConstant) || ((CQL2ExpConstant)dirYExp).constant.i != 0)))
         {
            *textOffsetY = CQL2ExpOperation {
               exp1 = CQL2ExpOperation {
                  exp1 = textRadOffsetExp.copy(),
                  op = multiply, exp2 = dirYExp ? dirYExp.copy() : CQL2ExpConstant { constant = {{ integer }, i = dirY } } },
               op = multiply,
               exp2 = textSizeExp.copy() };
            if(totalTextElements > 1)
            {
               // NOTE: this gap size also reflected in  textElementOffset used in setupTextPosition()
               CQL2Expression sizePlusGap = CQL2ExpBrackets { list = { [ CQL2ExpOperation { exp1 = textSizeExp.copy(), op = plus, exp2 = CQL2ExpConstant { constant = {{ real }, r = 7 } }} ]} };
               CQL2Expression textElementsExp = CQL2ExpBrackets { list = { [ CQL2ExpOperation { exp1 = CQL2ExpConstant { constant = {{ integer }, i = totalTextElements-1 } },
                  op = multiply, exp2 = dirYExp ? dirYExp.copy() : CQL2ExpConstant { constant = {{ integer }, i = dirY } } } ]}};

               *textOffsetY = CQL2ExpOperation {
                  exp1 = CQL2ExpBrackets { list = { [ *textOffsetY ] } }, op = plus,
                  exp2 = CQL2ExpBrackets { list = { [ CQL2ExpOperation {
                     exp1 = textElementsExp, op = multiply,
                     exp2 = sizePlusGap } ] } } };
            }
         }
         else if(totalTextElements > 1) // left/center/right alignment
         {
            // NOTE: this gap size also reflected in  textElementOffset used in setupTextPosition()
            CQL2Expression sizePlusGap = CQL2ExpBrackets { list = { [ CQL2ExpOperation { exp1 = textSizeExp.copy(), op = plus, exp2 = CQL2ExpConstant { constant = {{ real }, r = 7 } }} ]} };
            CQL2Expression textElementsExp = CQL2ExpConstant { constant = {{ integer }, i = -1*(totalTextElements-1) } };
            *textOffsetY = CQL2ExpOperation {
                  exp1 = CQL2ExpBrackets { list = { [ CQL2ExpOperation {
                     exp1 = textElementsExp, op = multiply,
                     exp2 = sizePlusGap } ] } },
                  op = divide, exp2 = CQL2ExpConstant { constant = {{ real }, r = 2.0 } } };
            *textOffsetY = CQL2ExpBrackets { list = { [ *textOffsetY ] } };
         }

         delete textRadOffsetExp;
      }
   }

   void setupTextOffset(CQL2Expression * textOffsetX, CQL2Expression * textOffsetY, CQL2Expression textSizeExp)
   {
      // Text position offset from text-offset
      // This is not deprecated, it's a valid option, but text-radial-offset takes priority
      *textOffsetX = layout.textoffset.type.type == array && layout.textoffset.a.count > 0 &&
         (layout.textoffset.a[0].type.type != nil && layout.textoffset.a[0].type.type != 0) ?
         CQL2ExpOperation {
            exp1 = convertMBGLExp(((MBGLFilterValue *)layout.textoffset.a)[0], false, false, none),
            op = multiply, exp2 = textSizeExp.copy() } : null;
      *textOffsetY = layout.textoffset.type.type == array && layout.textoffset.a.count > 1 &&
         (layout.textoffset.a[1].type.type != nil && layout.textoffset.a[1].type.type != 0) ?
         CQL2ExpOperation {
            exp1 = convertMBGLExp(((MBGLFilterValue *)layout.textoffset.a)[1], false, false, none),
            op = multiply, exp2 = textSizeExp.copy() } : null;
   }

   CQL2ExpInstance setupTextPosition(
      Alignment2D alignment, CQL2Expression hAlignExp, CQL2Expression vAlignExp, CQL2Expression textSizeExp,
      const Pointf imageHotSpot, CQL2Expression symbolExp, Map<String, Size> symbolSizes, int textElementNum, int totalTextElements)
   {
      CQL2ExpInstance positionInst = null;
      const MBGLFilterValue * radialOffset = layout.textradialoffset.type.type && layout.textradialoffset.type.type != nil ? &layout.textradialoffset : null;
      // REVIEW: How is center alignment supposed to work with radial offset and icon?
      bool useIconOffset = symbolExp && symbolSizes &&
         ((alignment.horzAlign == unset || (alignment.horzAlign != center && imageHotSpot.x != (alignment.horzAlign == left ? 1 : 0))) ||
          (alignment.vertAlign == unset || (alignment.vertAlign != middle && imageHotSpot.y != (alignment.vertAlign == top ? 1 : 0))));
      bool useTextOffset = radialOffset ? (alignment != { center, middle }) :
         (layout.textoffset.type.type != nil && layout.textoffset.type.type != 0);
      if(useIconOffset || useTextOffset)
      {
         int dirX = 0, dirY = 0; // This is the direction away from the text anchor point based on alignment
         CQL2Expression dirXExp = null, dirYExp = null;
         CQL2Expression offsetFromIconX = null, offsetFromIconY = null;
         CQL2Expression textOffsetX = null, textOffsetY = null, textElementOffset = null;

         if(useIconOffset || radialOffset)
            // We need the alignment direction if using radial offset or icon offsets
            getAlignmentDirection(alignment, hAlignExp, vAlignExp, &dirX, &dirY, &dirXExp, &dirYExp);

         if(useIconOffset)
            setupTextIconOffset(&offsetFromIconX, &offsetFromIconY,
               alignment, dirX, dirY, dirXExp, dirYExp,
               imageHotSpot, symbolExp, symbolSizes);

         if(useTextOffset)
         {
            if(radialOffset)
               setupTextRadialOffset(&textOffsetX, &textOffsetY, alignment, dirX, dirY, dirXExp, dirYExp, textSizeExp, totalTextElements);
            else
               setupTextOffset(&textOffsetX, &textOffsetY, textSizeExp);
         }
         if(textElementNum)
         {
             textElementOffset = CQL2ExpOperation { exp1 = CQL2ExpConstant { constant = { { integer }, i = 7} }, op = plus, exp2 = textSizeExp ? textSizeExp.copy() : CQL2ExpConstant { constant = { { integer }, i = 12 } }};
             textElementOffset = CQL2ExpOperation { exp1 = CQL2ExpConstant { constant = { { integer }, i = textElementNum} }, op = multiply, exp2 = CQL2ExpBrackets { list = { [ textElementOffset ] } } };
             textElementOffset = CQL2ExpBrackets { list = { [ textElementOffset ] } };
         }

         if(offsetFromIconX || offsetFromIconY || textOffsetX || textOffsetY || textElementOffset)
         {
            // Set up combined Text position2D offset from icon offset and text (radial) offset
            CQL2Expression x = offsetFromIconX && textOffsetX ?
               CQL2ExpOperation { exp1 = offsetFromIconX, op = plus, exp2 = textOffsetX } :
               offsetFromIconX ? offsetFromIconX : textOffsetX;
            CQL2Expression y = offsetFromIconY && textOffsetY ?
               CQL2ExpOperation { exp1 = offsetFromIconY, op = plus, exp2 = textOffsetY } :
               offsetFromIconY ? offsetFromIconY : textOffsetY;
            if(textElementOffset) y = y ? CQL2ExpOperation { exp1 = y, op = plus, exp2 = textElementOffset } : textElementOffset;
            positionInst = { };
            if(x) positionInst.setMember("x", 0, true, x);
            if(y) positionInst.setMember("y", 0, true, y);
         }
         delete dirXExp, delete dirYExp;
      }
      return positionInst;
   }

   #define MAX_TEXT_ELEMENTS  10
   void setupText(CQL2ExpInstance textElements[MAX_TEXT_ELEMENTS], const Pointf imageHotSpot, CQL2Expression symbolExp, Map<String, Size> symbolSizes, StylingRule stylingRule)
   {
      MBGLLayoutJSONData layout = this.layout;
      CQL2Expression textExp = layout && layout.textfield.type.type != nil && layout.textfield.type.type != 0 ?
         convertMBGLExp(layout.textfield, false, false, none) : null;
      if(textExp)
      {
         CQL2Expression transformExp = layout.texttransform.type.type != nil ?
            convertMBGLExp(layout.texttransform, false, false, none) : null;

         if(textExp._class == class(CQL2ExpConditional))
         {
            CQL2ExpOperation expOp = ((CQL2ExpConditional)textExp).condition._class == class(CQL2ExpOperation) ? (CQL2ExpOperation)((CQL2ExpConditional)textExp).condition : null;
            if(!expOp || (expOp.exp1._class == class(CQL2ExpIdentifier) && strcmp(((CQL2ExpIdentifier)expOp.exp1).identifier.string, "viz.sd")))
               setupTextForBlock(textExp, transformExp, imageHotSpot, symbolExp, symbolSizes, textElements);
            else
               setupTextRules(textExp, transformExp, imageHotSpot, symbolExp, symbolSizes, stylingRule);
         }
         else
            setupTextForBlock(textExp, transformExp, imageHotSpot, symbolExp, symbolSizes, textElements);

         delete textExp;
         delete transformExp;
      }
   }

   void setupTextRules(CQL2Expression textExp, CQL2Expression transformExp, const Pointf imageHotSpot, CQL2Expression symbolExp, Map<String, Size> symbolSizes, StylingRule stylingRule)
   {
      CQL2ExpConditional cond = textExp._class == class(CQL2ExpConditional) ? (CQL2ExpConditional)textExp : null;
      CQL2ExpInstance text[10] = { null };
      StylingRule rule = minMaxZoomNestedRule(stylingRule);
      StylingRule nr {};
      SelectorList list1 { };
      int i;
      bool isViz = false;
      addExpSelectors(list1, cond.condition.copy());
      setupTextForBlock(cond.expList.lastIterator.data, transformExp, imageHotSpot, symbolExp, symbolSizes, text);
      if(!rule.nestedRules)
      {
         rule.nestedRules = { };
         if(layout.symbolsortkey.type.type != nil && layout.symbolsortkey.type.type != 0)
         {
            CQL2Expression ssk = convertMBGLExp(layout.symbolsortkey, false, false, none);
            if(ssk) rule.setStyle(class(CartoSymbolizer), "label.priority", labelPriority, false, ssk, evaluator, class(CartoSymbolizer));
         }
      }
      nr.symbolizer = {};
      nr.selectors = list1;
      // TODO: REFACTOR else section
      for(i = 0; i < 10; i++)
         if(text[i])
         {
            nr.setStyleEx(class(CartoSymbolizer), "label.elements", labelElements, false, text[i], evaluator, class(CartoSymbolizer), CQL2TokenType::addAssign);
         }
      rule.nestedRules.Add(nr);
      if(cond.elseExp._class == class(CQL2ExpConditional))
      {
         CQL2ExpOperation expOp = ((CQL2ExpConditional)cond.elseExp).condition._class == class(CQL2ExpOperation) ? (CQL2ExpOperation)((CQL2ExpConditional)cond.elseExp).condition : null;
         if(expOp && (expOp.exp1._class == class(CQL2ExpIdentifier) && !strcmp(((CQL2ExpIdentifier)expOp.exp1).identifier.string, "viz.sd")))
            isViz = true;
         else if(expOp && (expOp.exp1._class == class(CQL2ExpMember) && !strcmp(((CQL2ExpMember)expOp.exp1).member.string, "sd")))
            isViz = true;
      }
      if(isViz)
         setupTextRules(cond.elseExp, transformExp, imageHotSpot, symbolExp, symbolSizes, stylingRule);
      else
      {
         SelectorList list2 { };
         StylingRule elseRule {};
         CQL2Expression elseCond = reverseSD(cond.condition);
         CQL2ExpInstance textElse[10] = { null };
         addExpSelectors(list2, elseCond.copy());
         setupTextForBlock(cond.elseExp, transformExp, imageHotSpot, symbolExp, symbolSizes, textElse);
         elseRule.symbolizer = {};
         elseRule.selectors = list2;
         for(i = 0; i < 10; i++)
            if(textElse[i])
            {
               elseRule.setStyleEx(class(CartoSymbolizer), "label.elements", labelElements, false, textElse[i], evaluator, class(CartoSymbolizer), CQL2TokenType::addAssign);
            }
         rule.nestedRules.Add(elseRule);
      }
   }

   void setupTextForBlock(CQL2Expression textExp, CQL2Expression transformExp, const Pointf imageHotSpot, CQL2Expression symbolExp, Map<String, Size> symbolSizes, CQL2ExpInstance textElements[MAX_TEXT_ELEMENTS])
   {
      // Split text in multiple Text elements based on \n
      CQL2Expression splitText[MAX_TEXT_ELEMENTS];
      int numParts = 0, i;
      splitTextFromNewline(textExp, splitText, &numParts, null);
      for(i = 0; i < numParts; i++)
      {
         CQL2ExpInstance textInst { instance = { _class = { name = CopyString("Text") } } };
         CQL2Expression textPart = setupTextContent(splitText[i], transformExp);
         CQL2Expression textSizeExp;
         CQL2ExpInstance fontInst = setupTextFont(&textSizeExp);
         Alignment2D alignment2D;
         CQL2Expression hAlignExp, vAlignExp;
         CQL2ExpInstance alignmentInst = setupTextAlignment(&alignment2D, &hAlignExp, &vAlignExp);
         CQL2ExpInstance positionInst = setupTextPosition(alignment2D, hAlignExp, vAlignExp,
            textSizeExp, imageHotSpot, symbolExp, symbolSizes, i, numParts);
         textInst.setMember("text", text, true, textPart);
         if(fontInst) textInst.setMember("font", font, true, fontInst);
         if(alignmentInst) textInst.setMember("alignment", alignment, true, alignmentInst);
         if(positionInst) textInst.setMember("position2D", position, true, positionInst);
         textElements[i] = textInst;
      }
   }

   CQL2Expression reverseSD(CQL2Expression e)
   {
      CQL2Expression result = null;
      if(e._class == class(CQL2ExpOperation))
      {
         CQL2ExpOperation expOp = (CQL2ExpOperation)e;
         CQL2ExpOperation expOp2 = ((CQL2ExpOperation)e).copy();
         switch(expOp.op)
         {
            case greater: expOp2.op = smallerEqual; break;
            case smaller: expOp2.op = greaterEqual; break;
         }
         result = expOp2;
      }
      return result;
   }

   void processSymbol(StylingRule stylingRule, Map<String, Size> symbolSizes)
   {
      MBGLLayoutJSONData layout = this.layout;
      // TODO: Figure out when to use Label vs. Marker (once markers are supported)
      // NOTE: fallback support for circles will use dot images for now
      bool isCircle = !strcmpi(type, "circle");
      Pointf imageHotSpot { }; // REVIEW: Possibly this could be a runtime expression as well?
      CQL2ExpInstance image = null, text[10] = { null };
      CQL2Expression symbolExp = null;

      if(isCircle || (layout && layout.iconimage.type.type != nil && layout.iconimage.type.type != 0))
         image = setupImage(isCircle, imageHotSpot, &symbolExp);
      if(!symbolExp && stylingRule.nestedRules)
      {
         // see if Image was previously added from a separate layer
         // were Text added first, the Image layer processing should also update Text...
         // NOTE: in e.g. TLM airports, Image has minzoom but Text does not
         SelectorList selectors = buildSelectors({}, 0, maxzoom);
         String selectorsString = selectors.toString(0);
         StylingRule subRule = null;
         for(e : stylingRule.nestedRules; e._class == class(StylingRule))
         {
            StylingRule each = (StylingRule)e;
            String s = each.selectors.toString(0);
            if(strstr(s, selectorsString))
            {
               subRule = each;
               delete s;
               break;
            }
            delete s;
         }
         delete selectorsString;
         delete selectors;
         if(subRule)
            symbolExp = findSymbolExpInElements(subRule, imageHotSpot);
      }
      if(layout && layout.textfield.type.type && layout.textfield.type.type != nil)
         // NOTE: The text can be positioned based on the icon
         setupText(text, imageHotSpot, symbolExp, symbolSizes, stylingRule);

      if(image || text[0])
      {
         CQL2ExpArray expArray = null;
         // nested rule for min/maxzoom
         StylingRule rule = minMaxZoomNestedRule(stylingRule);
         int i;
         CQL2ExpList findElements = labelElementsFromBlock(rule);
         CQL2ExpList elements = findElements ? findElements.copy() : { };

         if(findElements) rule.removeProperty(labelElements);
         if(!rule.symbolizer) rule.symbolizer = { };

         if(image) elements.Add(image);
         for(i = 0; i < 10; i++)
            if(text[i])
               elements.Add(text[i]);
         expArray = { elements = elements };

         setSymbolizerExp(rule.symbolizer, labelElements, expArray);
         //else
           // rule.setStyle(class(CartoSymbolizer), "label.elements", labelElements, false, array, evaluator, class(CartoSymbolizer));
         if(layout.symbolsortkey.type.type != nil && layout.symbolsortkey.type.type != 0)
         {
            CQL2Expression ssk = convertMBGLExp(layout.symbolsortkey, false, false, none);
            if(ssk) rule.setStyle(class(CartoSymbolizer), "label.priority", labelPriority, false, ssk, evaluator, class(CartoSymbolizer));
         }
      }
   }

   void processRaster(StylingRule stylingRule)
   {
      MBGLPaintJSONData paint = this.paint;
      StylingRule rule = minMaxZoomNestedRule(stylingRule);
      if(!rule.symbolizer) rule.symbolizer = { };
      // if(layout && layout.visibility)
      {
         bool visible = !layout || !layout.visibility || !strcmpi(layout.visibility, "visible");
         CQL2ExpConstant vExp { constant = { type = { integer, format = boolean }, i = visible } };
         rule.setStyle(class(CartoSymbolizer), "visibility", visibility, false, vExp, evaluator, class(CartoSymbolizer));
      }
      if(paint)
      {
         /*if(paint.rasterbrightnessmax)
         {
            CQL2ExpConstant constant { constant.r = paint.rasterbrightnessmax, constant.type = { real } };
            instance.setMember("brightness", brightness, true, constant);
         }*/
         if(paint.rasteropacity.type.type != nil && paint.rasteropacity.type.type != 0)
         {
            CQL2Expression rasterOpacity = convertMBGLExp(paint.rasteropacity, false, false, none);
            if(rasterOpacity)
            {
               // nested rule for min/maxzoom
               rule.setStyle(class(CartoSymbolizer), "opacity", opacity, false, rasterOpacity, evaluator, class(CartoSymbolizer));
            }
         }
         /*if(paint.rastersaturation)
         {
            CQL2ExpConstant constant { constant.r = paint.rastersaturation, constant.type = { real } };
            instance.setMember("saturation", saturation, true, constant);
         }*/
      }
   }

   void processHillshade(StylingRule rule)
   {
      // FIXME: This instance is not added anywhere?
      /*
      CQL2ExpInstance instance { };

      if(!rule.symbolizer) rule.symbolizer = { };
      if(layout && layout.visibility)
      {
         String viz = !strcmpi(layout.visibility, "visible") ? CopyString("true") : CopyString("false");
         instance.setMember("visibility", visibility, true, CQL2ExpIdentifier { identifier = { string = viz } } );
      }
      */
   }

   StylingRule minMaxZoomNestedRule(StylingRule stylingRule)
   {
      StylingRule subRule = null;
      if(minzoom || maxzoom)
      {
         SelectorList selectors = buildSelectors({}, minzoom, maxzoom);
         String selectorsString = selectors.toString(0);
         if(!stylingRule.nestedRules) stylingRule.nestedRules = {};
         for(e : stylingRule.nestedRules; e._class == class(StylingRule))
         {
            StylingRule each = (StylingRule)e;
            String s = each.selectors.toString(0);
            // this should take care of merging fill/line with identical selectors
            if(!strcmp(s, selectorsString))
            {
               subRule = each;
               delete selectors;
               delete s;
               break;
            }
            delete s;
         }
         if(!subRule)
         {
            subRule = { };
            subRule.symbolizer = {};
            subRule.selectors = selectors;
            stylingRule.nestedRules.Add(subRule);
         }
         delete selectorsString;
      }
      else
         subRule = stylingRule;
      return subRule;
   }

public:
   String id;
   String source;
   String sourcelayer;
   String type;
   property double minzoom
   {
      set { minzoom = value; }
      get { return this ? minzoom : 0; }
      isset { return minzoom ? true : false; } // false?
   };

   property double maxzoom
   {
      set { maxzoom = value; }
      get { return this ? maxzoom : 0; }
      isset { return maxzoom ? true : false; } // false?
   };
   property MBGLFilterValue filter
   {
      set { filter = value; }
      get { value = filter; }
      isset { return filter.type.type != nil && filter.type.type != 0; } // false?
   };

   property FieldValue metadata
   {
      // TODO:
      set { }
      get { value = { }; /*return null;*/ }
      isset { return false; }
   };

   MBGLLayoutJSONData layout;
   MBGLPaintJSONData paint;

   MBGLLayersJSONData copy()
   {
      if(this)
      {
         MBGLLayersJSONData layer
         {
            id = CopyString(id),
            source = CopyString(source),
            sourcelayer = CopyString(sourcelayer),
            paint = paint,
            filter = filter,
            minzoom = minzoom,
            maxzoom = maxzoom
         };
         return layer;
      }
      return null;
   }
}

public class MBGLLayoutJSONData : struct
{
   // move members to private, add isset property
public:
   property MBGLFilterValue /*double*/ iconsize
   {
      set { iconsize = value; }
      get { value = iconsize; }
      isset { return iconsize.type.type != nil && iconsize.type.type != 0; } // false?
   };
   property MBGLFilterValue /*String*/ iconimage
   {
      set { iconimage = value; }
      get { value = iconimage; }
      isset { return iconimage.type.type != nil && iconimage.type.type != 0; }
   };
   property MBGLFilterValue iconoffset
   {
      set { iconoffset = value; }
      get { value = iconoffset; }
      isset { return iconoffset.type.type != nil && iconoffset.type.type != 0; }
   };
   property MBGLFilterValue iconanchor
   {
      set { iconanchor = value; }
      get { value = iconanchor; }
      isset { return iconanchor.type.type != nil && iconanchor.type.type != 0; } // false?
   };
   property MBGLFilterValue iconallowoverlap
   {
      // TODO:
      set { }
      get { value = { }; }
      isset { return false; }
   };
   property MBGLFilterValue textfield
   {
      set { textfield = value; }
      get { value = textfield; }
      isset { return textfield.type.type != nil && textfield.type.type != 0; }
   };
   property MBGLFilterValue linejoin // spec says ver >= 0.4 supports data-driven-styling
   {
      set { linejoin = value; }
      get { value = linejoin; }
      isset { return linejoin.type.type != nil && linejoin.type.type != 0; } // false?
   };
   property MBGLFilterValue linecap // spec says ver >= 2.3 supports data-driven-styling
   {
      set { linecap = value; }
      get { value = linecap; }
      isset { return linecap.type.type != nil && linecap.type.type != 0; } // false?
   };
   property MBGLFilterValue textsize
   {
      set { textsize = value; }
      get { value = textsize; }
      isset { return textsize.type.type != nil && textsize.type.type != 0; }
   };
   property MBGLFilterValue textmaxwidth
   {
      // TODO:
      set { }
      get { value = { }; }
      isset { return false; }
   };
   property MBGLFilterValue textoptional
   {
      // TODO:
      set { }
      get { value = { }; }
      isset { return false; }
   };
   property MBGLFilterValue textallowoverlap
   {
      // TODO:
      set { }
      get { value = { }; }
      isset { return false; }
   };
   property MBGLFilterValue textfont
   {
      set { textfont.OnFree(); textfont = value; }
      get { value = textfont; }
      isset { return textfont.type.type != nil && textfont.type.type != 0; }
   };
   property MBGLFilterValue textjustify
   {
      set { textjustify = value; }
      get { value = textjustify; }
      isset { return textjustify.type.type != nil && textjustify.type.type != 0; }
   };
   property MBGLFilterValue textoffset
   {
      set { textoffset = value; }
      get { value = textoffset; }
      isset { return textoffset.type.type != nil && textoffset.type.type != 0; }
   };
   // string vs enum? https://github.com/mapbox/mapbox-gl-js/issues/5577
   property MBGLFilterValue textanchor
   {
      set { textanchor = value; }
      get { value = textanchor; }
      isset { return textanchor.type.type != nil && textanchor.type.type != 0; }
   };
   // NOTE: textanchor seems deprecated...
   property MBGLFilterValue textvariableanchor
   {
      set { textvariableanchor = value; }
      get { value = textvariableanchor; }
      isset { return textvariableanchor.type.type != nil && textvariableanchor.type.type != 0; } // false?
   };

   // NOTE: These are supposed to go in 'paint'
   property MBGLFilterValue /*String*/ textcolor
   {
      set { textcolor = value; }
      get { value = textcolor; }
      isset { return textcolor.type.type != nil && textcolor.type.type != 0; } // false?
   };
   property MBGLFilterValue /*double*/ texthalowidth
   {
      set { texthalowidth = value;}
      get { value = texthalowidth; }
      isset { return texthalowidth.type.type != nil && texthalowidth.type.type != 0; }
   };
   property MBGLFilterValue texthalocolor
   {
      set { texthalocolor = value; }
      get { value = texthalocolor; }
      isset { return texthalocolor.type.type != nil && texthalocolor.type.type != 0; }
   };
   property double texthaloblur
   {
      set { texthaloblur = value; }
      get { return this ? texthaloblur : 0; }
      isset { return texthaloblur ? true : false; } // false?
   };
   property String visibility
   {
      set { delete visibility; if(value) visibility = CopyString(value); }
      get { return this ? visibility : null; }
      isset { return visibility != null; }
   };

   property MBGLFilterValue textmaxangle
   {
      // TODO:
      set { }
      get { value = { }; }
      isset { return false; }
   }

   property MBGLFilterValue texttransform //strlwr and strupr
   {
      set { texttransform = value;}
      get { value = texttransform; }
      isset { return texttransform.type.type != nil && texttransform.type.type != 0; }
   }

   property MBGLFilterValue textrotationalignment
   {
      // TODO:
      set { }
      get { value = { }; }
      isset { return false; }
   }

   property MBGLFilterValue textletterspacing
   {
      // TODO:
      set { }
      get { value = { }; }
      isset { return false; }
   }

   property MBGLFilterValue symbolsortkey
   {
      set { symbolsortkey = value;}
      get { value = symbolsortkey; }
      isset { return symbolsortkey.type.type != nil && symbolsortkey.type.type != 0; }
   }

   property MBGLFilterValue textradialoffset
   {
      set { textradialoffset = value; }
      get { value = textradialoffset; }
      isset { return textradialoffset.type.type != nil && textradialoffset.type.type != 0; } // false?
   }

   property MBGLFilterValue icontextfit
   {
      // TODO:
      set { }
      get { value = { }; /*return null;*/ }
      isset { return false; }
   }

   property MBGLFilterValue icontextfitpadding
   {
      // TODO:
      set { }
      get { value = { }; /*return null;*/ }
      isset { return false; }
   }

   property MBGLFilterValue iconrotate
   {
      // TODO:
      set { }
      get { value = { }; /*return null;*/ }
      isset { return false; }
   }

   property MBGLFilterValue iconrotationalignment
   {
      // TODO:
      set { }
      get { value = { }; /*return null;*/ }
      isset { return false; }
   }

   property MBGLFilterValue iconpitchalignment
   {
      // TODO:
      set { }
      get { value = { }; /*return null;*/ }
      isset { return false; }
   };

   property MBGLFilterValue iconignoreplacement
   {
      // TODO:
      set { }
      get { value = { }; /*return null;*/ }
      isset { return false; }
   }

   property MBGLFilterValue symbolspacing
   {
      // TODO:
      set { }
      get { value = { }; /*return null;*/ }
      isset { return false; }
   }

   property MBGLFilterValue symbolplacement
   {
      // TODO:
      set { }
      get { value = { }; /*return null;*/ }
      isset { return false; }
   };

   property MBGLFilterValue symbolavoidedges
   {
      // TODO:
      set { }
      get { value = { }; /*return null;*/ }
      isset { return false; }
   };

   property MBGLFilterValue fillsortkey
   {
      set { fillsortkey = value; }
      get { value = fillsortkey; }
      isset { return fillsortkey.type.type != nil && fillsortkey.type.type != 0; } // false?
   };

   property MBGLFilterValue linesortkey
   {
      set { linesortkey = value; }
      get { value = linesortkey; }
      isset { return linesortkey.type.type != nil && linesortkey.type.type != 0; } // false?
   };

   property MBGLFilterValue textpitchalignment
   {
      isset { return textpitchalignment.type.type != nil && textpitchalignment.type.type != 0; }
   }

   property MBGLFilterValue textpadding
   {
      set { textpadding = value; }
      get { value = textpadding; }
      isset { return textpadding.type.type != nil && textpadding.type.type != 0; }
   };

   property MBGLFilterValue textrotate
   {
      set { textrotate = value; }
      get { value = textrotate; }
      isset { return textrotate.type.type != nil && textrotate.type.type != 0; }
   };

private:

   ~MBGLLayoutJSONData()
   {
      iconimage.OnFree();
      iconanchor.OnFree();
      iconoffset.OnFree();
      textfield.OnFree();
      textfont.OnFree();
      textsize.OnFree();
      textjustify.OnFree();
      textoffset.OnFree();
      textanchor.OnFree();
      textvariableanchor.OnFree();
      textrotationalignment.OnFree();
      linejoin.OnFree();
      textcolor.OnFree();
      texthalocolor.OnFree();
      texthalowidth.OnFree();
      texttransform.OnFree();
      delete visibility;
      fillsortkey.OnFree();
      linesortkey.OnFree();
      linecap.OnFree();
      symbolsortkey.OnFree();
      textradialoffset.OnFree();
      textpitchalignment.OnFree();
      textpadding.OnFree();
      textrotate.OnFree();
   }

   MBGLLayoutJSONData copy()
   {
      if(this)
      {
         // FIXME: If we really need this copy(), these are not copying MBGLFilterValue / FieldValue properly
         MBGLLayoutJSONData layoutData
         {
            iconsize = iconsize;
            iconimage = iconimage;   // REVIEW: Doesn't property do the copy?
            iconoffset = iconoffset;
            iconanchor = iconanchor;
            textfield = textfield;
            textfont = textfont;
            textsize = textsize;
            textjustify = textjustify;
            textoffset = textoffset;
            textanchor = textanchor;
            texthalowidth = texthalowidth;
            texttransform = texttransform;
            textrotationalignment = textrotationalignment;
            textvariableanchor = textvariableanchor;
            textradialoffset = textradialoffset;
            visibility = CopyString(visibility);
            fillsortkey = fillsortkey;
            linesortkey = linesortkey;
            linecap = linecap;
            symbolsortkey = symbolsortkey;
            textpitchalignment = textpitchalignment;
         };
         return layoutData;
      }
      return null;
   }

   MBGLFilterValue iconsize;
   MBGLFilterValue iconimage;
   MBGLFilterValue iconoffset;
   MBGLFilterValue iconanchor;
   MBGLFilterValue textfield;
   MBGLFilterValue textfont;
   MBGLFilterValue textsize;
   MBGLFilterValue textoffset;
   MBGLFilterValue textjustify;
   MBGLFilterValue textanchor; //deprecated
   MBGLFilterValue texttransform;
   MBGLFilterValue textvariableanchor;
   MBGLFilterValue textradialoffset;
   MBGLFilterValue linejoin;
   MBGLFilterValue linecap;
   MBGLFilterValue fillsortkey;
   MBGLFilterValue linesortkey;
   MBGLFilterValue symbolsortkey;
   MBGLFilterValue textpitchalignment;
   MBGLFilterValue textpadding;
   MBGLFilterValue textrotate;

   // NOTE: These are supposed to go in paint
   MBGLFilterValue textcolor;
   MBGLFilterValue texthalocolor;
   MBGLFilterValue texthalowidth;
   double texthaloblur;
   String visibility;
};

public class MBGLPaintJSONData : struct
{
public:
   property MBGLFilterValue /*double */ lineopacity
   {
      set { lineopacity = value; }
      get { value = lineopacity; }
      isset { return lineopacity.type.type != nil && lineopacity.type.type != 0; } // false?
   };
   property MBGLFilterValue /*String*/ linepattern
   {
      set { linepattern = value; }
      get { value = linepattern; }
      isset { return linepattern.type.type != nil && linepattern.type.type != 0; }
   };
   property MBGLFilterValue /*String*/ linecolor
   {
      set { linecolor = value; }
      get { value = linecolor; }
      isset { return linecolor.type.type != nil && linecolor.type.type != 0; }
   };
   property MBGLFilterValue /*String*/ linedasharray
   {
      // TODO:
      set { /*delete linepattern; if(value.type.type == text) linepattern = CopyString(value.s);*/ }
      get { value = { s = this ? null /*linedasharray*/ : null }; }
      isset { return  false /*linedasharray != null*/; }
   };

   property MBGLFilterValue backgroundcolor
   {
      // TODO:
      set {  }
      get { value = { }; }
      isset { return false; }
   };

   property MBGLFilterValue circleradius
   {
      // TODO:
      set {  }
      get { value = { }; }
      isset { return false; }
   };

   property MBGLFilterValue circlecolor
   {
      set { circlecolor = value; }
      get { value = circlecolor; }
      isset { return circlecolor.type.type != nil && circlecolor.type.type != 0; }
   };
   property MBGLFilterValue circlestrokecolor
   {
      set { circlestrokecolor = value; }
      get { value = circlestrokecolor; }
      isset { return circlestrokecolor.type.type != nil && circlestrokecolor.type.type != 0; }
   };

   property MBGLFilterValue circlestrokeopacity
   {
      // TODO:
      set {  }
      get { value = { }; }
      isset { return false; }
   };

   property MBGLFilterValue circleopacity
   {
      // TODO:
      set {  }
      get { value = { }; }
      isset { return false; }
   };

   property MBGLFilterValue circlestrokewidth
   {
      // TODO:
      set {  }
      get { value = { }; }
      isset { return false; }
   };
   property MBGLFilterValue circlepitchalignment
   {
      set { circlepitchalignment = value; }
      get { value = circlepitchalignment; }
      isset { return circlepitchalignment.type.type != nil && circlepitchalignment.type.type != 0; }
   };

   property MBGLFilterValue linewidth
   {
      set { linewidth = value; }
      get { value = linewidth; }
      isset { return linewidth.type.type != nil && linewidth.type.type != 0; }
   };
   property MBGLFilterValue linegapwidth //casing
   {
      set { linegapwidth = value; }
      get { value = linegapwidth; }
      isset { return linegapwidth.type.type != nil && linegapwidth.type.type != 0; }
   };
   property MBGLFilterValue /*String*/ fillcolor
   {
      set { fillcolor = value; }
      get { value = fillcolor; }
      isset { return fillcolor.type.type != nil && fillcolor.type.type != 0; }
   };
   property MBGLFilterValue /*String */ filloutlinecolor
   {
      set { filloutlinecolor = value; }
      get { value = filloutlinecolor; }
      isset { return filloutlinecolor.type.type != nil && filloutlinecolor.type.type != 0; }
   };
   property MBGLFilterValue fillpattern
   {
      set { fillpattern = value; }
      get { value = fillpattern; }
      isset { return fillpattern.type.type != nil && fillpattern.type.type != 0; }
   };
   property MBGLFilterValue fillopacity
   {
      set { fillopacity = value; }
      get { value = fillopacity; }
      isset { return fillopacity.type.type != nil && fillopacity.type.type != 0; } // false?
   };
   property MBGLFilterValue fillantialias
   {
      set { fillantialias = value; }
      get { value = fillantialias; }
      isset { return fillantialias.type.type != nil && fillantialias.type.type != 0; } // false?
   };
   property MBGLFilterValue fillextrusioncolor
   {
      set { fillextrusioncolor = value; }
      get { value = fillextrusioncolor; }
      isset { return fillextrusioncolor.type.type != nil && fillextrusioncolor.type.type != 0; } // false?
   };
   property MBGLFilterValue fillextrusionheight
   {
      set { fillextrusionheight = value; }
      get { value = fillextrusionheight; }
      isset { return fillextrusionheight.type.type != nil && fillextrusionheight.type.type != 0; } // false?
   };
   property MBGLFilterValue fillextrusionopacity
   {
      set { fillextrusionopacity = value; }
      get { value = fillextrusionopacity; }
      isset { return fillextrusionopacity.type.type != nil && fillextrusionopacity.type.type != 0; } // false?
   };
   property MBGLFilterValue iconopacity
   {
      set { iconopacity = value; }
      get { value = iconopacity; }
      isset { return iconopacity.type.type != nil && iconopacity.type.type != 0; }
   };
   property MBGLFilterValue /*String*/ textcolor
   {
      set { textcolor = value; }
      get { value = textcolor; }
      isset { return textcolor.type.type != nil && textcolor.type.type != 0; }
   };
   property MBGLFilterValue texthalocolor
   {
      set { texthalocolor = value; }
      get { value = texthalocolor; }
      isset { return texthalocolor.type.type != nil && texthalocolor.type.type != 0; }
   };
   property MBGLFilterValue texthalowidth
   {
      set { texthalowidth = value;}
      get { value = texthalowidth; }
      isset { return texthalowidth.type.type != nil && texthalowidth.type.type != 0; } // false?
   };
   property MBGLFilterValue textopacity
   {
      set { textopacity = value;}
      get { value = textopacity; }
      isset { return textopacity.type.type != nil && textopacity.type.type != 0; }
   };

   property double texthaloblur
   {
      set { texthaloblur = value; }
      get { return this ? texthaloblur : 0; }
      isset { return texthaloblur ? true : false; } // false?
   };
   property Array<double> texttranslate
   {
      set { delete texttranslate; if(value) texttranslate = { copySrc = value }; }
      get { return texttranslate; }
      isset { return texttranslate != null; }
   };
   property MBGLFilterValue /*double*/ rasteropacity
   {
      set { rasteropacity = value; }
      get { value = rasteropacity; }
      isset { return rasteropacity.type.type != nil && rasteropacity.type.type != 0; } // false?
   };
   property Degrees rasterhuerotate
   {
      set { rasterhuerotate = value; }
      get { return this ? rasterhuerotate : 0; }
      isset { return rasterhuerotate ? true : false; } // false?
   };
   property double rasterbrightnessmin
   {
      set { rasterbrightnessmin = value; }
      get { return this ? rasterbrightnessmin : 0; }
      isset { return rasterbrightnessmin ? true : false; } // false?
   };
   property double rasterbrightnessmax
   {
      set { rasterbrightnessmax = value; }
      get { return this ? rasterbrightnessmax : 0; }
      isset { return rasterbrightnessmax ? true : false; } // false?
   };
   property double rastersaturation
   {
      set { rastersaturation = value; }
      get { return this ? rastersaturation : 0; }
      isset { return rastersaturation ? true : false; } // false?
   };
   property double rasterfadeduration
   {
      set { rasterfadeduration = value; }
      get { return this ? rasterfadeduration : 0; }
      isset { return rasterfadeduration ? true : false; } // false?
   };

   //double rasterresampling;
   property int hillshadeilluminationdirection
   {
      set { hillshadeilluminationdirection = value; }
      get { return this ? hillshadeilluminationdirection : 0; }
      isset { return hillshadeilluminationdirection ? true : false; } // false?
   };
   property String hillshadeilluminationanchor
   {
      set { delete hillshadeilluminationanchor; if(value) hillshadeilluminationanchor = CopyString(value); }
      get { return this ? hillshadeilluminationanchor : null; }
      isset { return hillshadeilluminationanchor != null; } // false?
   };
   property double hillshadeexaggeration
   {
      set { hillshadeexaggeration = value; }
      get { return this ? hillshadeexaggeration : 0; }
      isset { return hillshadeexaggeration ? true : false; } // false?
   };
   property String hillshadeshadowcolor
   {
      set { delete hillshadeshadowcolor; if(value) hillshadeshadowcolor = CopyString(value); }
      get { return this ? hillshadeshadowcolor : null; }
      isset { return hillshadeshadowcolor != null; }
   };
   property String hillshadehighlightcolor
   {
      set { delete hillshadehighlightcolor; if(value) hillshadehighlightcolor = CopyString(value); }
      get { return this ? hillshadehighlightcolor : null; }
      isset { return hillshadehighlightcolor != null; }
   };
   property String hillshadeaccentcolor
   {
      set { delete hillshadeaccentcolor; if(value) hillshadeaccentcolor = CopyString(value); }
      get { return this ? hillshadeaccentcolor : null; }
      isset { return hillshadeaccentcolor != null; }
   };
   property MBGLFilterValue rastercontrast
   {
      isset { return rastercontrast.type.type != nil && rastercontrast.type.type != 0; }
   }
   property MBGLFilterValue fillextrusionverticalgradient
   {
      isset { return fillextrusionverticalgradient.type.type != nil && fillextrusionverticalgradient.type.type != 0; }
   }

   // TODO: New properties used in light base map
   property MBGLFilterValue lineblur
   {
      set { lineblur = value; }
      get { value = lineblur; }
      isset { return lineblur.type.type != nil && lineblur.type.type != 0; }
   }

   property MBGLFilterValue lineoffset
   {
      set { lineoffset = value; }
      get { value = lineoffset; }
      isset { return lineoffset.type.type != nil && lineoffset.type.type != 0; }
   }

   property MBGLFilterValue filltranslateanchor
   {
      set { filltranslateanchor = value; }
      get { value = filltranslateanchor; }
      isset { return filltranslateanchor.type.type != nil && filltranslateanchor.type.type != 0; }
   }

private:

   ~MBGLPaintJSONData()
   {
      linewidth.OnFree();
      lineopacity.OnFree();
      linegapwidth.OnFree();
      linepattern.OnFree();
      linecolor.OnFree(); //need to remove quotes
      fillcolor.OnFree();
      filloutlinecolor.OnFree();
      fillopacity.OnFree();
      fillantialias.OnFree();
      fillextrusioncolor.OnFree();
      fillextrusionheight.OnFree();
      fillextrusionopacity.OnFree();
      fillpattern.OnFree();;
      textcolor.OnFree();
      texthalocolor.OnFree();
      textopacity.OnFree();
      delete texttranslate;
      delete hillshadeilluminationanchor;
      delete hillshadeshadowcolor;
      delete hillshadehighlightcolor;
      delete hillshadeaccentcolor;
      circlepitchalignment.OnFree();
      circlecolor.OnFree();
      circlestrokecolor.OnFree();
      rastercontrast.OnFree();
      fillextrusionverticalgradient.OnFree();
      iconopacity.OnFree();
      lineblur.OnFree();
      filltranslateanchor.OnFree();
      lineoffset.OnFree();
   }

   MBGLPaintJSONData copy()
   {
      if(this)
      {
         // FIXME: If we really this copy(), this is not properly copying FieldValue / MBGLFilterValue properly
         MBGLPaintJSONData paintData
         {
            lineopacity = lineopacity;
            linewidth = linewidth;
            linepattern = linepattern;
            linecolor = linecolor;
            fillcolor = fillcolor;
            fillpattern = fillpattern;
            fillopacity = fillopacity;
            filloutlinecolor = filloutlinecolor;
            fillantialias = fillantialias;
            fillextrusioncolor = fillextrusioncolor;
            fillextrusionheight = fillextrusionheight;
            fillextrusionopacity = fillextrusionopacity;
            iconopacity = iconopacity;
            textcolor = textcolor;
            texthalocolor = texthalocolor;
            texthalowidth = texthalowidth;
            texthaloblur = texthaloblur;
            texttranslate = texttranslate;
            rasteropacity = rasteropacity;
            rasterhuerotate = rasterhuerotate;
            rasterbrightnessmin = rasterbrightnessmin;
            rasterbrightnessmax = rasterbrightnessmax;
            rastersaturation = rastersaturation;
   //double rasterresampling;
            rasterfadeduration = rasterfadeduration;

            hillshadeilluminationdirection = hillshadeilluminationdirection;
            hillshadeilluminationanchor = hillshadeilluminationanchor;
            hillshadeexaggeration = hillshadeexaggeration;
            hillshadeshadowcolor = hillshadeshadowcolor;
            hillshadehighlightcolor = hillshadehighlightcolor;
            hillshadeaccentcolor = hillshadeaccentcolor;
            circlepitchalignment = circlepitchalignment;
            circlecolor = circlecolor;
            circlestrokecolor = circlestrokecolor;
            rastercontrast = rastercontrast;
            fillextrusionverticalgradient = fillextrusionverticalgradient;
         };
         return paintData;
      }
      return null;
   }

   MBGLFilterValue lineopacity;
   MBGLFilterValue linewidth; // TOCHECK: Should everything be an expression?
   MBGLFilterValue linegapwidth;
   MBGLFilterValue linepattern;
   MBGLFilterValue linecolor; //need to remove quotes
   MBGLFilterValue fillcolor;
   MBGLFilterValue filloutlinecolor;
   MBGLFilterValue fillpattern;
   MBGLFilterValue fillopacity;
   MBGLFilterValue fillantialias;
   MBGLFilterValue fillextrusioncolor;
   MBGLFilterValue fillextrusionheight;
   MBGLFilterValue fillextrusionopacity;
   MBGLFilterValue iconopacity;
   MBGLFilterValue textcolor;
   MBGLFilterValue texthalocolor;
   MBGLFilterValue texthalowidth;
   MBGLFilterValue textopacity;
   double texthaloblur;
   Array<double> texttranslate;
   MBGLFilterValue rasteropacity;
   Degrees rasterhuerotate;
   double rasterbrightnessmin;
   double rasterbrightnessmax;
   double rastersaturation;
   //double rasterresampling;
   double rasterfadeduration;
   int hillshadeilluminationdirection;
   String hillshadeilluminationanchor;
   double hillshadeexaggeration;
   String hillshadeshadowcolor;
   String hillshadehighlightcolor;
   String hillshadeaccentcolor;
   MBGLFilterValue circlepitchalignment;
   MBGLFilterValue circlecolor;
   MBGLFilterValue circlestrokecolor;
   MBGLFilterValue rastercontrast;
   MBGLFilterValue fillextrusionverticalgradient;
   MBGLFilterValue lineblur;
   MBGLFilterValue lineoffset;
   MBGLFilterValue filltranslateanchor;
};

static CartoSymEvaluator evaluator { class(CartoSymEvaluator) };

 //getColorAlpha function may eventually find it's way to another module

//json.ec needs to account for those segments with unnamed containers
//this also applies to styling

#if 0  // REVIEW: dependency on gfx's Bitmap
/*static */Bitmap downloadBitmapData(const String url, MemoryFileCache cache, GeoDataOutputType format)
{
   Bitmap result = null;
   File f;
   cache.mutex.Wait();
   f = FileOpen(url, read); // TODO: Use new NetworkThread mechanisms
   if(f)
   {
      result = readBitmapDataFromFile(f, format, pixelFormat888);
      delete f;
   }
   cache.mutex.Release();
   return result;
}
#endif

public Map<String, MBGLSpriteSymbol> loadMapboxSpriteSymbolInfo(File f)
{
   Map<String, MBGLSpriteSymbol> spriteSymbols = null;
   if(f)
   {
      JSONParser spriteParser { f = f };
      if(spriteParser.GetObject(class(Map<String, MBGLSpriteSymbol>), &spriteSymbols) != success)
         delete spriteSymbols;
      delete spriteParser;
   }
   return spriteSymbols;
}

public Map<String, Size> loadMapboxSpriteSizes(File f)
{
   Map<String, Size> sizes = null;
   Map<String, MBGLSpriteSymbol> symbols = f? loadMapboxSpriteSymbolInfo(f) : null;
   if(symbols)
   {
      sizes = { };
      for(s : symbols)
      {
         const String symbol = &s;
         MBGLSpriteSymbol value = s;
         sizes[symbol] = { value.width, value.height };
      }
      symbols.Free(), delete symbols;
   }
   return sizes;
}

public CartoStyle loadMapboxgl(File f, bool useSprite, Map<String, Size> spriteSymbols)
{
   CartoStyle sheet = null;
   evaluator.setFeatureID(-1);
   if(f)
   {
      StyleBlockList rules { };//Array<StylingRule> rules { };
      JSONParser parser { f = f }; //, true };
      MapboxGLJSONData mb;
      JSONResult jsonResult = parser.GetObject(class(MapboxGLJSONData), &mb);

      if(jsonResult != success)
         PrintLn("WARNING: Parsing MBGL style returned ", jsonResult);
      if(mb)
      {
         // int curZOrder = 10; // Start with an arbitrary z order at 10 for now...
         // Bitmap bitmapSrc = null;
         // REVIEW: MemoryFileCache cache { };
         // TOCHECK keep old logic?
         /*if(useSprite == true)
         {
            useSprite = (mb.sprite && spriteData);
            if(mb.sprite)
            {
               File spriteFile = FileOpen(mb.sprite, read);
               if(spriteFile)
               {
                  String spritePng = PrintString(mb.sprite, ".png"); //sharing the same name
                  bitmapSrc = downloadBitmapData(spritePng, cache, none);

                  delete spritePng;
                  delete spriteParser;
                  delete spriteFile;
               }
            }
         }*/

         // Make all layers invisible by default
         SymbolizerProperties globalSymProperties { };
         StylingRule globalRule { symbolizer = globalSymProperties };

         setSymbolizerVal(globalSymProperties, visibility, { { integer, format = boolean }, i = bool::false }, class(bool) );
         setSymbolizerVal(globalSymProperties, strokeOpacity, { { real }, r = 0 }, class(double) );  // Make stroke opacity 0 as well since it's not set for fill-only symbolizer
         setSymbolizerVal(globalSymProperties, fillOpacity, { { real }, r = 0 }, class(double) );  // Make fill opacity 0 as well since it's not set for stroke-only symbolizer
         rules.Add(globalRule);

         if(mb.layers)
         {
            for(layer : mb.layers)
            {
               const String title = layer.sourcelayer ? layer.sourcelayer : layer.source; // FIXME:
               StylingRule rule = setupStylingRule(layer, title, rules);
               layer.process(rule, useSprite, spriteSymbols);
            }

            // If we do not have an else filter, this layer is not visible unless it matches a nested rule
            for(r : rules; r._class == class(StylingRule))
            {
               StylingRule rTop = (StylingRule)r;
               // TODO: Recognize exclusion filter / else filter
               if(rTop.nestedRules && !getRuleBlockInitExp(rTop, label))
               {
                  // Add visibility = false to rTop rule block
                  setSymbolizerVal(rTop.symbolizer, visibility, { { integer }, i = bool::false }, class(bool));

                  for(nr : rTop.nestedRules; nr._class == class(StylingRule))
                  {
                     StylingRule nRule = (StylingRule)nr;
                     //bool strokeOp = false;
                     //bool fillOp = false;
                     if(!nRule.symbolizer)
                     {
                        // REVIEW: Should this logic handle deeper promotion?
                        // promote if all selectors same
                        if(nRule.nestedRules && nRule.nestedRules.GetCount() == 1)
                        {
                           StylingRule nestedRule = (StylingRule) nRule.nestedRules[0]; // REVIEW: Cast here
                           // REVIEW: Adding the selectors at the head of the list to maintain previous outputs (change this?)
                           //for(s : nestedRule.selectors)
                              //nRule.selectors.Add(s.copy());

                           Iterator<StylingRuleSelector> it { nestedRule.selectors };
                           StyleBlockList snr = null;
                           while(it.Prev())
                           {
                              StylingRuleSelector s = it.data;
                              nRule.selectors.Insert(null, s.copy());
                           }
                           nRule.symbolizer = nestedRule.symbolizer.copy();
                           if(nestedRule.nestedRules && nestedRule.nestedRules.GetCount())
                              snr = nestedRule.nestedRules.copy();
                           nRule.nestedRules.Free();
                           delete nRule.nestedRules;
                           if(snr) nRule.nestedRules = snr;
                           /*for(sub : nRule.nestedRules)
                              if(sub.symbolizer)
                              {
                                 if(sub.symbolizer.getProperty(ShapeSymbolizerKind::stroke))
                                    strokeOp = true;
                                 if(sub.symbolizer.getProperty(ShapeSymbolizerKind::fill))
                                    fillOp = true;
                              }*/
                           setSymbolizerVal(nRule.symbolizer, visibility, { { integer }, i = bool::true }, class(bool));
                        }
                        else if(nRule.nestedRules)
                        {
                           for(s : nRule.nestedRules; s._class == class(StylingRule))
                           {
                              StylingRule sub = (StylingRule)s;
                              if(sub.symbolizer)
                                 setSymbolizerVal(sub.symbolizer, visibility, { { integer }, i = bool::true }, class(bool));
                           }
                        }
                        else
                        {
                           nRule.symbolizer = {};
                           setSymbolizerVal(nRule.symbolizer, visibility, { { integer }, i = bool::true }, class(bool));
                        }
                     }
                     else  // Add visibility = true to rTop's nested rules
                        setSymbolizerVal(nRule.symbolizer, visibility, { { integer }, i = bool::true }, class(bool));
                     /*
                     if(nRule.symbolizer.getProperty(ShapeSymbolizerKind::stroke))
                        strokeOp = true;
                     if(nRule.symbolizer.getProperty(ShapeSymbolizerKind::fill))
                        fillOp = true;
                     if(strokeOp)
                        rTop.setStyle(class(CartoSymbolizer), "stroke.opacity", strokeOpacity, false, CQL2ExpConstant { constant = { r = 0.0, type = { real } } }, evaluator, class(CartoSymbolizer));
                     if(fillOp)
                        rTop.setStyle(class(CartoSymbolizer), "fill.opacity", fillOpacity, false, CQL2ExpConstant { constant = { r = 0.0, type = { real } } }, evaluator, class(CartoSymbolizer));
                     */
                  }
               }
               else if(!rTop.symbolizer || !(rTop.symbolizer.mask & CartoSymbolizerMask { visibility = true }) )
                  // Turn visibility back on for this layer rule
                  setSymbolizerVal(rTop.symbolizer, visibility, { { integer }, i = bool::true }, class(bool));
            }
            // TODO: Review if bitmapSrc should be freed?
            sheet = { list = rules };
         }
         // REVIEW: delete cache;
         delete mb;
         //delete spriteData;
      }
      delete parser;
   }
   return sheet;
}

static StylingRule setupStylingRule(MBGLLayersJSONData layer, const String title, StyleBlockList rules)
{
   StylingRule rule = null;
   StylingRule layerIDRule = null;
   SelectorList selectors = null;
   int zOrder = 1;

   if(title)
   {
      for(r : rules; r._class == class(StylingRule))
      {
         StylingRule rb = (StylingRule)r;
         if(rb.id && rb.id.string && !rb.selectors)
         {
            if(title && !strcmp(title, rb.id.string))
            {
               layerIDRule = rb;
               break;
            }
            zOrder++;
         }
      }
   }
   if(title && !layerIDRule)
   {
      layerIDRule = { id = title ? { string = CopyString(title) } : null, symbolizer = { } };
      layerIDRule.symbolizer.changeProperty(CartoSymbolizerKind::zOrder, { type = { integer }, i = zOrder }, class(GraphicalSymbolizer), evaluator, false, null);
      rules.Add(layerIDRule);
   }

   if(layer.filter.type.type || layer.minzoom || layer.maxzoom)
   {
      selectors = buildSelectors(layer.filter, 0, 0);

      if(layerIDRule)
      {
         if(selectors)
         {
            String selectorsString = selectors.toString(0);

            if(!layerIDRule.nestedRules)
               layerIDRule.nestedRules = { };

            for(e : layerIDRule.nestedRules; e._class == class(StylingRule))
            {
               StylingRule each = (StylingRule)e;
               String s = each.selectors.toString(0);
               // this should take care of merging fill/line with identical selectors
               if(!strcmp(s, selectorsString))
               {
                  rule = each;
                  delete selectors;
                  delete s;
                  break;
               }
               delete s;
            }
            if(!rule)
            {
               rule = { };
               layerIDRule.nestedRules.Add(rule);
               rule.selectors = selectors;
            }
            delete selectorsString;
         }
         else
            rule = layerIDRule;
      }
   }
   else
      rule = layerIDRule;

   return rule;
}
/* TODO: Implement?
static bool matchSelectors(CQL2Expression e1, CQL2Expression e2)
{
   bool match = false;
   if(e1._class == e2._class)
   {
      //compute?
   }
   return match;
}
*/
// setInstanceMemberFromMask(CQL2ExpInstance inst, CQL2Expression valueExpression, SymbolizerMask mask)

static bool filterHasGet(MBGLFilterValue filter)
{
   bool result = false;

   if(filter.type.type)
   {
      Array<MBGLFilterValue> params = filter.type.type == array ? (Array<MBGLFilterValue>)filter.a : null;  // FIXME: Should use 'array'
      String op = params && params.count && params[0].type.type == text ? params[0].s : null;
      int i;
      if(op && params.count > 1)
      {
         if(!strcmpi(op, "get") || !strcmpi(op, "has")) // get retrieves a property value and returns null if missing, while has tests presence
            result = true;
      }
      if(!result)
      {
         for(i = 0; i < (params ? params.count : 0); i++)
         {
            result = filterHasGet(params[i]);
            if(result)
               break;
         }
      }
   }
   return result;
}

static SelectorList buildSelectors(MBGLFilterValue filter, double minZoom, double maxZoom)
{
   SelectorList list = null;
   bool implyKey = !filterHasGet(filter);
   CQL2Expression e = filter.type.type ? convertMBGLExp(filter, false, implyKey, none) : null;

   if(minZoom || maxZoom)
   {
      //subtract 2 from GMC for gnosis level
      int minGGG = minZoom > 1 ? (int)minZoom-2 : 0;
      int maxGGG = maxZoom > 1 ? (int)maxZoom-2 : 0;
      if(!list) list = { };
      // NOTE: Assuming no level gives smaller scale than 1:1 (max GMC level 29)
      if(minGGG)
      {
         double scale = scaleDenominatorFromLevel(minGGG);
         __attribute__((unused)) bool isDenum = roundScale(&scale);
         CQL2ExpOperation temp { exp1 = newCSScaleExp(), op = smallerEqual, exp2 = CQL2ExpConstant { constant = { { integer }, i = (int64)scale } } };
         list.Add(StylingRuleSelector { exp = temp });
      }
      if(maxGGG)
      {
         double scale = scaleDenominatorFromLevel(maxGGG);
         __attribute__((unused)) bool isDenum = roundScale(&scale);
         CQL2ExpOperation temp { exp1 = newCSScaleExp(), op = greaterEqual, exp2 = CQL2ExpConstant { constant = { { integer }, i = (int64)scale } } };
         list.Add(StylingRuleSelector { exp = temp });
      }
   }

   if(e)
   {
      if(!list) list = {};
      addExpSelectors(list, e);
   }
   return list;
}

static CQL2Expression convertOpExp(const String op, Array<MBGLFilterValue> params, bool implyKey, ColorParseMode colorMode)
{
   CQL2Expression result = null;

   if((!strcmpi(op, "get") || !strcmpi(op, "has") || !strcmpi(op, "!has")) && params[1].type.type == text) // NOTE: "!has" is deprecated but used in RBT json files https://docs.mapbox.com/style-spec/reference/other/#other-filter
   {
      CQL2ExpIdentifier id { identifier = CQL2Identifier { string = CopyString(params[1].s) } };
      if(!strcmpi(op, "!has") || !strcmpi(op, "has"))
         result = CQL2ExpOperation { exp1 = id, op = !strcmpi(op, "!has") ? equal : notEqual, exp2 = CQL2ExpIdentifier { identifier = { string = CopyString("null") } } };
      else
         result = id;
   }
   else if(!strcmpi(op, "match"))
      result = convertMatchExp(params, implyKey, colorMode);
   else if(!strcmpi(op, "step"))
      result = convertStepExp(params, implyKey, colorMode);
   else if(!strcmpi(op, "stops"))
      result = convertStopsExp(params, colorMode);
   else if(!strcmpi(op, "interpolate"))
      result = convertInterpolateExp(params, implyKey, colorMode);
   else if(!strcmpi(op, "case")) // selects first true condition, else fallbackvalue
      //TOFIX: evaluate this properly with conditional statement, for now try fallback value
      result = getConditionalExpression(params, 1, params.count-1, null, colorMode, false);
      //result = convertMBGLExp(params[params.count-1], false, implyKey, colorMode);
   else if(!strcmpi(op, "coalesce"))
      result = convertCoalesceExp(params, implyKey, colorMode);
   else if(!strcmpi(op, "boolean"))
      result = convertBooleanExp(params, implyKey, colorMode);
   // type conversion, we handle this in our own compute
   else if(!strcmpi(op, "to-number"))
   {
      CQL2ExpCall formatExp { exp = CQL2ExpIdentifier { identifier = CQL2Identifier { string = CopyString("strtod") } }, arguments = { } };
      int i;
      // NOTE: fallback value is possible
      for(i = 1; i < params.count; i++)
      {
         CQL2Expression ne = convertMBGLExp(params[i], false, implyKey, colorMode);
         if(ne)
            formatExp.arguments.Add(ne);
      }
      result = formatExp;
   }
   else if(!strcmpi(op, "to-boolean") || !strcmpi(op, "to-string") || !strcmpi(op, "to-color"))
      result = convertMBGLExp(params[1], false, implyKey, colorMode);
   // this is just an array -- REVIEW: Is "literal" only used to disambiguate arrays from expressions?
   // Can it be used for anything other than array? e.g, "literal", 123  or  "literal", "text" ?
   else if(!strcmpi(op, "literal"))
      // FIXME: This should go in special block handling literals, not in this general function
      //       without loses the context that this was indicated to be a literal
      result = convertMBGLExp(params[1], false, implyKey, colorMode);
   else if(!strcmpi(op, "format") || !strcmpi(op, "concat"))
      result = convertFormatOrConcatExp(params, implyKey, colorMode);
   else if(!strcmpi(op, "round"))
   {
      CQL2Expression ne = convertMBGLExp(params[1], false, implyKey, colorMode);
      if(ne._class == class(CQL2ExpConstant))
      {
         if(((CQL2ExpConstant)ne).constant.type.type == real)
         {
            result = CQL2ExpConstant { constant = { { integer }, i = (int)round(((CQL2ExpConstant)ne).constant.r) } };
            delete ne;
         }
         else
            result = ne;
      }
   }
   else
   {
      CQL2TokenType operator = mbTokens[op];
      if(operator == endOfInput)
      {
         // FIXME: This should really be in a section specifically handling "literal", [ ... ]
         //        The op == endOfInput check is to handle unrecognized value
         //        If literal was used, it should go here always and not even check op
         //        " e.g., "literal", [ "step", "s
         CQL2ExpList elements { };
         if(params)
         {
            int i;
            for(i = 0; i < params.count; i++)
            {
               CQL2Expression ne = convertMBGLExp(params[i], false, implyKey, colorMode);
               if(ne)
                  elements.Add(ne);
            }
         }
         result = CQL2ExpArray { elements = elements };
      }
      else if(!strcmp(op, "all") && params.count == 2) // avoid bad '&!' confusion when short 'all' used as conditional fallback
         result = convertMBGLExp(params[1], false, implyKey, colorMode);
      else
         result = convertOperationExp(operator, params, implyKey, colorMode);
   }
   return result;
}

static CQL2Expression convertMatchExp(Array<MBGLFilterValue> params, bool implyKey, ColorParseMode colorMode)
{
   CQL2Expression result = null;
   if(params[1].type.type == array)
   {
      CQL2ExpOperation expOp { exp1 = convertMBGLExp(params[1], false, implyKey, none) };
      if(isMatchOutputBoolean(params, 2))
      {
         // Converting match to an in expression since all outputs are boolean and fallback is opposite
         int paramsCount = params.count;
         bool hasFallback = paramsCount & 1;
         int matchSets = (paramsCount - 2 - hasFallback) / 2;
         int fallback = paramsCount - 1;
         bool fallbackValue = hasFallback ? (bool)params[fallback].i : false;
         if(matchSets > 1 || (params[2].type.type == array && params[2].a.count > 1))
         {
            // Multiple matches
            CQL2ExpList elements { };
            Array<ContainerForStringCompare> elementsForSort {};
            // create struct with OnCompare..
            int i;
            expOp.op = in;
            for(i = 2; i < paramsCount - hasFallback; i+= 2) // Don't include fallback
               if(params[i+1].i != fallbackValue) // Don't include unnecessary values same as fallback (e.g., RBT closed airport)
               {
                  if(params[i].type.type == array)
                     for(e : params[i].a)
                        elementsForSort.Add( { exp = convertMBGLExp((MBGLFilterValue)e, false, implyKey, colorMode )});
                  else
                     elementsForSort.Add( { exp = convertMBGLExp(params[i], false, implyKey, colorMode )});
               }
            elementsForSort.Sort(true); // handle cases where identical 'in' lists have values in different order
            for(e : elementsForSort)
               elements.Add(e.exp.copy());
            elementsForSort.Free(), delete elementsForSort;
            expOp.exp2 = CQL2ExpArray { elements = elements };
         }
         else if(fallbackValue == (bool)params[3].i)
         {
            // Always same match
            result = CQL2ExpIdentifier { identifier = { string = fallbackValue ? CopyString("true") : CopyString("false") } };
            delete expOp;
         }
         else
         {
            // Single output value
            expOp.op = (params[2].type.type == array && params[2].a.count > 1) ? in : equal;
            expOp.exp2 = convertMBGLExp(params[2], false, implyKey, colorMode);
         }
         // Handle negative match
         if(expOp)
         {
            if(fallbackValue == true)
               result = CQL2ExpOperation { op = not, exp2 = CQL2ExpBrackets { list = { [ expOp ] } } };
            else
               result = expOp;
         }
      }
      else
      {
         result = getConditionalExpression(params, 2, params.count-1, expOp, colorMode, false);
         delete expOp; // getConditionalExp() re-uses and copies
      }
   }
   return result;
}

static CQL2Expression convertStepExp(Array<MBGLFilterValue> params, bool implyKey, ColorParseMode colorMode)
{
   CQL2Expression result = null;
   bool isZoom = false;
   if(params[1].type.type == array)
   {
       Array<MBGLFilterValue> ar = (Array<MBGLFilterValue>)params[1].a;
       isZoom = (ar.count == 1 && ar[0].type.type == text && !strcmp(ar[0].s, "zoom"));
   }
   if(isZoom)
   {
      // conditional exp, eventually create nested rules to avoid the use of long conditional expressions (requires ExpIndex support)
      CQL2Expression e = getConditionalZoomExp(params, 2, params.count, colorMode);
      if(e && (e._class != class(CQL2ExpConstant) || ((CQL2ExpConstant)e).constant.type.format != boolean))
         result = e; // avoid adding mere True selector for now
      else
         delete e;
   }
   else
   {
      CQL2ExpOperation expOp { };
      if(params[1].type.type == array)
         expOp.exp1 = convertMBGLExp(params[1], false, implyKey, none);
      result = getConditionalExpression(params, 2, params.count-1, expOp, colorMode, true);
   }
   return result;
}

static CQL2Expression convertStopsExp(Array<MBGLFilterValue> params, ColorParseMode colorMode)
{
   CQL2Expression result = null;
   int i;

   for (i = 0; i < params.count; i++)
   {
      if (params[i].type.type == array)
      {
         Array<MBGLFilterValue> pair = (Array<MBGLFilterValue>)params[i].a;

         if (pair.count >= 2)
         {
            MBGLFilterValue *zoom = &pair[0], *val  = &pair[1];

            if (val && val->type.type == array)
            {
               Array<MBGLFilterValue> anchors = (Array<MBGLFilterValue>)val->a;
               int k;
               bool picked = false;
               for (k = 0; k < anchors.count; k++)
               {
                  if (anchors[k].type.type == text && !strcmp(anchors[k].s, "left"))
                  {
                     val = &anchors[k];
                     picked = true;
                     break;
                  }
               }
               if (!picked && anchors.count > 0)
                  val = &anchors[0];
            }

            if (val && val->type.type != nil && val->type.type != 0)
            {
               CQL2Expression eVal = convertMBGLExp(val, false, false, colorMode);

               if(eVal)
               {
                  if(result)
                  {
                     if(zoom && (zoom->type.type == real || zoom->type.type == integer))
                     {
                        CQL2Expression eZoom = convertMBGLExp(zoom, false, false, none);
                        if(eZoom)
                        {
                           CQL2Expression sd = zoomtoSD(eZoom);
                           if (sd)
                              result = CQL2ExpConditional {
                                 expList = { [ result ] },
                                 condition = CQL2ExpBrackets { list = { [ CQL2ExpOperation {
                                       exp1 = newCSScaleExp(), op = smaller, exp2 = sd } ] } },
                                 elseExp = eVal
                              };
                           delete eZoom;
                        }
                     }
                  }
                  else
                     result = eVal;
               }
            }
         }
      }
   }
   return result;
}


static CQL2Expression convertInterpolateExp(Array<MBGLFilterValue> params, bool implyKey, ColorParseMode colorMode)
{
   CQL2Expression result = null;
   //TODO: internal interpolate() function to handle this expression
   // example usage: textSize: interpolate(linear, viz.sd, 0, featureclas = sea ? zoomToSD(10) : zoomToSD(9), featureClas in [ocean, sea] ? 18 : featureClas in (gulf, bay, Lake) ? 16 : 14);
   CQL2ExpCall interpolateExp { exp = CQL2ExpIdentifier { identifier = CQL2Identifier { string = CopyString("interpolate") } }, arguments = { } };
   Array<CQL2Expression> args {};
   CQL2Expression expoExp = null;
   int i;
   Color col = 0;
   bool allSameCol = true;

   for(i = 1; i < params.count; i++)
   {
      if(i == 1 && params[i].type.type == array && params[i].a.count)
      {
         CQL2Expression e = convertMBGLExp((MBGLFilterValue)params[i].a[0], false, implyKey, none);
         args.Add(e);
         // exponential value added at the end? -- FIXME: don't put the base at the end, but it at the start.
         //                                               also we sohuld either use interpolateExp() or always pass the 1.0 and drop the 'linear'/'exponential' string
         if(params[i].a.count > 1)
            expoExp = convertMBGLExp((MBGLFilterValue)params[i].a[1], false, implyKey, none);
      }
      else if(i == 2 && params[i].type.type == array && params[i].a.count)
      {
         // FIXME: This is not done right. "zoom" should be handled separtely as converting the
         //        zoom identifier regardless of whether it's in interpolate() or something else.
         if(params[i].a[0].type.type == text && !strcmp(params[i].a[0].s, "zoom"))
         {
            // log(2, 1 / viz.sd) + 29.0584853377
            // or 29.0584853377 - log(2, viz.sd)
            /*double magicNum = 29.0584853377; // get zoom levels back from scale denominator specifically for WorldMercatorWGS84Quad/WebMercator
            CQL2Expression sd = newCSScaleExp();
            CQL2ExpCall lExp { exp = CQL2ExpIdentifier { identifier = CQL2Identifier { string = CopyString("log") } }, arguments = { } };
            CQL2ExpOperation expOp { exp1 = CQL2ExpConstant { constant = { { integer }, i = 1 } }, op = divide, exp2 = sd };
            CQL2ExpCall lExp2 = lExp.copy();
            lExp.arguments.Add(expOp);*/
                                     // NOTE: This number assumes a WebMercatorQuad or WorldMercatorWGS84Quad or
                                     //       GNOSISGlobalGrid: 27.0584853377 ; WorldCRS84Quad: 28.0584853377
            CQL2Expression parsedE = parseCQL2Expression("29.0584853377 - log(2, viz.sd)");
            args.Add(parsedE);
         }
         else
            args.Add(convertMBGLExp(params[i], false, implyKey, none));
      }
      else
      {
         CQL2Expression e = convertMBGLExp(params[i], false, implyKey, colorMode);
         /* // No longer converting to Scale Denominator -- we convert viz.sd to level instead
         if(isZoom && (i & 1))
         {
            CQL2Expression sd = zoomtoSD(e);
            delete e;
            e = sd;
         }
         */
         if(colorMode == hex && !(i & 1))
         {
            if(i == 4 && e._class == class(CQL2ExpConstant))
               col = (Color)((CQL2ExpConstant)e).constant.i;
            else if(e._class != class(CQL2ExpConstant) || col != (Color)((CQL2ExpConstant)e).constant.i)
               allSameCol = false;
         }
         args.Add(e);
      }
   }
   if(colorMode == hex && allSameCol && args.count >= 4)
   {
      result = args[3].copy();
      if(args) args.Free(), delete args, delete interpolateExp;
   }
   else
   {
      // FIXME: We should have the exponential at the start, not the end.
      if(expoExp)
         args.Add(expoExp);
      if(args.count)
      {
         for(a : args)
            interpolateExp.arguments.Add(a.copy());
      }
      else
         delete interpolateExp;
      if(args) args.Free(), delete args;//, delete interpolateExp;
      result = interpolateExp;
   }
   return result;
}

static CQL2Expression convertCoalesceExp(Array<MBGLFilterValue> params, bool implyKey, ColorParseMode colorMode)
{
   CQL2Expression result = null;
   CQL2Expression conditional = null;
   int i;
   for(i = params.count - 1; i > 0; i--)
   {
      CQL2Expression e = convertMBGLExp(params[i], false, implyKey, colorMode);
      if(e)
      {
         // REVIEW: According to Mapbox style spec this is used for strings and images unavailable in symbolizer
         if(i < params.count - 1)
         {
            CQL2ExpOperation condition
            {
               exp1 = e, op = notEqual,
               exp2 = CQL2ExpIdentifier { identifier = { string = CopyString("null") } }
            };
            conditional = CQL2ExpConditional
            {
               condition = condition,
               expList = { [ e.copy() ] },
               elseExp = conditional
            };
         }
         else
            conditional = e;
      }
   }
   result = CQL2ExpBrackets { list = { [ conditional ] } };
   return result;
}

static CQL2Expression convertBooleanExp(Array<MBGLFilterValue> params, bool implyKey, ColorParseMode colorMode)
{
   CQL2Expression result = null;
   // Evaluates each expression in turn until the first valid value is obtained.
   // translating this to OR or conditional expressions
   CQL2ExpOperation expOp = null;
   int i;
   for(i = 1; i < params.count; i++)
   {
      CQL2Expression e = convertMBGLExp(params[i], false, implyKey, colorMode);
      if(e && e._class == class(CQL2ExpIdentifier))
         e = CQL2ExpOperation { exp1 = e, op = notEqual, exp2 = CQL2ExpIdentifier { identifier = { string = CopyString("null") } } };
      if(e && !expOp)
         expOp = { exp1 = e };
      else if(e && !expOp.exp2)
      {
         expOp.exp2 = e;
         expOp.op = or;
      }
      else
         expOp = CQL2ExpOperation { exp1 = expOp, op = or, exp2 = e };
   }
   result = params.count > 2 ? CQL2ExpBrackets { list = { [ expOp ] } } : expOp;

   // since we may not handle expressions in Text or other element yet, just use one of the identifiers for now
   //result = convertMBGLExp(params[1], false, implyKey, colorMode);
   return result;
}

static CQL2Expression convertFormatOrConcatExp(Array<MBGLFilterValue> params, bool implyKey, ColorParseMode colorMode)
{
   // NOTE: what mbgl 'format' does is concatenate mixed-format text, we don't need eccss::formatValues to do this, use concatenate
   CQL2ExpCall formatExp { exp = CQL2ExpIdentifier { identifier = CQL2Identifier { string = CopyString("concatenate") } }, arguments = { } };
   int i;
   for(i = 1; i < params.count; i++)
   {
      //NOTE: for 'format' don't use 'style override object' map, these are per-substring and not merely reserved for the whole formatted string as done in 3395 json files
      // which is unsupported behavior, but may technically be approximated by using separate label elements with offset values
      if(params[i].type.type != map && params[i].type.type != blob)
      {
         CQL2Expression ne = convertMBGLExp(params[i], false, implyKey, colorMode);
         if(ne)
         {
            if(ne._class == class(CQL2ExpConditional))
            {
               CQL2ExpBrackets tempBrkt { list = { [ ne ] } };
               ne = tempBrkt;
            }
            formatExp.arguments.Add(ne);
         }
      }
   }
   return formatExp;
}

static CQL2Expression convertOperationExp(CQL2TokenType operator, Array<MBGLFilterValue> params, bool implyKey, ColorParseMode colorMode)
{
   CQL2Expression result = null;
   bool singleOperand = params.count == 2;
   int i;

   for(i = 1; i < params.count; i++)
   {
      // we're assuming i == 1 is the key, i == 2 is the value
      CQL2Expression ne = convertMBGLExp(params[i], i == 1 && implyKey, implyKey, colorMode);
      if(ne)
      {
         bool simplifyNot = false;
         // Bracket the operand as needed
         if(ne._class == class(CQL2ExpOperation))
         {
            CQL2ExpOperation oe = (CQL2ExpOperation)ne;
            // "!",[has, {id}] translates to "not ({id} != null), simplify it. This may be written in inconsistent fashion, since !has may also be employed though it may be deprecated
            // REVIEW: Why was this commented out?
            if(operator == not && oe.op == notEqual)
            {
               simplifyNot = true;
               oe.op = equal;
            }
            else if(operator != oe.op && (operator.isUnaryOperator || isLowerEqualPrecedence(operator, oe.op)))
               ne = CQL2ExpBrackets { list = { [ ne ] } };
         }
         if(simplifyNot)
            result = ne;
         else if(singleOperand)  // REVIEW: Is this still useful?
         {
            if(operator == not && ne._class == class(CQL2ExpIdentifier))
               result = CQL2ExpOperation { exp1 = ne, op = equal, exp2 = CQL2ExpIdentifier { identifier = { string = CopyString("null") } } };
            else
               result = CQL2ExpOperation { op = operator, exp2 = ne };
         }
         else if(operator == in) //|| !strcmp(op, "none"))
         {
            // This is using "in" directly in JSON style(rather than match)
            // FIXME: Use of result here for intermediate results as part of loop is really confusing
            //        Process left-hand and right-hand size of in separately, in dedicated processInExp() function
            if(ne._class == class(CQL2ExpIdentifier))
               result = result ? CQL2ExpOperation { exp1 = ne, op = operator, exp2 = result } : ne;
            else if(!result)
               result = ne._class == class(CQL2ExpArray) ? ne : CQL2ExpArray { elements = { [ ne ] } };
            else if(result._class == class(CQL2ExpIdentifier))
               result = CQL2ExpOperation { exp1 = result, op = operator,
                  exp2 = ne._class == class(CQL2ExpArray) ? ne : CQL2ExpArray { elements = { [ ne ] } } };
            else if(result._class == class(CQL2ExpOperation) && ((CQL2ExpOperation)result).exp2._class == class(CQL2ExpArray))
            {
               CQL2ExpArray array = (CQL2ExpArray)((CQL2ExpOperation)result).exp2;
               array.elements.Add(ne);
            }
         }
         else
         {
            // it's unnecessary to include AND TRUE in selectors,
            // once case/boolean statements properly evaluated then we can have an expoperation here as a result
            // however, it's technically possible for a fallback/default value to be 'False', just not expected, so a better check is needed
            if(operator == and && ne._class == class(CQL2ExpIdentifier)) // 'has' op will yield this
            {
               // maybe want a condition for != NULL expression, but as in coelesce maybe we sometimes only want the identifier
               ne = CQL2ExpOperation { exp1 = ne, op = notEqual, exp2 = CQL2ExpIdentifier { identifier = { string = CopyString("null") } }  };
               result = result ? CQL2ExpOperation { exp1 = result, op = operator, exp2 = ne } : ne;
            }
            else if(!(operator == and && ne._class == class(CQL2ExpConstant))) // True/False
               result = result ? CQL2ExpOperation { exp1 = result, op = operator, exp2 = ne } : ne;
            else
               delete ne;
            if(result && result._class == class(CQL2ExpOperation))
            {
               CQL2ExpOperation e = (CQL2ExpOperation)result;
               if(e.exp1 && e.exp1._class != class(CQL2ExpIdentifier) &&
                  e.exp2 && e.exp2._class == class(CQL2ExpIdentifier))
               {
                  // Flip key to be on the left and value on the right
                  CQL2Expression e2 = e.exp1;
                  e.exp1 = e.exp2;
                  e.exp2 = e2;
               }
            }
         }
      }
   }
   return result;
}

static CQL2Expression convertMBGLExp(MBGLFilterValue filter, bool isKey, bool implyKey, ColorParseMode colorParseMode)
{
   CQL2Expression result = null;
   Array<MBGLFilterValue> params = filter.type.type == array ? (Array<MBGLFilterValue>)filter.a : null;    // FIXME: Should use 'array'
   const String op = params && params.count && params[0].type.type == text ? params[0].s : null;
   if(op && params.count >= 2)
      result = convertOpExp(op, params, implyKey, colorParseMode);
   else if(filter.type.type == text)
   {
      if(isKey)
         result = CQL2ExpIdentifier { identifier = { string = CopyString(filter.s) } };
      else
      {
         if(colorParseMode != none)
            result = getColorHexConstant(filter.s, colorParseMode);
         if(!result)
            result = CQL2ExpString { string = CopyString(filter.s) };
      }
   }
   else if((filter.type.type == blob || filter.type.type == array) && params.count)// > 1  // FIXME: Should use 'array'
   { // REVIEW: This section seems to be handling "in" lists. Anything else?
      if(params.count > 1)
      {
         CQL2ExpList list { };
         int i;
         for(i = 0; i < params.count; i++)
         {
            CQL2Expression ne = convertMBGLExp(params[i], false, implyKey, colorParseMode);
            list.Add(ne.copy());
         }
         // result = CQL2ExpBrackets { list = list }; // REVIEW: brackets were being used here, which are only array in CQL2-Text
         result = CQL2ExpArray { elements = list };
      }
      else
         result = convertMBGLExp(params[0], false, implyKey, colorParseMode);
   }
   else if(filter.type.type == nil)
      result = CQL2ExpIdentifier { identifier = { string = CopyString("null") } };
   else if(filter.type.type == map)
   {
      for(each : filter.m)
      {
         //MBGLFilterValue sub = each;
         Array<MBGLFilterValue> subArray = null;
         if(((MBGLFilterValue)each).type.type == array)
         {
            subArray = (Array<MBGLFilterValue>)each.a;
         }
         result = convertOpExp(&each, subArray, implyKey, colorParseMode);
         break;
      }
   }
   else if(filter.type.type != 0)
      result = CQL2ExpConstant { constant = *(FieldValue *)filter };

   if(!result && filter.type.type != 0)
   {
      // PrintLn(filter.type.type);
      // PrintLn(filter);
      //convertMBGLExp(filter, isKey, implyKey, colorParseMode);
      result = CQL2ExpString { string = CopyString("!!unsupported!!") };
   }
   return result;
}

static CQL2Expression convertWidth(MBGLFilterValue linewidth, bool isPattern)
{
   CQL2Expression lineWidthExp = null;
   if(linewidth.type.type != array && isPattern)   // REVIEW: Why this?
      lineWidthExp = CQL2ExpConstant { constant = { { integer }, i = 2 } };
   else
      lineWidthExp = convertMBGLExp(linewidth, false, false, none);
   if(lineWidthExp && linewidth.type.type == array)
   {
      // NOTE: we want regular interpolation for low zoom and Meters for high zoom (large scale)
      Array<MBGLFilterValue> params = (Array<MBGLFilterValue>)linewidth.a;
      if(params && params.count && params[0].type.type == text)
      {
         // FIXME: These are two completely separate things that should be handled in two different functions.
         //        Instead, both functions could potentially invoke the same functions for parts of the work which are exactly the same.
         if(!strcmpi(params[0].s, "step") || !strcmpi(params[0].s, "interpolate"))
         {
            if(params.count >= 3)
            {
               CQL2Expression size = null;//double size = 1;
               CQL2Expression firstSize = null;
               CQL2Expression mWidth = null, level = null;//int level = 18; // defaults to handle map-types as we won't use expressions here for now
               // 34123.6733415965
               // TOFIX: actually interpolate based on type
               // Start from the end to use the most detailed scale
               int i = params.count - 2;
               CQL2Expression patternDivide = null;
               int firstI = (i & 1) ? 3 : 2;

               // corresponding input/output order is reversed for interpolate/step
               firstSize = convertMBGLExp(params[(firstI & 1) ? firstI + 1 : firstI], false, false, none);
               size = convertMBGLExp(params[(i & 1) ? i + 1 : i], false, false, none);
               level = convertMBGLExp(params[(i & 1) ? i : i + 1], false, false, none);

               // Last specified size is when we're >= than the previous level specified (sub 2 for GMC->GGG)
               // use meters for zoom greater than 12 if possible, otherwise use the expression. TOFIX: other level expressions?
               //level += 3;   // We add 3 here because otherwise the line will be too thick once zoomed in
               if(size && level)
               {
                  CQL2ExpConstant levelConstant = level._class == class(CQL2ExpConstant) ? (CQL2ExpConstant)level : null;
                  CQL2ExpConstant sizeConstant = size._class == class(CQL2ExpConstant) ? (CQL2ExpConstant)size : null;
                  double lvl = levelConstant ? (levelConstant.constant.type.type == integer ? levelConstant.constant.i : levelConstant.constant.r) : 18;
                  double s = sizeConstant ? (sizeConstant.constant.type.type == integer ? sizeConstant.constant.i : sizeConstant.constant.r) : 0;
                  if(lvl >= 15 || s > 5) // Only use this approach if stroke intended for detailed zoom levels and/or large stroke size
                  {
                     double mpp = firstZoomLevelTileDistance / (tilePixels * pow(2.0, lvl - 2)); // support fractional level
                     //double mpp = //metersPerPixelFromLevel(lvl-2);
                     if(s)
                        mWidth = CQL2ExpConstant { constant = { { real }, r = ((int)(s * mpp * 100 + 0.5))/100.0 } };
                     else
                        mWidth = CQL2ExpOperation {
                              exp1 = CQL2ExpBrackets { list = { [ size.copy() ] } },
                              op = multiply,
                              exp2 = CQL2ExpConstant { constant = { { real }, r = mpp } } };
                  }
               }

               if(isPattern)
                  patternDivide = firstSize /*size*/ ? firstSize /*size*/.copy() : CQL2ExpConstant { constant = { { integer }, i = 8 } };

               if(mWidth)
               {
                  lineWidthExp = CQL2ExpConditional {
                     //condition = CQL2ExpOperation { exp1 = newCSScaleExp(), op = smaller, exp2 = cutOff},
                     condition = CQL2ExpOperation {
                        exp1 = CQL2ExpBrackets { list = { [ lineWidthExp.copy() ] } },
                        op = greater,
                        exp2 = patternDivide ?
                           CQL2ExpOperation {
                              exp1 = patternDivide.copy(),
                              op = multiply,
                              exp2 = firstSize /*size*/ ? firstSize /*size*/.copy() : CQL2ExpConstant { constant = { { integer }, i = 4 } } } :
                           size ? size.copy() : CQL2ExpConstant { constant = { { integer }, i = 4 }
                        }},
                     expList = { [ CQL2ExpInstance { instance =
                        CQL2Instantiation
                        {
                           _class = { name = CopyString("Meters") },
                           members = { [ { [ { initializer = mWidth } ] } ] }
                        }
                      } ] },
                     elseExp = lineWidthExp };
               }
               delete level;

               if(isPattern)
                  lineWidthExp = CQL2ExpOperation {
                     exp1 = CQL2ExpBrackets { list = { [ lineWidthExp ] } },
                     op = divide,
                     exp2 = patternDivide
                  };

               delete size;
            }
         }
      }
   }
   return lineWidthExp;
}
static CQL2Expression convertCasingWidth(MBGLFilterValue linewidth, MBGLFilterValue linegapwidth)
{
   CQL2Expression lineWidthExp = convertMBGLExp(linewidth, false, false, none);
   lineWidthExp = CQL2ExpOperation { exp1 = lineWidthExp, op = minus, exp2 = convertMBGLExp(linegapwidth, false, false, none) };
   lineWidthExp = CQL2ExpOperation {
      exp1 = CQL2ExpBrackets { list = { [ lineWidthExp ] } },
      op = divide,
      exp2 = CQL2ExpConstant { constant = { { real }, r = 2.0 } }
   };
   return lineWidthExp;
}

/*
static CQL2Expression convertLiteral(MBGLFilterValue filter)
{
   CQL2Expression result = null;
   Array<MBGLFilterValue> params = filter.type.type == array ? (Array<MBGLFilterValue>)filter.a : null;    // FIXME: Should use 'array'
   if(params && params.count)
   {
      // take the first supported value e.g. a font set name, in the future see if system supports
      result = convertMBGLExp(params[0], false, false, none);
   }
   else
      result = convertMBGLExp(filter, false, false, none);
   return result;
}
*/

// FIXME: This function is badly named -- it removes paired double quotes, parentheses or curly brackets, in a newly allocated string!
static String removeDoubleQuotesOrBrackets(const String string)
{
   String newStr = null;

   if(string && (string[0] == '\"' || string[0] == '(' || string[0] == '{'))
   {
      int len = strlen(string + 1);
      if(len > 1) len--;
      newStr = new char[len + 1];
      memcpy(newStr, string+1, len);
      newStr[len] = 0;
      //PrintLn(strProp);
   }
   else
      newStr = CopyString(string);
   return newStr;
}

static Map<String, CQL2TokenType> mbTokens
{ [
   { "<=", smallerEqual },
   { ">=", greaterEqual },
   { ">", greater },
   { "<", smaller },
   { "==", equal },
   { "!=", notEqual },
   { "%", modulo },
   { "/", divide },
   { "-", minus },
   { "and", and },
   { "all", and },
   { "any", or },
   { "or", or },
   { "in", in },
   { "!", not },
   { "none", not } //TODO: This is actually NOR, more than one expression on right side should be ORed
] };

static Map<CQL2TokenType, CQL2TokenType> tokenFlipMap
{ [
   { equal, notEqual },
   { notEqual, equal },
   { smaller, greaterEqual },
   { smallerEqual, greater },
   { greater, smallerEqual },
   { greaterEqual, smaller }
] };

bool constantIsNum(const char * string, double * v)
{
   char ch;
   int i;
   bool digit = true;

   for(i = 0; (ch = string[i]); i++)
   {
      if(!isdigit(ch))
      {
         digit = false;
         break;
      }
   }
   if(digit)
      *v = strtod(string, null);
   return digit;
}

static CQL2Expression getColorHexConstant(String string, ColorParseMode colorMode)
{
   CQL2ExpConstant constant  = null;

   if(string)
   {
      if(colorMode == hex)
      {
         Color color = 0;
         constant = { constant = { { integer, format = FieldValueFormat::color /*hex*/ } } };
         if(string[0] == '0' && string[1] == 'x')
            color = (uint)strtoul(string, null, 0);
         else if(string[0] == '#' && isalnum(string[1]))
            color = (uint)strtoul(string+1, null, 16);
         else if(string[0] == 'r' && string[1] == 'g')
         {
            ColorRGB rgb { };
            int index = string[3] == 'a' ? 4 : 3;
            String splitMe = removeDoubleQuotesOrBrackets(string+index);
            Array<String> params = splitCommaValues(splitMe);
            rgb.r = (float)strtod(params[0], null);
            rgb.g = (float)strtod(params[1], null);
            rgb.b = (float)strtod(params[2], null);
            if(params)
            {
               params.Free();
               delete params;
            }
            delete splitMe;
            color.r = (byte)Min(Max(rgb.r,0),255);
            color.g = (byte)Min(Max(rgb.g,0),255);
            color.b = (byte)Min(Max(rgb.b,0),255);
         }
         /*else if(string[0] == 'h' && string[1] == 's')
         {
            //ugly stuff, move a block to a function
            ColorHSV hsv { };
            String s = null, v = null;
            int len;// = strlen(string[3]);
            Array<String> params = splitCommaValues(removeDoubleQuotesOrBrackets(string[3]));
            hsv.h = (Degrees)strtod(params[0], null);
            len = strlen(params[1]);
            if(len > 1) len--;
            s = new char[len + 1];
            memcpy(s, params[1], len);
            s[len] = 0;
            hsv.s = (float)strtod(s, null);
            len = strlen(params[2]);
            if(len > 1) len--;
            v = new char[len + 1];
            memcpy(v, params[2], len);
            v[len] = 0;
            hsv.v = (float)strtod(v, null);
            color = hsv;
         }*/
         else
         {
            DefinedColor c = 0;
            char *d = strchr(string, ',');
            if(d)
               d += 1;
            else
               d = string;
            color = c.class::OnGetDataFromString(d) ? c : (Color)strtoul(d, null, 16);
         }
         constant.constant.i = color;
      }
      else if(colorMode == alphaOnly && string[0] == 'r' && string[1] == 'g')
      {
         double alpha = 1;
         int index = string[3] == 'a' ? 4 : 3;
         String splitMe = removeDoubleQuotesOrBrackets(string+index);
         Array<String> params = splitCommaValues(splitMe);
         alpha = params.count > 3 ? strtod(params[3], null) : 1;
         if(params)
         {
            params.Free();
            delete params;
         }
         delete splitMe;
         constant = { constant = { { real }, r = alpha } };
      }
   }
   return constant;
}

static void getAlignmentDirection(Alignment2D alignment, CQL2Expression hAlignExp, CQL2Expression vAlignExp,
   int * x, int * y, CQL2Expression * xExp, CQL2Expression * yExp)
{
   // NOTE: text moves away from anchor point, so if anchored from bottom-left centered to the anchor, then move up-right
   CQL2Expression alignmentExp = null;
   switch(alignment.horzAlign)
   {
      case left:  *x = 1; break;
      case right: *x = -1; break;
      case center: default: *x = 0; break;
   }

   switch(alignment.vertAlign)
   {
      case top:  *y = 1; break;
      case bottom: *y = -1; break;
      case middle: default: *y = 0; break;
   }

   // This would turn for example:
   // (viz.sd > 50000) ? left : center
   //    into
   // (viz.sd > 50000) ? 1 : 0

   *xExp = alignment.horzAlign == unset ?
      substituteExpValues(hAlignExp, mbglAlignmentToHDirection) :
      CQL2ExpConstant { constant = { { integer }, i = *x } };
   *yExp = alignment.vertAlign == unset ?
      substituteExpValues(vAlignExp, mbglAlignmentToVDirection) :
      CQL2ExpConstant { constant = { { integer }, i = *y } };

   delete alignmentExp;
}

// TODO:
static CQL2Expression mbglAlignmentToHAlign(CQL2Expression e)
{
   CQL2Expression result = mbglAlignmentConvert(e, true);
   return result;
}

static CQL2Expression mbglAlignmentToVAlign(CQL2Expression e)
{
   CQL2Expression result = mbglAlignmentConvert(e, false);
   return result;
}

static CQL2Expression mbglAlignmentConvert(CQL2Expression e, bool horz)
{
   CQL2Expression result = null;
   ObjectNotationType on = econ;
   HAlignment ha;
   VAlignment va;
   CQL2ExpString expStr = e._class == class(CQL2ExpString) ? (CQL2ExpString)e : null;
   String s = expStr ? expStr.string : null;
   Alignment2D alignment = 0;


   if(!s || !strcmp(s, "center")) alignment = { center, middle };
   else if(!strcmp(s, "left"))         alignment = { left, middle };
   else if(!strcmp(s, "right"))        alignment = { right, middle };
   else if(!strcmp(s, "top"))          alignment = { center, top };
   else if(!strcmp(s, "bottom"))       alignment = { center, bottom };
   else if(!strcmp(s, "top-left"))     alignment = { left, top };
   else if(!strcmp(s, "top-right"))    alignment = { right, top };
   else if(!strcmp(s, "bottom-left"))  alignment = { left, bottom };
   else if(!strcmp(s, "bottom-right")) alignment = { right, bottom };
   if(horz)
   {
      ha = alignment.horzAlign; // FIXME: eC warnings calling OnGetString() directly on bit class members
      result = CQL2ExpIdentifier { identifier = { string = CopyString(ha.OnGetString(null, null, &on)) } };
   }
   else
   {
      va = alignment.vertAlign; // FIXME: eC warnings calling OnGetString() directly on bit class members
      result = CQL2ExpIdentifier { identifier = { string = CopyString(va.OnGetString(null, null, &on)) } };
   }
   return result;
}

static CQL2Expression mbglAlignmentToHDirection(CQL2Expression e)
{
   CQL2Expression result = null;
   // NOTE: only ever identifier at this point?
   String s = e._class == class(CQL2ExpIdentifier) ?
      ((CQL2ExpIdentifier)e).identifier.string : null;
   if(s)
   {
      if(!strcmp(s, "left")) result = CQL2ExpConstant { constant = { { real }, r = 1 } };
      else if(!strcmp(s, "right")) result = CQL2ExpConstant { constant = { { real }, r = -1 } };
      else if(!strcmp(s, "center")) result = CQL2ExpConstant { constant = { { real }, r = 0 } };
   }
   else
      result = e;
   return result;
}

static CQL2Expression mbglAlignmentToVDirection(CQL2Expression e)
{
   CQL2Expression result = null;
   String s = e._class == class(CQL2ExpIdentifier) ?
      ((CQL2ExpIdentifier)e).identifier.string : null;
   if(s)
   {
      if(!strcmp(s, "top")) result = CQL2ExpConstant { constant = { { real }, r = 1 } };
      else if(!strcmp(s, "bottom")) result = CQL2ExpConstant { constant = { { real }, r = -1 } };
      else if(!strcmp(s, "middle")) result = CQL2ExpConstant { constant = { { real }, r = 0 } };
   }
   else
      result = e;
   return result;
}

static CQL2Expression substituteExpValues(CQL2Expression input, CQL2Expression (* function)(CQL2Expression))
{
   CQL2Expression result = input.copy();
   if(result._class == class(CQL2ExpConditional))
   {
      CQL2ExpConditional cond = (CQL2ExpConditional)result;
      if(cond.expList.lastIterator.data)
      {
         CQL2Expression newExp = substituteExpValues(cond.expList.lastIterator.data, function);
         delete cond.expList.lastIterator.data;
         cond.expList.lastIterator.data = newExp;
      }
      if(cond.elseExp)
      {
         CQL2Expression newExp = substituteExpValues(cond.elseExp, function);
         delete cond.elseExp;
         cond.elseExp = newExp;
      }
   }
   else if(result._class == class(CQL2ExpBrackets))
   {
      CQL2ExpBrackets brkts = (CQL2ExpBrackets)result;
      CQL2Expression newExp = substituteExpValues(brkts.list.lastIterator.data, function);
      delete brkts.list.lastIterator.data;
      brkts.list.lastIterator.data = newExp;
   }
   else if(result._class == class(CQL2ExpOperation))
   {
      CQL2ExpOperation expOp = (CQL2ExpOperation)result;
      CQL2Expression exp1 = expOp.exp1 ? substituteExpValues(expOp.exp1, function) : null;
      CQL2Expression exp2 = expOp.exp2 ? substituteExpValues(expOp.exp2, function) : null;
      delete expOp.exp1, delete expOp.exp2;
      expOp.exp1 = exp1;
      expOp.exp2 = exp2;
   }
   else if(result._class == class(CQL2ExpCall))
   {
      CQL2ExpCall call = (CQL2ExpCall)result;
      CQL2ExpList arguments {};
      for(a : call.arguments)
      {
         CQL2Expression newArg = substituteExpValues(a, function);
         arguments.Add(newArg);
      }
      call.arguments.Free(), delete call.arguments;
      call.arguments = arguments;
   }
   else if(result._class == class(CQL2ExpList))
   {
      CQL2ExpList list = (CQL2ExpList)result;
      CQL2ExpList newList { };
      for(l : list)
      {
         CQL2Expression newArg = substituteExpValues(l, function);
         newList.Add(newArg);
      }
      list.Free(), delete list; // copySrc?
      result = (CQL2Expression)newList;
   }
   else if(result._class == class(CQL2ExpArray))
   {
      CQL2ExpArray arr = (CQL2ExpArray)result;
      CQL2ExpArray newList { elements = {} };

      for(l : arr.elements)
      {
         CQL2Expression newArg = substituteExpValues(l, function);
         newList.elements.Add(newArg);
      }
      arr.Free(), delete arr;
      result = (CQL2Expression)newList;
   }
   else if(result._class == class(CQL2ExpInstance))
   {
      CQL2ExpInstance inst = (CQL2ExpInstance)result;
      if(inst && inst.instance)
      {
         for(i : inst.instance.members)
         {
            CQL2MemberInitList members = i;
            for(m : members)
            {
               CQL2MemberInit mInit = m;
               if(mInit.initializer)
               {
                  CQL2Expression newArg = substituteExpValues(mInit.initializer, function);
                  delete mInit.initializer;
                  mInit.initializer = newArg;
               }
            }
         }
      }
   }
   else if(result._class == class(CQL2ExpString))
   {
      CQL2Expression newExp = function(result);
      delete result;
      result = newExp;
   }
   else if(result._class == class(CQL2ExpIdentifier) && (function == mbglAlignmentToHDirection || function == mbglAlignmentToVDirection))
   {
      CQL2Expression newExp = function(result);
      delete result;
      result = newExp;
   }
   return result;
}

static bool isMatchOutputBoolean(Array<MBGLFilterValue> params, int start)
{
   bool result = false;
   int paramsCount = params.count, fallback = paramsCount - (paramsCount & 1), i;
   for(i = start; i < paramsCount; i+=2)
   {
      // Check fallback on last iteration
      MBGLFilterValue * output = &params[i + (i != fallback)];
      if(output->type.type != integer || output->type.format != boolean)
      {
         result = false;
         break;
      }
      else
         result = true;
   }
   return result;
}

static CQL2Expression zoomtoSD(CQL2Expression e)
{
   CQL2Expression result = null;

   if(e._class == class(CQL2ExpConstant) && ((CQL2ExpConstant)e).constant.type.type == integer)
   {
   // NOTE: Assuming no level gives smaller scale than 1:1 (max GMC level 29)
      int zoomLvl = Max(0, (int)((CQL2ExpConstant)e).constant.i - 2);
      double scale = scaleDenominatorFromLevel(zoomLvl);
      __attribute__((unused)) bool isDenum = roundScale(&scale);
      result = CQL2ExpConstant { constant = { { integer }, i = (int64)scale } };
   }
   return result;
}

static CQL2Expression getConditionalZoomExp(Array<MBGLFilterValue> params, int start, int end, ColorParseMode colorMode)
{
   CQL2Expression result = null;
   // some of this may be reused for interpolation logic
   if(start < end)
   {
      CQL2ExpOperation expOp { exp1 = newCSScaleExp() };
      CQL2ExpConditional c { expList = {}};
      CQL2Expression e = convertMBGLExp(params[start], false, false, none);
      if(e._class != class(CQL2ExpConstant) || ((CQL2ExpConstant)e).constant.type.format != boolean)
      {
         CQL2Expression sd1 = null;
         if(colorMode != none)
         {
            CQL2Expression t = null;
            if(e._class == class(CQL2ExpString))
               t = getColorHexConstant(((CQL2ExpString)e).string, colorMode);
            if(t) delete e, e = t;
         }
         else if(e._class == class(CQL2ExpOperation) || e._class == class(CQL2ExpConditional))
            e = CQL2ExpBrackets { list = { [ e ] } };
         if(start < end -1) expOp.op = greater;
         else expOp.op = smallerEqual;
         expOp.exp2 = start < end-1 ? convertMBGLExp(params[start+1], false, false, colorMode) : convertMBGLExp(params[start-1], false, false, colorMode);
         sd1 = zoomtoSD(expOp.exp2);
         if(sd1)
         {
            delete expOp.exp2;
            expOp.exp2 = sd1;
         }

         if(start == end-1)
            result = expOp;
         else
         {
            c.condition = expOp;
            c.expList.Add(e);

            if(start +2 < end-1)
               c.elseExp = getConditionalZoomExp(params, start+=2, end, colorMode);
            else
               c.elseExp = convertMBGLExp(params[start+2], false, false, colorMode);
            result = c;
         }
      }
      else
         delete expOp, delete c, delete e;
   }

   return result;
}

// NOTE: This is used with "step", "case" and "match"
//       The fact that there is an isStep parameter is probably a good indication that this is a bad idea.
//       Split it into smaller pieces that can be re-used in distinct functions instead.
static CQL2Expression getConditionalExpression(Array<MBGLFilterValue> params, int start, int end, CQL2ExpOperation expOp, ColorParseMode colorMode, bool isStep)
{
   CQL2Expression result = null;
   if(start < end)
   {
      CQL2ExpConditional c { expList = {}};
      CQL2ExpOperation eo = expOp ? expOp.copy() : null; // NOTE: for 'match' we use the one passed, for 'case' we don't
      CQL2Expression e = convertMBGLExp(params[start], false, false, colorMode);
      CQL2Expression forExpList = convertMBGLExp(params[start+1], false, false, colorMode); // REVIEW: Is this for "in" array of options?
      CQL2Expression elseExp = null;
      if(colorMode != none && forExpList)
      {
         CQL2Expression t = null;
         if(forExpList._class == class(CQL2ExpString))
            t = getColorHexConstant(((CQL2ExpString)forExpList).string, colorMode);
         else if(forExpList._class == class(CQL2ExpArray) && ((CQL2ExpArray)forExpList).elements.GetCount() && ((CQL2ExpArray)forExpList).elements[0]._class == class(CQL2ExpString))
         {
            CQL2ExpArray brkts = (CQL2ExpArray)forExpList;
            t = getColorHexConstant(((CQL2ExpString)brkts.elements[0]).string, colorMode);
         }
         if(t) delete forExpList, forExpList = t;
      }

      if(eo)
      {
         if(!isStep)
         {
            eo.op = (params[start].type.type == array && params[start].a.count > 1) ? in : equal;
            eo.exp2 = e;
         }
         else
         {
            eo.op = smaller;
            eo.exp2 = forExpList;
         }
      }

      c.condition = eo ? CQL2ExpBrackets { list = { [ eo ] } } : CQL2ExpBrackets { list = { [ e ] } };
      if(!isStep)
         c.expList.Add(forExpList);
      else
         c.expList.Add(e);
      if(start+2 == end && end == params.count-1)
         elseExp = convertMBGLExp(params[start+2], false, false, colorMode);
      else
         elseExp = getConditionalExpression(params, start+=2, end, expOp, colorMode, isStep);

      c.elseExp = elseExp;
      result = c;
   }
   return result;
}

static Array<CQL2Expression> splitTextFromNewline(CQL2Expression original, CQL2Expression elements[MAX_TEXT_ELEMENTS], int * count, KeepOrSkip * keepSkip)
{
   Array<CQL2Expression> forSplitExp = null;

   if(original._class == class(CQL2ExpCall))
   {
      CQL2ExpIdentifier idExp = (CQL2ExpIdentifier)((CQL2ExpCall)original).exp;
      {
         int i;
         CQL2ExpCall callExp = (CQL2ExpCall)original;
         bool useEnum = (idExp.identifier && idExp.identifier.string && !strcmp(idExp.identifier.string, "concatenate"));
         Map<int, KeepOrSkip> splitActionMap {};
         MapIterator<int, KeepOrSkip> it { map = splitActionMap };
         for(i=0; i < callExp.arguments.GetCount(); i++)
         {
            CQL2Expression arg = callExp.arguments[i];
            KeepOrSkip ss = noaction;
            Array<CQL2Expression> e = splitTextFromNewline(arg, null, 0, useEnum ? &ss : null);
            //if(useEnum)
               delete e;

            if(ss != noaction) // delete?
            {
               it.Index(i, true);
               it.data = ss;
            }
         }
         it.pointer = null;
         // create new Text element with the concatenated text following a "\n"
         if(splitActionMap.GetCount() > 0)
         {
            int prevIndex = 0, j = 0;
            CQL2ExpList arguments = callExp.arguments;
            int argCnt = arguments.GetCount();
            CQL2ExpCall callExpLast;

            while(it.Next())
            {
               KeepOrSkip ss = it.data;
               int index = ss == keep ? it.key +1 : it.key;
               CQL2ExpCall callExpNew = callExp.copy();
               callExpNew.arguments.Free();
               for(j = prevIndex; j < index; j++)
                  callExpNew.arguments.list.Add(arguments.list[j].copy());
               prevIndex = ss == keep ? index : index +1;
               if(elements)
                  elements[(*count)++] = callExpNew;
               else
               {
                  if(!forSplitExp) forSplitExp = {[ callExpNew]};
                  else forSplitExp.Add(callExpNew);
               }
            }
            callExpLast = callExp.copy();
            callExpLast.arguments.Free();
            for(j = prevIndex; j < argCnt; j++)
               callExpLast.arguments.list.Add(arguments.list[j].copy());
            if(elements)
               elements[(*count)++] = callExpLast;
            else
            {
               if(!forSplitExp) forSplitExp = {[ callExpLast]};
               else forSplitExp.Add(callExpLast);
            }
         }
         splitActionMap.Free(), delete splitActionMap;
      }
   }
   else if(original._class == class(CQL2ExpConditional))
   {
      CQL2ExpConditional cond = (CQL2ExpConditional)original;
      Array<CQL2Expression> e1 = splitTextFromNewline(cond.expList.lastIterator.data, null, 0, keepSkip);
      Array<CQL2Expression> e2 = splitTextFromNewline(cond.elseExp, null, 0, keepSkip);
      if(e1 || e2)
      {
         int i;
         if(e1)
         {
            for(i = 0; i < e1.count; i++)
            {
               CQL2ExpConditional condCopy = cond.copy();
               delete condCopy.expList.lastIterator.data; // safe to delete as this should be copied
               condCopy.expList.lastIterator.data = e1[i].copy();
               if(e2)
               {
                  int j;
                  for(j = 0; j < e2.count; j++)
                  {
                     CQL2ExpConditional elseCond = j == i ? condCopy : j > e1.count-1 ? condCopy.copy() : null;
                     if(elseCond)
                     {
                        delete elseCond.elseExp;
                        elseCond.elseExp = e2[j].copy();
                        populateSplitElements(elseCond, elements, forSplitExp, count);
                     }
                  }
                  if(i > e2.count-1)
                  {
                     delete condCopy.elseExp;
                     condCopy.elseExp = CQL2ExpIdentifier { identifier = { string = CopyString("null") } };
                     populateSplitElements(condCopy, elements, forSplitExp, count);
                  }
               }
               else
               {
                  if(i > 0)
                  {
                     delete condCopy.elseExp;
                     condCopy.elseExp = CQL2ExpIdentifier { identifier = { string = CopyString("null") } };
                  }
                  populateSplitElements(condCopy, elements, forSplitExp, count);
               }
            }
         }
         else if(e2)
         {
            for(i = 0; i < e2.count; i++)
            {
               CQL2ExpConditional condCopy = cond.copy();
               delete condCopy.elseExp;
               condCopy.elseExp = e2[i].copy();
               if(i > 0)
               {
                  delete condCopy.expList.lastIterator.data;
                  condCopy.expList.lastIterator.data = CQL2ExpIdentifier { identifier = { string = CopyString("null") } };
               }
               populateSplitElements(condCopy, elements, forSplitExp, count);
            }
         }
         if(e1) e1.Free(), delete e1;
         if(e2) e2.Free(), delete e2;
      }
   }
   else if(original._class == class(CQL2ExpOperation))
   {
      CQL2ExpOperation expOp = (CQL2ExpOperation)original;
      Array<CQL2Expression> e1 = splitTextFromNewline(expOp.exp1, null, 0, keepSkip);
      Array<CQL2Expression> e2 = splitTextFromNewline(expOp.exp2, null, 0, keepSkip);
      if(e1 || e2)
      {
         // TOFIX, not yet required
         /*CQL2ExpOperation expOpCopy = expOp.copy();
         if(e1)
         {
            delete expOpCopy.exp1;
            expOpCopy.exp1 = e1[0].copy(); //fix
         }
         if(e2)
         {
            delete expOpCopy.exp2;
            expOpCopy.exp2 = e2[0].copy();
         }
         if(elements)
            elements[(*count)++] = expOpCopy;
         else
            forSplitExp = { [ expOpCopy ] };*/
         e1.Free(), e2.Free(), delete e1, delete e2;
      }
   }
   else if(original._class == class(CQL2ExpBrackets))
   {
      CQL2ExpBrackets brkts = (CQL2ExpBrackets)original;
      if(brkts.list.GetCount() == 1)
      {
         Array<CQL2Expression> e1 = splitTextFromNewline(brkts.list[0], null, 0, keepSkip);
         if(e1)
         {
            if(elements)
            {
               for(e : e1)
                  elements[(*count)++] = CQL2ExpBrackets { list = { [ e ] } };
            }
            else
            {
               if(!forSplitExp) forSplitExp = {};
               for(e : e1)
                  forSplitExp.Add(CQL2ExpBrackets { list = { [ e ] } });
            }
         }
      }
   }
   else if(original._class == class(CQL2ExpString))
   {
      if(strstr(((CQL2ExpString)original).string, "\n"))
      {
         if(keepSkip)
         {
            String str = ((CQL2ExpString)original).string;
            int len = strlen(str);
            if(len > 1)
            {
               *keepSkip = keep;
               if(str[len-1] == '\n')
                  ((CQL2ExpString)original).string[len-1] = '\0';
            }
            else if(*keepSkip == noaction)
               *keepSkip = skip;
         }
      }
   }
   if(elements && *count == 0) elements[(*count)++] = original.copy();
   return forSplitExp;
}

void populateSplitElements(CQL2Expression result, CQL2Expression elements[MAX_TEXT_ELEMENTS], Array<CQL2Expression> forSplitExp, int * count)
{
   if(elements)
      elements[(*count)++] = result;
   else
   {
      if(!forSplitExp) forSplitExp = {};
      forSplitExp.Add(result);
   }
}

CQL2Expression findSymbolExpInElements(StylingRule stylingRule, Pointf imageHotSpot)
{
   CQL2Expression result = null;
   // NOTE: we only ever expect a single Image element
   CQL2List<CQL2Expression> elements = labelElementsFromBlock(stylingRule);
   for(e : elements)
   {
      CQL2ExpInstance inst = e._class == class(CQL2ExpInstance) ? (CQL2ExpInstance)e : null;
      CQL2SpecName specName = inst ? (CQL2SpecName)inst.instance._class : null;
      if(specName && !strcmp(specName.name, "Image"))
      {
         CQL2ExpInstance imageInstance = inst;
         CQL2Expression imageExp = imageInstance.getMemberByIDs([ "image" ]);
         if(imageInstance.instance && imageInstance.instance.members)
         {
            CQL2ExpInstance hotSpotInst = (CQL2ExpInstance)imageInstance.instance.members.getProperty(hotSpot);
            if(hotSpotInst)
            {
               CQL2Expression x = hotSpotInst.getMemberByIDs([ "x" ]);
               CQL2Expression y = hotSpotInst.getMemberByIDs([ "y" ]);
               if(x && x._class == class(CQL2ExpConstant))
                  imageHotSpot.x = ((CQL2ExpConstant)x).constant.type.type == real ? (float)((CQL2ExpConstant)x).constant.r : ((CQL2ExpConstant)x).constant.i;
               if(y && y._class == class(CQL2ExpConstant))
                  imageHotSpot.y = ((CQL2ExpConstant)y).constant.type.type == real ? (float)((CQL2ExpConstant)y).constant.r : ((CQL2ExpConstant)y).constant.i;
            }
         }
         if(imageExp && imageExp._class == class(CQL2ExpInstance))
         {
            CQL2ExpInstance imgInst = (CQL2ExpInstance)imageExp;
            result = imgInst.getMemberByIDs([ "id" ]);
            break;
         }
      }
   }
   return result;
}

enum KeepOrSkip { noaction, keep, skip };

struct ContainerForStringCompare
{
   CQL2Expression exp;
   int OnCompare(ContainerForStringCompare b)
   {
      if(this == b) return 0;
      if(exp._class == class(CQL2ExpString) && b.exp._class == class(CQL2ExpString))
      {
         CQL2ExpString str1 = (CQL2ExpString)exp;
         CQL2ExpString str2 = (CQL2ExpString)b.exp;
         return strcmp(str1.string, str2.string);
      }
      else if(exp._class == class(CQL2ExpConstant) && b.exp._class == class(CQL2ExpConstant) &&
         ((CQL2ExpConstant)exp).constant.type.type == integer && ((CQL2ExpConstant)b.exp).constant.type.type == integer)
      {
         int x = (int)((CQL2ExpConstant)exp).constant.i, y = (int)((CQL2ExpConstant)b.exp).constant.i;
         if(x && !y) return 1;
         else if(!x && y) return -1;
         else if(x > y) return 1;
         else if(x < y) return -1;
         else return 0;
      }
      else if(exp._class != b.exp._class)
         return -1;
      return 0;
   }
   void OnFree()
   {
      delete exp;
   }
};
