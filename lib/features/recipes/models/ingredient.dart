import 'package:isar/isar.dart';

part 'ingredient.g.dart';

@embedded
class Ingredient {
  String name = '';
  String? amount;
  String? unit;
  String? preparation;
  String? alternative;
  bool isOptional = false;
  String? section;
  String? bakerPercent;

  Ingredient();

  Ingredient.create({
    required this.name,
    this.amount,
    this.unit,
    this.preparation,
    this.alternative,
    this.isOptional = false,
    this.section,
    this.bakerPercent,
  });

  factory Ingredient.fromJson(Map<String, dynamic> json) {
    return Ingredient()
      ..name = json['name'] as String
      ..amount = json['amount'] as String?
      ..unit = json['unit'] as String?
      ..preparation = json['preparation'] as String?
      ..alternative = json['alternative'] as String?
      ..isOptional = json['isOptional'] as bool? ?? false
      ..section = json['section'] as String?
      ..bakerPercent = json['bakerPercent'] as String?;
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'amount': amount,
      'unit': unit,
      'preparation': preparation,
      'alternative': alternative,
      'isOptional': isOptional,
      'section': section,
      'bakerPercent': bakerPercent,
    };
  }

  String get displayText {
    final buffer = StringBuffer();
    if (amount != null && amount!.isNotEmpty) {
      buffer.write(amount);
      if (unit != null && unit!.isNotEmpty) {
        buffer.write(' ');
        buffer.write(unit);
      }
      buffer.write(' ');
    }
    buffer.write(name);
    return buffer.toString();
  }

  String get displayAmount {
    final buffer = StringBuffer();
    if (amount != null && amount!.isNotEmpty) {
      buffer.write(amount);
      if (unit != null && unit!.isNotEmpty) {
        buffer.write(' ');
        buffer.write(unit);
      }
    }
    return buffer.toString();
  }
}
