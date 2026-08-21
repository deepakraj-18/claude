# Vue 3 + Inertia.js Conventions

These conventions apply to Vue 3 / Inertia.js frontend code. `developer` must follow them during implementation; `tester` must test component behavior; `reviewer` must verify compliance.

## Component Structure (Single File Components)

```vue
<script setup>
// 1. Imports
import { ref, computed, onMounted } from 'vue'
import { useForm, router } from '@inertiajs/vue3'
import AppLayout from '@/Layouts/AppLayout.vue'

// 2. Props
const props = defineProps({
  ride: Object,
  zones: Array,
})

// 3. Reactive state
const isLoading = ref(false)
const searchQuery = ref('')

// 4. Computed
const filteredZones = computed(() =>
  props.zones.filter(z => z.name.includes(searchQuery.value))
)

// 5. Methods
function handleSubmit() { /* ... */ }

// 6. Lifecycle
onMounted(() => { /* ... */ })
</script>

<template>
  <!-- Single root element, semantic HTML -->
</template>

<style scoped>
/* Scoped styles only — no global leakage */
</style>
```

### Rules
- **Always use `<script setup>`** (Composition API) — not Options API.
- **Always use `scoped` styles** — never global styles in components.
- **Props are readonly** — never mutate props directly. Use `emit` or Inertia forms.
- **One component per file.** Name matches the filename: `RideCard.vue` exports `RideCard`.

## Inertia.js Patterns

### Page Components
Pages live in `resources/js/Pages/` and are rendered by Laravel controllers via `Inertia::render()`.

```php
// Laravel controller
return Inertia::render('Rides/Index', [
    'rides' => RideResource::collection($rides),
    'filters' => $request->only(['status', 'date']),
]);
```

```vue
<!-- resources/js/Pages/Rides/Index.vue -->
<script setup>
defineProps({
  rides: Array,
  filters: Object,
})
</script>
```

### Navigation (No Full Page Reloads)
```vue
<!-- ✅ Inertia Link (SPA navigation) -->
<Link :href="route('rides.show', ride.id)">View Ride</Link>

<!-- ❌ Never use raw <a> tags for internal navigation -->
<a :href="route('rides.show', ride.id)">View Ride</a>
```

### Forms (useForm)
```vue
<script setup>
import { useForm } from '@inertiajs/vue3'

const form = useForm({
  pickup: '',
  destination: '',
  vehicle_type_id: null,
})

function submit() {
  form.post(route('rides.store'), {
    onSuccess: () => form.reset(),
  })
}
</script>

<template>
  <form @submit.prevent="submit">
    <input v-model="form.pickup" />
    <div v-if="form.errors.pickup" class="error">{{ form.errors.pickup }}</div>
    <button :disabled="form.processing">Book Ride</button>
  </form>
</template>
```

### Shared Data (via HandleInertiaRequests middleware)
Access shared data via `usePage()`:
```vue
<script setup>
import { usePage } from '@inertiajs/vue3'
const { auth, flash } = usePage().props
</script>
```

## Routing (Ziggy)

Use Ziggy's `route()` helper for named Laravel routes — never hardcode URLs:
```vue
<!-- ✅ Named route -->
<Link :href="route('rides.show', { ride: ride.id })">View</Link>

<!-- ❌ Hardcoded URL -->
<Link href="/rides/123">View</Link>
```

## State Management (Vuex)

- Use Vuex for **client-side global state** (UI state, sidebar toggle, notifications).
- **Do NOT use Vuex for server data** — that comes from Inertia props, which are always fresh on navigation.
- Keep stores small and focused: `store/modules/ui.js`, `store/modules/notifications.js`.

## Layouts

```vue
<!-- resources/js/Layouts/AppLayout.vue -->
<template>
  <div class="app-layout">
    <Sidebar />
    <main>
      <slot />  <!-- Page content rendered here -->
    </main>
  </div>
</template>
```

Pages declare their layout:
```vue
<script setup>
import AppLayout from '@/Layouts/AppLayout.vue'
defineOptions({ layout: AppLayout })
</script>
```

## Maps & Geolocation

Ridekaroo uses both Google Maps API and Leaflet (OpenStreetMap):
- **Google Maps**: For geocoding, route calculation, and driver tracking.
- **Leaflet**: For open-source map rendering (`booking.vue` vs `open-booking.vue`).
- Use `vue3-google-map` component for Google Maps integration.
- Use `leaflet` + `leaflet-routing-machine` for Leaflet-based maps.

## Build (Vite)

- Config in `vite.config.js` with `laravel-vite-plugin`.
- Dev server: `npm run dev` (Vite HMR).
- Production build: `npm run build` (outputs to `public/build/`).
- Import aliases: `@` maps to `resources/js/`.

## Naming Conventions

| Element | Convention | Example |
|---|---|---|
| Component file | PascalCase `.vue` | `RideCard.vue`, `ZoneMap.vue` |
| Page file | PascalCase in route folders | `Pages/Rides/Index.vue` |
| Props | camelCase | `vehicleType`, `rideStatus` |
| Events (emit) | kebab-case | `@ride-selected`, `@form-submitted` |
| CSS classes | kebab-case (BEM optional) | `ride-card`, `ride-card__header` |
| Composables | `use` prefix | `useRideTracking`, `useMapControls` |
