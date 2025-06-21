public import IMPORT_STATIC "ecrt"
public import IMPORT_STATIC "GeoExtents"

import "VectorFeatures"

// TODO: Move all Raster stuff elsewhere
public enum RasterType { none, argb, bits8, bits16 };

public enum CoreFeatureType
{
   none,
   coverage,
   raster,
   vector,
   multi,
   elevation = coverage // for backward compatibility
};

public class FeatureDataType : uint
{
private:
   property RasterType rasterType { isset { return type == raster; } }
   // Backwards compatibility...
   property RasterType rType { isset { return false; } }

public:
   CoreFeatureType type:3:16;      // We have bits 18..31 free right now
   VectorType vectorType:3:0;
   RasterType rasterType:3:0;
   RasterType rType:3:0;

   // TODO: Organize these better, see if they're all needed
   bool is3D:1:19;      // True for 3D point clouds, models with Z components, pointZ/lineZ/polygonZ, embedded3DModel, vector3DPolygons
   bool isModel:1:20;   // If a vector/point (models3D/models3DGround) or polygon3D (embedded3DModel)
   bool hasMeasure:1:21;
   bool isContour:1:5;
   bool oldFormat64BitID:1:4;
   bool isTopo:1:6;
   bool isPointCloud:1:7;
   bool singlePoints:1:8;   // Store Id's per points
   bool hasColor:1:9, hasAlpha:1:10;
   bool measure32Bit:1:11;
   bool hasYaw:1:12, hasYawPitchRoll:1:13;
   bool hasScale:1:14, hasXYZScale:1:15;
   bool hasScanInfo:1:12;   // Use Id for classification, measure for intensity
   bool hasTexCoords:1:12, hasNormals:1:13, hasTangents:1:14;     // Apply Materials with style sheet per Id
}

public class FeatureCollection : private Array     // Do we want to keep this inheritance from Array, rather than having a features Array member to try to save overhead?
{
public:

   uint64 tileKey;  // REVIEW: Get rid of this?

   void setType(FeatureDataType value) // TOREVIEW: Currently not a property so as not to be first implied member of feature collection
   {
      this.type = value;
   }
   FeatureDataType getType() // TOREVIEW: Currently not a property so as not to be first implied member of feature collection
   {
      return type;
   }

private:
   FeatureDataType type;
   // TODO: CRS crs;
   uint64 storageSize;  // Perhaps
   // TileKey tileKey; // -- we probably don't want this here...
   HashMap<int64, Map<String, FieldValue>> keyMap;

   public void calculateExtent(GeoExtent extent)
   {
      extent.clear();

      if(type.type == vector && type.vectorType == polygons)
      {
         FeatureCollection<PolygonFeature> pfc = (FeatureCollection<PolygonFeature>)this;
         int i;
         for(i = 0; i < pfc.count; i++)
         {
            PolygonFeature * pf = &pfc[i];
            Array<Polygon> polygons = (Array<Polygon>)pf->geometry;
            if(polygons)
            {
               int j;

               for(j = 0; j < polygons.count; j++)
               {
                  Polygon * p = &polygons[j];
                  GeoExtent e;

                  p->calculateExtent(e);

                  extentUnionNoDL(extent, e); // REVIEW: Do we want DL version here?
               }
            }
         }
      }
      else if(type.type == vector && type.vectorType == lines)
      {
         FeatureCollection<LineFeature> pfc = (FeatureCollection<LineFeature>)this;
         int i;
         for(i = 0; i < pfc.count; i++)
         {
            LineFeature * pf = &pfc[i];
            Array<LineString> lines = (Array<LineString>)pf->geometry;
            if(lines)
            {
               int j;

               for(j = 0; j < lines.count; j++)
               {
                  LineString * l = &lines[j];
                  GeoExtent e;

                  l->calculateExtent(e);

                  extentUnionNoDL(extent, e); // REVIEW: Do we want DL version here?
               }
            }
         }
      }
      else if(type.type == vector && type.vectorType == points)
      {
         FeatureCollection<PointFeature> pfc = (FeatureCollection<PointFeature>)this;
         int i;
         uintsize featureSize = _class.templateArgs[0].dataTypeClass.structSize;
         for(i = 0; i < pfc.count; i++)
         {
            PointFeature * pf = (PointFeature *)((byte *)pfc.array + featureSize * i);
            Array<GeoPoint> points = (Array<GeoPoint>)pf->geometry;
            if(points)
            {
               int j;

               for(j = 0; j < points.count; j++)
               {
                  GeoPoint * p = &points[j];
                  addExtentPoint(extent, p); // REVIEW: This takes date line into consideration
               }
            }
         }
      }
   }

