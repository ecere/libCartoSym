/******************************************************************************
 Cartographic Symbology Cascading Style Sheets

 - Based on Ecere's Butterbur Graphics GraphicalElement and GraphicalSymbolizer
 - Support for markers and labels
 - Support for coverage styling (single & multi color bands, color & opacity maps and hillshading)
 - Selectors for geographic data layers, scale, visualization time
 - Selectors for vector features attributes
******************************************************************************/
public import IMPORT_STATIC "ecrt"
public import IMPORT_STATIC "CQL2"

import "GraphicalSymbolizer"

import "CartoSymTools" // For getStylesInt()

public struct ColorRGBAf
{
   float r, g, b, a;
};
// import "GeoDataCache"

/*
import "mbglParser" // for load/write stylesheet functions
import "sldParser"
import "mbglWriter"
import "sldWriter"
*/

import "DE9IM"

public class SymbolsReferenceMode
{
public:
   bool id:1, url:1, localFile:1;
}

public struct ValueColor
{
   double value;
   Color color;
};

public struct ValueOpacity
{
   double value;
   double opacity;
};

public struct AzimuthElevation
{
   double /*Degrees */ azimuth, elevation;
};

public struct HillShading
{
private:
   double factor;
   AzimuthElevation sun;
   Array<ValueColor> colorMap;
   Array<ValueOpacity> opacityMap;

public:
   property double factor { get { return factor; } set { factor = value; } }
   property AzimuthElevation sun { get { value = sun; } set { sun = value; } }
   property Array<ValueColor> colorMap
   {
      get { return colorMap; }
      set { /*if(value) incref value; delete colorMap;*/ colorMap = value; }  // TODO: Review doing this in struct and parsing
      isset { return colorMap != null; }
   }
   property Array<ValueOpacity> opacityMap
   {
      get { return opacityMap; }
      set { /*if(value) incref value; delete opacityMap;*/ opacityMap = value; }
      isset { return opacityMap != null; }
   }
};

public struct ExtrusionOptions
{
private:
   float height, base;
   bool extrude, terrainRelative;
public:
   property float height { set { extrude = true; height = value; } get { return height; } }
   property float base { set { extrude = true; base = value; } get { return base; } }
   property bool terrainRelative { set { terrainRelative = value; } get { return terrainRelative; } }
};

public class CartoSymbolizer : ShapeSymbolizer
{
   Marker marker;
   CSLabel label;
   Array<ValueColor> colorMap;
   Array<ValueOpacity> opacityMap;
   HillShading hillShading;
   ExtrusionOptions extrusion;
   ColorRGBAf colorChannels;
   double singleChannel;

   ~CartoSymbolizer()
   {
      // TODO: freeGE(marker);
      // TODO: freeGE(label);
      delete marker;
      delete label;
      delete colorMap;
      delete opacityMap;
      delete hillShading.colorMap;
      delete hillShading.opacityMap;
   }

public:
   property Marker marker
   {
      get { return marker; }
      set { delete marker; marker = value; incref value; }
   }
   property CSLabel label
   {
      get { return label; }
      set { delete label; label = value; incref value; }
   }
   property Array<ValueColor> colorMap
   {
      get { return colorMap; }
      set { if(value) incref value; delete colorMap; colorMap = value; }
   }
   property Array<ValueOpacity> opacityMap
   {
      get { return opacityMap; }
      set { if(value) incref value; delete opacityMap; opacityMap = value; }
   }
   property HillShading hillShading
   {
      get { value = hillShading; }
      set
      {
         delete hillShading.opacityMap;
         delete hillShading.colorMap;
         if(value && value.opacityMap) incref value.opacityMap;
         if(value && value.colorMap) incref value.colorMap;
         if(value != null)
         {
            hillShading = value;
            // Temporary work around for old Daraa geopackage
            if(value.sun.elevation == -39.0265486725664)
               hillShading.sun.elevation = 19.0265486725664;
         }
         else
            hillShading = { };
      }
      isset { return hillShading.factor != 0; }
   }
   property ExtrusionOptions extrusion
   {
      get { value = extrusion; }
      set
      {
         if(value != null)
         {
            extrusion = value;
            extrusion.extrude = true;
         }
         else
            extrusion = { };
      }
      isset { return extrusion.extrude; }
   }
   property ColorRGBAf colorChannels
   {
      get { value = colorChannels; }
      set { colorChannels = value; }
   }
   property double singleChannel
   {
      get { return singleChannel; }
      set { singleChannel = value; }
   }

   property CartoExpFlags flags { get { return (CartoExpFlags)*&flags; } }

   private CartoSymbolizer ::build(CartoStyle styleSheet, CartoSymEvaluator evaluator)
   {
      return (CartoSymbolizer)GraphicalSymbolizer::build(styleSheet, evaluator, class(CartoSymbolizer));
   }
   private CartoSymbolizer ::build2(CartoStyle styleSheet, CartoSymEvaluator evaluator, CartoSymbolizerMask * fm)
   {
      return (CartoSymbolizer)GraphicalSymbolizer::build2(styleSheet, evaluator, class(CartoSymbolizer), fm);
   }

   CartoSymbolizer copy()
   {
      CartoSymbolizer sym
      {
         zOrder = zOrder, visibility = visibility, opacity = opacity,
         brightness = brightness, saturation = saturation,
         transform = transform, flags = flags
      };
      Fill fill = null;
      Stroke stroke = null;
      fill.OnCopy(this.fill);       sym.fill = fill;
      stroke.OnCopy(this.stroke);   sym.stroke = stroke;

      if(marker) sym.marker = marker.copy();
      if(label) sym.label = label.copy();

      if(colorMap) sym.colorMap = { colorMap };
      if(opacityMap) sym.opacityMap = { opacityMap };
      sym.hillShading = hillShading;
      if(hillShading.opacityMap) sym.hillShading.opacityMap = { hillShading.opacityMap };
      if(hillShading.colorMap) sym.hillShading.colorMap = { hillShading.colorMap };
      if(*&extrusion.extrude) *&sym.extrusion = extrusion;

      return sym;
   }
}

public class Marker : MultiGraphicalElement
{
public:
   Marker copy()
   {
      Marker m { opacity = this.opacity, elements = { this.elements } };
      return m;
   }
}

public class CSLabel : MultiGraphicalElement
{
public:
   float priority;
   float minSpacing;
   float maxSpacing;

   CSLabel copy()
   {
      CSLabel l { opacity = opacity };
      // NOTE: Container::Copy() and copySrc do not make use of OnCopy()!
      if(elements)
      {
         Array<GraphicalElement> lElements = (Array<GraphicalElement>)l.elements;
         for(e : elements)
         {
            GraphicalElement el = e;
            if(el)
            {
               GraphicalElement ge = eInstance_New(el._class);
               ge.OnCopy(e);
               lElements.Add(ge);
            }
         }
      }
      return l;
   }
}

// TODO: Test automatic inheritance & bit positions..
public class CartoSymbolizerMask : ShapeStyleMask
{
public:
   bool markerElements           :1:40;
   bool markerExtra              :1:41; // Dummy flag to distinguish Marker from Marker::Elements for stringFromMask()
   bool labelElements            :1:42;
   bool labelPriority            :1:43;
   bool labelMinSpacing          :1:45;
   bool labelMaxSpacing          :1:46;
   bool singleChannel            :1:49;
   bool colorMap                 :1:50;
   bool opacityMap               :1:51;
   bool hillShadingFactor        :1:52;
   bool hillShadingSunAzimuth    :1:53;
   bool hillShadingSunElevation  :1:54;
   bool hillShadingColorMap      :1:55;
   bool hillShadingOpacityMap    :1:56;
   bool extrusionHeight          :1:57;
   bool extrusionBase            :1:58;
   bool extrusionTerrainRelative :1:59;
   bool colorChannelsR           :1:60;
   bool colorChannelsG           :1:61;
   bool colorChannelsB           :1:62;
   bool colorChannelsA           :1:63;
};

