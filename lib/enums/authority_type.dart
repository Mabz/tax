enum AuthorityType {
  localAuthority,
  borderOfficial,
}

extension AuthorityTypeExtension on AuthorityType {
  String get displayName {
    switch (this) {
      case AuthorityType.localAuthority:
        return 'Local Authority';
      case AuthorityType.borderOfficial:
        return 'Border Official';
    }
  }

  String get description {
    switch (this) {
      case AuthorityType.localAuthority:
        return 'Can scan and view pass details only';
      case AuthorityType.borderOfficial:
        return 'Can scan and deduct pass entries';
    }
  }

  bool get canDeduct {
    switch (this) {
      case AuthorityType.localAuthority:
        return false;
      case AuthorityType.borderOfficial:
        return true;
    }
  }
}
