import 'package:alist/generated/json/base/json_field.dart';
import 'package:alist/generated/json/file_list_resp_entity.g.dart';
import 'dart:convert';

@JsonSerializable()
class FileListRespEntity {
	List<FileListRespContent>? content;
	int total = 0;
	String readme = "";
	bool write = false;
	String provider = "";

	FileListRespEntity();

	factory FileListRespEntity.fromJson(Map<String, dynamic> json) => $FileListRespEntityFromJson(json);

	Map<String, dynamic> toJson() => $FileListRespEntityToJson(this);

	@override
	String toString() {
		return jsonEncode(this);
	}
}

@JsonSerializable()
class FileListRespContent {
	String name = "";
	int? size;
	@JSONField(name: "is_dir")
	bool isDir = false;
	String modified = "";
	String sign = "";
	String thumb = "";
	int type = 0;
	String? readme;

	FileListRespContent();

	factory FileListRespContent.fromJson(Map<String, dynamic> json) => $FileListRespContentFromJson(json);

	Map<String, dynamic> toJson() => $FileListRespContentToJson(this);

	@override
	String toString() {
		return jsonEncode(this);
	}
}
