class ChannelData {
  final int channel;
  final int value;
  final String currency;
  final int level;
  final bool recycling;

  ChannelData({
    required this.channel,
    required this.value,
    required this.currency,
    this.level = 0,
    this.recycling = false,
  });

  @override
  String toString() {
    return 'Channel $channel: ${(value / 100).toStringAsFixed(2)} $currency';
  }
}