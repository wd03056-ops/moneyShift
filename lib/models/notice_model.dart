import 'package:equatable/equatable.dart';

/// 매장 공지사항
class NoticeModel extends Equatable {
  const NoticeModel({
    required this.id,
    required this.roomId,
    required this.authorId,
    required this.authorName,
    required this.title,
    required this.body,
    this.isImportant = false,
    this.readByUserIds = const {},
    this.createdAt,
  });

  final String id;
  final String roomId;
  final String authorId;
  final String authorName;
  final String title;
  final String body;
  final bool isImportant;
  final Set<String> readByUserIds;
  final DateTime? createdAt;

  bool isReadBy(String userId) => readByUserIds.contains(userId);

  NoticeModel copyWith({
    String? title,
    String? body,
    bool? isImportant,
    Set<String>? readByUserIds,
  }) {
    return NoticeModel(
      id: id,
      roomId: roomId,
      authorId: authorId,
      authorName: authorName,
      title: title ?? this.title,
      body: body ?? this.body,
      isImportant: isImportant ?? this.isImportant,
      readByUserIds: readByUserIds ?? this.readByUserIds,
      createdAt: createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        roomId,
        authorId,
        authorName,
        title,
        body,
        isImportant,
        readByUserIds,
        createdAt,
      ];
}