public enum CartoSymbolizerKind : ShapeSymbolizerKind
{
   marker = CartoSymbolizerMask { markerElements = true, markerExtra = true },
   markerElements = CartoSymbolizerMask { markerElements = true },
   label = CartoSymbolizerMask { labelElements = true, labelPriority = true, labelMinSpacing = true, labelMaxSpacing = true },
   labelElements = CartoSymbolizerMask { labelElements = true },
   labelPriority = CartoSymbolizerMask { labelPriority = true },
   labelMinSpacing = CartoSymbolizerMask { labelMinSpacing = true },
   labelMaxSpacing = CartoSymbolizerMask { labelMaxSpacing = true },

   colorMap = CartoSymbolizerMask { colorMap = true },
   opacityMap = CartoSymbolizerMask { opacityMap = true },
   hillShading = CartoSymbolizerMask { hillShadingFactor = true, hillShadingSunAzimuth = true, hillShadingSunElevation = true,
      hillShadingColorMap = true, hillShadingOpacityMap = true },
   hillShadingFactor = CartoSymbolizerMask { hillShadingFactor = true },
   hillShadingSun = CartoSymbolizerMask { hillShadingSunAzimuth = true, hillShadingSunElevation = true },
   hillShadingSunAzimuth = CartoSymbolizerMask { hillShadingSunAzimuth = true },
   hillShadingSunElevation = CartoSymbolizerMask { hillShadingSunElevation = true },
   hillShadingColorMap = CartoSymbolizerMask { hillShadingColorMap = true },
   hillShadingOpacityMap = CartoSymbolizerMask { hillShadingOpacityMap = true },
   extrusion = CartoSymbolizerMask { extrusionHeight = true, extrusionBase = true, extrusionTerrainRelative = true },
   extrusionHeight = CartoSymbolizerMask { extrusionHeight = true },
   extrusionBase = CartoSymbolizerMask { extrusionBase = true },
   extrusionTerrainRelative = CartoSymbolizerMask { extrusionTerrainRelative = true },
   colorChannels = CartoSymbolizerMask { colorChannelsR = true, colorChannelsG = true, colorChannelsB = true, colorChannelsA = true },
   colorChannelsR = CartoSymbolizerMask { colorChannelsR = true },
   colorChannelsG = CartoSymbolizerMask { colorChannelsG = true },
   colorChannelsB = CartoSymbolizerMask { colorChannelsB = true },
   colorChannelsA = CartoSymbolizerMask { colorChannelsA = true },
   singleChannel = CartoSymbolizerMask { singleChannel = true }
};


// TODO: Replace these by class reflection
Map<String, CartoSymbolizerKind> cartoSymbolizerIdentifierMap
{ [
   { "label", label },
   { "label.priority", labelPriority },
   { "label.minSpacing", labelMinSpacing },
   { "label.maxSpacing", labelMaxSpacing },
   { "label.elements", labelElements },
   { "marker", marker },
   { "marker.elements", markerElements },

   { "colorMap", colorMap },
   { "opacityMap", opacityMap },
   { "hillShading", hillShading },
   { "hillShading.factor", hillShadingFactor },
   { "hillShading.sun", hillShadingSun },
   { "hillShading.sun.azimuth", hillShadingSunAzimuth },
   { "hillShading.sun.elevation", hillShadingSunElevation },
   { "hillShading.colorMap", hillShadingColorMap },
   { "hillShading.opacityMap", hillShadingOpacityMap },
   { "extrusion", extrusion },
   { "extrusion.height", extrusionHeight },
   { "extrusion.base", extrusionBase },
   { "extrusion.terrainRelative", extrusionTerrainRelative },
   { "colorChannels", colorChannels },
   { "colorChannels.r", colorChannelsR },
   { "colorChannels.g", colorChannelsG },
   { "colorChannels.b", colorChannelsB },
   { "colorChannels.a", colorChannelsA },
   { "singleChannel", singleChannel }
] };

Map<CartoSymbolizerKind, const String> geoStringFromMaskMap
{ [
   { label, "label" },
   { labelPriority, "label.priority" },
   { labelMinSpacing, "label.minSpacing" },
   { labelMaxSpacing, "label.maxSpacing" },
   { labelElements, "label.elements" },
   { marker, "marker" },
   { markerElements, "marker.elements" },

   { colorMap, "colorMap" },
   { opacityMap, "opacityMap" },
   { hillShading, "hillShading" },
   { hillShadingFactor, "hillShading.factor" },
   { hillShadingSun, "hillShading.sun" },
   { hillShadingSunAzimuth, "hillShading.sun.azimuth" },
   { hillShadingSunElevation, "hillShading.sun.elevation" },
   { hillShadingColorMap, "hillShading.colorMap" },
   { hillShadingOpacityMap, "hillShading.opacityMap" },
   { extrusion, "extrusion" },
   { extrusionHeight, "extrusion.height" },
   { extrusionBase, "extrusion.base" },
   { extrusionTerrainRelative, "extrusion.terrainRelative" },
   { colorChannels, "colorChannels" },
   { colorChannelsR, "colorChannels.r" },
   { colorChannelsG, "colorChannels.g" },
   { colorChannelsB, "colorChannels.b" },
   { colorChannelsA, "colorChannels.a" },
   { singleChannel, "singleChannel" }
] };

public class CSLayer : struct
{
public:
   String id;
   CoreFeatureType type;
   //MapPrimitiveType fc//featureClass fc;
   //VectorFeatureType vt;  //new def?
}

public struct CSVisualization
{
   double sd;
   //TimeInterval time;
   DateTime startTime; // until we can figure out a better solution for interval
   DateTime endTime;
   Date date;
   DateTime timeOfDay;
};
public class CSTime // will need if using interval rather than two different DateTimes?
{

}

public class CSRecord : struct
{
public:
   int64 id;
   void * geom;
}

public class CSScene : struct
{
public:
   String id;
}

public class CartoExpFlags : ExpFlags // FIXME: Problems inheriting positions from base bit class ?
{
public:
   bool scale:1:1;
   bool time:1:2;
   bool record:1:3;
   bool callAgain:1:4;
   bool invalid:1:5;
   bool dimension:1:6;
   bool isNotLiteral:1:7; // REVIEW: Do we really need this flag
   bool scene:1:8;
};

public struct CartoSymEvaluator : GraphicalSymbolizerEvaluator
{
private:
   int64 featureID;
   double scale;
   const String sceneID;
   /* TODO:
   GriddedCoverageFeature * coverage;
   RasterFeature * image;
   */
   uint x;
   uint y;
   uint i, j, k;
   uint * slices, numSlices; // For i
   Array<const CIString> fieldNames;
   Geometry * featureGeometry;
   Map<int64, Geometry> geomMap;
   TimeIntervalSince1970 time;

   // FIXME: The double causes padding between base CQL2Evaluator and this class to be added in external instantiation, while this module does not ahve it
   public void setFeatureID(int64 value) { featureID = value; }
   public void setFeatureGeometry(Geometry * value) { featureGeometry = value; }
   public void setPosition(Point value, uint i, uint j, uint k) { x = value.x; y = value.y; this.i = i; this.j = j; this.k = k; }
   public void setSelectedFields(Array<const CIString> value) { fieldNames = value; }
   public void setTimeInterval(TimeIntervalSince1970 value) { time = value; }
   public void setSceneID(const String value) { sceneID = value; } // Probably don't need to make a copy here
   /* TODO:
   public void flushAttributeRequest() { cache.flushAttributeRequests(); }
   void setGeoDataCache(GeoDataCache value)
   {
      cache = value;
   }
   public void setGeoData(GeoData value)
   {
      dataCacheMutex.Wait();
      cache = GeoDataCache::findOrSetup(value);
      dataCacheMutex.Release();
   }
   */
   public void OnFree() // TOFIX: add this line in codebase where evaluator is used
   {
      if(geomMap)
         geomMap.Free(), delete geomMap;
      // REVIEW: delete sceneID;
   }

