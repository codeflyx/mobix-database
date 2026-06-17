# CODEFLYX POS — Database Schema Reference

**Engine:** Turso / LibSQL (SQLite-compatible)  
**Version:** V1 — Phase 1  
**Money:** All monetary values are `INTEGER` in PKR whole rupees (no decimals)  
**IDs:** `TEXT PRIMARY KEY` using ULIDs  
**Timestamps:** `TEXT` in ISO-8601 format e.g. `2026-04-06T10:30:00Z`  
**Soft deletes:** `deleted_at TEXT` — `NULL` = active, timestamp = deleted  

---

## Schema Change Rules

> **These rules apply every time a column or table is added, renamed, or removed.**  
> The schema and the codebase must always stay in sync. Never update one without the other.

### Rule 1 — Adding a new column to an existing table

1. Add the column to `schema.sql` (the source of truth).
2. Add the column to the matching file in `tables/` (e.g. `05_products.sql`).
3. Update this file (`SCHEMA.md`) — add the column to the table description, enum reference, or business rules section if relevant.
4. Search the codebase for every `SELECT`, `INSERT`, and `UPDATE` query that touches that table:
   - `admin/app/(app)/<table-name>/` — page.js, actions.js, Client.js
   - `software/app/<table-name>/` — page.js, actions.js
   - Any shared lib files: `admin/lib/`, `software/lib/`
5. Update those queries to include the new column where appropriate.
6. If the column affects what is **displayed** in a list or detail view, update the matching Client component too.

### Rule 2 — Adding a new table

1. Add the `CREATE TABLE` + indexes to `schema.sql`.
2. Create a new numbered file in `tables/` following the existing FK order (e.g. `17_new_table.sql`). Include a header comment explaining purpose, key columns, and any non-obvious rules.
3. Add a row to the **Table Index** in this file.
4. Add the table to the **Relationships Map** in this file.
5. Add any new enums to the **Enum Reference** table in this file.
6. Add soft-delete info to the **Soft Delete Convention** section.
7. In the codebase, for each new table that has a corresponding UI page:
   - Create `admin/app/(app)/<table>/page.js` (server component — queries DB)
   - Create `admin/app/(app)/<table>/actions.js` (server actions — insert/update/delete)
   - Create `admin/app/(app)/<table>/<Table>Client.js` (client component — UI)
   - Add a nav entry to `admin/components/layout/nav.js`
   - Add a permission entry to `admin/lib/permissions.js`
   - Mirror the above in `software/app/<table>/` and `software/lib/nav.js` if the cashier app also needs it
8. If the new table is a **sub-table** (e.g. documents, line items) with no dedicated page, add its queries inside the parent page's actions instead.

### Rule 3 — Renaming or removing a column or table

1. Update `schema.sql` and the matching `tables/` file.
2. Update `SCHEMA.md` (this file).
3. **Search the entire codebase** for every reference to the old name before deleting:
   ```
   admin/app, admin/components, admin/lib
   software/app, software/components, software/lib
   ```
4. Update or remove every query, action, and client component that referenced the old column/table.
5. If removing a table that has a nav entry, also remove it from:
   - `admin/components/layout/nav.js`
   - `admin/lib/permissions.js`
   - `software/lib/nav.js`
   - Delete the corresponding page/actions/client files.

### Quick Checklist

```
Schema change made?
 ☐ schema.sql updated
 ☐ tables/<N>_<table>.sql updated
 ☐ SCHEMA.md updated (index, map, enums, rules)
 ☐ admin queries updated (page.js, actions.js, Client.js)
 ☐ software queries updated (page.js, actions.js)
 ☐ nav.js updated (if page added/removed)
 ☐ permissions.js updated (if page added/removed)
```

---

## Table Index

