# Google Stitch Prompts

## Pujangga-POS Flutter Wireframe

## 1. Purpose

This document contains English prompts for Google Stitch to generate the early wireframes for Pujangga-POS.

The prompts follow the Stitch prompting guide:

- Start with a high-level prompt for the overall app direction.
- Refine one screen at a time.
- Keep prompts clear and specific.
- Use UI/UX terms directly.
- Make one or two major changes per iteration when refining.

The design target is:

- Android-only
- Flutter app
- Single-user
- Local-first
- POS for products and services

## 2. Which GitHub Issues These Prompts Support

Use these prompts for the following tickets:

- Issue `#1` for the Flutter skeleton and app structure direction.
- Issue `#2` for the initial business setup wireframe.
- Issue `#3` for the catalog and add/edit item wireframes.
- Issue `#4` for the transaction screen and transaction success wireframes.
- Issue `#6` for the dashboard wireframe.

Secondary relevance:

- Issue `#7` because setup and dashboard prompts influence the settings/profile flow.
- Issue `#8` and `#9` are not the main focus of this prompt file, but the visual style can be reused later for history and stock screens.

## 3. Suggested Usage Order

Recommended order when using Stitch:

1. Use the master prompt first.
2. Generate the initial app direction.
3. Refine the setup screen.
4. Refine the dashboard screen.
5. Refine the catalog screen.
6. Refine the add/edit item form.
7. Refine the transaction screen.
8. Refine the transaction success screen.
9. Apply language and theme refinement prompts last.

## 4. Master Prompt

Use this first to establish the main app structure and visual direction.

```text
Design a mobile Android point-of-sale app called Pujangga-POS for small businesses in Indonesia. The app is built for fish shops, coffee shops, hardware stores, convenience stores, and barbershops, so it must support both products and services in one workflow.

Create a clean, practical, modern, mobile-first wireframe with a simple and efficient layout for non-technical business owners. The vibe should be minimalist, warm, trustworthy, and operational-focused. Use clear hierarchy, rounded cards, structured spacing, and fast-access actions. Prioritize usability over decoration.

The app is single-user, Android-only, and local-first. There is no login screen, no multi-user flow, and no cloud-first assumption. Focus on these main screens:
- Initial business setup
- Dashboard
- Catalog for products and services
- Sales transaction screen

Use bottom navigation for the main structure with:
- Home
- Catalog
- Transaction
- Stock
- Reports
- Settings

The default operational focus should emphasize quick transactions, simple setup, and clear daily sales visibility.
```

## 5. Prompt for Issue #2: Initial Business Setup

Use this for GitHub issue `#2`.

```text
Create the initial business setup screen for Pujangga-POS. This is the first screen after opening the app for the first time.

The layout should feel simple, welcoming, and low-friction. Show a short intro message and a form to set up the business.

Required fields:
- Business Name
- Business Type

Optional fields:
- Owner Name
- Contact Number
- Address

Add one prominent primary call-to-action button: "Save and Continue".

Use a clean card-based form layout, mobile-friendly spacing, clear labels, and lightweight helper text. The screen should feel practical and easy for small business owners who are not tech-savvy.
```

## 6. Prompt for Issue #6: Dashboard

Use this for GitHub issue `#6`.

```text
Create the dashboard screen for Pujangga-POS. This is the business overview screen after setup is complete.

The dashboard should be clean, efficient, and operational-focused. Show high-priority business summary cards:
- Today's Revenue
- Today's Transactions
- Best-Selling Item
- Top Payment Method

Add quick action buttons near the top:
- Add Item
- New Transaction

Also include an empty state version if there is no transaction data yet. In the empty state, show a helpful message and a strong button leading to "New Transaction".

Use a practical card layout with strong hierarchy, soft neutral colors, rounded components, and mobile-first spacing.
```

## 7. Prompt for Issue #3: Catalog

Use this for GitHub issue `#3`.

```text
Create the catalog screen for Pujangga-POS. This screen manages both products and services.

The screen should include:
- Header title: "Catalog"
- Search bar
- Filter chips for:
  - All
  - Products
  - Services
- Category filter option
- Item list in card layout
- Floating action button or clear primary action: "Add Item"

Each catalog card should show:
- Item name
- Category
- Price
- Item type label: Product or Service
- Stock only for Product
- Active or inactive status

The layout should feel structured, simple, and fast to scan. Make it suitable for many item types and practical daily use.
```

