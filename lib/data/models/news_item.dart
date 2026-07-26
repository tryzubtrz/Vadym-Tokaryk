class NewsItem {
  const NewsItem({
    required this.id,
    required this.title,
    required this.body,
    required this.publishedAt,
    this.isRead = false,
  });

  final String id;
  final String title;
  final String body;
  final DateTime publishedAt;
  final bool isRead;

  NewsItem copyWith({bool? isRead}) => NewsItem(
        id: id,
        title: title,
        body: body,
        publishedAt: publishedAt,
        isRead: isRead ?? this.isRead,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'publishedAt': publishedAt.toIso8601String(),
        'isRead': isRead,
      };

  factory NewsItem.fromJson(Map<String, dynamic> json) => NewsItem(
        id: json['id'] as String,
        title: json['title'] as String,
        body: json['body'] as String,
        publishedAt: DateTime.parse(json['publishedAt'] as String),
        isRead: json['isRead'] as bool? ?? false,
      );
}
