# CartQuest

**Cross-platform grocery route optimizer** — native iOS (Swift/SwiftUI) and Android (Kotlin/Jetpack Compose) apps that find the optimal multi-store shopping route for your grocery list, minimizing total drive time while covering every item.

> For a deeper walkthrough of every layer, data flow, concurrency model, and cross-platform comparison, see **[ARCHITECTURE.md](ARCHITECTURE.md)**.

## Demo

Both demos walk through the full user journey: **authentication → product search with location-aware availability → cart building → route optimization across nearby stores → Google Maps navigation → trip completion → community feed browsing and sharing.**

### iOS (Swift / SwiftUI)



![CarQuest iOS Demo](https://github.com/user-attachments/assets/de15b458-b4a8-40b9-a9f4-0edeab235f5c)

### Android (Kotlin / Jetpack Compose)

Coming soon

---

## Table of Contents

- [Demo](#demo)
- [Motivation](#motivation)
- [Architecture Overview](#architecture-overview)
- [iOS App](#ios-app)
- [Android App](#android-app)
- [Shared Backend (Firebase)](#shared-backend-firebase)
- [Route Optimization Algorithm](#route-optimization-algorithm)
- [External API Integrations](#external-api-integrations)
- [Data Model](#data-model)
- [Security Model](#security-model)
- [Performance Engineering](#performance-engineering)
- [Testing Strategy](#testing-strategy)
- [Project Structure](#project-structure)
- [Setup & Configuration](#setup--configuration)
- [Design Decisions](#design-decisions)

---

## Motivation

Grocery shopping across multiple stores is a constrained optimization problem: each store carries different products at different prices, and driving between stores has a real time cost. CartQuest solves this by:

1. Letting users search products with real-time in-store availability across all nearby stores, then build a cart with optional substitute products
2. Querying product availability in parallel across up to 50 nearby Kroger-family store locations
3. Solving a **minimum-cost set cover** variant to find the smallest set of stores that covers every cart item (including substitutes)
4. Using the **Google Directions API** with waypoint optimization to minimize total drive time across feasible store subsets, evaluated in parallel
5. Rendering the optimal route on an interactive map with turn-by-turn navigation handoff

The app also features a **community feed** where users can share completed shopping runs (with embedded static map images), providing social visibility into route efficiency and cost savings.

---

## Architecture Overview

Both platforms follow **MVVM (Model–View–ViewModel)** with a **Repository pattern** for data access, cleanly separating concerns across four layers:

```
┌─────────────────────────────────────────────────────────┐
│                    View Layer                            │
│  SwiftUI Views (iOS) │ Jetpack Compose Screens (Android)│
├─────────────────────────────────────────────────────────┤
│                  ViewModel Layer                         │
│  @Observable classes  │  StateFlow + ViewModel           │
│  State machines (enum)│  Sealed classes for state        │
├─────────────────────────────────────────────────────────┤
│                 Repository Layer                         │
│  CartRepository │ UserRepository │ RunsRepository        │
│  Firestore abstraction — platform-specific SDKs          │
├─────────────────────────────────────────────────────────┤
│                  Service Layer                           │
│  KrogerService/API │ DirectionsService │ LocationService  │
│  RouteOptimizer (pure algorithm, no framework deps)      │
└─────────────────────────────────────────────────────────┘
```

**Why MVVM + Repository?** ViewModels expose reactive state that the declarative UI layers (SwiftUI / Compose) observe directly, eliminating manual view update logic. The Repository layer abstracts Firestore operations behind a clean async interface, making it straightforward to swap data sources or add caching without touching UI code. The Service layer encapsulates external API interactions (Kroger, Google Directions) and pure algorithms (RouteOptimizer), keeping them independently testable and reusable.

---

## iOS App

**Language:** Swift 5.9+
**UI Framework:** SwiftUI (100% declarative — no UIKit except `UIViewRepresentable` bridges for Google Maps and the share sheet)
**Minimum Target:** iOS 17.0
**State Management:** `@Observable` macro (Observation framework)
**Dependencies:** Firebase iOS SDK (Auth, Firestore), Google Maps iOS SDK, Google Sign-In iOS

### State Management Approach

The iOS app uses Swift's `@Observable` macro (iOS 17+) rather than the older `ObservableObject` / `@Published` pattern. This provides:

- **Automatic dependency tracking** — SwiftUI only re-renders views that read properties that actually changed, without requiring explicit `@Published` annotations
- **Simpler ViewModel declarations** — no conformance to `ObservableObject`, no `objectWillChange` publishers
- **Seamless two-way binding** via `@Bindable` in views that need to mutate ViewModel state

ViewModels use **enum-based state machines** to model screen states:

```swift
enum RouteState: Equatable {
    case loading
    case computed(route: RouteOptimizer.OptimizedRoute, userLocation: CLLocationCoordinate2D)
    case error(String)
}
```

This pattern eliminates impossible states (e.g., a loading indicator shown alongside an error message) and makes the view's `switch` exhaustive — the compiler enforces that every state is handled.

### Navigation Architecture

```
CartQuestiOSApp (auth state gate)
├── LoginView                        [unauthenticated]
└── AppTabView                       [authenticated]
    ├── Tab 1: Shop
    │   └── NavigationStack
    │       ├── ShopHomeView         [centered search bar]
    │       ├── ProductListView      [grid results + availability badges]
    │       ├── CartView             [cart items + substitutes + "Find Route"]
    │       │   └── SubstituteSearchView  [push via navigationDestination]
    │       └── RouteMapView         [push via NavigationLink]
    ├── Tab 2: Community Feed
    │   └── NavigationStack
    │       └── RunDetailView        [push via navigationDestination]
    └── Tab 3: Profile
        └── ProfileView             [account info + logout]
```

The app root (`CartQuestiOSApp`) observes `LoginViewModel.authState` and conditionally renders either the login flow or the main tab interface. Each tab maintains its own `NavigationStack`, providing independent navigation history per tab — standard iOS UX behavior. The Shop tab uses a shared `ShopViewModel` that manages search, cart state, and location-aware product availability across all screens in the navigation stack. On trip completion, the `onTripCompleted` callback propagates up through `RouteMapView` → `CartView` → `AppTabView`, where it clears the cart, resets the Shop navigation stack (by rotating the `NavigationStack` identity via `UUID`), refreshes the Community feed, and switches the selected tab to Community.

### UIKit Interop

Three components require `UIViewRepresentable` / `UIViewControllerRepresentable` bridges:

| Component | Bridge Type | Reason |
|-----------|-------------|--------|
| `GoogleMapsView` | `UIViewRepresentable` | Google Maps iOS SDK provides `GMSMapView` (UIKit) — wrapped to display route polylines and store markers |
| `RunMiniMapView` | `UIViewRepresentable` | Lightweight map in run detail view showing store markers only |
| `ActivityViewController` | `UIViewControllerRepresentable` | iOS share sheet (`UIActivityViewController`) for sharing generated trip cards |

### Share Card Generation

The iOS share card uses SwiftUI's `ImageRenderer` (iOS 16+) to render a `ShareCardView` — a regular SwiftUI view — directly to a `UIImage` at 3× scale. The share card includes an embedded **Google Static Maps** image showing store markers and a connecting path, fetched asynchronously before rendering:

```swift
@MainActor
static func render(run: CompletedRun, mapImage: UIImage? = nil) -> UIImage? {
    let renderer = ImageRenderer(content: ShareCardView(run: run, mapImage: mapImage))
    renderer.scale = 3.0
    return renderer.uiImage
}
```

The `loadStaticMapImage` method constructs a Google Static Maps API URL with numbered markers for each store and a polyline path connecting them, then fetches the image asynchronously. The share card layout includes the app icon, date, map image, numbered store list with item counts, and summary statistics (total cost, item count, drive time).

---

## Android App

**Language:** Kotlin 2.0
**UI Framework:** Jetpack Compose (100% Compose — no XML layouts)
**Min SDK:** 24 (Android 7.0) / **Target SDK:** 36
**Build System:** Gradle Kotlin DSL with version catalogs (`libs.versions.toml`)
**State Management:** Kotlin `StateFlow` / `MutableStateFlow`
**Dependencies:** Firebase Android SDK (Auth, Firestore), Google Maps Compose, Retrofit 2, OkHttp 4, Coil, Credential Manager

### State Management Approach

The Android app uses Kotlin Coroutines' `StateFlow` for reactive state emission, collected in Compose via `collectAsState()`. Each ViewModel exposes an immutable `StateFlow<T>` backed by a private `MutableStateFlow<T>`:

```kotlin
sealed class RouteState {
    object Loading : RouteState()
    data class Computed(val route: OptimizedRoute, val userLocation: LatLng) : RouteState()
    data class Error(val message: String) : RouteState()
}

private val _routeState = MutableStateFlow<RouteState>(RouteState.Loading)
val routeState: StateFlow<RouteState> = _routeState
```

**Why `StateFlow` over `LiveData`?** StateFlow is coroutine-native (no lifecycle dependency for emission), supports `combine()` / `map()` operators for derived state, and has a well-defined initial value — avoiding the nullable `LiveData.value` footgun. Compose's `collectAsState()` handles lifecycle-aware collection automatically.

The `CommunityFeedViewModel` demonstrates **flow combination** for reactive search filtering:

```kotlin
val filteredRuns = searchQuery
    .debounce(300)
    .combine(allRuns) { query, runs ->
        if (query.isBlank()) runs
        else runs.filter { /* match against user, store, product names */ }
    }
    .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())
```

### Navigation Architecture

```
MainActivity (auth state gate)
├── LoginScreen                          [unauthenticated]
└── AppNavigation                        [authenticated]
    ├── Tab 1: Shop
    │   └── NavHost
    │       ├── ShopHomeScreen                      [centered search bar]
    │       ├── ProductListScreen                   [grid results + availability]
    │       ├── CartScreen                          [cart items + substitutes + checkout]
    │       │   └── SubstituteSearchScreen/{idx}    [navigate with cartItemIndex arg]
    │       └── RouteMapScreen/{cartId}             [navigate with arg]
    ├── Tab 2: Community
    │   └── NavHost
    │       ├── CommunityFeedScreen      [start]
    │       └── RunDetailScreen/{runId}  [navigate with arg]
    └── Tab 3: Profile
        └── ProfileScreen               [account info + logout]
```

Navigation uses **Jetpack Navigation Compose** with a sealed `Screen` class for type-safe route definitions. The Shop tab uses a shared `ShopViewModel` across its NavHost, with `LocationService` initialized via `LaunchedEffect` on first composition. Route parameters (`cartId`, `runId`, `cartItemIndex`) are extracted via `SavedStateHandle` or `NavBackStackEntry.arguments` in ViewModels and screens. On trip completion, the `onTripCompleted` callback in `RouteMapScreen` clears the cart, pops back to `ShopHomeScreen`, and switches the selected tab to Community.

### Authentication: Credential Manager

Android authentication uses the modern **Credential Manager API** (replacing the deprecated Google Sign-In SDK):

```kotlin
val request = GetCredentialRequest.Builder()
    .addCredentialOption(GetGoogleIdOption.Builder()
        .setServerClientId(WEB_CLIENT_ID)
        .setFilterByAuthorizedAccounts(false)
        .build())
    .build()
```

This integrates with the system-level credential picker, supporting passkeys, saved passwords, and federated identity (Google) in a unified flow. The returned `GoogleIdTokenCredential` is exchanged for a Firebase `AuthCredential` to establish the session.

### Build Configuration & Secrets

Secrets are loaded from a gitignored `secrets.properties` file and injected into `BuildConfig` at compile time via Gradle:

```kotlin
buildConfigField("String", "KROGER_CLIENT_ID", "\"${secretsProperties.getProperty("KROGER_CLIENT_ID", "")}\"")
```

This avoids hardcoding API keys in source while keeping them accessible at runtime through generated constants (`BuildConfig.KROGER_CLIENT_ID`). The Google Maps API key is additionally injected as a manifest placeholder for the `<meta-data>` tag required by the Maps SDK.

### Share Card Generation

Unlike iOS (which leverages SwiftUI's `ImageRenderer`), the Android share card is rendered programmatically using the **Canvas API**:

```kotlin
fun render(run: CompletedRun, context: Context, mapBitmap: Bitmap? = null): Bitmap {
    val height = calculateHeight(run, mapBitmap != null)
    val bitmap = Bitmap.createBitmap(WIDTH, height, Bitmap.Config.ARGB_8888)
    val canvas = Canvas(bitmap)
    // Draw app icon, title, date, map, numbered stores, stats, footer
    return bitmap
}
```

The share card includes an embedded **Google Static Maps** image (fetched via `loadStaticMapImage`) showing numbered store markers and a connecting path. The renderer dynamically calculates bitmap height based on content (number of stores, presence of map image), draws the app icon alongside the title, numbered store badges with item counts, and summary statistics. Sharing uses `FileProvider` for secure URI generation and `Intent.ACTION_SEND` with the system chooser.

**Why Canvas instead of Compose-to-Bitmap?** Compose snapshot testing APIs for bitmap capture are experimental and require a running composition. The Canvas approach gives precise pixel control, works from any coroutine context, and produces consistent output regardless of device configuration.

---

## Shared Backend (Firebase)

Both platforms share the same Firebase project, providing a unified backend:

| Service | Usage |
|---------|-------|
| **Firebase Auth** | Email/password registration + sign-in, Google federated identity |
| **Cloud Firestore** | User profiles, shopping carts, completed run history |
| **Security Rules** | Row-level access control (see [Security Model](#security-model)) |

### Firestore Schema

```
Firestore
├── users/{userId}
│   ├── uid: string
│   ├── email: string
│   ├── displayName: string
│   ├── photoUrl: string
│   └── createdAt: timestamp
│   └── carts/ (subcollection)
│       └── {cartId}
│           ├── id: string
│           ├── status: "active" | "completed"
│           ├── createdAt: timestamp
│           ├── updatedAt: timestamp
│           └── items: array<CartItem>
│               ├── productId: string
│               ├── name: string
│               ├── brand: string
│               ├── imageUrl: string
│               ├── quantity: number
│               └── substitutes: array<Substitute>
│                   ├── productId: string
│                   ├── name: string
│                   └── brand: string
│
└── runs/{runId}
    ├── userId: string
    ├── displayName: string
    ├── photoUrl: string
    ├── completedAt: timestamp
    ├── totalDriveTimeMinutes: number
    ├── totalCost: number
    └── stores: array<StoreStop>
        ├── storeId: string
        ├── storeName: string
        ├── address: string
        ├── lat: number
        ├── lng: number
        └── items: array<AssignedItem>
            ├── productId: string
            ├── name: string
            ├── brand: string
            └── price: number
```

**Why carts as a subcollection under users?** Carts are inherently user-scoped — no cross-user access is needed. Subcollections keep the `users` document lightweight (no unbounded array growth) and enable efficient queries (`where status == "active"` scoped to a single user's carts).

**Why runs as a top-level collection?** Completed runs are readable by all authenticated users (community feed). A top-level collection allows a single `orderBy(completedAt, desc).limit(20)` query without collection group queries, simplifying security rules and indexing.

---

## Route Optimization Algorithm

The core algorithmic challenge: given a shopping cart of *n* items and *m* nearby stores with varying product availability, find the **minimum-drive-time route** that visits the fewest stores necessary to cover all items.

### Formal Problem Definition

This is a variant of the **Weighted Set Cover Problem** where:
- **Universe** *U* = set of all cart items
- **Sets** *S₁, S₂, …, Sₘ* = products available at each store
- **Cost function** = total drive time of the route visiting a particular store subset (not a per-store cost, but a route-level cost dependent on the Directions API)

The route-level cost function makes this strictly harder than classical set cover — we can't greedily pick stores by marginal cost because the cost of adding a store depends on the entire route, not just the store itself.

### Algorithm

The optimizer (`RouteOptimizer.swift` / `RouteOptimizer.kt`) implements a **minimum-cardinality enumeration** strategy:

```
function optimize(cartItems, storeAvailabilities, userLocation, getDriveTime):
    // Phase 1: Build coverage matrix
    coverage = {}
    for each (itemIndex, item) in cartItems:
        productIds = [item.productId] + item.substitutes.map(s -> s.productId)
        coverage[itemIndex] = { storeIdx | any productId available at storeIdx }

    // Phase 2: Validate feasibility
    uncovered = { idx | coverage[idx] is empty }
    if uncovered is not empty:
        throw UncoveredItemsError(uncovered)

    // Phase 3: Enumerate minimal subsets (increasing cardinality)
    for k = 1 to |stores|:
        feasibleSubsets = { S ⊆ stores, |S| = k | S covers all items }
        if feasibleSubsets is not empty:
            break  // found minimum cardinality

    // Phase 4: Minimize drive time within minimum-cardinality subsets (parallelized)
    routeCandidates = parallelMap(feasibleSubsets, subset ->
        (driveTime, polyline) = getDriveTime(userLocation, subset)
        assignItemsToStores(cartItems, subset) with driveTime, polyline
    ).filterSuccessful()

    return routeCandidates.minBy(driveTime)
```

**Phase 3 — Combination generation** uses backtracking to enumerate all C(m, k) subsets of size *k*. Starting from k=1, we find the minimum number of stores needed and only evaluate drive times for subsets of that minimum size. This dramatically prunes the search space: if one store can cover everything, we never evaluate 2-store combinations.

**Phase 4 — Parallel drive time evaluation.** Item assignments for all feasible subsets are pre-computed synchronously (no concurrency issues). Then, all Directions API calls are dispatched in parallel using `withTaskGroup` (iOS) / `coroutineScope { async }` (Android). Failed API calls are filtered out, and the route with the minimum total drive time is selected via `min(by:)` / `minByOrNull`. This parallelization reduces the total wall-clock time from O(feasibleSubsets) sequential API calls to approximately O(1) parallel calls.

**Item assignment** assigns each cart item to the first store (in visit order) that carries it, preferring the primary product over substitutes in declared priority order. This greedy assignment is optimal given a fixed store sequence because it concentrates items at earlier stops (reducing the chance of visiting a store for only one item).

### Complexity Analysis

- **Coverage matrix construction:** O(n × m × s) where *s* is max substitutes per item
- **Subset enumeration:** O(C(m, k)) where *k* is the minimum cover size — exponential in worst case, but practical because *m* (nearby store count) is bounded by the API query limit (10) and *k* is typically 1–3
- **Per-subset evaluation:** One Google Directions API call with waypoint optimization (all subsets evaluated in parallel)

For the typical case (10 stores, 2-store cover), we evaluate at most C(10, 2) = 45 subsets. With parallel evaluation, the wall-clock time is bounded by the slowest single Directions API call rather than the sum of all 45.

### Substitute Priority System

Each cart item carries an ordered list of substitutes. During coverage checking and item assignment, the optimizer respects this priority:

```
CartItem: "Organic Whole Milk"
  └── substitutes (priority order):
      1. "Whole Milk (store brand)"
      2. "2% Milk (organic)"
```

The coverage matrix considers all product IDs (primary + substitutes), but assignment prefers the primary, falling back through substitutes in declared order. This lets users express preferences like "I want brand X, but I'll accept brand Y if brand X isn't available at any nearby store."

---

## External API Integrations

### Kroger API

The [Kroger Developer API](https://developer.kroger.com/) provides product catalog and store location data across Kroger-family banners.

**Authentication:** OAuth 2.0 Client Credentials flow

| Platform | Implementation | Thread Safety |
|----------|---------------|---------------|
| iOS | `KrogerService` with `NSLock`-guarded token cache | `NSLock` around token read/write |
| Android | `KrogerAuthManager` with Kotlin `Mutex` | `Mutex.withLock { }` suspending lock |

Both implementations cache the access token and preemptively refresh 60 seconds before expiry to avoid mid-request token invalidation:

```
tokenExpiry = currentTime + expiresIn - 60 seconds
```

**Endpoints used:**

| Endpoint | Purpose | Parameters |
|----------|---------|------------|
| `POST /v1/connect/oauth2/token` | Obtain access token | `grant_type=client_credentials`, `scope=product.compact` |
| `GET /v1/products` | Search products by keyword | `filter.term`, `filter.locationId`, `filter.limit` |
| `GET /v1/locations` | Find stores by coordinates (up to 50) | `filter.lat.near`, `filter.lon.near`, `filter.radiusInMiles`, `filter.limit` |

Product search fans out across all nearby store location IDs in parallel (up to 50 stores), deduplicating results by product ID. Only products with confirmed in-store availability are shown. The optimizer separately queries each nearby store for each product in the cart (also parallelized), building the coverage matrix for route computation.

### Google Directions API

Used to compute actual drive times and route polylines for store subsets.

**Key feature:** `waypoints=optimize:true` — Google reorders waypoints to minimize total route distance. This means we provide the store set and Google returns the optimal visit sequence, which we then use for item assignment and map rendering.

```
GET /maps/api/directions/json?
    origin={userLat},{userLng}
    &destination={lastStoreLat},{lastStoreLng}
    &waypoints=optimize:true|{store1Lat},{store1Lng}|{store2Lat},{store2Lng}
    &key={API_KEY}
```

The response provides:
- `routes[0].legs[].duration.value` — per-leg drive time in seconds (summed for total)
- `routes[0].overview_polyline.points` — encoded polyline for map rendering
- `routes[0].waypoint_order` — optimized visit sequence

### Google Maps SDK

| Platform | SDK | Usage |
|----------|-----|-------|
| iOS | Google Maps iOS SDK (`GMSMapView`) | Route polyline rendering, numbered store markers, user location |
| Android | Maps Compose (`GoogleMap` composable) | Same — polyline, markers, camera positioning |

Both platforms decode the overview polyline from the Directions API into coordinate arrays for rendering. The iOS app includes a custom polyline decoder implementing the [Google Encoded Polyline Algorithm](https://developers.google.com/maps/documentation/utilities/polylinealgorithm), while Android uses the Maps SDK utility.

**Navigation handoff:** Both platforms construct deep-link URIs to the Google Maps app with all stops in route order (not just the last stop as a destination). The iOS app uses the `comgooglemaps://` URL scheme with `saddr` (user location) and `daddr` (all stops chained with `+to:`), falling back to `https://www.google.com/maps/dir/{origin}/{stop1}/{stop2}/...`. Android uses an `ACTION_VIEW` intent with the `/maps/dir/` path format for multi-stop routes, or `google.navigation:q=` for single-stop routes, targeting `com.google.android.apps.maps` with a browser fallback.

---

## Data Model

Both platforms define identical model structures to ensure Firestore document compatibility. Here's the shared schema with platform-specific serialization notes:

### CartItem

```
CartItem
├── productId: String        # Kroger product ID
├── name: String             # Product display name
├── brand: String            # Brand name
├── imageUrl: String         # Product image URL (from Kroger)
├── quantity: Int             # Default: 1
└── substitutes: [Substitute]
    ├── productId: String
    ├── name: String
    └── brand: String
```

Substitutes are managed through a dedicated `SubstituteSearchView`/`SubstituteSearchScreen` that reuses the same multi-store parallel search pipeline. Users add substitutes from the cart view — each substitute is searched across all nearby stores and added to the cart item's `substitutes` array. During route optimization, the coverage matrix considers all product IDs (primary + substitutes), and item assignment prefers the primary product, falling back through substitutes in declared priority order.

| iOS | Android |
|-----|---------|
| `struct CartItem: Codable, Identifiable` | `data class CartItem` |
| `Identifiable.id` computed from `productId` | Default parameter values for Firestore deserialization |
| `Codable` for automatic Firestore encoding | Firestore auto-maps data class properties |

### StoreStop (computed during route optimization)

```
StoreStop
├── storeId: String
├── storeName: String
├── address: String          # "{addressLine1}, {city}, {state}"
├── lat: Double
├── lng: Double
└── items: [AssignedItem]
    ├── productId: String
    ├── name: String
    ├── brand: String
    └── price: Double        # Unit price from Kroger
```

### CompletedRun (persisted to Firestore)

```
CompletedRun
├── userId: String
├── displayName: String
├── photoUrl: String
├── completedAt: Timestamp   # iOS: Date / Android: Long (millis)
├── stores: [StoreStop]
├── totalDriveTimeMinutes: Int
└── totalCost: Double        # Sum of all assigned item prices
```

---

## Security Model

### Firestore Security Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can only read/write their own user document
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;

      // Carts are private to the user
      match /carts/{cartId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
    }

    // Completed runs: owner can write, anyone authenticated can read
    match /runs/{runId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null
                    && request.resource.data.userId == request.auth.uid;
      allow update, delete: if request.auth != null
                            && resource.data.userId == request.auth.uid;
    }
  }
}
```

**Access control summary:**

| Collection | Read | Write | Rationale |
|------------|------|-------|-----------|
| `users/{userId}` | Owner only | Owner only | Profile data is private |
| `users/{userId}/carts/{cartId}` | Owner only | Owner only | Shopping carts are private |
| `runs/{runId}` | Any authenticated user | Owner only (create/update/delete) | Community feed requires read access; `create` validates `userId` matches auth UID to prevent impersonation |

### API Key Management

| Platform | Mechanism | Storage |
|----------|-----------|---------|
| iOS | `Secrets.xcconfig` → Build Settings → Info.plist | Gitignored `.xcconfig` file |
| Android | `secrets.properties` → Gradle `buildConfigField` → `BuildConfig` | Gitignored properties file |

Both approaches keep secrets out of version control while making them accessible at compile time. Runtime access patterns differ by platform convention: iOS reads from the app bundle's Info.plist; Android accesses generated `BuildConfig` constants.

---

## Performance Engineering

### Debouncing Strategy

Aggressive API call reduction through layered debouncing:

| Operation | iOS Delay | Android Delay | Rationale |
|-----------|-----------|---------------|-----------|
| Product search | Immediate on submit | Immediate on submit | Search is triggered on submit, not on keystroke; parallelized across all nearby store locations |
| Cart save to Firestore | 800ms | 1000ms | Batch rapid mutations (quantity changes, add/remove) into a single write |
| Community feed search | 300ms | 300ms (via `Flow.debounce`) | Client-side filtering is fast; shorter delay for responsiveness |

### Task Cancellation (iOS)

Search and save operations use cancellable `Task` references to prevent race conditions:

```swift
private var searchTask: Task<Void, Never>?

private func debouncedSearch() {
    searchTask?.cancel()               // Cancel in-flight search
    searchTask = Task {
        try? await Task.sleep(for: .milliseconds(400))
        guard !Task.isCancelled else { return }  // Check after sleep
        await search(query: query)
    }
}
```

This ensures that only the latest user input triggers an API call — earlier, stale requests are cancelled before execution.

### Coroutine Scoping (Android)

All ViewModel coroutines launch in `viewModelScope`, which is automatically cancelled when the ViewModel is cleared (e.g., on configuration change or navigation away). This prevents memory leaks and stale callbacks:

```kotlin
viewModelScope.launch {
    _routeState.value = RouteState.Loading
    // ...long-running route computation...
    _routeState.value = RouteState.Computed(route, userLocation)
}
```

### Lazy Rendering

Both platforms use lazy containers for scrollable content:
- **iOS:** `LazyVGrid` (2-column) for product search results, `LazyVStack` for store stop cards
- **Android:** `LazyVerticalGrid` (2-column) for product search results, `LazyColumn` for feed items, cart items, and store stops

This ensures only visible items are composed/rendered, keeping memory usage flat regardless of list size.

### Parallelized Network Operations

The app aggressively parallelizes independent API calls using structured concurrency:

| Operation | iOS | Android | Parallelism |
|-----------|-----|---------|-------------|
| Product search | `withTaskGroup` | `async/awaitAll` | Fans out across all nearby store location IDs simultaneously |
| Availability matrix | Nested `withTaskGroup` (stores × products) | Nested `async/awaitAll` | Each store's products queried in parallel; all stores queried in parallel |
| Drive time evaluation | `withTaskGroup` over feasible subsets | `coroutineScope { async }` over feasible subsets | All C(m, k) subset Directions API calls made concurrently |

This parallelization is critical for route optimization latency: with 10 stores and 5 products, the sequential approach would make 50 API calls in series. The parallel approach completes all 50 in roughly the time of one call (bounded by API rate limits and network latency).

### Token Caching

The Kroger OAuth token is cached in memory with preemptive refresh (60 seconds before expiry). During route optimization, which makes many concurrent API calls (one per product per store), this avoids redundant token requests. Thread safety is ensured via `NSLock` (iOS) / `Mutex` (Android) to handle concurrent access from parallel network operations.

---

## Testing Strategy

### Unit Tests (Android)

The `RouteOptimizerTest` suite validates the core algorithm with focused test cases:

| Test Case | What It Validates |
|-----------|-------------------|
| Single store covers all items | Simplest case — one-store route returned correctly |
| Items split across multiple stores | Multi-store coverage with correct item assignment |
| Optimizer selects cheapest route among equal-coverage subsets | Drive time comparison logic |
| Substitute fallback | Items assigned via substitute when primary unavailable |
| Uncovered items throw error | Graceful failure when no store carries a required product |
| Empty cart / no stores throw error | Input validation at algorithm boundaries |

Tests use a **mock `getDriveTime` callback** that returns deterministic drive times, isolating the algorithm from network dependencies:

```kotlin
val getDriveTime: suspend (LatLng, List<KrogerStore>) -> Pair<Int, String> = { _, stores ->
    Pair(stores.size * 600, "mock_polyline")  // 10 min per store
}
```

### Testing Architecture Decisions

- **RouteOptimizer accepts `getDriveTime` as a function parameter** (strategy pattern) specifically to enable testing — production code injects the real Directions API call, tests inject a mock
- **Repository layer is separate from ViewModels** — repositories can be independently mocked for ViewModel unit tests
- **Pure data models with no framework dependencies** — testable without Android/iOS instrumentation

---

## Project Structure

```
CartQuest/
├── README.md
├── ARCHITECTURE.md                              # Detailed architecture documentation
├── firestore.rules                              # Firestore security rules
├── .gitignore
│
├── CartQuestiOS/
│   └── CartQuestiOS/
│       ├── CartQuestiOSApp.swift                # App entry, Firebase init, auth gate
│       ├── Info.plist                           # Location permissions, API key refs
│       ├── Secrets.xcconfig                     # API keys (gitignored)
│       │
│       ├── Models/
│       │   ├── User.swift
│       │   ├── Cart.swift
│       │   ├── CartItem.swift                   # CartItem + Substitute
│       │   ├── CompletedRun.swift
│       │   ├── KrogerProduct.swift              # API response models
│       │   ├── KrogerStore.swift                # API response models
│       │   └── StoreStop.swift                  # AssignedItem
│       │
│       ├── Services/
│       │   ├── KrogerService.swift              # OAuth2 + product/location API
│       │   ├── DirectionsService.swift          # Google Directions API client
│       │   ├── LocationService.swift            # CoreLocation wrapper
│       │   └── RouteOptimizer.swift             # Set cover + route optimization
│       │
│       ├── Repositories/
│       │   ├── UserRepository.swift             # Firestore user CRUD
│       │   ├── CartRepository.swift             # Firestore cart CRUD
│       │   └── RunsRepository.swift             # Firestore runs CRUD
│       │
│       └── Views/
│           ├── Navigation/
│           │   └── AppTabView.swift             # Three-tab layout (Shop, Community, Profile)
│           ├── Auth/
│           │   ├── LoginView.swift              # Email/password + Google Sign-In UI
│           │   └── LoginViewModel.swift         # Auth state machine
│           ├── Shop/
│           │   ├── ShopHomeView.swift           # Google-style centered search landing
│           │   ├── ProductListView.swift        # Grid results with availability badges
│           │   ├── ProductCard.swift            # Product card with add-to-cart action
│           │   ├── CartView.swift               # Cart items + substitutes + "Find Route"
│           │   ├── SubstituteSearchView.swift   # Substitute product search + add
│           │   └── ShopViewModel.swift          # Shared VM: search, cart, location, subs
│           ├── Profile/
│           │   └── ProfileView.swift            # Account info + logout
│           ├── Route/
│           │   ├── RouteMapView.swift           # Google Maps + store cards
│           │   ├── RouteMapViewModel.swift      # Route orchestration
│           │   └── StoreStopCard.swift          # Per-store item breakdown
│           └── Feed/
│               ├── CommunityFeedView.swift      # Feed list with search
│               ├── CommunityFeedViewModel.swift # Feed state + filtering
│               ├── RunDetailView.swift          # Run detail + mini map
│               ├── RunDetailViewModel.swift     # Run detail state
│               └── ShareCardRenderer.swift      # ImageRenderer share card
│
└── CartQuestAndroid/
    └── app/src/main/java/com/amoghghadge/cartquestandroid/
        ├── MainActivity.kt                      # App entry, Firebase init, auth gate
        │
        ├── data/
        │   ├── model/
        │   │   ├── User.kt
        │   │   ├── Cart.kt
        │   │   ├── CartItem.kt
        │   │   ├── Substitute.kt
        │   │   ├── CompletedRun.kt
        │   │   ├── KrogerProduct.kt
        │   │   ├── KrogerStore.kt
        │   │   └── StoreStop.kt                 # AssignedItem
        │   ├── remote/
        │   │   ├── KrogerApiService.kt          # Retrofit interface + factory
        │   │   ├── KrogerAuthManager.kt         # Mutex-based OAuth2 token cache
        │   │   └── DirectionsApiService.kt      # Google Directions client
        │   └── repository/
        │       ├── UserRepository.kt
        │       ├── CartRepository.kt
        │       └── RunsRepository.kt
        │
        ├── service/
        │   ├── LocationService.kt               # FusedLocationProvider wrapper
        │   └── RouteOptimizer.kt                # Set cover + route optimization
        │
        └── ui/
            ├── auth/
            │   ├── LoginScreen.kt               # Compose login UI + Credential Manager
            │   └── LoginViewModel.kt            # Auth state machine
            ├── navigation/
            │   ├── AppNavigation.kt             # Bottom nav + per-tab NavHosts
            │   └── Screen.kt                    # Sealed route definitions (6 routes)
            ├── shop/
            │   ├── ShopHomeScreen.kt            # Centered search bar landing page
            │   ├── ProductListScreen.kt         # Grid results with availability badges
            │   ├── ProductCard.kt               # Product card composable
            │   ├── CartScreen.kt                # Cart items + substitutes + checkout
            │   ├── SubstituteSearchScreen.kt    # Substitute product search + add
            │   └── ShopViewModel.kt             # Shared VM: search, cart, location, subs
            ├── profile/
            │   ├── ProfileScreen.kt             # Account info + logout
            │   └── ProfileViewModel.kt          # Profile state + signOut
            ├── route/
            │   ├── RouteMapScreen.kt            # Maps Compose + route display
            │   ├── RouteMapViewModel.kt         # Route orchestration
            │   └── StoreStopCard.kt             # Per-store item breakdown
            ├── feed/
            │   ├── CommunityFeedScreen.kt       # Feed list with search
            │   ├── CommunityFeedViewModel.kt    # Flow combination filtering
            │   ├── RunDetailScreen.kt           # Run detail + map + sharing
            │   ├── RunDetailViewModel.kt        # Run detail state
            │   └── ShareCardRenderer.kt         # Canvas bitmap generation
            └── theme/
                ├── Color.kt                     # Material 3 color palette
                ├── Theme.kt                     # Dynamic color + dark mode
                └── Type.kt                      # Typography scale
```

---

## Setup & Configuration

### Prerequisites

- **iOS:** Xcode 15+, iOS 17+ device or simulator
- **Android:** Android Studio Hedgehog+, Min SDK 24
- **Backend:** Firebase project with Auth and Firestore enabled
- **APIs:** Kroger Developer account, Google Cloud project with Maps SDK + Directions API enabled

### Firebase Setup

1. Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
2. Enable **Authentication** with Email/Password and Google sign-in providers
3. Enable **Cloud Firestore** in production mode
4. Deploy the security rules from `firestore.rules`
5. Register both apps:
   - **iOS:** Add an iOS app with your bundle ID → download `GoogleService-Info.plist` into `CartQuestiOS/CartQuestiOS/`
   - **Android:** Add an Android app with package `com.amoghghadge.cartquestandroid` → download `google-services.json` into `CartQuestAndroid/app/`

### API Keys

**iOS** — Create `CartQuestiOS/CartQuestiOS/Secrets.xcconfig`:
```
KROGER_CLIENT_ID = your_kroger_client_id
KROGER_CLIENT_SECRET = your_kroger_client_secret
GOOGLE_MAPS_API_KEY = your_google_maps_api_key
```

**Android** — Create `CartQuestAndroid/secrets.properties`:
```properties
KROGER_CLIENT_ID=your_kroger_client_id
KROGER_CLIENT_SECRET=your_kroger_client_secret
GOOGLE_MAPS_API_KEY=your_google_maps_api_key
```

### Kroger Developer Portal

1. Register at [developer.kroger.com](https://developer.kroger.com)
2. Create an application to obtain OAuth2 client credentials
3. Ensure the `product.compact` scope is enabled

### Google Cloud

1. Enable the **Maps SDK for iOS**, **Maps SDK for Android**, and **Directions API** in the [Google Cloud Console](https://console.cloud.google.com)
2. Create an API key and restrict it to these APIs
3. For Android, add your app's SHA-1 fingerprint to the key's restrictions

---

## Design Decisions

### Why Native Over Cross-Platform?

CartQuest implements the same app natively on both platforms rather than using a cross-platform framework (React Native, Flutter, KMM). This decision was deliberate:

1. **Platform-idiomatic UI** — SwiftUI and Jetpack Compose have fundamentally different layout, navigation, and animation paradigms. A native approach produces UX that feels right on each platform rather than a lowest-common-denominator abstraction.

2. **First-class SDK access** — Google Maps SDK, CoreLocation, FusedLocationProvider, Credential Manager, `ImageRenderer`, Canvas API — all are accessed directly without bridging layers or third-party wrappers.

3. **Modern framework adoption** — Using `@Observable` (iOS 17+) and Compose (no XML) demonstrates comfort with the latest platform capabilities, not just legacy patterns.

### Why Kroger API Specifically?

Kroger operates the largest supermarket chain in the US by revenue, with 2,700+ stores under banners including Kroger, Ralphs, Fred Meyer, Harris Teeter, and others. Their public Developer API is one of the few grocery APIs that provides both **product catalog search** and **per-store availability**, which are both required for the set cover optimization to work. Most grocery delivery APIs (Instacart, etc.) don't expose store-level availability for third-party use.

### Why Set Cover Over Greedy Approaches?

A greedy approach (e.g., always pick the store covering the most uncovered items) would be faster but doesn't account for drive time. Two stores that cover everything but are 30 miles apart might be worse than three stores that are clustered nearby. By enumerating all minimum-cardinality subsets and evaluating each with the Directions API, we find the true drive-time-optimal route — not just the minimum store count.

### Why Firestore Over a Custom Backend?

For a mobile-first app with straightforward CRUD operations, Firestore provides:
- **Zero server management** — no API server to deploy, scale, or monitor
- **Native SDKs** — direct integration with both iOS and Android, with offline caching
- **Security rules** — declarative, Firebase-Auth-aware access control without middleware
- **Real-time listeners** — available for future features (live feed updates)

A custom backend (e.g., Express + PostgreSQL) would be warranted if the app needed complex server-side queries, relational joins, or background processing — none of which apply here.

### Why Manual DI Over Hilt/Dagger?

The Android app uses manual dependency construction in ViewModels rather than a DI framework. For an app of this scope (6 ViewModels, 3 repositories, 3 API services), the overhead of Hilt's annotation processing, module declarations, and generated code outweighs the benefit. Dependencies are straightforward (no complex graphs, no scoping needs beyond ViewModel lifecycle), and the constructor-based approach keeps the dependency graph explicit and visible.

This is a pragmatic choice — in a larger codebase with dozens of ViewModels and shared scoped dependencies, Hilt would be the clear winner.
