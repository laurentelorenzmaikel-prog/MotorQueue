# Hive Type Adapter Regeneration Guide

## When to Regenerate

You need to regenerate Hive type adapters whenever you:
- Add new fields to a Hive model
- Remove fields from a Hive model
- Change field types in a Hive model
- Create a new model class with `@HiveType` annotation

## How to Regenerate

Run the following command in the project root directory:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### What this does:
- Regenerates all `.g.dart` files
- `--delete-conflicting-outputs` removes old generated files before creating new ones

### For watch mode (auto-regenerate on file changes):
```bash
flutter pub run build_runner watch --delete-conflicting-outputs
```

## After Regenerating

1. Check that `.g.dart` files have been updated
2. Look for any errors in the generated files
3. Test your app to ensure Hive models work correctly

## Affected Files

Currently, these models use Hive and need regeneration when changed:
- `lib/models/appointment.dart` → `lib/models/appointment.g.dart`
- `lib/models/feedback_model.dart` → `lib/models/feedback_model.g.dart`
- `lib/models/user_model.dart` → `lib/models/user_model.g.dart`

## Important Notes

⚠️ **CRITICAL**: The updated `appointment.dart` model includes new fields (motorBrand, plateNumber, reference, status, userId, createdAt, id). You MUST regenerate before running the app, or you'll get runtime errors.

## Troubleshooting

### Error: "Conflicting outputs"
Run with `--delete-conflicting-outputs` flag

### Error: "Type adapter already registered"
Clear Hive boxes or change the typeId in your @HiveType annotation

### Error: "Part file doesn't exist"
Make sure you have `part 'filename.g.dart';` at the top of your model file

## Regeneration Command (Quick Copy)

```bash
# Navigate to project root first
cd lorenz_app

# Then run
flutter pub run build_runner build --delete-conflicting-outputs
```
