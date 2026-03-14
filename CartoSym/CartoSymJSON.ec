import "ecrt"
import "CartoStyle"
import "CartoSymbolizer"

class CSJSONStyle
{
public:
   List<CSJSONStylingRule> stylingRules;
   CSJSONMetadata metadata;

   ~CSJSONStyle()
   {
      if(stylingRules)
      {
         stylingRules.Free();
         delete stylingRules;
      }

      delete metadata;
   }
}

class CSJSONStylingRule
{
   FieldValue selector;
public:
   property FieldValue selector
   {
      isset { return selector.type.type != 0; }
      get { value = selector; }
      set { selector = value; }
   }
   CSJSONSymbolizer symbolizer;
   List<CSJSONStylingRule> nestedRules;
   String name;

   ~CSJSONStylingRule()
   {
      if(nestedRules)
      {
         nestedRules.Free();
         delete nestedRules;
      }

      delete symbolizer;
      delete name;

      selector.OnFree();
   }
}

class CSJSONMetadata
{
public:
   String title;
   String abstract;

   ~CSJSONMetadata()
   {
      delete title;
      delete abstract;
   }
}

class CSJSONSymbolizer
{
   FieldValue visibility;
   FieldValue zOrder;
   FieldValue opacity;
   FieldValue singleChannel;
   FieldValue colorChannels;
   FieldValue alphaChannel;
   FieldValue colorMap;
   FieldValue hillShading;
   FieldValue fill;
   FieldValue stroke;
   FieldValue marker;
   FieldValue label;

public:
   property FieldValue zOrder     { isset { return zOrder.type.type != 0; }     get { value = zOrder; }     set { zOrder = zOrder; } }
   property FieldValue opacity    { isset { return opacity.type.type != 0; }    get { value = opacity; }    set { visibility = opacity; } }
   property FieldValue visibility { isset { return visibility.type.type != 0; } get { value = visibility; } set { visibility = value; } }
   property FieldValue singleChannel { isset { return singleChannel.type.type != 0; } get { value = singleChannel; } set { singleChannel = value; } }
   property FieldValue alphaChannel { isset { return alphaChannel.type.type != 0; } get { value = alphaChannel; } set { alphaChannel = value; } }
   property FieldValue colorChannels { isset { return colorChannels.type.type != 0; } get { value = colorChannels; } set { colorChannels = value; } }
   property FieldValue colorMap { isset { return colorMap.type.type != 0; } get { value = colorMap; } set { colorMap = value; } }
   property FieldValue hillShading { isset { return hillShading.type.type != 0; } get { value = hillShading; } set { hillShading = value; } }
   property FieldValue fill        { isset { return fill.type.type != 0; } get { value = fill; } set { fill = value; } }
   property FieldValue stroke      { isset { return stroke.type.type != 0; } get { value = stroke; } set { stroke = value; } }
   property FieldValue marker      { isset { return marker.type.type != 0; } get { value = marker; } set { marker = value; } }
   property FieldValue label       { isset { return label.type.type != 0; } get { value = label; } set { label = value; } }

   ~CSJSONSymbolizer()
   {
      visibility.OnFree();
      zOrder.OnFree();
      opacity.OnFree();
      singleChannel.OnFree();
      colorChannels.OnFree();
      alphaChannel.OnFree();
      colorMap.OnFree();
      hillShading.OnFree();
      fill.OnFree();
      stroke.OnFree();
      marker.OnFree();
      label.OnFree();
   }
}

/*static */public void toCQL2JSON(CQL2Expression v, FieldValue out, Class type)
{
   CQL2Expression normalized = normalizeCQL2(v);
   if(type) normalized.destType = type;
   normalized.toCQL2JSON(out);
   delete normalized;
}

