enum GalleryAccess { granted, denied }

class GalleryImage {
  const GalleryImage(this.id);

  final String id;

  @override
  bool operator ==(Object other) => other is GalleryImage && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
