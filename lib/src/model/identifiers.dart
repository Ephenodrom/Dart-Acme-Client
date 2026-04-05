import 'package:meta/meta.dart';

enum IdentifierType { dns }

extension IdentifierTypeWireValue on IdentifierType {
  String get wireValue => switch (this) {
    IdentifierType.dns => 'dns',
  };

  static IdentifierType fromWireValue(String value) => switch (value) {
    'dns' => IdentifierType.dns,
    _ => throw ArgumentError.value(
      value,
      'value',
      'Unsupported identifier type',
    ),
  };
}

abstract class Identifier {
  const Identifier(this.value);

  @nonVirtual
  final String value;

  IdentifierType get identifierType;

  String get type => identifierType.wireValue;
}

class DomainIdentifier extends Identifier {
  const DomainIdentifier(super.value);

  @override
  IdentifierType get identifierType => IdentifierType.dns;
}