| # | File | Table | Purpose |
|---|---|---|---|
| 1 | [01_users.sql](tables/01_users.sql) | `users` | Staff accounts (admin / cashier) |
| 2 | [02_shop_settings.sql](tables/02_shop_settings.sql) | `shop_settings` | Shop identity and invoice config |
| 3 | [03_document_counters.sql](tables/03_document_counters.sql) | `document_counters` | Sequential number generator (INV-000001 etc.) |
| 4 | [04_categories.sql](tables/04_categories.sql) | `categories` | Product categories |
| 5 | [05_products.sql](tables/05_products.sql) | `products` | Product catalog |
| 6 | [06_product_stock.sql](tables/06_product_stock.sql) | `product_stock` | Quantity stock for non-IMEI products |
| 7 | [07_imei_units.sql](tables/07_imei_units.sql) | `imei_units` | Individual mobile units tracked by IMEI |
| 8 | [08_customers.sql](tables/08_customers.sql) | `customers` | Customer contacts and credit config |
| 9 | [09_customer_documents.sql](tables/09_customer_documents.sql) | `customer_documents` | CNIC / agreement uploads for customers |
| 10 | [10_suppliers.sql](tables/10_suppliers.sql) | `suppliers` | Supplier contacts |
| 11 | [11_supplier_documents.sql](tables/11_supplier_documents.sql) | `supplier_documents` | CNIC / agreement uploads for suppliers |
| 12 | [12_purchases.sql](tables/12_purchases.sql) | `purchases` | Stock-in transactions (from supplier or trade-in) |
| 13 | [13_purchase_items.sql](tables/13_purchase_items.sql) | `purchase_items` | Line items for each purchase |
| 14 | [14_invoices.sql](tables/14_invoices.sql) | `invoices` | Sales and return transactions |
| 15 | [15_invoice_items.sql](tables/15_invoice_items.sql) | `invoice_items` | Line items for each invoice |
| 16 | [16_payments.sql](tables/16_payments.sql) | `payments` | Individual payment events (in / out) |

---

## Relationships Map

```
users
 ├── shop_settings          (owner_user_id)
 ├── document_counters      (owner_user_id)
 ├── categories             (owner_user_id)
 ├── products               (owner_user_id)
 │    ├── product_stock     (product_id)
 │    └── imei_units        (product_id)
 ├── customers              (owner_user_id)
 │    ├── customer_documents(customer_id)
 │    └── invoices          (customer_id)
 │         ├── invoice_items(invoice_id)
 │         │    └── imei_units (sold_invoice_id)
 │         └── payments     (invoice_id)
 ├── suppliers              (owner_user_id)
 │    ├── supplier_documents(supplier_id)
 │    └── purchases         (supplier_id)
 │         ├── purchase_items(purchase_id)
 │         │    └── imei_units (purchase_item_id)
 │         └── payments     (purchase_id)
 └── purchases              (customer_id — for trade-ins)
```

---

## Key Business Rules

### Stock Tracking
Products have two tracking modes set at creation — never changed:

| `stock_tracking_type` | Stock source | Table used |
|---|---|---|
| `'imei'` | Count of `imei_units WHERE status = 'in_stock'` | `imei_units` |
| `'quantity'` | `product_stock.quantity` | `product_stock` |

### Product Serial Number (`products.serial_no`)
- Auto-assigned integer starting at 1, scoped per shop (`owner_user_id`)
- App assigns it inside a transaction:
  ```sql
  SELECT COALESCE(MAX(serial_no), 0) + 1
  FROM products WHERE owner_user_id = ?
  ```
- Used for fast POS lookup — cashier types `"42"` to find product #42
- Enforced unique per shop via `products_owner_serial_uq` index

### Document Numbering (`document_counters`)
Used for: invoices (`INV-000001`), purchases (`PUR-000001`), product serials.  
App flow (inside a transaction):
1. `SELECT next_no, prefix FROM document_counters WHERE owner_user_id=? AND doc_type=?`
2. Format: `prefix + padStart(next_no, padding, '0')`
3. `UPDATE document_counters SET next_no = next_no + 1`

### Purchases — `kind` vs `type`
- `kind`: **where** stock came from — `'supplier'` or `'trade_in'`
- `type`: **what action** — `'purchase'` (stock in) or `'return'` (stock out)
- For `kind='supplier'`: `supplier_id` is set
- For `kind='trade_in'`: `customer_id` is set

