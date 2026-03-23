### Outdated Packages Audit for Drift Migration

| Package Name                               | Current Version | Latest Version | Change Reason       | Notes                                                                 |
|--------------------------------------------|-----------------|----------------|---------------------|----------------------------------------------------------------------|
| `isar`                                     | *3.1.0+1        | -              | ISAR-DIRECT         | Remove; replaced by Drift.                                           |
| `isar_flutter_libs`                        | *3.1.0+1        | -              | ISAR-DIRECT         | Remove; replaced by SQLite libraries.                               |
| `isar_generator`                           | *3.1.0+1        | -              | ISAR-DIRECT         | Remove; replaced by Drift code generator.                           |
| `build_runner`                             | *2.4.13         | 2.13.1         | OUTDATED            | Needs version bump for compatibility.                               |
| `flutter_riverpod`                         | *2.6.1          | 3.3.1          | OUTDATED            | Breaking changes in v3.x; update required for compatibility.        |
| `riverpod_annotation`                      | *2.6.1          | 4.0.2          | OUTDATED            | Breaking changes in v4.x; update required for compatibility.        |
| `flutter_secure_storage`                   | *9.2.4          | 10.0.0         | OUTDATED            | Breaking changes in v10.x; update required for compatibility.       |
| `google_fonts`                             | *6.3.3          | 8.0.2          | OUTDATED            | Safe to bump; no breaking changes noted.                            |
| `google_sign_in`                           | *6.3.0          | 7.2.0          | OUTDATED            | Safe to bump; no breaking changes noted.                            |
| `googleapis`                               | *14.0.0         | 16.0.0         | OUTDATED            | Safe to bump; no breaking changes noted.                            |
| `googleapis_auth`                          | *1.6.0          | 2.2.0          | OUTDATED            | Safe to bump; no breaking changes noted.                            |
| `image_cropper`                            | *8.1.0          | 12.0.0         | OUTDATED            | Breaking changes in v12.x; update required for compatibility.       |
| `intl`                                     | *0.19.0         | 0.20.2         | OUTDATED            | Safe to bump; no breaking changes noted.                            |
| `json_annotation`                          | *4.9.0          | 4.11.0         | OUTDATED            | Safe to bump; no breaking changes noted.                            |
| `mobile_scanner`                           | *4.0.1          | 7.2.0          | OUTDATED            | Safe to bump; no breaking changes noted.                            |
| `ota_update`                               | *5.1.0          | 7.1.0          | OUTDATED            | Safe to bump; no breaking changes noted.                            |
| `package_info_plus`                        | *8.3.1          | 9.0.0          | OUTDATED            | Safe to bump; no breaking changes noted.                            |
| `share_plus`                               | *7.2.2          | 12.0.1         | OUTDATED            | Safe to bump; no breaking changes noted.                            |
| `uuid`                                     | *4.5.2          | 4.5.3          | OUTDATED            | Safe to bump; no breaking changes noted.                            |
| `vibration`                                | *2.1.0          | 3.1.8          | OUTDATED            | Safe to bump; no breaking changes noted.                            |
| `wakelock_plus`                            | *1.3.3          | 1.5.1          | OUTDATED            | Safe to bump; no breaking changes noted.                            |
| `window_manager`                           | *0.4.3          | 0.5.1          | OUTDATED            | Safe to bump; no breaking changes noted.                            |
| `flutter_lints`                            | *3.0.2          | 6.0.0          | OUTDATED            | Safe to bump; no breaking changes noted.                            |
| `json_serializable`                        | *6.8.0          | 6.13.1         | OUTDATED            | Safe to bump; no breaking changes noted.                            |
| `riverpod_generator`                       | *2.4.0          | 4.0.3          | OUTDATED            | Breaking changes in v4.x; update required for compatibility.        |

---

### Drift Packages to Add

| Package Name           | Notes                                      |
|------------------------|--------------------------------------------|
| `drift`               | Core Drift package for database operations. |
| `drift_flutter`       | Flutter integration for Drift.              |
| `sqlite3_flutter_libs` | SQLite libraries for Flutter.               |
| `drift_dev`           | Dev dependency for Drift code generation.   |