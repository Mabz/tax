class PaymentDetails {
  final String? cardHolderName;
  final String? cardLast4;
  final int? cardExpMonth;
  final int? cardExpYear;
  final String? paymentProviderToken;
  final String? paymentProvider;

  PaymentDetails({
    this.cardHolderName,
    this.cardLast4,
    this.cardExpMonth,
    this.cardExpYear,
    this.paymentProviderToken,
    this.paymentProvider,
  });

  factory PaymentDetails.fromJson(Map<String, dynamic> json) {
    return PaymentDetails(
      cardHolderName: json['card_holder_name']?.toString(),
      cardLast4: json['card_last4']?.toString(),
      cardExpMonth: (json['card_exp_month'] as num?)?.toInt(),
      cardExpYear: (json['card_exp_year'] as num?)?.toInt(),
      paymentProviderToken: json['payment_provider_token']?.toString(),
      paymentProvider: json['payment_provider']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'card_holder_name': cardHolderName,
      'card_last4': cardLast4,
      'card_exp_month': cardExpMonth,
      'card_exp_year': cardExpYear,
      'payment_provider_token': paymentProviderToken,
      'payment_provider': paymentProvider,
    };
  }

  PaymentDetails copyWith({
    String? cardHolderName,
    String? cardLast4,
    int? cardExpMonth,
    int? cardExpYear,
    String? paymentProviderToken,
    String? paymentProvider,
  }) {
    return PaymentDetails(
      cardHolderName: cardHolderName ?? this.cardHolderName,
      cardLast4: cardLast4 ?? this.cardLast4,
      cardExpMonth: cardExpMonth ?? this.cardExpMonth,
      cardExpYear: cardExpYear ?? this.cardExpYear,
      paymentProviderToken: paymentProviderToken ?? this.paymentProviderToken,
      paymentProvider: paymentProvider ?? this.paymentProvider,
    );
  }

  bool get hasPaymentMethod {
    return cardLast4 != null && cardLast4!.isNotEmpty;
  }

  String get displayCardInfo {
    if (!hasPaymentMethod) return 'No payment method saved';
    return '**** **** **** $cardLast4';
  }

  String get displayExpiry {
    if (cardExpMonth == null || cardExpYear == null) return '';
    return '${cardExpMonth.toString().padLeft(2, '0')}/${cardExpYear.toString().substring(2)}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PaymentDetails &&
        other.cardHolderName == cardHolderName &&
        other.cardLast4 == cardLast4 &&
        other.cardExpMonth == cardExpMonth &&
        other.cardExpYear == cardExpYear &&
        other.paymentProviderToken == paymentProviderToken &&
        other.paymentProvider == paymentProvider;
  }

  @override
  int get hashCode {
    return Object.hash(
      cardHolderName,
      cardLast4,
      cardExpMonth,
      cardExpYear,
      paymentProviderToken,
      paymentProvider,
    );
  }

  @override
  String toString() {
    return 'PaymentDetails(cardHolderName: $cardHolderName, cardLast4: $cardLast4, expiry: $displayExpiry, provider: $paymentProvider)';
  }
}
