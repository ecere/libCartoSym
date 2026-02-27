public import IMPORT_STATIC "ecrt"
public import IMPORT_STATIC "CartoSym"

import "sldParser"
import "mbglParser"

import "convertFeatures"

void printTextGraphic(Text text)
{
   PrintLn("         Text: ", text.text);
   if(text.font)
      PrintLn("         Font: ", text.font);
   if(text.alignment)
      PrintLn("         Alignment: ", text.alignment);
}

void printImageGraphic(Image image)
{
   PrintLn("         Image: ", image.image);
   PrintLn("         HotSpot: ", image.hotSpot);
}

void printShapeGraphic(Shape shape)
{
   PrintLn("         Size: ", shape.stroke.width, shape.stroke.widthUnit);
}

void printGraphics(MultiGraphicalElement mge)
{
   if(mge)
   {
      Array<GraphicalElement> elements = (Array<GraphicalElement>)mge.elements;
      if(elements && elements.count)
      {
         int i;
         PrintLn($"   with ", elements.count, $" graphic", elements.count > 1 ? $"s" : "", ":");
         for(i = 0; i < elements.count; i++)
         {
            GraphicalElement graphic = elements[i];
            PrintLn("      [", i, "]: ", graphic._class.name);
            if(graphic._class == class(Text))
            {
               printTextGraphic((Text)graphic);
            }
            else if(graphic._class == class(Image))
            {
               printImageGraphic((Image)graphic);
            }
            else if(graphic._class == class(Shape))
            {
               printShapeGraphic((Shape)graphic);
            }
         }
      }
   }
}

void printFill(Fill fill)
{
   if(fill && fill.opacity)
   {
      Print($"Fill Color: ");
      printColor(fill.color);
      PrintLn($"Fill Opacity: ", fill.opacity * 100, "%");
      // Array<GraphicalElement> pattern;
      // StippleType stipple;
      // HatchType hatch;
      // Array<ColorKey> gradient;
   }
   else if(fill)
      PrintLn($"Fill Opacity: 0%");
}


void printStrokeStyling(StrokeStyling styling)
{
   PrintLn($"   Color: ");
   printColor(styling.color);
   PrintLn($"   Opacity: ", styling.opacity * 100, "%");
   PrintLn($"   Width: ", styling.width, " ", styling.widthUnit);
}

void printColor(Color color)
{
   printf("#%02X%02X%02X", color.r, color.g, color.b);
   PrintLn(" (R: ", color.r, ", G: ", color.g, ", B: ", color.b, ")");
}

void printStroke(Stroke stroke)
{
   if(stroke && stroke.opacity)
   {
      Print($"Stroke Color: ");
      printColor(stroke.color);

      PrintLn($"Stroke Opacity: ", stroke.opacity * 100, "%");
      PrintLn($"Stroke Width: ", stroke.width, " ", stroke.widthUnit);

      if(stroke.casing.width && stroke.casing.opacity)
      {
         PrintLn($"Stroke Casing:");
         printStrokeStyling(stroke.casing);
      }
      if(stroke.center.width && stroke.center.opacity)
      {
         PrintLn($"Stroke Centerline:");
         printStrokeStyling(stroke.center);
      }

      // Array<GraphicalElement> pattern;
      // LineJoin join;
      // LineCap cap;
      // Array<int> dashes;
   }
   else if(stroke)
      PrintLn("Stroke Opacity: 0%");

}

void printSymbolizer(CartoSymbolizer symbolizer)
{
   if(symbolizer.visibility)
   {
      PrintLn("Visibility: True");
      PrintLn("Opacity: ", symbolizer.opacity * 100, "%");
      PrintLn("ZOrder: ", symbolizer.zOrder);
      if(symbolizer.marker)
      {
         PrintLn("Marker: ");
         printGraphics(symbolizer.marker);
      }
      if(symbolizer.label)
      {
         PrintLn("Label: ");
         printGraphics(symbolizer.label);
      }

      /*
      Array<ValueColor> colorMap;
      Array<ValueOpacity> opacityMap;
      HillShading hillShading;
      ExtrusionOptions extrusion;
      ColorRGBAf colorChannels;
      double singleChannel;
      */

      printFill(symbolizer.fill);
      printStroke(symbolizer.stroke);
   }
   else
      PrintLn("Visibility: False");
}