## 8. Prompt for Issue #3: Add/Edit Item Form

Use this after the main catalog screen for GitHub issue `#3`.

```text
Create the add/edit item form screen for Pujangga-POS.

The form should support both product and service types. Include:
- Item Name
- Category
- Item Type with segmented selection: Product / Service
- Selling Price
- Optional SKU
- Optional Unit
- Starting Stock, only visible if the selected type is Product
- Active Status

Add one clear primary button: "Save".

Use a clean form layout with clear field grouping. If the user selects Service, hide the stock field. The screen should feel simple, mobile-first, and easy for non-technical users.
```

## 9. Prompt for Issue #4: Transaction Screen

Use this for GitHub issue `#4`.

```text
Create the main sales transaction screen for Pujangga-POS. This is the most important operational screen.

The layout should be optimized for fast cashier-style usage on Android phones. It must support product sales, service sales, and mixed transactions.

Include:
- Search bar for items
- Category or type filter
- Scrollable item list
- Cart section or selected items summary
- Quantity controls
- Price and subtotal per line item
- Discount option
- Optional tax section
- Payment method selector:
  - Cash
  - Bank Transfer
  - QRIS
  - E-Wallet
  - Card
- Payment amount input if payment method is Cash
- Auto-calculated change
- Strong primary button: "Save Transaction"

The screen should feel fast, efficient, and clear. Emphasize tap-friendly controls, strong hierarchy, and minimal clutter. This should look like a POS wireframe, not a generic shopping app.
```

## 10. Prompt for Issue #4: Transaction Success Screen

Use this after the transaction screen for GitHub issue `#4`.

```text
Create a simple transaction success screen for Pujangga-POS.

Show:
- Success state message
- Invoice number
- Date and time
- Item list summary
- Total paid
- Payment method
- Change amount if payment was cash

Add two clear actions:
- Done
- New Transaction

Keep the screen simple, reassuring, and easy to scan.
```

## 11. Refinement Prompt: Make It Feel Like a Flutter Android Wireframe

Use this after the first generated result if the output feels too generic or too decorative.

```text
Refine the app to look like a realistic Flutter Android wireframe. Keep the interface clean and structured, with clear mobile component spacing, bottom navigation, practical cards, standard form patterns, and tap-friendly controls. Avoid overly decorative visuals. Prioritize operational clarity and usability.
```

## 12. Refinement Prompt: Theme Direction

Use this if the initial color and component direction is too plain or inconsistent.

```text
Update the theme to feel warm, practical, and trustworthy. Use a soft neutral color palette with one clear accent color for primary actions. Keep cards rounded, keep input fields clean and visible, and use a modern sans-serif font. Make the app feel suitable for small business operations rather than a lifestyle app.
```

## 13. Refinement Prompt: Language Change

Use this near the end, after the structure looks correct.

```text
Switch all UI copy, labels, helper text, navigation labels, button text, and empty state messages to Bahasa Indonesia. Keep the wording simple, practical, and suitable for Indonesian small business owners.
```

## 14. Refinement Prompt Examples Per Screen

Use these only after the first version exists.

### Setup Screen Refinement

```text
On the initial business setup screen, make the primary call-to-action button larger and place it at the bottom of the form. Add a short helper line under the Business Type field.
```

### Dashboard Refinement

```text
On the dashboard screen, move the quick action buttons closer to the top summary area and make the Today's Revenue card more visually prominent.
```

### Catalog Refinement

```text
On the catalog screen, add a stronger visual separation between Product and Service items. Make the search bar more prominent in the header.
```

### Transaction Refinement

```text
On the transaction screen, enlarge the primary Save Transaction button and make the cart summary area more visually distinct from the item list.
```

## 15. Notes

- Use the master prompt first, not the detailed prompts first.
- Refine one screen at a time.
- Do not ask Stitch for too many major changes in one prompt.
- If the result is off, re-run with one targeted refinement instead of rewriting the whole app prompt.
- After the structure is good, switch the language to Bahasa Indonesia.
