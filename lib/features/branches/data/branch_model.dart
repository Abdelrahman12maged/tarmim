import '../domain/branch_entity.dart';

export '../domain/branch_entity.dart';

/// Data model alias for Firestore serialization of shop branches.
///
/// Aliased directly to [BranchEntity] to prevent any runtime subtype mismatch.
typedef BranchModel = BranchEntity;
