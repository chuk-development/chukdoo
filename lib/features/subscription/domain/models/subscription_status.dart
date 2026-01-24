/// Subscription tier levels
enum SubscriptionTier {
  /// Free tier - local storage only
  free,

  /// Pro tier - includes cloud sync
  pro,
}

/// Represents the current subscription status
class SubscriptionStatus {
  final SubscriptionTier tier;
  final bool isActive;
  final DateTime? expiresAt;
  final String? productIdentifier;

  const SubscriptionStatus({
    this.tier = SubscriptionTier.free,
    this.isActive = false,
    this.expiresAt,
    this.productIdentifier,
  });

  /// Whether the user can sync to cloud
  bool get canSync => tier == SubscriptionTier.pro && isActive;

  /// Whether the subscription is expired
  bool get isExpired =>
      expiresAt != null && expiresAt!.isBefore(DateTime.now());

  SubscriptionStatus copyWith({
    SubscriptionTier? tier,
    bool? isActive,
    DateTime? expiresAt,
    String? productIdentifier,
    bool clearExpiration = false,
  }) {
    return SubscriptionStatus(
      tier: tier ?? this.tier,
      isActive: isActive ?? this.isActive,
      expiresAt: clearExpiration ? null : (expiresAt ?? this.expiresAt),
      productIdentifier: productIdentifier ?? this.productIdentifier,
    );
  }

  @override
  String toString() {
    return 'SubscriptionStatus(tier: $tier, isActive: $isActive, expiresAt: $expiresAt)';
  }
}
