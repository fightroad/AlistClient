import 'dart:convert';

import 'package:alist/generated/json/base/json_field.dart';
import 'package:alist/generated/json/share_entity.g.dart';

@JsonSerializable()
class ShareEntity {
  String id = "";
  String? expires;
  String pwd = "";
  int accessed = 0;
  @JSONField(name: "max_accessed")
  int maxAccessed = 0;
  bool disabled = false;
  String remark = "";
  List<String> files = [];
  String creator = "";
  @JSONField(name: "creator_role")
  int creatorRole = 0;

  ShareEntity();

  factory ShareEntity.fromJson(Map<String, dynamic> json) =>
      $ShareEntityFromJson(json);

  Map<String, dynamic> toJson() => $ShareEntityToJson(this);

  @override
  String toString() {
    return jsonEncode(this);
  }
}

@JsonSerializable()
class ShareListResp {
  List<ShareEntity>? content;
  int total = 0;

  ShareListResp();

  factory ShareListResp.fromJson(Map<String, dynamic> json) =>
      $ShareListRespFromJson(json);

  Map<String, dynamic> toJson() => $ShareListRespToJson(this);

  @override
  String toString() {
    return jsonEncode(this);
  }
}
