# React Native Conventions (Community CLI + React Native Paper)

These conventions apply to all React Native mobile code. `developer` must follow them during implementation; `reviewer` must reject any violation; `tester` must test on both platforms.

## ⚠️ Project Scaffold — Non-Negotiable

**Always use the React Native Community CLI. Never use `expo init`, `create-expo-app`, or `npx expo` to scaffold a project.**

```bash
# ✅ Correct — Community CLI scaffold
npx @react-native-community/cli@latest init ProjectName --template react-native-template-typescript

# ❌ Wrong — Expo scaffold (banned)
npx create-expo-app ProjectName
npx expo init ProjectName
```

**Expo packages are allowed** (and preferred for hardware/platform APIs). Only the Expo **scaffold and runtime** is banned. The distinction:

| | Allowed? | Example |
|---|---|---|
| Expo as project scaffold | ❌ **Never** | `create-expo-app`, `expo start` as the runner |
| Expo as Expo Go runtime | ❌ **Never** | Running with `expo start --go` |
| Individual Expo packages | ✅ **Yes** | `expo-camera`, `expo-image-picker`, `expo-notifications` |

Why: Community CLI gives full native build access (Xcode / Android Studio), custom native modules, and production-grade signing. Expo Go constrains what native code you can include.

---

## UI Library — React Native Paper (Primary)

**React Native Paper is the default UI library.** Use it for all standard UI components before reaching for custom implementations or other libraries.

### Setup
```bash
npm install react-native-paper react-native-safe-area-context react-native-vector-icons
```

For iOS after install:
```bash
npx pod-install
```

### Theme setup (once, in App.tsx)
```tsx
import { MD3LightTheme, PaperProvider } from 'react-native-paper'

const theme = {
  ...MD3LightTheme,
  colors: {
    ...MD3LightTheme.colors,
    primary: '#6750A4',    // Override per project brand colour
    secondary: '#625B71',
  },
}

export default function App() {
  return (
    <PaperProvider theme={theme}>
      {/* app content */}
    </PaperProvider>
  )
}
```

### Paper Components to Use

| Need | Paper Component |
|---|---|
| Button | `<Button mode="contained">` |
| Text input | `<TextInput mode="outlined">` |
| Card | `<Card>`, `<Card.Content>`, `<Card.Actions>` |
| App bar / header | `<Appbar.Header>`, `<Appbar.BackAction>` |
| List items | `<List.Item>`, `<List.Section>` |
| Dialogs / modals | `<Dialog>`, `<Portal>` |
| Snackbar / toast | `<Snackbar>` |
| Bottom navigation | `<BottomNavigation>` |
| Chips / tags | `<Chip>` |
| FAB | `<FAB>`, `<FAB.Group>` |
| Icons | `<Icon source="camera" />` (Material icons via vector-icons) |
| Loading | `<ActivityIndicator>` |
| Dividers | `<Divider>` |
| Switch / toggle | `<Switch>` |
| Radio buttons | `<RadioButton>` |
| Checkbox | `<Checkbox>` |

### When NOT to use Paper
Only skip Paper when:
- The design requirement deviates significantly from Material Design 3
- Paper's component has a measurable performance problem at scale

Always document the reason in a code comment: `// Custom: Paper TextInput doesn't support inline suffix icon on Android`

---

## Approved Expo Packages (install individually — NOT via `expo install`)

Install these with `npm install`, not `expo install` (which rewrites `package.json` with Expo version constraints that conflict with Community CLI):

```bash
# Hardware & Device APIs
npm install expo-camera              # Camera capture
npm install expo-image-picker        # Photo library / camera roll
npm install expo-notifications       # Push notifications (FCM + APNs)
npm install expo-location            # GPS / location services
npm install expo-media-library       # Save images/videos to device gallery
npm install expo-av                  # Audio / video playback
npm install expo-document-picker     # File upload (PDF, docs)
npm install expo-file-system         # File read/write

# Security & Auth
npm install expo-secure-store        # Encrypted key-value storage (ALWAYS use for tokens/passwords)
npm install expo-local-authentication # Biometrics (FaceID / fingerprint)

# UX & Utilities
npm install expo-haptics             # Haptic feedback
npm install expo-clipboard           # Copy/paste to clipboard
npm install expo-constants           # Device info (device ID, app version, platform)
npm install expo-linking             # Deep linking / universal links
npm install expo-blur                # Blur effects (iOS frosted glass)
npm install expo-splash-screen       # Splash screen control
```

**Rule**: When a feature requires a hardware API, check this list first. If an Expo package exists for it, use it — don't reach for a different community package for the same thing.

