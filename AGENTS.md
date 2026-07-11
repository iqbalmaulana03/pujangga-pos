# AGENTS.md

## Required Context

When starting work in this repository, always read and use the following documents as the primary context before working on any issue, implementation task, or refinement:

1. [STITCH-FINAL-SCREENS.md](./STITCH-FINAL-SCREENS.md)
   Final design reference and canonical Stitch screen IDs for implementation.

2. [USER-FLOW-Pujangga-POS.md](./USER-FLOW-Pujangga-POS.md)
   Reference for the main user flows and relationships between features and screens.

3. [PRD-Pujangga-POS.md](./PRD-Pujangga-POS.md)
   Reference for product scope, MVP boundaries, and business requirements.

## Additional Rules

- Treat `STITCH-FINAL-SCREENS.md` as the source of truth for locked UI decisions.
- Do not use older Stitch screens if a newer canonical screen already exists in `STITCH-FINAL-SCREENS.md`.
- If you are working on an issue related to design or screen implementation, align technical decisions with all three documents above.
- If you are implementing UI, you must match the canonical Stitch screen for that flow before introducing any additional interpretation.
- Use the screen title, screen ID, navigation structure, and UI intent from `STITCH-FINAL-SCREENS.md` as the baseline for layout decisions.
- Do not improvise new navigation patterns, extra tabs, alternate section order, or different CTA hierarchy unless the product docs explicitly require it.
- Treat visual parity with the locked Stitch screens as a delivery requirement, not as optional inspiration.
- For each UI-related task, first identify which canonical Stitch screen(s) apply, then implement against that reference.
- If a screen is not listed in the canonical set, do not infer its design from older Stitch screens unless the task explicitly asks for a new design pass.
- If implementation constraints require a deviation from the Stitch design, explicitly call out the deviation and the reason in the final response.

## UI Implementation Checklist

Before implementing or editing any UI screen:

1. Find the relevant canonical screen in `STITCH-FINAL-SCREENS.md`.
2. Confirm the matching user flow in `USER-FLOW-Pujangga-POS.md`.
3. Confirm the product scope and constraints in `PRD-Pujangga-POS.md`.
4. Implement the screen to match the locked Stitch reference as closely as practical in Flutter.
5. Verify that navigation, labels, CTA priority, and screen role still match the locked design.

## Canonical UI Mapping

Use these locked Stitch screens as the implementation baseline:

- Setup: `Siapkan Bisnis` - `3a95eeb4db5c4eaba51876c6c11b6f9c`
- Dashboard: `Beranda (Margin Insights)` - `3e1e0f8b40a642d7a78dd71a77bc45e1`
- Catalog: `Katalog` - `143f9b18db9d4fcca87cf6f9beac08e5`
- Add/Edit Item: `Tambah Barang (Margin Integration)` - `b0e520e7ed2d4d7481c7b29017fa4e57`
- New Transaction: `Transaksi Baru` - `20c72054c3824a1ab13cf4a2497158be`
- Transaction Success: `Transaksi Berhasil (Refined)` - `5850c03fe09249a58f10b4d3073297d1`
- Stock: `Manajemen Stok (Refined)` - `492ac73ccb0c49a7aa4277b70cef2b67`
- Reports: `Laporan (Margin Refined)` - `0b87761dc37d4db3a89f40a1fdca0232`
- Transaction History: `Riwayat Transaksi (Refined)` - `bc9d71eefe764dabbb279f9f8cadb250`
- Transaction History Empty State: `Riwayat Transaksi (Kosong)` - `fe7da2c17da346fd929e40456b61eae1`
- Transaction Detail: `Detail Transaksi` - `4d7d925fe610423880d0eafb586073ba`
- Settings: `Pengaturan (Capital Feature)` - `575d0f627212423f83fa661c29db4395`

## Locked Navigation Rules

- The primary bottom navigation must have exactly 5 items: `Beranda`, `Katalog`, `Transaksi`, `Stok`, `Laporan`.
- `Pengaturan` is not a primary bottom navigation tab.
- `Riwayat Transaksi` is a subflow, not a primary tab.
- Form screens such as `Tambah Barang` should use an app bar with back navigation rather than the primary bottom navigation.
- For shell commands in this repository, follow the instructions in `C:\Users\Peentar PC\.codex\RTK.md`.
