enum ScanFilter {
  original('Original'),
  enhanced('Enhanced'),
  grayscale('Grayscale'),
  blackAndWhite('B&W');

  const ScanFilter(this.label);
  final String label;
}