**When to prefer a community package over an Expo package:**
- Navigation → React Navigation (not expo-router)
- Animation → react-native-reanimated (not Expo's Animated)
- Data fetching → TanStack Query (no Expo equivalent)
- Storage (non-sensitive) → @react-native-async-storage/async-storage

---

## Full Dependency Stack

```bash
# 1. Scaffold (run once at project init)
npx @react-native-community/cli@latest init ProjectName \
  --template react-native-template-typescript

# 2. Navigation
npm install @react-navigation/native @react-navigation/native-stack \
  @react-navigation/bottom-tabs @react-navigation/drawer
npm install react-native-screens react-native-safe-area-context

# 3. UI (React Native Paper)
npm install react-native-paper react-native-vector-icons

# 4. Animations & Gestures (required by Navigation too)
npm install react-native-reanimated react-native-gesture-handler

# 5. Data Fetching & State
npm install @tanstack/react-query axios
npm install zustand                                      # Global client state only

# 6. Storage
npm install @react-native-async-storage/async-storage   # Non-sensitive (cache, preferences)
npm install expo-secure-store                            # Sensitive (tokens, passwords)

# 7. Expo hardware packages — install per task as needed
npm install expo-camera expo-image-picker expo-notifications \
  expo-location expo-haptics expo-constants expo-linking

# iOS only (run after any native package install)
npx pod-install
```

---

## Project Structure

```
src/
├── components/
│   ├── ui/             Paper wrappers with custom theme (Button, TextInput variants)
│   └── forms/          Form inputs with validation
├── screens/            One folder per screen; screen-local components live here
├── navigation/         Navigator setup (stack, tab, drawer) with typed params
├── hooks/              Shared custom hooks only
├── lib/
│   └── native/         Native module wrappers — isolated typed interface
├── api/                Axios instance + endpoint functions
├── store/              Zustand stores (client-side global state only)
├── constants/          AppConstants.ts — ALL hardcoded values (per constants.md rule)
├── theme/              Paper theme configuration
└── App.tsx

android/                Native Android — Community CLI owns this, don't hand-edit
ios/                    Native iOS — same
```

---

## Navigation

- **React Navigation only.** Do not add Expo Router, React Native Navigation (Wix), or any other navigation library.
- Use typed navigation params — no `any` types:
  ```tsx
  type RootStackParamList = {
    Home: undefined
    RideDetails: { rideId: string }
    Profile: { userId: string }
  }
  ```
- Stack navigator for linear flows, bottom tab navigator for top-level sections.

---

## Components & State Rules

- **Function components + hooks only** — no class components.
- **React Query** for server state (remote data, loading, error, caching).
- **Zustand** for global client-side state (notification count, auth state, theme toggle).
- **`useState`** for screen-local UI state (modal open, form field values).
- No web-only APIs (`window`, `document`, DOM events). Use RN equivalents (`Dimensions`, `Platform`, `AppState`).

---

## Platform Differences

- Use `Platform.select()` or `.ios.tsx` / `.android.tsx` suffixes — not inline `Platform.OS` checks scattered through component bodies.
- Any task touching navigation, gestures, permissions, or native modules **must be verified on both iOS and Android** before marking PASS.

---

## Native Modules

- Prefer an Expo package or community package over writing a custom native module.
- If a custom native module is genuinely required, isolate it behind a typed JS interface in `src/lib/native/` — the rest of the app never imports native code directly.
- Any native package addition requires `npx pod-install` (iOS) and/or a Gradle sync (Android) — call this out explicitly in task implementation notes.

---

## Testing

- **Jest + React Native Testing Library** (`@testing-library/react-native`).
- Mock all Expo packages in tests — never call real hardware in test environment:
  ```ts
  jest.mock('expo-camera', () => ({
    Camera: () => null,
    useCameraPermissions: () => [{ granted: true }, jest.fn()],
  }))
  jest.mock('expo-notifications', () => ({
    getExpoPushTokenAsync: jest.fn().mockResolvedValue({ data: 'mock-token' }),
    requestPermissionsAsync: jest.fn().mockResolvedValue({ status: 'granted' }),
  }))
  ```
- E2E (Detox or Maestro) only if the repo already has it — don't introduce a new E2E framework as part of an unrelated task.

---

## Rules for Agents

### `developer`
- Check `src/constants/AppConstants.ts` before hardcoding any value (per `~/.claude/rules/constants.md`).
- Use a Paper component first — only build a custom component if Paper can't satisfy the requirement (and document why).
- Install Expo packages with `npm install expo-*`, never `expo install expo-*`.
- Run the app with `npx react-native run-android` / `npx react-native run-ios` — never `expo start`.
- Remember `npx pod-install` on iOS after any native package addition.

### `reviewer`
**FAIL any task that:**
- Imports from the `expo` root package: `import { ... } from 'expo'` (pulls in the Expo runtime)
- Adds `expo` (the root package, not `expo-*`) to `dependencies` in `package.json`
- Uses `expo install` in setup steps
- Uses `expo start` or `expo build` as the run command
- Implements a custom component for something Paper already provides without documentation of why
- Adds a second navigation library alongside React Navigation
- Uses `Platform.OS` inline more than once per component (use `Platform.select()`)
- Uses `@react-native-async-storage` for tokens or credentials (use `expo-secure-store`)

### `tester`
- Mock all Expo packages — see mocking examples above.
- Verify both iOS and Android acceptance criteria if the task touches native features.
- Include at least one test verifying the component renders correctly within a `<PaperProvider>` wrapper.
