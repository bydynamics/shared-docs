# Changelog 22.3.7.0

Merge of upstream forked-from 1.0.6.27 → 1.0.6.29 into OnPrem, plus KSeF fixes.

## Supplier Party Rewrite
- Supplier endpoint/legal entity now resolved via **Responsibility Center** instead of Company Information only
- New `XmlPortsHelpersPSB` procedures: `GetAccountingSupplierPartyInfoBIS`, `GetAccountingSupplierPartyTaxSchemeBIS`, `GetAccountingSupplierPartyLegalEntityBIS`, `FindReportSelections`
- Removed `SupplierPeppolID`/`SupplierPeppolScheme`/`SupplierPeppolValue` global overrides from both XmlPorts
- NL/DK scheme logic moved into `PartyLegalEntitySchemeID` trigger

## New Objects
- **ResponsibilityCenterPSB** (tableext 63017 / pageext 63018) — `EInvoiceIdPSB`, `EInvoiceNamePSB`, `EInvoiceVATRegistrationNoPSB` fields
- **CustomReportSelectionsPSB** (tableext 63018) — `UseForPeppolPSB` field + `InitValuePSB`
- **CustomerReportSelectionsPSB** (pageext 63019) — exposes `UseForPeppolPSB` on Customer Report Selections

## Client & Attachment Changes
- `ClientPSB.Send` now takes a `Sender` parameter (RespCenter-aware party ID)
- `SaveAttachment` saves the XML as a Document Attachment at send time
- `InsertAttachment` calls removed from `WebhookReceiverPSB` (no longer needed)
- New field `CreatedByEConnectPSB` on Document Attachment to filter auto-created attachments

## Report Selections
- `ReportSelections` record changed to `temporary` in both XmlPorts
- Report selection init replaced with `FindReportSelections` (supports Custom Report Selections per customer)
- `ReportSelectionsPSB` tableext: `InitValue` changed from `true` to `false`, added `CopyCustomReportSelectionToReportSelectionPSB`

## Other Changes
- `ValidationPSB`: changed validation from "Sell-to Customer No." to "Bill-to Customer No."
- `StatusPSB` enum: added values 20 (INVOICECLEARED), 21 (INVOICEERROR), 22 (INVOICERETRY)
- `GetSupplierSchemeAndId` in `PartyIdHelpersPSB` marked Obsolete
- `GetAccountingSupplierPartyName` in `XmlPortsHelpersPSB` marked Obsolete
- Permission set updated: added R access to Responsibility Center, Custom Report Selection, Bank Account
- BC 22 compatibility: removed fields not available in BC 22 (`Email Body Layout Name/AppID`, `Report Layout Name/AppID`)

## KSeF Issues (documented)
- Bank account fix applied (uses invoice bank account IBAN instead of Company Information)
- Issues 1, 3, 4, 5 assessed — no code changes needed (data entry / config / with eConnect)
