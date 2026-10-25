import 'package:equatable/equatable.dart';

import 'enums/member_role.dart';
import 'room_member_model.dart';
import 'room_model.dart';

/// 방 목록용: 매장 + 내 멤버십(역할) 묶음
class RoomMembershipEntry extends Equatable {
  const RoomMembershipEntry({
    required this.room,
    required this.membership,
  });

  final RoomModel room;
  final RoomMemberModel membership;

  MemberRole get role => membership.role;

  String get roleLabel => membership.roleLabel;

  bool get isOwnedByMe => role == MemberRole.owner;

  bool get isInvited => role != MemberRole.owner;

  @override
  List<Object?> get props => [room, membership];
}
