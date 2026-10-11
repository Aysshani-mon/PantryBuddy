/// Trims and upper-cases the first letter of a food item's name, leaving
/// the rest as typed ("greek yoghurt" -> "Greek yoghurt", "iPhone"-style
/// brand casing after the first letter is kept).
String capitaliseFirstLetter(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return trimmed;
  return trimmed[0].toUpperCase() + trimmed.substring(1);
}