bool evaluateStyle(
   const String inputFile, const String inType,
   const String featuresFile, const String ftType,
   const String featureIDString,
   const String layerID,
   double scaleDenominator)
{
   bool result = false;
   char inExt[MAX_EXTENSION], ftExt[MAX_EXTENSION];
   CartoStyle style = null;

   if(!inType)
   {
      GetExtension(inputFile, inExt);
      inType = inExt;
   }
   if(!ftType && featuresFile)
   {
      GetExtension(featuresFile, ftExt);
      ftType = ftExt;
   }
   if(featuresFile && strcmpi(ftType, "geojson") && strcmpi(ftType, "wkbc"))
   {
      PrintLn($"Unrecognized features format");
      return false;
   }

   if(!strcmpi(inType, "cscss"))
   {
      style = CartoStyle::load(inputFile);
      if(!style)
         PrintLn($"Failed to parse ", inputFile, $" as CartoSym-CSS style");
   }
   else if(!strcmpi(inType, "csjson") ||
      (!strcmpi(inType, "json") && RSearchString(inputFile, ".cs.json", strlen(inputFile), false, true)))
   {
      PrintLn($"CartoSym-JSON parsing not yet implemented");
   }
   else if(!strcmpi(inType, "json") || !strcmpi(inType, "mbgl"))
   {
      File f = FileOpen(inputFile, read);
      if(f)
      {
         style = loadMapboxgl(f, false, null);
         if(!style)
            PrintLn($"Failed to parse ", inputFile, $" as Mapbox GL / MapLibre style");
         delete f;
      }
   }
   else if(!strcmpi(inType, "sld"))
   {
      style = loadSLD(inputFile, null, null);
      if(!style)
         PrintLn($"Failed to parse ", inputFile, $" as SLD/SE style");
   }

   if(style)
   {
      FeatureCollection features = null;
      int64 featureID = -1;
      CartoSymEvaluator evaluator { class(CartoSymEvaluator) };
      HashMap<int64, Map<String, FieldValue>> attributes = null;
      CartoSymbolizerMask mask = 0;
      CartoSymbolizer symbolizer = null;
      CartoStyle boundStyle;

      if(featuresFile)
      {
         if(!strcmpi(ftType, "geojson") || !strcmpi(ftType, "json"))
         {
            attributes = { };
            features = readGeoJSONFeatures(featuresFile, attributes);
            if(!features)
               PrintLn($"Failed to parse ", featuresFile, $" as GeoJSON features");
         }
         else if(!strcmpi(ftType, "wkbc"))
         {
            features = readWKBCFeatures(featuresFile);
            if(!features)
               PrintLn($"Failed to parse ", featuresFile, $" as Well-Known text Binary Collection features");
         }

         if(featureIDString)
         {
            featureID = strtoll(featureIDString, null, 0);
         }
         evaluator.setFeatureID(featureID);
         evaluator.setLayerID(layerID);
         evaluator.setAttribsMap(attributes);
         evaluator.setScaleDenominator(scaleDenominator);
      }

      boundStyle = style.bind(evaluator, class(CartoSymbolizer), layerID);
      boundStyle.resolve(evaluator, class(CartoSymbolizer));

      symbolizer = (CartoSymbolizer)CartoSymbolizer::build2(
         boundStyle, evaluator, class(CartoSymbolizer), &mask);

      if(symbolizer)
      {
         printSymbolizer(symbolizer);
         result = true;
         delete symbolizer;
      }

      if(attributes)
         attributes.Free(), delete attributes;

      delete boundStyle;
      delete style;
   }
   return result;
}