   // FIXME: Having the cache before featureID was having wrong padding data layout at all
private:
   // TODO: GeoDataCache cache;

   Class resolve(const CQL2Identifier identifier, bool isFunction, int * fieldIX, CartoExpFlags * flags)
   {
      Class expType = null;

      if(!isFunction)
      {
         if(!strcmp(identifier.string, "lyr") || !strcmp(identifier.string, "dataLayer"))
         {
            //BUILT IN CLASS
            //set exptype based on this
            expType = class(CSLayer);
            flags->resolved = true;
         }
         else if(!strcmp(identifier.string, "viz"))
         {
            expType = class(CSVisualization);
            flags->resolved = true;
         }
         else if(!strcmp(identifier.string, "rec"))
         {
            expType = class(CSRecord);
            if(featureID != -1)
               flags->resolved = true;

            /* TODO:
            if(coverage || image)
               flags->record = true; // FIXME: Use another flag if only cell bbox is needed?
            */
         }
         //else if(!strcmpi(identifier.string, "geom"))
            //flags->resolved = true;
         else if(!strcmp(identifier.string, "scene"))
         {
            expType = class(CSScene);
            flags->resolved = true;
         }
         //TODO: elevation, clouds
/* TODO:
         else if((cache || fieldNames) && (coverage || (cache.data && cache.data.dataType.type == coverage)))
         {
            GeoData data = cache ? cache.data : null;
            int ix;  // Index in source bands
            // fieldIX is index in GCF bands
            *fieldIX = resolveFieldBandIndex(identifier.string, fieldNames, data, &ix);
            if(*fieldIX != -1)
            {
               if(ix != -1)
                  expType = data.bands[ix].type.type == integer ? class(int64) : class(double);
               else if(coverage)
               {
                  const CoverageBand * band = &coverage->bands[*fieldIX];
                  expType = (band->type == integer16 || band->type == integer32) ? class(int64) : class(double);
               }
               flags->record = true;
            }
            else
            {
               int dimIX = -1;

               if(data.extraDimensions)
               {
                  int i;
                  for(i = 0; i < data.extraDimensions.count; i++)
                  {
                     ExtraDimension dim = data.extraDimensions[i];
                     if(!strcmpi(dim.axis, identifier.string))
                     {
                        dimIX = i;
                        flags->dimension = true;
                        break;
                     }
                  }
               }

               if(dimIX == -1)
                  flags->invalid = true;
            }
         }
         else if(cache)
         {
            FieldType fieldType;
            if(*fieldIX == -1)
               *fieldIX = cache.data.attributes.getFieldIndex(identifier.string);

            fieldType = cache.data.attributes.getFieldType(*fieldIX);
            switch(fieldType)
            {
               case real: expType = class(double); break;
               case integer: expType = class(int64); break;
               case text: expType = class(String); break;
               case nil : expType = class(int64); break;
            }
            //if(!fieldIX) value.type.type = nil;
            flags->record = true;
            if(*fieldIX == -1)
               flags->invalid = true;
         }
*/
      }
      else
      {
         CQL2FunctionIndex fnIndex = unresolved;

         if(fnIndex.OnGetDataFromString(identifier.string))
         {
            *fieldIX = fnIndex;
            expType = class(GlobalFunction);
            flags->resolved = true;
         }
         else
            // NOTE: enum::OnGetDataFromString() is not resolving base values...
            expType = CQL2Evaluator::resolve(identifier, isFunction, fieldIX, flags);
      }
      return expType;
   }

   void compute(int fieldIX, const CQL2Identifier identifier, bool isFunction, FieldValue value, CartoExpFlags * flags)
   {
      // TODO: GeoDataCache cache = this.cache;
      int64 fid = featureID;
      /* TODO:
      if(!isFunction && cache && fieldIX != -1 && fid != -1)
      {
         AttributeQueryStatus status = cache.getCachedAttribute(fid, fieldIX, value);
         if(status == callAgain)
         {
            *flags |= { record = true, callAgain = true };
            value.type.type = nil;
         }
         flags->resolved = status == success;
         flags->isNotLiteral = true; //TOCHECK: verify if setting record=true instead would not break filterAndDeriveCells/pixels
      }
      else if(!isFunction && coverage && fieldIX != -1)
      {
         flags->isNotLiteral = true;
         if(fieldIX >= 0 && fieldIX < coverage->numBands)
         {
            // fieldIX will be a band
            // if filter evaluation returns false, then all bands get cleared to NODATA
            GriddedCoverageFeature * coverage = this.coverage;
            void * bandValues = coverage->valuesData;
            CoverageBand * band = &coverage->bands[fieldIX];
            // REVIEW: dimensions should always be set, but default to width / height if not to avoid crashes in case not all sources set it up proprerly
            int w = band->dimensions[0] ? band->dimensions[0] : coverage->width;
            int h = band->dimensions[1] ? band->dimensions[1] : coverage->height;
            uint yy = Min(h - 1, y * h / coverage->height);
            uint xx = Min(w - 1, x * w / coverage->width);
            uint ii = band->dimensions[2] ? Min(band->dimensions[2] - 1, i ) : 0;
            uint jj = band->dimensions[3] ? Min(band->dimensions[3] - 1, j ) : 0;
            uint kk = band->dimensions[4] ? Min(band->dimensions[4] - 1, k ) : 0;
            uint srcOffset = yy * band->dimensions[0] + xx;
            int b;

            if(ii || jj || kk)
               srcOffset += ((kk * band->dimensions[3] + jj) * band->dimensions[2] + ii) * w * h;

            for(b = 0; b < fieldIX; b++)
            {
               CoverageBand * pBand = &coverage->bands[b];
               uint numValues = pBand->dimensions[0] * pBand->dimensions[1]*
                  (pBand->dimensions[2] ? pBand->dimensions[2] : 1) *
                  (pBand->dimensions[3] ? pBand->dimensions[3] : 1) *
                  (pBand->dimensions[4] ? pBand->dimensions[4] : 1);

               if(pBand->type == integer16)
                  bandValues = (uint16 *)bandValues + numValues + (numValues & 1);
               else
                  bandValues = (float *)bandValues + numValues;
            }
            if(band->type == integer16)
            {
               uint16 noData = (uint16)band->noDataValue;
               uint16 v = ((uint16 *)bandValues)[srcOffset];
               if(v == noData)
                  value = { type = { nil } };
               else
                  value = { i = v, type = { integer } };
            }
            else
            {
               float noData = (float)band->noDataValue;
               float v = ((float *)bandValues)[srcOffset];
               if(v == noData)
                  value = { type = { nil } };
               else
                  value = { r = v, type = { real } };
            }
            flags->resolved = true;
         }
         else
            value = { type = { nil } };
      }
      else if(isFunction)
      {
         if(fieldIX != -1 || coverage)
         {
            // TODO: function support on coverage
            value = { type = { integer }, i = fieldIX };
            flags->resolved = true;
         }
         flags->isNotLiteral = true;
      }
      else*/
      {
         if(identifier.string)
         {
            if(!strcmpi(identifier.string, "viz"))
               flags->resolved = true;             // TODO: Review this? setting scale flag? -- That is done in evaluateMember
            else if(!strcmpi(identifier.string, "rec"))
               flags->resolved = true;
            else if(!strcmpi(identifier.string, "lyr") || !strcmpi(identifier.string, "dataLayer"))
               flags->resolved = true;
            else if(!strcmpi(identifier.string, "scene"))
               flags->resolved = true;
            else if(!strcmpi(identifier.string, "null"))
            {
               // NOTE: This currently handles the 'null' identifier
               // Computed with a feature ID, but identifier is not matched...
               // Mark as resolved so that e.g. conditions evaluate to false?
               flags->resolved = true;
               value.type.type = nil;
            }
            else if(!strcmpi(identifier.string, "false"))   // TODO: Could these have been converted to integer in preprocessing?
            {
               flags->resolved = true;
               value = { type = { integer, format = boolean }, i = 0 };
            }
            else if(!strcmpi(identifier.string, "true"))
            {
               flags->resolved = true;
               value = { type = { integer, format = boolean }, i = 1 };
            }
            else if(fid == -1) // TODO: && !coverage && !image)
               flags->record = true;
            else
            {
               flags->resolved = false;
               value.type.type = nil;
            }
         }
         else
            flags->record = true; // REVIEW: Assuming record?
      }
   }

#if 0
   /*virtual */Class computeAggregation(FieldValue value, const FieldValue * args, int numArgs, CQL2ExpList arguments, ExpFlags * flags)
   {
      Class expType = null;
      FieldValue e = args[1]; // Reducing operation function
      value = { { nil } };
      if(e.type.type == integer)
      {
         CQL2FunctionIndex fnIndex = (CQL2FunctionIndex)e.i;
         GriddedCoverageFeature * coverage = this.coverage;
         if(fnIndex >= min && fnIndex <= avg && coverage)
         {
            int i;
            CQL2Expression srcExpression = arguments[0];
            // CQL2Expression dimensions = arguments[2];
            const uint * slices = this.slices;
            int nSlices = coverage->bands[0].numDimensions > 2 ? (slices ? numSlices : coverage->bands[0].dimensions[2]) : 1;
            int backI = this.i;
            int nValues = 0;

            for(i = 0; i < nSlices; i++)
            {
               // REVIEW: Can we avoid copy if we avoid simplifyResolved() so that it does not get resolved to a constant?
               CQL2Expression expression = srcExpression; // .copy();
               FieldValue arg { };
               bool nonResolved = false;

               this.i = slices ? slices[i] : i;

               flags->resolved = false;
               *flags |= expression.compute(arg, this, runtime, null); //stylesClass);

               // NOTE: for interpolation handling use color format, ECCSSEvaluator_computeFunction does not have access to destType
               if(expression.destType == class(Color) && arg.type == { integer, format = hex })
                  arg.type = { integer, format = color };
               if(!flags->resolved)
                  nonResolved = true;

               if(nonResolved) flags->resolved = false;

               // Aggregation (assuming on ('time') for now)
               if(arg.type.type != nil)
               {
                  if(value.type.type == nil) // REVIEW: How to handle null value with avg() ?
                     value = arg;
                  else if(arg.type.type == real && value.type.type == real)
                  {
                     if(fnIndex == max && arg.r > value.r)
                        value = arg;
                     else if(fnIndex == min && arg.r < value.r)
                        value = arg;
                     else if(fnIndex == avg)
                        value.r += arg.r;
                  }
                  else if(arg.type.type == integer && value.type.type == integer)
                  {
                     if(fnIndex == max && arg.i > value.i)
                        value = arg;
                     else if(fnIndex == min && arg.i < value.i)
                        value = arg;
                     else if(fnIndex == avg)
                        value.i += arg.i;
                  }
                  nValues++;
               }
               //delete expression;
            }
            if(fnIndex == avg && nValues)
            {
               if(value.type.type == real)
                  value.r /= nValues;
               else if(value.type.type == integer)
                  value.i /= nValues;
            }
            this.i = backI;
         }
      }
      return expType;
   }
#endif

