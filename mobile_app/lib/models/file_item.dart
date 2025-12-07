class FileItem {
  final String name;
  final String type; // 'file' or 'directory'
  final int size;
  final String? path;
  final DateTime? dateCreated;

  FileItem({
    required this.name,
    required this.type,
    required this.size,
    this.path,
    this.dateCreated,
  });

  bool get isDirectory => type == 'directory';
  bool get isFile => type == 'file';

  String get sizeFormatted {
    if (isDirectory) return '';
    
    if (size < 1024) {
      return '${size} B';
    } else if (size < 1024 * 1024) {
      return '${(size / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  factory FileItem.fromJson(Map<String, dynamic> json) {
    DateTime? dateCreated;
    if (json['dateCreated'] != null) {
      try {
        if (json['dateCreated'] is String) {
          dateCreated = DateTime.tryParse(json['dateCreated']);
        } else if (json['dateCreated'] is int) {
          // Unix timestamp in seconds
          dateCreated = DateTime.fromMillisecondsSinceEpoch(json['dateCreated'] * 1000);
        }
      } catch (e) {
        dateCreated = null;
      }
    }
    
    return FileItem(
      name: json['name'] ?? '',
      type: json['type'] ?? 'file',
      size: json['size'] ?? 0,
      path: json['path'],
      dateCreated: dateCreated,
    );
  }


  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'type': type,
      'size': size,
      'path': path,
      'dateCreated': dateCreated?.toIso8601String(),
    };
  }
}
