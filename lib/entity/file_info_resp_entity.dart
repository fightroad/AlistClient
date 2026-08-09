import 'package:alist/generated/json/base/json_field.dart';
import 'package:alist/generated/json/file_info_resp_entity.g.dart';
import 'dart:convert';

@JsonSerializable()
class FileInfoRespEntity {
	String name = "";
	int size = 0;
	@JSONField(name: "is_dir")
	bool isDir = false;
	String modified = "";
	String sign = "";
	String thumb = "";
	int type = 0;
	@JSONField(name: "raw_url")
	String rawUrl = "";
	String readme = "";
	String provider = "";
	dynamic related;

	FileInfoRespEntity();

	factory FileInfoRespEntity.fromJson(Map<String, dynamic> json) => $FileInfoRespEntityFromJson(json);

	Map<String, dynamic> toJson() => $FileInfoRespEntityToJson(this);

	@override
	String toString() {
		return jsonEncode(this);
	}
}
