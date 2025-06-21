# libCartoSym
A Free and Open-Source Software library implementing [OGC Cartographic Symbology 2.0](https://github.com/opengeospatial/cartographic-symbology)

_libCartoSym_ aims to be an [eC](https://ec-lang.org) implementation of the [CartoSym-CSS](https://docs.ogc.org/DRAFTS/18-067r4.html#rc-cscss) and
[CartoSym-JSON](https://docs.ogc.org/DRAFTS/18-067r4.html#rc-json) encodings defined in the candidate
[OGC Cartographic Symbology - Part 1: Core Model and Encodings Standard version 2.0](https://docs.ogc.org/DRAFTS/18-067r4.html) Standard.

The library will allow to read and write these CartoSym encodings, as well as import from and export to additional encodings of portrayal rules such as
OGC [SLD](https://portal.ogc.org/files/?artifact_id=22364)/[SE](https://portal.ogc.org/files/?artifact_id=16700) and [Mapbox GL Styles](https://docs.mapbox.com/mapbox-gl-js/guides/styles/).

Since the CartoSym encodings extend the [OGC Common Query Language (CQL2)](https://www.opengis.net/doc/IS/cql2/1.0), the [_libCQL2_](https://github.com/ecere/libCartoSym/tree/main/CQL2) dependency provides support for
parsing and writing CQL2-Text and CQL2-JSON expressions, which themselves imply support for parsing and writing geometries defined in
[Well-Known Text (WKT)](http://portal.opengeospatial.org/files/?artifact_id=25355) and [GeoJSON](https://tools.ietf.org/rfc/rfc7946.txt) which is provided by
[_libSFGeometry_](https://github.com/ecere/libCartoSym/tree/main/SFGeometry) and [_libSFCollections_](https://github.com/ecere/libCartoSym/tree/main/SFCollections).
The ability to perform spatial relation queries based on the [Dimensionally Extended-9 Intersection Model](https://en.wikipedia.org/wiki/DE-9IM) is provided by [_libDE9IM_](https://github.com/ecere/libCartoSym/tree/main/DE9IM).
The [_libGeoExtents_](https://github.com/ecere/libCartoSym/tree/main/GeoExtents) library provides the foundational basic data structures for geographic points and extents.

Additional functionality related to implementing CartoSym 2.0 in renderers, such as the run-time evaluation of expressions and the generation of a symbology specifier for specific conditions, will also be integrated within this library.

Object-oriented bindings for _libCartoSym_ automatically generated using Ecere's [binding generating tool (bgen)](https://github.com/ecere/bgen) from the eC library will be available
for the C, C++ and Python programming languages, with eventual support for Java and Rust planned as well.