### Invoices — `type` and `sale_mode`
- `type`: `'sale'` (normal) or `'return'` (refund — `original_invoice_id` set)
- `sale_mode`: snapshot of payment at time of sale (avoids joining `payments` for display)
  - `'cash'` | `'jazzcash'` | `'easypaisa'` | `'bank_transfer'` | `'credit'` | `'mixed'`
  - `'credit'` = full khata/udhaar — `paid_total = 0`
  - `'mixed'` = part paid now, part on credit

### Payments — `direction`
- `'in'`  → money received from customer → `invoice_id` set
- `'out'` → money paid to supplier/customer → `purchase_id` set
- One invoice or purchase can have **multiple** payment rows (partial payments over time)

### IMEI Units — `selling_price`
- `NULL` → use `products.sale_price` at time of sale
- Set explicitly for used/refurbished phones priced individually
- Actual selling price is always captured in `invoice_items.unit_price` at sale time

### Profit Calculation
```sql
profit = invoice_items.line_total - (invoice_items.unit_cost_at_sale * invoice_items.qty)
```
`unit_cost_at_sale` is snapshotted at INSERT and **never updated**.

### Khata / Udhaar (Outstanding Balance)
No dedicated table — derived from invoices:
```sql
SELECT SUM(total - paid_total) AS balance
FROM invoices
WHERE customer_id = ? AND status != 'cancelled' AND deleted_at IS NULL
```

### Supplier Outstanding Dues
```sql
SELECT SUM(total - paid_total) AS dues
FROM purchases
WHERE supplier_id = ? AND status != 'cancelled' AND deleted_at IS NULL
```

---

## Enum Reference

| Table | Column | Allowed Values |
|---|---|---|
| `users` | `role` | `'admin'`, `'cashier'` |
| `products` | `stock_tracking_type` | `'imei'`, `'quantity'` |
| `imei_units` | `condition` | `'new'`, `'used'`, `'refurbished'` |
| `imei_units` | `pta_status` | `'approved'`, `'non-pta'`, `'pending'` |
| `imei_units` | `source` | `'supplier'`, `'trade_in'` |
| `imei_units` | `status` | `'in_stock'`, `'sold'`, `'returned'`, `'defective'` |
| `purchases` | `kind` | `'supplier'`, `'trade_in'` |
| `purchases` | `type` | `'purchase'`, `'return'` |
| `purchases` | `status` | `'completed'`, `'partial'`, `'pending'`, `'cancelled'` |
| `invoices` | `type` | `'sale'`, `'return'` |
| `invoices` | `sale_mode` | `'cash'`, `'jazzcash'`, `'easypaisa'`, `'bank_transfer'`, `'credit'`, `'mixed'` |
| `invoices` | `status` | `'completed'`, `'partial'`, `'pending'`, `'cancelled'` |
| `payments` | `direction` | `'in'`, `'out'` |
| `payments` | `method` | `'cash'`, `'jazzcash'`, `'easypaisa'`, `'bank_transfer'` |

---

## Soft Delete Convention

Tables with `deleted_at`:  
`products`, `customers`, `suppliers`, `purchases`, `invoices`

**Always filter active records with:**
```sql
WHERE deleted_at IS NULL
```

Tables without soft delete (hard delete is safe):  
`product_stock`, `imei_units`, `customer_documents`, `supplier_documents`,  
`purchase_items`, `invoice_items`, `payments`, `categories`,  
`document_counters`, `shop_settings`, `users`

---

## Files

```
database/
  schema.sql          ← full schema (single source of truth)
  SCHEMA.md           ← this file
  tables/
    01_users.sql
    02_shop_settings.sql
    03_document_counters.sql
    04_categories.sql
    05_products.sql
    06_product_stock.sql
    07_imei_units.sql
    08_customers.sql
    09_customer_documents.sql
    10_suppliers.sql
    11_supplier_documents.sql
    12_purchases.sql
    13_purchase_items.sql
    14_invoices.sql
    15_invoice_items.sql
    16_payments.sql
```
