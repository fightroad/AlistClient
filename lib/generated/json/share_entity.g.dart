import 'package:alist/generated/json/base/json_convert_content.dart';
import 'package:alist/entity/share_entity.dart';

ShareEntity $ShareEntityFromJson(Map<String, dynamic> json) {
  final ShareEntity entity = ShareEntity();
  final String? id = jsonConvert.convert<String>(json['id']);
  if (id != null) {
    entity.id = id;
  }
  final String? expires = jsonConvert.convert<String>(json['expires']);
  if (expires != null) {
    entity.expires = expires;
  }
  final String? pwd = jsonConvert.convert<String>(json['pwd']);
  if (pwd != null) {
    entity.pwd = pwd;
  }
  final int? accessed = jsonConvert.convert<int>(json['accessed']);
  if (accessed != null) {
    entity.accessed = accessed;
  }
  final int? maxAccessed = jsonConvert.convert<int>(json['max_accessed']);
  if (maxAccessed != null) {
    entity.maxAccessed = maxAccessed;
  }
  final bool? disabled = jsonConvert.convert<bool>(json['disabled']);
  if (disabled != null) {
    entity.disabled = disabled;
  }
  final String? remark = jsonConvert.convert<String>(json['remark']);
  if (remark != null) {
    entity.remark = remark;
  }
  final List<String>? files =
      (json['files'] as List<dynamic>?)?.map((e) => e.toString()).toList();
  if (files != null) {
    entity.files = files;
  }
  final String? creator = jsonConvert.convert<String>(json['creator']);
  if (creator != null) {
    entity.creator = creator;
  }
  final int? creatorRole = jsonConvert.convert<int>(json['creator_role']);
  if (creatorRole != null) {
    entity.creatorRole = creatorRole;
  }
  return entity;
}

Map<String, dynamic> $ShareEntityToJson(ShareEntity entity) {
  final Map<String, dynamic> data = <String, dynamic>{};
  data['id'] = entity.id;
  data['expires'] = entity.expires;
  data['pwd'] = entity.pwd;
  data['accessed'] = entity.accessed;
  data['max_accessed'] = entity.maxAccessed;
  data['disabled'] = entity.disabled;
  data['remark'] = entity.remark;
  data['files'] = entity.files;
  data['creator'] = entity.creator;
  data['creator_role'] = entity.creatorRole;
  return data;
}

ShareListResp $ShareListRespFromJson(Map<String, dynamic> json) {
  final ShareListResp entity = ShareListResp();
  final List<ShareEntity>? content =
      (json['content'] as List<dynamic>?)?.map((e) {
    if (e is Map<String, dynamic>) {
      return ShareEntity.fromJson(e);
    }
    return ShareEntity.fromJson(Map<String, dynamic>.from(e as Map));
  }).toList();
  if (content != null) {
    entity.content = content;
  }
  final int? total = jsonConvert.convert<int>(json['total']);
  if (total != null) {
    entity.total = total;
  }
  return entity;
}

Map<String, dynamic> $ShareListRespToJson(ShareListResp entity) {
  final Map<String, dynamic> data = <String, dynamic>{};
  data['content'] = entity.content?.map((e) => e.toJson()).toList();
  data['total'] = entity.total;
  return data;
}
