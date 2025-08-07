enum PassVerificationMethod {
  none, // Direct deduction without verification
  pin, // Personal PIN verification
  secureCode, // Dynamic secure code verification
}

extension PassVerificationMethodExtension on PassVerificationMethod {
  String get displayName {
    switch (this) {
      case PassVerificationMethod.none:
        return 'No Verification';
      case PassVerificationMethod.pin:
        return 'Personal PIN';
      case PassVerificationMethod.secureCode:
        return 'Secure Code';
    }
  }

  String get label {
    switch (this) {
      case PassVerificationMethod.none:
        return 'No Verification';
      case PassVerificationMethod.pin:
        return 'Personal PIN';
      case PassVerificationMethod.secureCode:
        return 'Secure Code';
    }
  }

  String get description {
    switch (this) {
      case PassVerificationMethod.none:
        return 'Direct deduction without verification';
      case PassVerificationMethod.pin:
        return 'Requires personal PIN from pass owner';
      case PassVerificationMethod.secureCode:
        return 'Requires dynamic secure code from pass owner';
    }
  }
}
