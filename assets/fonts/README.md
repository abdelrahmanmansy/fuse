# Bundled fonts

FUSE bundles two fonts so English and Arabic render identically on every machine.
Both are licensed under the SIL Open Font License 1.1, which permits bundling and
redistribution inside an application.

| File | Family | Source |
| --- | --- | --- |
| `NotoSans-Variable.ttf` | Noto Sans (variable width/weight) | <https://github.com/google/fonts/tree/main/ofl/notosans> |
| `NotoSansArabic-Variable.ttf` | Noto Sans Arabic (variable width/weight) | <https://github.com/google/fonts/tree/main/ofl/notosansarabic> |

License texts are `OFL-NotoSans.txt` and `OFL-NotoSansArabic.txt` in this folder.

`src/ui/theme_builder.gd` uses Noto Sans as the theme default and registers Noto
Sans Arabic as its fallback, so mixed Latin/Arabic strings and Arabic shaping work
without relying on system fonts.
