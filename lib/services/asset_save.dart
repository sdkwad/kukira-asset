import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;

import '../data/db.dart';
import 'error_log.dart';
import 'files.dart';

/// Creates an asset and then saves its photo, encrypted like every other picture. The asset
/// is kept even if its photo cannot be saved, because the photo can be added again later and
/// the name and type the owner typed should not be lost over it. Returns the new asset's id
/// and whether the photo (when there was one) was saved.
Future<(int, bool)> createAssetWithPhoto(
  AppDb db, {
  required String category,
  required String nickname,
  String? propertyType,
  String? plate,
  Uint8List? photo,
  String photoExt = 'jpg',
}) async {
  final id = await db.createAsset(category: category, nickname: nickname, propertyType: propertyType, plate: plate);
  if (photo == null) return (id, true);
  String? name;
  try {
    name = await SecureFiles.save(db, photo, photoExt);
    await db.updateAsset(id, AssetsCompanion(photoPath: Value(name)));
    return (id, true);
  } catch (e) {
    ErrorLog.record('asset.photo', e);
    // A file that was written but not linked to the asset would never be shown or backed up.
    if (name != null) {
      try {
        await SecureFiles.delete(name);
      } catch (_) {
        // The file stays unused (still encrypted) until a restore clears unused files.
      }
    }
    return (id, false);
  }
}