static void alterCQL2JSON(CQL2Expression v, FieldValue out, const String subProperties, Class type, int index)
{
   if(out.type.type == 0 || out.type.type == map)
   {
      FieldValue subOut { };
      DataMember member;
      Property prop;

      if(out.type.type == 0)
      {
         out.type = { type = map, mustFree = true };
         out.m = { };
      }

      member = eClass_FindDataMember(type, subProperties, type.module, null, null);
      if(member)
      {
         if(!member.dataTypeClass)
            member.dataTypeClass = eSystem_FindClass(type.module, member.dataTypeString);
         v.destType = member.dataTypeClass;
      }
      else if((prop = eClass_FindProperty(type, subProperties, type.module)))
      {
         if(!prop.dataTypeClass)
            prop.dataTypeClass = eSystem_FindClass(type.module, prop.dataTypeString);
         v.destType = prop.dataTypeClass;
      }

      // TODO: Support deeper nesting
      out.m["alter"] = FieldValue { type = { integer, format = boolean }, i = 1 };
      if(index != -1)
      {
         FieldValue value { };
         toCQL2JSON(v, value, v.destType);
         subOut = FieldValue { type = { map, mustFree = true }, m = { } };
         subOut.m["index"] = FieldValue { type = { integer }, i = index };
         subOut.m["value"] = value;
      }
      else
         toCQL2JSON(v, subOut, v.destType);
      out.m[subProperties] = subOut;
   }
}

void convertSymbolizer(SymbolizerProperties s, CSJSONSymbolizer symbolizer)
{
   for(i : s)
   {
      CQL2MemberInitList il = i;

      if(il)
      {
         for(ii : il)
         {
            CQL2MemberInit mi = ii;
            if(mi)
            {
               CQL2Expression k = mi.lhValue;
               CQL2Expression v = mi.initializer;
               // CQL2TokenType assignType = mi.assignType;
               // Class c = mi.destType;

               if(k && v)
               {
                  if(k._class == class(CQL2ExpIdentifier))
                  {
                     CQL2ExpIdentifier expId = (CQL2ExpIdentifier)k;
                     CQL2Identifier identifier = expId.identifier;
                     const String is = identifier.string;

                     if(!strcmpi(is, "visibility"))   toCQL2JSON(v, *&symbolizer.visibility, class(bool));
                     else if(!strcmpi(is, "zOrder"))  toCQL2JSON(v, *&symbolizer.zOrder, class(int));
                     else if(!strcmpi(is, "opacity")) toCQL2JSON(v, *&symbolizer.opacity, class(double));
                     else if(!strcmpi(is, "singleChannel")) toCQL2JSON(v, *&symbolizer.singleChannel, class(double));
                     else if(!strcmpi(is, "alphaChannel")) toCQL2JSON(v, *&symbolizer.alphaChannel, class(double));
                     else if(!strcmpi(is, "colorChannels")) toCQL2JSON(v, *&symbolizer.colorChannels, class(ColorRGB));
                     else if(!strcmpi(is, "colorMap")) toCQL2JSON(v, *&symbolizer.colorMap, class(Array<ValueColor>));
                     else if(!strcmpi(is, "hillShading")) toCQL2JSON(v, *&symbolizer.hillShading, class(HillShading));
                     else if(!strcmpi(is, "fill")) toCQL2JSON(v, *&symbolizer.fill, class(Fill));
                     else if(!strcmpi(is, "stroke")) toCQL2JSON(v, *&symbolizer.stroke, class(Stroke));
                     else if(!strcmpi(is, "marker")) toCQL2JSON(v, *&symbolizer.marker, class(Marker));
                     else if(!strcmpi(is, "label")) toCQL2JSON(v, *&symbolizer.label, class(CSLabel));
                     else if(!strcmpi(is, "fill.color"))
                        alterCQL2JSON(v, *&symbolizer.fill, "color", class(Fill), -1);
                     else if(!strcmpi(is, "stroke.color"))
                        alterCQL2JSON(v, *&symbolizer.stroke, "color", class(Stroke), -1);
                     else if(!strcmpi(is, "stroke.width"))
                        alterCQL2JSON(v, *&symbolizer.stroke, "width", class(Stroke), -1);
                  }
                  else if(k._class == class(CQL2ExpIndex))
                  {
                     CQL2ExpIndex expIndex = (CQL2ExpIndex)k;
                     CQL2Expression e = expIndex.exp;

                     if(e && e._class == class(CQL2ExpIdentifier))
                     {
                        CQL2ExpIdentifier expId = (CQL2ExpIdentifier)e;
                        CQL2Identifier identifier = expId.identifier;
                        const String is = identifier.string;
                        Iterator<CQL2Expression> it { expIndex.index };
                        CQL2ExpConstant c;

                        it.Next();
                        c = (CQL2ExpConstant)it.data;

                        if(c && c._class == class(CQL2ExpConstant))
                        {
                           if(!strcmpi(is, "marker.elements"))
                              alterCQL2JSON(v, *&symbolizer.marker, "elements", class(Marker), (int)c.constant.i);
                        }
                     }
                  }
               }
            }
         }
      }
   }
}

