import 'modifier_model.dart';

class ModifierGroupModel {
  final String id;
  final String name; // e.g. 'Level Gula', 'Level Es Batu', 'Level Pedas', 'Topping Tambahan'
  final String selectionType; // 'SINGLE' or 'MULTIPLE'
  final bool isRequired;
  final int displayOrder;
  final List<ModifierModel> options;

  ModifierGroupModel({
    required this.id,
    required this.name,
    this.selectionType = 'SINGLE',
    this.isRequired = false,
    this.displayOrder = 0,
    this.options = const [],
  });

  bool get isSingleChoice => selectionType == 'SINGLE';
  bool get isMultipleChoice => selectionType == 'MULTIPLE';

  factory ModifierGroupModel.fromMap(Map<String, dynamic> map, {List<ModifierModel>? options}) {
    return ModifierGroupModel(
      id: map['id'] as String,
      name: map['name'] as String,
      selectionType: map['selection_type'] as String? ?? 'SINGLE',
      isRequired: (map['is_required'] as int? ?? 0) == 1,
      displayOrder: map['display_order'] as int? ?? 0,
      options: options ?? [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'selection_type': selectionType,
      'is_required': isRequired ? 1 : 0,
      'display_order': displayOrder,
    };
  }

  ModifierGroupModel copyWith({
    String? id,
    String? name,
    String? selectionType,
    bool? isRequired,
    int? displayOrder,
    List<ModifierModel>? options,
  }) {
    return ModifierGroupModel(
      id: id ?? this.id,
      name: name ?? this.name,
      selectionType: selectionType ?? this.selectionType,
      isRequired: isRequired ?? this.isRequired,
      displayOrder: displayOrder ?? this.displayOrder,
      options: options ?? this.options,
    );
  }
}