   bool fixContours()
   {
      bool changed = false;
      if(this && _class == class(FeatureCollection<PolygonFeature>))
      {
         FeatureCollection<PolygonFeature> pfc = (FeatureCollection<PolygonFeature>)this;
         int i;
         for(i = 0; i < pfc.count; i++)
         {
            PolygonFeature * feature = &pfc[i];
            Array<Polygon> geometry = (Array<Polygon>)*&feature->geometry;
            int p;
            for(p = 0; p < (geometry ? geometry.count : 0); p++)
               changed |= geometry[p].fixContours();
         }
      }
      return changed;
   }

   static void ::combineFeature(FeatureDataType dataType, uintsize featureSize, VectorFeature * f, VectorFeature * f1, VectorFeature * f2)
   {
      // Same feature: merge geometry
      switch(dataType.vectorType)
      {
         case points:
         {
            PointFeature * pf = (PointFeature *) f, * pf1 = (PointFeature *) f1, * pf2 = (PointFeature *) f2;
            Array<GeoPoint> g1 = (Array<GeoPoint>)*&pf1->geometry, g2 = (Array<GeoPoint>)*&pf2->geometry;

            memset(pf, 0, featureSize);
            if(g1)
            {
               int o = g1.count;
               uint g2Count = g2.count;
               g1.size = o + g2.size;
               memcpy(g1.array + o, g2.array, g2Count * sizeof(g2[0]));
               g2.size = 0;
               pf->id = pf1->id;
               *&pf->geometry = g1;

               if(dataType.is3D)
               {
                  Point3DFeature * p3d = (Point3DFeature *)pf;
                  Point3DFeature * p3d1 = (Point3DFeature *)pf1;
                  Point3DFeature * p3d2 = (Point3DFeature *)pf2;

                  p3d->depths = new Meters[g1.count];
                  memcpy(p3d->depths, p3d1->depths, o * sizeof(Meters));
                  memcpy(p3d->depths + o, p3d2->depths, g2Count * sizeof(Meters));
                  delete p3d1->depths;
                  delete p3d2->depths;

                  if(dataType.isModel)
                  {
                     Models3DFeature * mf = (Models3DFeature *)p3d;
                     Models3DFeature * mf1 = (Models3DFeature *)p3d1;
                     Models3DFeature * mf2 = (Models3DFeature *)p3d2;

                     mf->modelIDs = new ModelID[g1.count];
                     memcpy(mf->modelIDs, mf1->modelIDs, o * sizeof(ModelID));
                     memcpy(mf->modelIDs + o, mf2->modelIDs, g2Count * sizeof(ModelID));
                     delete mf1->modelIDs;
                     delete mf2->modelIDs;

                     if(mf1->orientations)
                     {
                        mf->orientations = (Degrees *)new Degrees[3 * g1.count];
                        memcpy(mf->orientations, mf1->orientations, o * sizeof(Degrees) * 3);
                        memcpy(mf->orientations + o, mf2->orientations, g2Count * sizeof(Degrees) * 3);
                        delete mf1->orientations;
                        delete mf2->orientations;
                     }

                     if(mf1->scales)
                     {
                        mf->scales = (float *)new float[3 * g1.count];
                        memcpy(mf->scales, mf1->scales, o * sizeof(float) * 3);
                        memcpy(mf->scales + o, mf2->scales, g2Count * sizeof(float) * 3);
                        delete mf1->scales;
                        delete mf2->scales;
                     }

                     if(mf1->ids)
                     {
                        mf->ids = new int64[g1.count];
                        memcpy(mf->ids, mf1->ids, o * sizeof(int64));
                        memcpy(mf->ids + o, mf2->ids, g2Count * sizeof(int64));
                        delete mf1->ids;
                        delete mf2->ids;

                     }
                  }
                  if(dataType.isPointCloud && dataType.hasScanInfo)
                  {
                     PointCloudFeature * pcf = (PointCloudFeature *)p3d;
                     PointCloudFeature * pcf1 = (PointCloudFeature *)p3d1;
                     PointCloudFeature * pcf2 = (PointCloudFeature *)p3d2;

                     pcf->scanInfo = new PCScanInfo[g1.count];
                     memcpy(pcf->scanInfo, pcf1->scanInfo, o * sizeof(PCScanInfo));
                     memcpy(pcf->scanInfo + o, pcf2->scanInfo, g2Count * sizeof(PCScanInfo));
                     delete pcf1->scanInfo;
                     delete pcf2->scanInfo;
                  }
               }

               if(pf1->colors)
               {
                  pf->colors = (uint32 *)new uint32[g1.count];
                  memcpy(pf->colors, pf1->colors, o * sizeof(uint32));
                  memcpy(pf->colors + o, pf2->colors, g2Count * sizeof(uint32));
                  delete pf1->colors;
                  delete pf2->colors;
               }
               if(pf1->measures)
               {
                  pf->measures = new double[g1.count];
                  memcpy(pf->measures, pf1->measures, o * sizeof(double));
                  memcpy(pf->measures + o, pf2->measures, g2Count * sizeof(double));
                  delete pf1->measures;
                  delete pf2->measures;
               }
               delete g2;
               // TODO: ids array mode
            }
            else
            {
               *&pf->geometry = g2;
               pf->id = pf2->id;
               if(dataType.is3D)
               {
                  Point3DFeature * p3d = (Point3DFeature *)pf;
                  Point3DFeature * p3d1 = (Point3DFeature *)pf1;
                  Point3DFeature * p3d2 = (Point3DFeature *)pf2;

                  p3d->depths = p3d2->depths;
                  delete p3d1->depths;

                  if(dataType.isModel)
                  {
                     Models3DFeature * mf = (Models3DFeature *)p3d;
                     Models3DFeature * mf1 = (Models3DFeature *)p3d1;
                     Models3DFeature * mf2 = (Models3DFeature *)p3d2;

                     mf->modelIDs = mf2->modelIDs;
                     delete mf1->modelIDs;

                     mf->orientations = mf2->orientations;
                     delete mf1->orientations;

                     mf->scales = mf2->scales;
                     delete mf1->scales;

                     mf->ids = mf2->ids;
                     delete mf1->ids;
                  }
               }

               pf->colors = pf2->colors;
               delete pf1->colors;

               pf->measures = pf2->measures;
               delete pf1->measures;
            }
            break;
         }
         case lines:
         {
            LineFeature * lf = (LineFeature *) f, * lf1 = (LineFeature *) f1, * lf2 = (LineFeature *) f2;
            Array<LineString> g1 = (Array<LineString>)*&lf1->geometry, g2 = (Array<LineString>)*&lf2->geometry;
            if(g1)
            {
               int o = g1.count;
               g1.size = o + g2.size;
               memcpy(g1.array + o, g2.array, g2.count * sizeof(g2[0]));
               g2.size = 0;
               delete g2;
               lf->id = lf1->id;
               *&lf->geometry = g1;
            }
            else
            {
               *&lf->geometry = g2;
               lf->id = f2->id;
            }
            break;
         }
         case polygons:
         {
            PolygonFeature * pf = (PolygonFeature *) f, * pf1 = (PolygonFeature *) f1, * pf2 = (PolygonFeature *) f2;
            Array<Polygon> g1 = (Array<Polygon>)*&pf1->geometry, g2 = (Array<Polygon>)*&pf2->geometry;

            if(g1)
            {
               int o = g1.count;
               g1.size = o + g2.size;
               memcpy(g1.array + o, g2.array, g2.count * sizeof(g2[0]));
               g2.size = 0;
               delete g2;
               pf->id = pf1->id;
               *&pf->geometry = g1;
            }
            else
            {
               *&pf->geometry = g2;
               pf->id = f2->id;
            }
            break;
         }
      }
   }

