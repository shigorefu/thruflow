# Connector Logo Sources

Retrieved and verified on 2026-09-07. These assets identify the optional source
services in connector rows and imported-task source labels. They are third-party
artwork and are not relicensed under the ThruFlow source-code license.

## Apple Reminders

- Owner: Apple Inc.
- Official local source: `/System/Applications/Reminders.app/Contents/Resources/AppIcon.icns`.
- Asset: `ThruFlow/Assets.xcassets/ConnectorRemindersLogo.imageset/Reminders.png`.
- Extraction: `sips -s format png AppIcon.icns --out Reminders.png` decoded the
  bundled 256 x 256 representation. No drawing, recoloring, masking, or effects
  were added. The original icon inset is preserved.

## Todoist

- Owner: Todoist / Doist.
- Official press page: <https://www.todoist.com/press>.
- Official logo pack: <https://www.todoist.com/brand-assets/todoist-logo.zip>.
- Light asset: unmodified `Icon/Color.png` from that pack, stored as
  `ThruFlow/Assets.xcassets/ConnectorTodoistLogo.imageset/Todoist.png`.
- Dark asset: unmodified `Icon/White.png` from that pack, stored as
  `ThruFlow/Assets.xcassets/ConnectorTodoistLogo.imageset/Todoist-Dark.png`.
- The pack includes `Todoist Brand Guidelines.pdf`, updated 01/2021. The UI uses
  its supplied color and white variations, maintains the original proportions,
  and reserves clear space of half the logomark height on each side. The primary
  mark is 28 points; compact source labels use the documented 16-point minimum.

Current API brand usage:
<https://developer.todoist.com/api/v1/#section/Developing-with-Todoist/Brand-usage>

ThruFlow is not created by, affiliated with, or supported by Todoist.

## SHA-256 of Bundled Artwork

- `ThruFlow/Assets.xcassets/ConnectorRemindersLogo.imageset/Reminders.png`: `6477699ac3a244f047553084c1359ddad51e48683e2dc8290e9c6d8ee6baf45f`
- `ThruFlow/Assets.xcassets/ConnectorTodoistLogo.imageset/Todoist.png`: `625d678beb4d166608af81ba07549100079b49b4fea0481fc3530ada09298bee`
- `ThruFlow/Assets.xcassets/ConnectorTodoistLogo.imageset/Todoist-Dark.png`: `efdc476a2908165a8804b2ea01f74635d29b47304d43a4634bf7221ed48cd1ff`
