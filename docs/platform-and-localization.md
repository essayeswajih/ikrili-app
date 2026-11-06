# Platform and localization policy

English, French, and Arabic are supported. Arabic is rendered with an explicit
RTL direction at the application root; Material and Cupertino localization
delegates provide platform strings. New user-facing text must be added to all
three maps in `app_localizations.dart`.

Native platforms use SQLite. Web uses the `WebCache` SharedPreferences adapter
for cached snapshots and pending commands, while server data remains the
authority. Screens that require full relational queries must use the API on web
until their repository has a web cache implementation.

Currency values must be formatted through `CurrencyFormatter`; the stored
currency code is never silently converted. Notification settings are persisted
locally and should be synchronized with the backend preferences endpoint when
the authenticated API session is available.

Responsive and accessibility review checklist: keyboard navigation on web,
minimum touch targets, semantic labels for map/actions, text scaling at 200%,
dark-theme contrast, Arabic overflow, and form error announcements.
