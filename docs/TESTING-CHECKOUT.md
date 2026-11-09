# Checkout end-to-end regression on Android

Use Flutter 3.47.9 (Dart 3.13.7) and an unlocked, ADB-authorized Android device.
The runner installs the debug package `com.pujanggapos.pujangga_pos.debug`.
The integration test refuses to open its database in another package and uses a
unique database file under the debug application's temporary directory. It
does not clear app data, uninstall production, or open the user's business DB.

```powershell
flutter pub get --enforce-lockfile
adb devices -l
python tools/run_checkout_e2e.py --device DEVICE_SERIAL --flutter PATH_TO_FLUTTER
```

The runner checks that the debug application is foreground before sending a
native `adb shell input keyevent 4` at the test checkpoint. It records the run
log and a screenshot of the committed receipt under `build/checkout-e2e/`.
Do not navigate on the device while the test runs.

The test uses the actual application, router, Android SQLite plugin, transaction
repository, receipt reader, stock movements and employee commissions. Only the
catalog read error is injected by a test-only repository decorator, after the
real transaction save has returned successfully.

Verified scenarios:

- Checkout using the UI and an employee earning a 10% commission.
- Successful receipt despite a catalog refresh error after commit.
- Native Android back triggers another catalog read.
- A failed retry remains visibly different from an empty catalog; a later retry
  restores the catalog without another save.
- Replaying the original request at the real repository boundary returns the
  original invoice without repeating stock or commission effects.
- A deliberate second checkout creates a separate invoice and correct effects.
- The Transaksi Baru action returns to a usable catalog.
- Closing and reopening the SQLite file preserves the two sales, stock of eight
  from an initial ten, and exactly two commission entries.

Successful teardown removes only the test-owned temporary database directory.
The debug package may remain installed; the production package is unchanged.

## Device validation: 9 November 2026

- Production source revision: `96efe81acdf077329ffa609d3451776134bba537`
  (the harness and dev dependency are the only additions for this run).
- Physical device: Redmi 2201116TG, Android 13; Flutter 3.47.9 / Dart 3.13.7.
- Completed at approximately 12:29 WIB; the device test reported `1 passed`
  after 14 seconds of execution following build and installation.
- Final readback: two invoices and checkout keys, two sale details, two stock
  movements, two commission entries of Rp1,000, and remaining stock eight.
  Replaying the first checkout did not add any of these effects.
- Closing and reopening the Android SQLite database preserved the sales,
  remaining stock, and commission entries. Teardown deleted the disposable DB;
  a subsequent ADB inventory showed only the production package (Flutter had
  removed the test debug package).
- All 111 host Flutter tests passed; `flutter analyze --no-pub --fatal-infos`
  reported no issues.
- Tested APK SHA-256:
  `a04ae623788e0f21846018ed69ea2ab31ab1aa6f431acb51a3a18ad52fd7119b`.
- Local evidence: `build/checkout-e2e/run.log` and
  `build/checkout-e2e/committed-receipt.png` (synthetic fixture data only).

The first native-library download returned an HTTP 504 document and was rejected
by the dependency's SHA-256 check. The official Android arm64 asset was downloaded
again through `gh release download`, verified against the package's expected
hash, and then used by the successful build. No checksum check was disabled.