   // This method moves features from collection 'b' together with the features of corresponding IDs in this collection
   // NOTE: Expects features sorted by IDs (and occurring only once)!
   FeatureCollection combineFeatures(FeatureCollection b, bool skipEmpty)
   {
      FeatureCollection fc = this;
      if(!this && !b) return null;
      if(!this)
      {
         //return b; // Can we just return b?

         fc = eInstance_New(b._class); // FIXME: Using 'this' directly is broken
         this = fc;
         fc.type = b.type;
      }

      if(fc && fc.type.type == vector && b && b.type.type == vector)
      {
         bool sameType = fc.type == b.type;
         FeatureDataType dataType = fc.type;
         uint featureSize1 = fc._class.templateArgs[0].dataTypeClass.structSize;
         uint featureSize2 = b._class.templateArgs[0].dataTypeClass.structSize;
         int i = 0, j = 0;
         int f1Count = fc.count, f2Count = b.count;
         byte * combined = new byte[featureSize1 * (f1Count + f2Count)];
         byte * array1 = (byte *)fc.array, * array2 = (byte *)b.array;
         VectorFeature * f1 = i < f1Count ? (VectorFeature *)(array1 + (featureSize1 * i)) : null;
         VectorFeature * f2 = j < f2Count ? (VectorFeature *)(array2 + (featureSize2 * j)) : null;
         VectorFeature * f = (VectorFeature *)combined;
         int d = 0;

         // Skip null or empty geometry for added features
         if(skipEmpty)
            while(f2 && dataType.vectorType != none && (!((PointFeature *)f2)->geometry || !((Array)((PointFeature *)f2)->geometry).count))
               f2 = ++j < f2Count ? (VectorFeature *)((byte *)f2 + featureSize2) : null;

         while(f1 || f2)
         {
            if(f1 && f2 && f1->id == f2->id)
            {
               if(sameType)
                  combineFeature(dataType, featureSize1, f, f1, f2);
               f1 = ++i < f1Count ? (VectorFeature *)((byte *)f1 + featureSize1) : null;
               f2 = ++j < f2Count ? (VectorFeature *)((byte *)f2 + featureSize2) : null;
            }
            else if(f1 && (!f2 || f1->id < f2->id))
            {
               // Add feature from this collection
               // We keep the type of the first collection so we can safely copy the whole feature here
               memcpy(f, f1, featureSize1);
               f1 = ++i < f1Count ? (VectorFeature *)((byte *)f1 + featureSize1) : null;
            }
            else
            {
               // Add feature from collection being combined
               VectorFeature * prev = d ? (VectorFeature *)((byte *)f - featureSize1) : null;
               if(prev && prev->id == f2->id)
               {
                  // Duplicate feature id in added features... Combine those
                  if(sameType)
                  {
                     Models3DFeature tmp; // Models3DFeature is biggest struct for now...
                     combineFeature(dataType, featureSize1, (VectorFeature *)&tmp, prev, f2);
                     d--, f = prev;
                     memcpy(f, tmp, featureSize1);
                  }
                  else
                     d--, f = prev;
               }
               else
               {
                  if(sameType)
                     memcpy(f, f2, featureSize1);
                  else
                  {
                     memset(f, 0, featureSize1);
                     memcpy(f, f2, sizeof(VectorFeature));
                  }
               }

               f2 = ++j < f2Count ? (VectorFeature *)((byte *)f2 + featureSize2) : null;
            }
#ifdef _DEBUG
            if(!((VectorFeature *)(combined + d * featureSize1))->id)
            {
               if(fc.type.vectorType != points || (!((PointFeature *)(combined + d * featureSize1))->ids && ((PointFeature *)(combined + d * featureSize1))->geometry))
                  PrintLn("Bug?");
            }
#endif
            d++, f = (VectorFeature *)((byte *)f + featureSize1);

            // Skip null or empty geometry for added features
            if(skipEmpty)
               while(f2 && dataType.vectorType != none && (!((PointFeature *)f2)->geometry || !((Array)((PointFeature *)f2)->geometry).count))
                  f2 = ++j < f2Count ? (VectorFeature *)((byte *)f2 + featureSize2) : null;
         }
         b.size = 0;
         delete *&fc.array;
         *&fc.array = (void *)renew combined byte[featureSize1 * d];
         fc.count = d;
      }
      delete b;
      return this;
   }