   void evaluateMember(DataMember prop, CQL2Expression exp, const FieldValue val, FieldValue value, CartoExpFlags * flags)
   {
      //write class, then "if viz.sd value = scale;
      if(exp.expType == class(CSVisualization)) //no handling for 'pass' so check if prop null
      {
         if(!strcmp(prop.name, "sd"))
         {
            // NOTE resolved was previously getting the entire expoperation deleted in bind
            if(scale)
            {
               value.r = scale;
               value.type = { real };
               flags->resolved = true;
               // When rendering multiple mipmaps, not always setting the scale flags was causing stroke spilling artifacts
               // 35077ef7f0246497784cd0af24ef50c6e9678b8f  Nov 12
               // Fixes for scale-based visibility rules, stroke spilling on neighboring tiles
               //if(!singleTileMode) // NOTE: Attempting instead to check whether sFlags.resolved in StylingRuleClock::apply2()
                  flags->scale = true;
            }
            else
               flags->scale = true;
         }
         else if(!strcmp(prop.name, "timeInterval"))
         {
            if(time.start != unsetTime || time.end != unsetTime)
            {
               value = { b = &time, type = { blob } };
               //flags->time = true;
               flags->resolved = true;
               // expType = class(TimeIntervalSince1970);
            }
         }
         else if(!strcmp(prop.name, "startTime"))
         {
            if(time.start != unsetTime)
            {
               value = { i = time.start, type = { integer, isDateTime = true } };
               flags->time = true;
               flags->resolved = true;
               //expType = class(TimeIntervalSince1970);
            }
         }
         else if(!strcmp(prop.name, "endTime"))
         {
            if(time.end != unsetTime)
            {
               value = { i = time.end, type = { integer, isDateTime = true } };
               flags->time = true;
               flags->resolved = true;
               //expType = class(TimeIntervalSince1970);
            }
         }
         /*
         else if(!strcmp(prop.name, "date"))
         else if(!strcmp(prop.name, "timeOfDay"))
         if(!strcmp(prop.name, "pass"))
         {
            value.r = scale;
            value.type = { real };
            flags->scale = true;
            flags->resolved = true;
         }*/
      }
      else if(exp.expType == class(CSRecord))
      {
         if(!strcmp(prop.name, "id"))
         {
            if(featureID != -1)
            {
               value = { { integer }, i = featureID };
               flags->resolved = true;
            }
            else
               flags->record = true;
         }
         else if(!strcmp(prop.name, "geom"))
         {
            if(featureID != -1)
            {
               value = { { nil } };
               if(featureGeometry)
                  value = { { blob }, b = featureGeometry };
               /* TODO:
               else if(cache)
               {
                  // FIXME: When featureGeometry is not set, this currently leaks the geometry
                  // TODO: GeoData data = cache.data;
                  Geometry * geometry;
                  int maxLevel = data ? data.availableZoomLevel : maxGGGZoomLevel;
                  int zoomLevelGGG = Min(scale ? levelFromScaleDenominator(scale) : maxGGGZoomLevel, maxLevel);
                  double epsilon = zoomLevelGGG != maxGGGZoomLevel ? Pi / (2 * 256 * 128 * (1LL << zoomLevelGGG)) : 0;
                  MapIterator<int64, Geometry> it { };
                  bool exists;
                  if(!geomMap)
                     geomMap = { };
                  it.map = geomMap;

                  exists = it.Index(featureID, true);
                  geometry = (Geometry *)it.GetData(); // Geometry now points to the struct value inside the Map entry

                  if(exists && epsilon != geometry->epsilon)
                     geometry->OnFree(), exists = false; // We need a different scale
                  if(!exists)
                  {
                     // TODO: We need a GeoData::getFeature() singular
                     Array<int64> featureIDs { [ featureID ] };
                     FeatureCollection fc = getFeatureCollection(data, featureIDs, null, null, null, null, false,
                        null, zoomLevelGGG, 999, -1, -1, false, 0, null);
                     delete featureIDs;
                     if(fc)
                     {
                        fc.stealFirstFeatureGeometry(geometry);
                        delete fc;
                     }
                     geometry->epsilon = epsilon;
                  }
                  value = { { blob }, b = geometry };
               }*/
               flags->resolved = true;
            }
            /* TODO: else if(coverage || image)
            {
               value = { { nil } };
               if(featureGeometry)
               {
                  value = { { blob }, b = featureGeometry };
                  flags->resolved = true;
               }
            } */
            else
               flags->record = true;
         }
      }
      else if(exp.expType == class(CSLayer))
      {
         if(!strcmp(prop.name, "type"))
         {
            // TODO:
            // value.s = cache.data.cscssID; //title;
            // value.type = { text };
            // flags->resolved = true;
         }
         /* TODO: if(!strcmp(prop.name, "id") && cache && cache.data)
         {
            if(!cache.data.cscssID)
               cache.data.cscssID = cache.data.getSanitizedLayerID();
            value.s = cache.data.cscssID; //title;
            value.type = { text };
            flags->resolved = true;
         }*/
      }
      if(exp.expType == class(CSScene))
      {
         if(!strcmp(prop.name, "id"))
         {
            if(sceneID)
            {
               value.s = CopyString(sceneID);
               value.type = { text, mustFree = true };
               flags->resolved = true;
            }
            else
               flags->scene = true;
         }
      }
   }

