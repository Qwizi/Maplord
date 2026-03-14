class GeoFeature {
  final Map<String, dynamic> properties;
  final Map<String, dynamic> geometry;

  GeoFeature({
    required this.properties,
    required this.geometry,
  });

  factory GeoFeature.fromJson(Map<String, dynamic> json) => GeoFeature(
    properties: json['properties'] as Map<String, dynamic>,
    geometry: json['geometry'] as Map<String, dynamic>,
  );

  Map<String, dynamic> toJson() => {
    'type': 'Feature',
    'properties': properties,
    'geometry': geometry,
  };
}

class RegionGraphEntry {
  final String id;
  final List<String> neighborIds;
  final List<double>? centroid;

  RegionGraphEntry({
    required this.id,
    required this.neighborIds,
    this.centroid,
  });

  factory RegionGraphEntry.fromJson(Map<String, dynamic> json) => RegionGraphEntry(
    id: json['id'] as String,
    neighborIds: (json['neighbor_ids'] as List<dynamic>).cast<String>(),
    centroid: (json['centroid'] as List<dynamic>?)
        ?.map((e) => (e as num).toDouble())
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'neighbor_ids': neighborIds,
    'centroid': centroid,
  };
}