CSJSONStylingRule convertStylingRule(StylingRule r)
{
   CSJSONStylingRule rule { };

   if(r.symbolizer)
   {
      rule.symbolizer = { };
      convertSymbolizer(r.symbolizer, rule.symbolizer);
   }

   if(r.id)
   {
      Map<String, FieldValue> m { };
      FieldValue did { type = { text }, s = (String)CopyString("dataLayer.id") };
      // FIXME: This syntax currently does not work when key or value is struct as it uses 'value' property
      //Map<String, FieldValue> didMap { [ { "sysId", did } ] };
      Map<String, FieldValue> didMap { };
      didMap["sysId"] = did;
      m["op"] = FieldValue { type = { text }, s = (String)"=" };
      m["args"] = {
         type = { array, mustFree = true },
         a = Array<FieldValue> { [
            {
               type = { map, mustFree = true },
               m = didMap
            },
            { type = { text }, s = r.id.string }
         ] }
      };
      rule.selector = { type = { map, mustFree = true } , m = m };
   }

   if(r.selectors)
   {
      for(s : r.selectors)
      {
         if(!rule.selector.type)
         {
            // NOTE: The following does not work
            // s.exp.toCQL2JSON(rule.selector);

            FieldValue fv = rule.selector;
            CQL2Expression e = s.exp;
            toCQL2JSON(e, fv, null);
            rule.selector = fv;
         }
         else
         {
            FieldValue thisSelector { };
            Array<FieldValue> andArgs = null;

            toCQL2JSON(s.exp, thisSelector, null);

            if(rule.selector.type.type == map && rule.selector.m)
            {
               FieldValue fv = rule.selector.m["op"];
               if(fv.type.type == text && !strcmp(fv.s, "and"))
               {
                  fv = rule.selector.m["args"];
                  if(fv.type.type == array)
                     andArgs = fv.a;
               }
            }

            if(!andArgs)
            {
               Map<String, FieldValue> andMap { };

               andArgs = { };
               andMap["op"] = { type = { text }, s = (String)"and" };
               andMap["args"] = { type = { array }, a = andArgs };

               andArgs.Add(rule.selector);

               rule.selector = { type = { map, mustFree = true }, m = andMap };
            }

            andArgs.Add(thisSelector);
         }
      }
   }

   if(r.nestedRules)
   {
      rule.nestedRules = { };

      for(nr : r.nestedRules)
      {
         if(nr._class == class(StylingRule))
         {
            CSJSONStylingRule csr = convertStylingRule((StylingRule)nr);
            rule.nestedRules.Add(csr);
         }
      }
   }
   return rule;
}

CSJSONStyle convertToCSJSON(CartoStyle in)
{
   CSJSONStyle style { };

   if(in && in.list)
   {
      for(b : in.list)
      {
         if(b._class == class(StylingRule))
         {
            StylingRule m = (StylingRule)b;

            if(!style.stylingRules) style.stylingRules = { };

            style.stylingRules.Add(convertStylingRule(m));
         }
         else if(b._class == class(StyleMetadata))
         {
            StyleMetadata m = (StyleMetadata)b;
            const String id = m.type ? m.type.string : null;

            if(id)
            {
               if(!style.metadata) style.metadata = { };

               if(!strcmp(id, "title"))
                  style.metadata.title = m.value ? CopyString(m.value.string) : null;
               else if(!strcmp(id, "abstract"))
                  style.metadata.abstract = m.value ? CopyString(m.value.string) : null;
            }
         }
      }
   }
   return style;
}

static void setSymInitializer(SymbolizerProperties symbolizer, const String prop, /*const*/ FieldValue value, Class type)
{
   CQL2MemberInit memberInit { };
   CQL2MemberInitList initList { [ memberInit ] };

   // TODO: handle alter
   memberInit.lhValue = CQL2ExpIdentifier { identifier = { string = CopyString(prop) } };
   memberInit.initializer = convertCQL2JSONEx(value, type);
   memberInit.assignType = equal;
   /*if(memberInit.initializer)
   {
      PrintLn(memberInit.initializer._class.name);
      if(memberInit.initializer._class == class(CQL2ExpConstant))
      {
         CQL2ExpConstant c = (CQL2ExpConstant)memberInit.initializer;
         PrintLn(c.constant);
      }
   }*/

   symbolizer.Add(initList);
}