   const String stringFromMask(InstanceMask mask, Class c)
   {
      const String s = null;
      bool isGeo = eClass_IsDerived(c, class(CartoSymbolizer));
      bool isText = (eClass_IsDerived(c, class(TextSymbolizer)) || eClass_IsDerived(c, class(Text)));
      bool isImage = (eClass_IsDerived(c, class(ImageSymbolizer)) || eClass_IsDerived(c, class(Image)));
      bool isShape = (isGeo || eClass_IsDerived(c, class(ShapeSymbolizer)) || eClass_IsDerived(c, class(Shape)));
      bool isGraphic = (isText || isImage || isShape ||
         eClass_IsDerived(c, class(GraphicalSymbolizer)) || eClass_IsDerived(c, class(GraphicalElement)));
#ifdef _DEBUG
      if(!isGraphic)
         PrintLn("WARNING: Wrong usage of stringFromMask() with class ", c ? c.name : "(null)");
#endif
      if(mask)
      {
         if(      isGraphic) s =      stringFromMaskMap[mask];
         if(!s && isShape)   s = shapeStringFromMaskMap[mask];
         if(!s && isText)    s =  textStringFromMaskMap[mask];
         if(!s && isImage)   s = imageStringFromMaskMap[mask];
         if(!s && isGeo)     s =   geoStringFromMaskMap[mask];

#ifdef _DEBUG
         if(!s)
            PrintLn("WARNING: CartoSym failed to resolve mask ", (CartoSymbolizerMask)mask, " for ", c ? c.name : "(null)");
#endif
      }
      return s;
   }

   InstanceMask maskFromString(const String s, Class c)
   {
      CartoSymbolizerMask m = 0;
      bool isCarto = eClass_IsDerived(c, class(CartoSymbolizer));
      bool isText = (eClass_IsDerived(c, class(TextSymbolizer)) || eClass_IsDerived(c, class(Text)));
      bool isImage = (eClass_IsDerived(c, class(ImageSymbolizer)) || eClass_IsDerived(c, class(Image)));
      bool isShape = (isCarto || eClass_IsDerived(c, class(ShapeSymbolizer)) || eClass_IsDerived(c, class(Shape)));
      bool isGraphic = (isText || isImage || isShape ||
         eClass_IsDerived(c, class(GraphicalSymbolizer)) || eClass_IsDerived(c, class(GraphicalElement)));
#ifdef _DEBUG
      if(!isGraphic)
         PrintLn("WARNING: Wrong usage of maskFromString() with class ", c ? c.name : "(null)");
#endif

      if(      isGraphic) m = (CartoSymbolizerMask)graphicSymbolizerIdentifierMap[s];
      if(!m && isShape)   m = (CartoSymbolizerMask)  shapeSymbolizerIdentifierMap[s];
      if(!m && isText)    m = (CartoSymbolizerMask)   textSymbolizerIdentifierMap[s];
      if(!m && isImage)   m = (CartoSymbolizerMask)  imageSymbolizerIdentifierMap[s];
      if(!m && isCarto)   m = (CartoSymbolizerMask)  cartoSymbolizerIdentifierMap[s];

#ifdef _DEBUG
      if(!m)
         PrintLn("WARNING: CartoSym failed to resolve identifiers ", s, " for ", c ? c.name : "(null)");
#endif
      return m;
   }

   void applyStyle(CartoSymbolizer symbolizer, CartoSymbolizerKind mSet, FieldValue value, int unit, CQL2TokenType assignType)
   {
      switch(mSet)
      {
         case labelPriority:
         {
            CSLabel * label = &symbolizer.label;
            if(!*label) *label = { };
            label->priority   = (float)value.r;
            break;
         }
         case labelMinSpacing:
         {
            CSLabel * label = &symbolizer.label;
            if(!*label) *label = { };
            label->minSpacing = (float)value.r;
            break;
         }
         case labelMaxSpacing:
         {
            CSLabel * label = &symbolizer.label;
            if(!*label) *label = { };
            label->maxSpacing = (float)value.r;
            break;
         }
         case colorMap:
            symbolizer.colorMap = value.b;   // REVIEW:
            break;
         case opacityMap:
            symbolizer.opacityMap = value.b; // REVIEW:
            break;
         case hillShadingColorMap:
            symbolizer.hillShading.colorMap = value.b;
            break;
         case hillShadingFactor:
            symbolizer.hillShading.factor = value.r;
            break;
         case hillShadingSunAzimuth:
            symbolizer.hillShading.sun.azimuth = value.r;
            break;
         case hillShadingSunElevation:
            symbolizer.hillShading.sun.elevation = value.r;
            break;
         case hillShadingOpacityMap:
            symbolizer.hillShading.opacityMap = value.b;
            break;
         case extrusionBase:
            symbolizer.extrusion.base = (float)value.r;
            break;
         case extrusionHeight:
            symbolizer.extrusion.height = (float)value.r;
            break;
         case extrusionTerrainRelative:
            symbolizer.extrusion.terrainRelative = (bool)value.i;
            break;
         case colorChannelsR:
            symbolizer.colorChannels.r = (float)value.r;
            break;
         case colorChannelsG:
            symbolizer.colorChannels.g = (float)value.r;
            break;
         case colorChannelsB:
            symbolizer.colorChannels.b = (float)value.r;
            break;
         case colorChannelsA:
            symbolizer.colorChannels.a = (float)value.r;
            break;
         case singleChannel:
            symbolizer.singleChannel = value.r;
            break;
         default: ShapeSymbolizer::applyStyle(symbolizer, (ShapeSymbolizerKind)mSet, value, unit, assignType); break;
      }
   }

   Array<Instance> accessSubArray(CartoSymbolizer symbolizer, CartoSymbolizerKind mask)
   {
      Array<Instance> array = null;
      switch(mask)
      {
         case labelElements:
         {
            CSLabel * label = &symbolizer.label;
            if(!*label) *label = { };
            array = (Array<Instance>)label->elements;
            break;
         }
         case markerElements:
         {
            Marker * marker = &symbolizer.marker;
            if(!*marker) *marker = { };
            array = (Array<Instance>)marker->elements;
            break;
         }
         case colorMap:
            array = null; //(Array<Instance>)symbolizer.colorMap;   // REVIEW:
            break;
         case opacityMap:
            array = null; //(Array<Instance>)symbolizer.opacityMap; // REVIEW:
            break;
         case hillShadingColorMap:
            array = null; //(Array<Instance>)symbolizer.hillShading.colorMap;
            break;
         case hillShadingOpacityMap:
            array = null; //(Array<Instance>)symbolizer.hillShading.opacityMap;
            break;
      }
      return array;
   }

