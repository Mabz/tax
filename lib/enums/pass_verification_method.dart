enum PassVerificationMethod {
  none(
    label: 'No Verification',
    description: 'Passes are processed immediately upon scan without additional verification.',
  ),
  staticPin(
    label: 'Personal PIN',
    description: 'A memorable 3-digit PIN that can be used offline for verification.',
  ),
  dynamicCode(
    label: 'Secure Code',
    description: 'A one-time dynamic code sent to your device for highest security.',
  );

  final String label;
  final String description;

  const PassVerificationMethod({required this.label, required this.description});
}
