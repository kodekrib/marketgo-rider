# MarketGO Rider

Flutter courier/delivery app with an Uber Eats / DoorDash–style UI:

- **Login** — brand-green hero, top bar, and a clean white card with demo
  quick-fill chips, email + password, keep-signed-in toggle, and Phone/OTP
  options.
- **Home (landing after login)** — online/offline pill, dark earnings card,
  incoming "New delivery" offer with stops + Accept/Decline, and a "Your day"
  stats row. Bottom nav switches between Home, Deliveries, Earnings, and
  Account (with sign out).

## Demo credentials

| Account  | Email                | Password  |
|----------|----------------------|-----------|
| Rider    | rider@marketgo.com   | Rider@123 |
| Courier  | courier@marketgo.com | Rider@123 |

Tap the **Rider** or **Courier** chip on the login screen to auto-fill a demo
account, then press **Sign In** to land on the rider home page.

## Run

```sh
flutter run -d chrome    # web
flutter run              # connected device/emulator
```

## Structure

- `lib/main.dart` — entry point
- `lib/app.dart` — theme + app root (`RiderApp`) and post-login `RiderHome`
- `lib/screens/login_screen.dart` — the `LoginScreen`
- `lib/screens/home_screen.dart` — the `HomeScreen` landing page and tabs

## Verify

```sh
flutter analyze
flutter test
```
# marketgo-rider