   void * computeInstance(CQL2Instantiation inst, Class destType, ExpFlags * flags, Class * expTypePtr)
   {
      // NOTE: flip the Lat,Lon order for now, assuming CRS84 for WKT and EPSG:4326 for CS by default
      bool flipCoords = true;
      void * instData = GraphicalSymbolizerEvaluator::computeInstance(inst, destType, flags, expTypePtr);

      if(inst && instData)
      {
         CQL2SpecName specName = inst._class;
         Class c = inst ? getClassFromInst(inst, destType, null) : null;

         if((c == class(GeoPoint) && specName) ||
            c == class(GeoExtent) || (c == class(LineString) && specName) || (c == class(Polygon) && specName) ||
            c == class(Array<Polygon>) || c == class(Array<LineString>) || c == class(Array<GeoPoint>) ||
            c == class(Array<Geometry>))
         {
            Geometry * geometry = new0 Geometry[1];
            if(c == class(GeoPoint))
            {
               GeoPoint * p = (GeoPoint *)instData;
               geometry->type = point;
               geometry->point = flipCoords ? { p->lon, p->lat } : *p;
               delete instData;
            }
            else if(c == class(GeoExtent))
            {
               GeoExtent * e = (GeoExtent *)instData;
               geometry->type = bbox;
               if(flipCoords)
                  e->ll = { e->ll.lon, e->ll.lat }, e->ur = { e->ur.lon, e->ur.lat };
               geometry->bbox = *e;
               delete instData;
            }
            else if(c == class(LineString))
            {
               LineString * l = (LineString *)instData;
               Array<GeoPoint> points = (Array<GeoPoint>)l->points;

               geometry->type = lineString;
               if(flipCoords && points)
                  flipPoints(points);
               geometry->lineString = *l;
               delete instData;
            }
            else if(c == class(Polygon))
            {
               Polygon * poly = (Polygon *)instData;
               Array<PolygonContour> contours = poly->getContours();
               geometry->type = polygon;
               if(contours)
               {
                  for(c : contours)
                     fixPointsContour(c, flipCoords);
               }
               geometry->polygon = *poly;
               delete instData;
            }
            else if(c == class(Array<Polygon>))
            {
               Array<Polygon> polygons = (Array<Polygon>)instData;
               geometry->type = multiPolygon;

               for(poly : polygons)
               {
                  Array<PolygonContour> contours = poly.getContours();
                  if(contours)
                  {
                     for(c : contours)
                        fixPointsContour(c, flipCoords);
                  }
               }
               geometry->multiPolygon = polygons;
               instData = null;
            }
            else if(c == class(Array<LineString>))
            {
               Array<LineString> lines = (Array<LineString>)instData;
               geometry->type = multiLineString;
               for(l : lines)
               {
                  Array<GeoPoint> points = (Array<GeoPoint>)l.points;
                  if(flipCoords && points)
                     flipPoints(points);
               }
               geometry->multiLineString = lines;
               instData = null;
            }
            else if(c == class(Array<GeoPoint>))
            {
               Array<GeoPoint> points = (Array<GeoPoint>)instData;
               geometry->type = multiPoint;
               if(flipCoords)
                  flipPoints(points);

               geometry->multiPoint = points;
               instData = null;
            }
            else if(c == class(Array<Geometry>))
            {
               Array<Geometry> geom = (Array<Geometry>)instData;
               geometry->type = geometryCollection;
               // TODO: refactor to flip points per geom type?
               for(g : geom)
               {
                  if(g.type == point)
                  {
                     GeoPoint p = g.point;
                     p = flipCoords ? { p.lon, p.lat } : p;
                  }
               }
               geometry->geometryCollection = geom;
            }

            instData = geometry;
            *expTypePtr = class(Geometry); // REVIEW: modified expType here vs.
                                           // a different one returned from getClassFromInst and set during preprocessing
         }
      }
      return instData;
   }

   // NOTE: located here because classes in eccss need corrected Geometry classes that have to be set in gnosis3 library
   Class getClassFromInst(CQL2Instantiation instance, Class destType, Class * stylesClassPtr)
   {
      Class c = null;
      CQL2SpecName specName = instance ? (CQL2SpecName)instance._class : null;
      if(specName && specName.name)
      {
         if(!strcmp(specName.name, "Point"))
            c = class(GeoPoint);
         else if(!strcmp(specName.name, "MultiPolygon"))
            c = class(Array<Polygon>);
         else if(!strcmp(specName.name, "MultiLineString"))
            c = class(Array<LineString>);
         else if(!strcmp(specName.name, "MultiPoint"))
            c = class(Array<GeoPoint>);
         else if(!strcmp(specName.name, "GeometryCollection"))
            c = class(Array<Geometry>);
         else if(!strcmp(specName.name, "TimeInterval"))
            c = class(TimeIntervalSince1970);
         else
            c = eSystem_FindClass(specName._class.module, specName.name);
      }
      else
         c = destType;
      if(c && stylesClassPtr && !*stylesClassPtr &&
         c != class(PolygonContour) &&
         !eClass_IsDerived(c, class(Array)))
         *stylesClassPtr = c;
      return c;
   }

   private static void fixPointsContour(PolygonContour contour, bool flipCoords)
   {
      Array<GeoPoint> points = (Array<GeoPoint>)contour.points;
      if(flipCoords)
         flipPoints(points);
      // Drop repeated last polygon contour points
      if(points.count >= 2 && points[0].lon == points[points.count-1].lon && points[0].lat == points[points.count-1].lat)
         points.size--;
   }

   private static void flipPoints(Array<GeoPoint> points)
   {
      int i;
      for(i = 0; i < points.count; i++)
         points[i] = { points[i].lon, points[i].lat };
   }
};
                                                              // REVIEW: May we need more than just Size?
public CartoStyle loadStyleSheetFile(File file, const String format, Map<String, Size> symbolSizes)
{
   CartoStyle result = null;

   if(!strcmp(format, "cscss"))
      result = CartoStyle::loadFile(file);
   /* TODO:
   else if(!strcmp(format, "sld"))
      result = loadSLD(null, null, file);
   else if(!strcmp(format, "json") || !strcmpi(format, "mbstyle") || !strcmpi(format, "mbs"))
      // avoid having to iterate and add to Size map for now
      result = loadMapboxgl(file, false, symbolSizes);
   */
   if(result && !result._refCount)
      incref result; // Return with a refCount of 1
   return result;
}

public CartoStyle loadStyleSheet(const String fileName)
{
   CartoStyle result = null;
   File f = fileName ? FileOpen(fileName, read) : null;
   if(f)
   {
      char ext[MAX_EXTENSION];

      GetExtension(fileName, ext);
      if(!ext[0])
      {
         char * q = strstr(fileName, "f=");
         if(q) strncpy(ext, q+2, MAX_EXTENSION-1);
         ext[MAX_EXTENSION-1] = 0;
      }
      result = loadStyleSheetFile(f, ext, null);
      delete f;
   }
   return result;
}

class ZSortedStylingRuleBlock : StylingRule
{
   int OnCompare(ZSortedStylingRuleBlock b)
   {
      int64 za = getStylesInt(this, zOrder, 0);
      int64 zb = getStylesInt(b, zOrder, 0);

      if(za > zb) return 1;
      if(za < zb) return -1;
      return 0;
   }
}

