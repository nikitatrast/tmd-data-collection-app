import 'package:flutter/material.dart' show Color, Colors, IconData, Icons;
import '../backends/upload_manager.dart' show UploadStatus;

extension UploadStatusView on UploadStatus {
  IconData get iconData {
    switch(this) {
      case UploadStatus.local:
        return Icons.cloud_upload;
      case UploadStatus.pending:
        return Icons.cloud_queue;
        break;
      case UploadStatus.uploading:
        return Icons.cloud_queue;
      case UploadStatus.uploaded:
        return Icons.cloud_done;
      case UploadStatus.error:
        return Icons.cloud_off;
      case UploadStatus.unknown:
      default:
        return Icons.device_unknown;
    }
  }

  Color get iconColor {
    switch(this) {
      case UploadStatus.local:
        return Colors.blue;
      case UploadStatus.pending:
        return null;
      case UploadStatus.uploading:
        return Colors.blue;
      case UploadStatus.uploaded:
        return Colors.lightGreen;
      case UploadStatus.error:
        return Colors.red;
      case UploadStatus.unknown:
      default:
        return null;
    }
  }
}