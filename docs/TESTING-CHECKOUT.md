# Checkout end-to-end regression on Android

Use Flutter 3.47.9 (Dart 3.13.7) and an unlocked, ADB-authorized Android device.
The runner builds the debug APK before starting Flutter's test runner and uses
`--no-uninstall`. The installed package is `com.pujanggapos.pujangga_pos.debug`.
Both precautions are required: on a clean checkout Flutter 3.47.9 can discover
the unsuffixed namespace before building and retain it as its cleanup target.
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
It also records the preflight build and production-package presence before and
after the run. Flutter's automatic uninstall is disabled; the debug app remains
installed after testing.
Do not navigate on the device while the test runs.

The test uses the actual application, router, Android SQLite plugin, transaction
repository, receipt reader, stock movements and employee commissions. Only the
catalog read error is injected by a test-only repository decorator, after the
real transaction save has returned successfully.

Verified scenarios:

- Checkout using the UI and an employee earning a 10% commission.
- Pending saves disable the submit button. Payment changes via the UI and
  controller mutations cannot change the pending checkout or start another save.
- An injected failure before persistence leaves sales, stock and commissions
  unchanged and preserves the cart, employee and payment method for retry.
- Retrying from the UI after the error toast expires uses the same request/key.
- While a committed checkout waits for catalog refresh, submit remains locked
  and attempts to add items or change payment cannot open another checkout.
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

## PR #58 device validation: 9 November 2026

**Initial result before the navigation fix: hold merge.** See the fix
verification below for the subsequent result.

Application source: `3894750d01591222b31f755124dd5d18edb0bca1`, against main
`82b6783787c7532c41304e5c6802fef8015fb13f`. Only this document, the integration
test and its Python runner were edited during validation; application code was
not changed. Device: Redmi 2201116TG / Android 13. SDK: Flutter 3.47.9 /
Dart 3.13.7. All fixture data is synthetic, with Android SQLite in a unique
temporary directory under the debug package.

- Host checks: all 114 Flutter tests passed; analysis with `--fatal-infos` and
  `git diff --check` passed. The official Windows SQLite binary was downloaded
  through GitHub CLI and verified against the package's SHA-256; no hash check
  was disabled.
- At approximately 13:33 WIB the expanded integration test passed in 20 seconds.
  It verified the disabled submit button, ignored input while saving, rejection
  of repeated submits, no database effects after a pre-save failure, preserved
  checkout state, a retry using the identical request/key after the error toast
  expired, and the lock during post-commit refresh. It then completed Android
  Back, catalog recovery, durable replay protection, a second checkout and
  database reopen. Final ledger: two sales, stock eight, two commission entries.
- The same test failed on repetition at approximately 13:39-13:40 WIB, after
  confirming that the same-key retry committed once and refresh remained locked.
  Flutter raised a Navigator disposal assertion and subsequent overlay errors;
  the receipt page was absent after the bounded wait. This does not establish
  whether the root cause is application navigation or integration-test timing.
  A passing run is insufficient to clear this failure.
- Local passing evidence: `build/checkout-e2e/pr58-verified/run.log` and
  `committed-receipt.png`. Failing repetition:
  `build/checkout-e2e/pr58-safe-confirmed/run.log`. The latter run uses the
  corrected runner and exited with status 1. Its disposable database was deleted
  in teardown, and the debug package remained installed.

To reproduce the original failure on the unpatched application, run the command above with
`--output build/checkout-e2e/pr58-reproduction`. The failure occurs after the
`same-key retry committed once; refresh still locked` checkpoint and before
`E2E_WAIT_ANDROID_BACK`. Preserve failing logs rather than retrying until green.

### Navigation fix

The mobile cart dismisses itself when a committed sale clears the cart. The
submit callback also called `Navigator.pop` when catalog refresh finished.
If the sheet's exit animation was still running, its context was mounted and
the second pop removed the page underneath. The checkout button also passed
the transaction page's context rather than the sheet's own context.

Checkout now captures the actual modal route before saving, pops only when
that route is current, and awaits its completed dismissal before pushing the
receipt. Save-error handling is limited to the save operation, so later
navigation errors cannot be labeled as a failed transaction. No layout,
navigation destinations or database schema were changed.

The host regression deliberately releases catalog refresh 50 milliseconds into
the sheet's exit animation. It reproduced the Navigator assertion before the
fix and passes afterward, verifying both the receipt and Back to checkout with
one save. The host fixture blocks the runtime database provider and uses fakes.

**Fix verification: passed.** All 115 host Flutter tests and analysis with
`--no-pub --fatal-infos` passed. Two consecutive complete Android runs passed
at approximately 13:48 and 13:50 WIB (21 and 22 seconds of test execution),
using the corrected runner with automatic uninstall disabled. Evidence:

- `build/checkout-e2e/pr58-fixed-1/run.log`
- `build/checkout-e2e/pr58-fixed-2/run.log`
- Each run's `committed-receipt.png` and `package-inventory.txt`.

Both runs verified the save lock, failed save with zero ledger effects, retry
with the same key, lock during refresh, successful receipt, native Android
Back, failed/recovered catalog reads, replay protection, second checkout and
database reopen. Each ended with two sales, stock eight and two commissions.
The disposable database directories were independently confirmed absent after
teardown; the debug package remained installed. Production was absent before
and after these two runs; this does not resolve the earlier installation
incident described below.

### Installation incident during validation

The production package was present in the initial ADB inventory and absent in
the final inventory. The original runner allowed Flutter's default automatic
uninstall. In Flutter 3.47.9, `IntegrationTestDevice` retains the package resolved
before building for cleanup; on a clean checkout `AndroidApk.fromAndroidProject`
can fall back to the unsuffixed namespace, while `AndroidDevice.startApp` builds
and launches the suffixed debug APK. This is a plausible removal path consistent
with the observed inventory; the exact uninstall command was not captured.

The runner now builds first, passes `--no-uninstall`, and records package
presence before/after. The final repetition recorded production absent before
and after, and left the debug package installed. These observations do not prove
the earlier production installation or its data was preserved. No production
data was read, restored or reconciled; recovery remains unverified. Reinstalling
an APK alone must not be described as recovering its previous local data.