public bool writeStyleSheetFile(File file, const String format, const String name, CartoStyle sheet,
   Map<String, FeatureDataType> typeMap, SymbolsReferenceMode refMode, const String resourcesURL, const String dataBaseURL)
{
   bool result = false;
   if(sheet)
   {
      // Order rules by zOrder
      CartoStyle sorted { list = { } };
      List<ZSortedStylingRuleBlock> l { };

      if(refMode)
         applyResourceBaseURL(sheet.list, resourcesURL, refMode);

      for(r : sheet.list)
      {
         if(r._class == class(StylingRule))
         {
            StylingRule rb = (StylingRule)r;
            if(!rb.id || !rb.id.string || !rb.symbolizer || !((CartoSymbolizerMask)rb.symbolizer.mask).zOrder)
               sorted.list.Add(rb);
            else
               l.Add((ZSortedStylingRuleBlock)rb);
         }
      }
      l.Sort(true);
      for(r : l)
         sorted.list.Add(r);
      delete l;

      if(!format || !strcmp(format, "cscss"))
         result = sorted.writeFile(file);
      /* TODO:
      else if(!strcmp(format, "sld"))
         result = writeSLDFile(sorted, file, typeMap, refMode, resourcesURL); // this could probably use the typeMap as well if available
      else if(!strcmp(format, "json") || !strcmpi(format, "mbstyle") || !strcmpi(format, "mbs"))
      {
         FeatureDataType type0 = typeMap.count == 1 ? typeMap.root.value : { vector };
         bool isVector = type0.type == multi || type0.type == vector;
         // "https://services.interactive-instruments.de/t15/daraa/resources/sprites"
         // "https://services.interactive-instruments.de/t15/daraa/tiles/WebMercatorQuad/{z}/{y}/{x}?f=mvt"
         MapboxGLSourceData data
         {
            type = CopyString(isVector ? "vector" : "raster"),
            // tiles = { [ dataBaseURL ? PrintString(dataBaseURL, "/tiles/WebMercatorQuad/metadata") : CopyString("") ] },
            url = dataBaseURL ? PrintString(dataBaseURL, type0.type == coverage ? "/map" : "", "/tiles/WebMercatorQuad.tilejson") : CopyString(""),
            maxzoom = 17 // TODO: Pass this? data.availableZoomLevel+1; // WMQ is one more than GGG
         };
         const String sourceName = isVector ? "vectorSource" : "rasterSource";
         String sprite = PrintString(resourcesURL, "/sprites");
         if(!isVector) data.tileSize = 256;
         // bool ii = baseURL && SearchString(baseURL, 0, "interactive-instruments", false, false);
         result = writeMBGLFile(sorted, file, name, typeMap, sourceName, data, sprite, false, false, false);
         delete data;
         delete sprite;
      }
      */

      sorted.list.RemoveAll();
      delete sorted;
   }
   return result;
}

public bool writeStyleSheet(const String fileName, CartoStyle sheet, Map<String, FeatureDataType> typeMap)
{
   char ext[MAX_EXTENSION];
   char name[MAX_FILENAME];
   File f;
   bool result = true;

   GetLastDirectory(fileName, name);
   StripExtension(name);
   GetExtension(fileName, ext);
   f = FileOpen(fileName, write);
   if(f)
   {
      result = writeStyleSheetFile(f, ext, name, sheet, typeMap, { localFile = true }, null, null);
      //String testPass = "http://maps.ecere.com/geoapi/resources/";
      delete f;
   }
   return result;
}

public void applyResourceBaseURL(StyleBlockList list, const String baseURL, SymbolsReferenceMode refMode)
{
   for(b : list; b._class == class(StylingRule))
   {
      StylingRule block = (StylingRule)b;
      CQL2MemberInit mInit = block.symbolizer.findProperty(CartoSymbolizerKind::label);
      if(block.nestedRules) applyResourceBaseURL(block.nestedRules, baseURL, refMode);
      if(mInit)
      {
         // = l.findStyle(ImageStyleKind::image); // THIS returns improper value because the class is completely ignored, workaround
         CQL2Expression init = mInit.initializer;
         CQL2ExpInstance inst = init && init._class == class(CQL2ExpInstance) ? (CQL2ExpInstance)init : null;
         CQL2MemberInitList members = inst && inst.instance.members ? inst.instance.members[0] : null; //one array
         CQL2MemberInit arrMinit = members ? members[0] : null;
         CQL2ExpArray arr = arrMinit && arrMinit.initializer._class == class(CQL2ExpArray) ? (CQL2ExpArray)arrMinit.initializer : null;
         if(arr)
         {
            //PrintLn(arr.elements.list.count);
            for(e : arr.elements)
            {
               CQL2ExpInstance inst = e._class == class(CQL2ExpInstance) ? (CQL2ExpInstance)e : null;
               CQL2SpecName specName = inst ? (CQL2SpecName)inst.instance._class : null;
               if(specName && !strcmp(specName.name, "Image"))
               {
                  CQL2ExpInstance imageInstance = inst;
                  CQL2Expression imageExp = imageInstance.getMemberByIDs([ "image" ]);
                  if(imageExp && imageExp._class == class(CQL2ExpInstance))
                  {
                     CQL2ExpInstance imgInst = (CQL2ExpInstance)imageExp;
                     CQL2Expression idExp = imgInst.getMemberByIDs([ "id" ]);
                     CQL2Expression urlExp = imgInst.getMemberByIDs([ "url" ]);
                     CQL2Expression pathExp = imgInst.getMemberByIDs([ "path" ]);
                     CQL2Expression extExp = imgInst.getMemberByIDs([ "ext" ]);

                     if(refMode.id && !idExp)
                     {
                        if(pathExp)
                        {
                           const String s = pathExp && pathExp._class == class(CQL2ExpString) ? ((CQL2ExpString)pathExp).string : null;
                           if(s)
                           {
                              char id[MAX_LOCATION];
                              GetLastDirectory(s, id);
                              StripExtension(id);
                              imgInst.setMember("id", ImageStyleKind::imageId, true, CQL2ExpString { string = CopyString(id) });
                           }
                        }
                        else if(urlExp)
                        {
                           const String s = urlExp && urlExp._class == class(CQL2ExpString) ? ((CQL2ExpString)urlExp).string : null;
                           if(s)
                           {
                              char id[MAX_LOCATION];
                              const String q = strstr(s, "?");
                              String p;
                              if(q)
                              {
                                 int len = (int)(q-s);
                                 p = new char[len+1];
                                 memcpy(p, s, len);
                                 p[len] = 0;
                              }
                              else
                                 p = CopyString(s);
                              GetLastDirectory(p, id);
                              StripExtension(id);
                              imgInst.setMember("id", ImageStyleKind::imageId, true, CQL2ExpString { string = CopyString(id) });
                              if(p != q)
                                 delete p;
                           }
                        }
                        idExp = imgInst.getMemberByIDs([ "id" ]);
                     }
                     if(refMode.localFile && !pathExp)
                     {
                        if(idExp) // || urlExp eventually
                        {
                           const String idStr = idExp && idExp._class == class(CQL2ExpString) ? ((CQL2ExpString)idExp).string : null;
                           const String extStr = extExp && extExp._class == class(CQL2ExpString) ? ((CQL2ExpString)extExp).string : null;
                           if(idStr)
                           {
                              String path;
                              char curExt[MAX_EXTENSION];

                              GetExtension(idStr, curExt);
                              if(curExt[0] && (!strcmpi(curExt, "png") || !strcmpi(curExt, "svg")))
                              {
                                 path = PrintString("symbols/", idStr);
                                 ChangeExtension(path, "png", path);
                              }
                              else
                                 path = PrintString("symbols/", idStr, ".", extStr ? extStr : "png");
                              imgInst.setMember("path", ImageStyleKind::imagePath, true, CQL2ExpString { string = path });
                           }
                        }
                     }
                     if(refMode.url && !urlExp && baseURL)
                     {
                        const String idStr = idExp && idExp._class == class(CQL2ExpString) ? ((CQL2ExpString)idExp).string : null;
                        const String extStr = extExp && extExp._class == class(CQL2ExpString) ? ((CQL2ExpString)extExp).string : null;
                        if(idStr)
                        {
                           int len = strlen(baseURL);
                           bool addSlash = !len || baseURL[len-1] != '/';
                           String urlStr = PrintString(baseURL, addSlash ? "/" : "", idStr, ".", extStr ? extStr : "png");
                           imgInst.setMember("url", ImageStyleKind::imageUrl, true, CQL2ExpString { string = urlStr });
                        }
                     }
                  }
               }
            }
         }
      }
   }
}

public struct ColorOpacityMap
{
   Array<ValueColor> colorMap;
   Array<ValueOpacity> opacityMap;
   bool isDefault;

   void OnCopy(ColorOpacityMap b)
   {
      colorMap = b.colorMap; if(colorMap) incref colorMap;
      opacityMap = b.opacityMap; if(opacityMap) incref opacityMap;
      isDefault = b.isDefault;
   }