   void stealFirstFeatureGeometry(Geometry geometry)
   {
      if(count)
      {
         VectorFeature * vf = (VectorFeature *)array;
         vf->getGeometry(type.vectorType, geometry, true);
      }
      else
         geometry = { };
   }

   ~FeatureCollection()
   {
      eSystem_LockMem();
      Free(); // This frees the individual Feature elements of the array
      if(keyMap) keyMap.Free(), delete keyMap;
      eSystem_UnlockMem();
   }
}

public struct RecordField
{
   String name;
   FieldTypeEx type;   // TOCHECK: Can we extend this to FieldTypeEx for finer control?
   String description;
   int id;

   void OnCopy(RecordField b)
   {
      name = CopyString(b.name);
      description = CopyString(b.description);
      type = b.type;
      id = b.id;
   }

   void OnFree()
   {
      delete name;
      delete description;
   }
   int OnCompare(RecordField b)
   {
      // NOTE: Case insensitive for now...
      return strcmpi(this.name, b.name); // for use of Find in newlyNeededOrUpdated(), GeoDataCache.ec
   }
};

public class MinimalAttributeStore
{
public:
   property Array<RecordField> fields
   {
      get { return getFieldsList(); }
   }

   virtual Array<RecordField> getFieldsList() { return null; }
   virtual int getFieldIndex(const String name)
   {
      Array<RecordField> fields = getFieldsList();
      if(fields)
      {
         int i;
         for(i = 0; i < fields.count; i++)
         {
            if(strcmpi(fields[i].name, name) == 0)
               return i;
         }
      }
      return -1;
   }
   virtual bool getValue(int64 featureID, int fieldIX, FieldValue value) { value = { { nil } }; return false; }
   virtual Array<int64> queryAllRecords() { return null; }
   virtual Array<int64> validateRecords(Array<int64> featureIDs) { return { featureIDs }; }
   virtual FieldValue * getAllValues(int64 featureID, FieldValue * buffer, uint allocCount)
   {
      FieldValue * values = null;
      Array<RecordField> fields = getFieldsList();

      if(fields && fields.count)
      {
         int i;

         values = buffer && allocCount == fields.count ? buffer : new0 FieldValue[fields.count];   // REVIEW: New 0 here ?
         for(i = 0; i < fields.count; i++)
            getValue(featureID, i, values[i]);
      }
      return values;
   }
}
