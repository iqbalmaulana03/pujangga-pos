import 'package:file_picker/file_picker.dart';

class BackupFilePickerService {
  const BackupFilePickerService();

  Future<String?> pickBackupFile() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: const ['json'],
      withData: false,
    );

    if (result == null || result.files.isEmpty) {
      return null;
    }

    return result.files.single.path;
  }
}