SymbolizerProperties convertCSJSONSymbolizer(CSJSONSymbolizer s)
{
   SymbolizerProperties symbolizer { };

   if(s.visibility.type.type)
      setSymInitializer(symbolizer, "visibility", s.visibility, class(bool));
   if(s.zOrder.type.type)
      setSymInitializer(symbolizer, "zOrder", s.zOrder, class(int));
   if(s.opacity.type.type)
      setSymInitializer(symbolizer, "opacity", s.opacity, class(double));
   if(s.singleChannel.type.type)
      setSymInitializer(symbolizer, "singleChannel", s.singleChannel, class(double));
   if(s.colorChannels.type.type)
      setSymInitializer(symbolizer, "colorChannels", s.colorChannels, class(ColorRGB));
   if(s.alphaChannel.type.type)
      setSymInitializer(symbolizer, "alphaChannel", s.alphaChannel, class(double));
   if(s.colorMap.type.type)
      setSymInitializer(symbolizer, "colorMap", s.colorMap, class(Array<ValueColor>));
   if(s.hillShading.type.type)
      setSymInitializer(symbolizer, "hillShading", s.hillShading, class(HillShading));
   if(s.fill.type.type)
      setSymInitializer(symbolizer, "fill", s.fill, class(Fill));
   if(s.stroke.type.type)
      setSymInitializer(symbolizer, "stroke", s.stroke, class(Stroke));
   if(s.marker.type.type)
      setSymInitializer(symbolizer, "marker", s.marker, class(Marker));
   if(s.label.type.type)
      setSymInitializer(symbolizer, "label", s.label, class(CSLabel));
   return symbolizer;
}

StylingRule convertCSJSONStylingRule(CSJSONStylingRule r)
{
   StylingRule rule { };

   if(r.selector.type.type && r.selector.type.type != nil)
   {
      StylingRuleSelector selector { exp = convertCQL2JSONEx(r.selector, class(bool)) };

      rule.selectors = { [ selector ] };
   }

   if(r.symbolizer)
   {
      rule.symbolizer = convertCSJSONSymbolizer(r.symbolizer);
   }

   if(r.nestedRules && r.nestedRules.count)
   {
      rule.nestedRules = { };
      for(nr : r.nestedRules)
         rule.nestedRules.Add(convertCSJSONStylingRule(nr));
   }
   return rule;
}

CartoStyle convertFromCSJSON(CSJSONStyle in)
{
   CartoStyle style { };

   if(in && in.stylingRules && in.stylingRules.count)
   {
      StyleBlockList rules { };

      style.list = rules;

      if(in.metadata)
      {
         if(in.metadata.title)
         {
            StyleMetadata title
            {
               type = { string = CopyString("title") },
               value = { string = CopyString(in.metadata.title) }
            };
            rules.Add(title);
         }
         if(in.metadata.abstract)
         {
            StyleMetadata abstract
            {
               type = { string = CopyString("abstract") },
               value = { string = CopyString(in.metadata.abstract) }
            };
            rules.Add(abstract);
         }
      }

      for(r : in.stylingRules)
      {
         CSJSONStylingRule rule = r;

         style.list.Add(convertCSJSONStylingRule(rule));
      }
   }
   return style;
}

public bool writeCSJSON(CartoStyle style, const String outputFile)
{
   bool result = false;
   File f = FileOpen(outputFile, write);
   if(f)
   {
      CSJSONStyle csJSON = convertToCSJSON(style);

      WriteJSONObject2(f, class(CSJSONStyle), csJSON, 0, keepCase);

      result = true;

      delete f;
   }
   return result;
}

public CartoStyle loadCSJSON(File f)
{
   CartoStyle result = null;
   if(f)
   {
      JSONParser parser { f = f };
      CSJSONStyle csJSON = null;
      JSONResult r = parser.GetObject(class(CSJSONStyle), &csJSON);

      if(r == success && csJSON)
         result = convertFromCSJSON(csJSON);
      delete csJSON;
      delete parser;
   }
   return result;
}