   void OnFree()
   {
      delete colorMap;
      delete opacityMap;
   }

   int OnCompare(ColorOpacityMap b)
   {
      if(this == null && b) return -1;
      if(this != null && !b) return 1;
      if(colorMap == b.colorMap && opacityMap == b.opacityMap) return 0;

      // Check for equivalent color maps...
      if(colorMap && !b.colorMap) return 1;
      if(!colorMap && b.colorMap) return -1;
      if(opacityMap && !b.opacityMap) return 1;
      if(!opacityMap && b.opacityMap) return -1;

      if(colorMap)
      {
         int i;

         if(colorMap.count > b.colorMap.count) return 1;
         if(colorMap.count < b.colorMap.count) return -1;

         for(i = 0; i < colorMap.count; i++)
         {
            if(colorMap[i].value > b.colorMap[i].value) return 1;
            if(colorMap[i].value < b.colorMap[i].value) return -1;
            if(colorMap[i].color > b.colorMap[i].color) return 1;
            if(colorMap[i].color < b.colorMap[i].color) return -1;
         }
      }

      if(opacityMap)
      {
         int i;

         if(opacityMap.count > b.opacityMap.count) return 1;
         if(opacityMap.count < b.opacityMap.count) return -1;

         for(i = 0; i < opacityMap.count; i++)
         {
            if(opacityMap[i].value > b.opacityMap[i].value) return 1;
            if(opacityMap[i].value < b.opacityMap[i].value) return -1;
            if(opacityMap[i].opacity > b.opacityMap[i].opacity) return 1;
            if(opacityMap[i].opacity < b.opacityMap[i].opacity) return -1;
         }
      }
      return 0;
   }

   #if 0 // FIXME:
   void OnDisplay(Surface surface, int x, int y, int width, void * fieldData, Alignment alignment, DataDisplayFlags displayFlags)
   {
      if(colorMap || opacityMap)
      {
         Array<ColorKey> keys { size = Max(colorMap ? colorMap.count : 0, opacityMap ? opacityMap.count : 0) };
         double minVal = MAXDOUBLE, maxVal = -MAXDOUBLE;
         int i;
         if(colorMap)
         {
            for(k : colorMap)
            {
               if(k.value < minVal) minVal = k.value;
               if(k.value > maxVal) maxVal = k.value;
            }
         }
         if(opacityMap)
         {
            for(k : opacityMap)
            {
               if(k.value < minVal) minVal = k.value;
               if(k.value > maxVal) maxVal = k.value;
            }
         }
         i = 0;
         if(colorMap)
         {
            for(k : colorMap)
            {
               keys[i] = { { 255, k.color }, (float)((k.value - minVal) / (maxVal - minVal)) };
               i++;
            }
         }
         else if(opacityMap)
         {
            // TODO: Improve mixed and either opacity/colors display
            for(k : opacityMap)
            {
               keys[i] = { { (byte)(k.opacity * 255), black }, (float)((k.value - minVal) / (maxVal - minVal)) };
               i++;
            }
         }

         surface.Gradient(keys.array, keys.count, 1, horizontal, x + 10, y + 1, x + width - 10, y + 15);
         surface.foreground = black;
         surface.Rectangle(x + 9, y, x + width - 9, y + 16);
         delete keys;
      }
      else
         surface.WriteTextf(x, y, $"(New...)");
   }
   #endif
};

CQL2Expression parseCSMultiLayerExpression(const String string)
{
   CQL2Expression result = null;
   int i = 0;
   Map<String, CQL2Expression> layers { };
   int state = 0; // 1: layer
   int start = 0;
   MapIterator<String, CQL2Expression> it { map = layers };
   CQL2Expression gExp = null;
   char quoteCH = 0;

   while(true)
   {
      char ch = string[i];

      if(state == 1)
      {
         if(!isalnum(ch))
         {
            int len = i - start;
            char * name = new byte[len + 1];
            memcpy(name, string + start, len);
            name[len] = 0;

            it.Index(name, true);
            delete name;

            state = 0;
         }
      }

      if(state == 0)
      {
         if(ch == '#')
         {
            state = 1;
            start = i + 1;
         }
         else if(ch == '[')
         {
            state = 2;
            start = i + 1;
         }
         else if(ch && !isspace(ch))
            break; // Error
      }
      else if(state == 2)
      {
         if(ch == ']')
         {
            int len = i - start;
            char * filter = new byte[len + 1];
            CQL2Expression oe, e;

            memcpy(filter, string + start, len);
            filter[len] = 0;

            e = parseCQL2Expression(filter);

            if(it.pointer)
               oe = it.data;
            else
               oe = gExp;

            if(oe)
               e = CQL2ExpOperation
               {
                  exp1 = oe._class == class(CQL2ExpBrackets) ? oe : CQL2ExpBrackets { list = { [ oe ] } },
                  op = and,
                  exp2 = CQL2ExpBrackets { list = { [ e ] } }
               };

            if(it.pointer)
               it.data = e;
            else
               gExp = e;

            delete filter;
            state = 0;
         }
         else if(ch == '\'' || ch == '"')
         {
            state = 3;
            quoteCH = ch;
         }
      }
      else if(state == 3 && ch == quoteCH)
      {
         state = 2;
      }
      i++;
      if(!ch) break;
   }

   if(layers.count)
   {
      if(layers.count > 1)
      {
         CQL2Expression orLayers = null;

         for(l : layers)
         {
            const String n = &l;
            CQL2Expression le = l;
            CQL2ExpOperation leOp
            {
               exp1 = CQL2ExpMember {
                     exp = CQL2ExpIdentifier { identifier = CQL2Identifier { string = CopyString("dataLayer") } },
                     member = CQL2Identifier { string = CopyString("id") }
                  },
               op = equal,
               exp2 = CQL2ExpString { string = CopyString(n) }
            };
            CQL2Expression leAnd = le ? CQL2ExpOperation
            {
               exp1 = leOp,
               op = and,
               exp2 = le._class == class(CQL2ExpBrackets) ? le : CQL2ExpBrackets { list = { [ le ] } }
            } : leOp;

            if(!orLayers)
            {
               orLayers = CQL2ExpBrackets { list = { [ leAnd ] } };
            }
            else
            {
               orLayers = CQL2ExpOperation
               {
                  exp1 = orLayers,
                  op = or,
                  exp2 = CQL2ExpBrackets { list = { [ leAnd ] } }
               };
            }
         }

         if(gExp)
         {
            result = CQL2ExpOperation
            {
               exp1 = CQL2ExpBrackets { list = { [ gExp ] } },
               op = and,
               exp2 = CQL2ExpBrackets { list = { [ orLayers ] } }
            };
         }
         else
            result = orLayers;
      }
      else
      {
         CQL2Expression l0 = layers.root.value;
         CQL2ExpOperation l0Op
         {
            exp1 = CQL2ExpMember {
                  exp = CQL2ExpIdentifier { identifier = CQL2Identifier { string = CopyString("dataLayer") } },
                  member = CQL2Identifier { string = CopyString("id") }
               },
            op = equal,
            exp2 = CQL2ExpString { string = CopyString(layers.root.key) }
         };
         CQL2Expression l0And = l0 ? CQL2ExpOperation
         {
            exp1 = l0Op,
            op = and,
            exp2 = l0._class == class(CQL2ExpBrackets) ? l0 : CQL2ExpBrackets { list = { [ l0 ] } }
         } : l0Op;

         if(gExp)
         {
            result = CQL2ExpOperation
            {
               exp1 = CQL2ExpBrackets { list = { [ gExp ] } },
               op = and,
               exp2 = l0And
            };
         }
         else
            result = l0And;
      }
   }
   else
      result = gExp;

   delete layers;

#ifdef _DEBUG
   if(result)
      PrintLn("final filter: ", result.toString(0));
#endif

   return result;
}
