# in_app_review 2.0.12, patched for built-in Kotlin

A copy of [in_app_review 2.0.12](https://pub.dev/packages/in_app_review/versions/2.0.12)
(`example/`, `screenshots/` and `test/` left out, and the `screenshots:` list in its pubspec.yaml with them). The only change is
`android/build.gradle` (lines marked "Guidy patch"): it applies the Kotlin
Gradle plugin only when AGP's built-in Kotlin is off, and sets the JVM target
with `kotlin { compilerOptions }` instead of the removed `kotlinOptions`.

2.0.12 is the latest release and it (and upstream master) always applies the
Kotlin plugin, which AGP 9 with built-in Kotlin does not allow.

When a release supports built-in Kotlin, delete this folder and go back to
`in_app_review: ^<that version>` in the app's pubspec.yaml.
