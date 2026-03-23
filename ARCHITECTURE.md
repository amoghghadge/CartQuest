# CartQuest — Architecture Deep Dive

This document provides a detailed walkthrough of every architectural layer, data flow, and implementation detail in the CartQuest iOS and Android apps. It supplements the [README](README.md) with lower-level specifics intended for developers reviewing or extending the codebase.

---

## Table of Contents

- [End-to-End User Flow](#end-to-end-user-flow)
- [Authentication Pipeline](#authentication-pipeline)
- [Shop Flow: Search → Cart → Checkout](#shop-flow-search--cart--checkout)
- [Route Optimization Pipeline](#route-optimization-pipeline)
- [Map Rendering & Navigation Handoff](#map-rendering--navigation-handoff)
- [Community Feed & Sharing](#community-feed--sharing)
- [Cross-Platform Comparison Matrix](#cross-platform-comparison-matrix)
- [Concurrency Model](#concurrency-model)
- [Error Handling Taxonomy](#error-handling-taxonomy)
- [Networking Layer Details](#networking-layer-details)

---

## End-to-End User Flow

The complete user journey through the app follows this sequence:

```
1. AUTH
   User opens app → Firebase checks existing session
   ├── Session exists → Skip to AppTabView
   └── No session → LoginView/LoginScreen
       ├── Email/Password sign up → Create Firebase user + Firestore user doc
       └── Email/Password sign in → Authenticate against Firebase

2. SHOP (Tab 1: Shop)
   ShopHomeView/ShopHomeScreen displayed (Google-style centered search)
   ├── On init: fetch nearest Kroger store for availability data
   ├── Load active cart from Firestore (status == "active")
   │   └── If none exists, start with empty cart
   ├── User types search → Kroger API call (location-aware, limit 50)
   ├── Results shown in 2-column grid with availability badges
   ├── User taps "Add to Cart" → Added to cart.items array
   ├── User adjusts quantity via stepper on product cards
   ├── Every mutation → Debounced Firestore save (800ms iOS / 1000ms Android)
   ├── Cart icon badge shows item count across all screens
   └── User taps "Find Route" in CartView/CartScreen → Navigate to RouteMapView/Screen

3. ROUTE OPTIMIZATION (RouteMapView/Screen)
   Triggered automatically on screen load:
   ├── Load active cart from Firestore
   ├── Get user GPS location (CoreLocation / FusedLocationProvider)
   ├── Query Kroger API for 10 nearest stores (10-mile radius)
   ├── For each store × each product: query availability
   ├── Build coverage matrix
   ├── Enumerate minimum-cardinality store subsets
   ├── For each feasible subset: query Google Directions API
   ├── Select route with minimum total drive time
   ├── Assign items to stores (priority-based)
   └── Display on map with polyline + numbered markers

4. NAVIGATION
   User taps "Start Navigation"
   ├── iOS: Open Google Maps via comgooglemaps:// URL scheme
   └── Android: Open Google Maps via Intent (ACTION_VIEW)
   User taps "Complete Trip"
   ├── Calculate total cost from assigned item prices
   ├── Save CompletedRun to Firestore /runs collection
   ├── Mark cart as completed (status = "completed")
   └── Navigate back to ShopHome (fresh cart)

5. COMMUNITY FEED (Tab 2: Community)
   CommunityFeedView/Screen displayed
   ├── Query Firestore: runs ordered by completedAt desc, limit 20
   ├── Display run cards with user info, stores, stats
   ├── Search filter: debounced client-side filtering
   └── Tap card → RunDetailView/Screen
       ├── Load full run document
       ├── Display items grouped by store
       ├── Display mini map with store markers
       └── Share button → Generate share card image → Native share sheet

6. PROFILE (Tab 3: Profile)
   ProfileView/ProfileScreen displayed
   ├── Shows user avatar, display name, email from Firebase Auth
   ├── Shows user ID (truncated) and email verification status
   └── "Log Out" button → Firebase signOut → returns to LoginView/LoginScreen
```

---

## Authentication Pipeline

### iOS

```
LoginViewModel.authState: AuthState
├── .unauthenticated → LoginView rendered
├── .loading → ProgressView shown
├── .authenticated(User) → AppTabView rendered
└── .error(String) → Error alert shown

Sign Up Flow:
  LoginViewModel.signUpWithEmail()
  ├── Auth.auth().createUser(email, password)
  ├── user.createProfileChangeRequest() → set displayName
  └── UserRepository.createUserDocument(User)
      └── Firestore setData on /users/{uid}

Sign In Flow:
  LoginViewModel.signInWithEmail()
  └── Auth.auth().signIn(email, password)

Session Check (App Launch):
  LoginViewModel.init()
  └── if Auth.auth().currentUser != nil → .authenticated
```

### Android

```
LoginViewModel.authState: StateFlow<AuthState>
├── Unauthenticated → LoginScreen rendered
├── Loading → CircularProgressIndicator shown
├── Authenticated(user) → AppNavigation rendered
└── Error(message) → Snackbar shown

Sign Up Flow:
  LoginViewModel.signUpWithEmail()
  ├── Firebase.auth.createUserWithEmailAndPassword()
  ├── user.updateProfile(displayName)
  └── UserRepository.createUserDocument(User)
      └── Firestore collection("users").document(uid).set(data)

Google Sign-In Flow:
  LoginViewModel.signInWithGoogle(context)
  ├── CredentialManager.getCredential(request)
  ├── Extract GoogleIdTokenCredential from result
  ├── GoogleAuthProvider.getCredential(idToken)
  ├── Firebase.auth.signInWithCredential(firebaseCredential)
  └── UserRepository.createUserDocument(User)
```

**Key difference:** Android implements Google Sign-In through the modern Credential Manager API, while iOS has it stubbed for GoogleSignIn-iOS SDK integration (pending SPM package addition). Both share the same Firebase Auth backend, so a user signed up on one platform can sign in on the other.

---

## Shop Flow: Search → Cart → Checkout

The Shop tab uses a shared ViewModel (`ShopViewModel` on both platforms) that manages search state, cart state, and location-aware product availability across a 3-screen NavigationStack: ShopHomeView → ProductListView → CartView (iOS) / ShopHomeScreen → ProductListScreen → CartScreen (Android).

### Location-Aware Search

On ViewModel init, the nearest Kroger store is fetched using the device's GPS coordinates. This `nearbyLocationId` is passed to all subsequent product searches, enabling the Kroger API to return per-store fulfillment data (in-store availability).

### Search Pipeline

```
User types in search bar (ShopHomeView) and hits Search
    │
    ▼
search() called
├── Cancel any in-flight searchTask
├── If query is empty → return
├── Start new Task:
│   └── Call krogerService.searchProducts(term: query, locationId: nearbyLocationId)
│       ├── Ensure valid OAuth token (refresh if expired)
│       ├── GET /v1/products?filter.term={query}&filter.locationId={id}&filter.limit=50
│       └── Decode response → [KrogerProduct]
    │
    ▼
searchResults mapped to [ProductResult] with isAvailable flag
    │
    ▼
Navigate to ProductListView/ProductListScreen → 2-column grid with availability badges
```

### Mutation Operations

All cart mutations follow the same pattern: mutate the in-memory `cart.items` array, then trigger a debounced save.

| Operation | Behavior |
|-----------|----------|
| **Add item** | Append `CartItem` to `cart.items` with `productId`, `name`, `brand`, `imageUrl` from Kroger product |
| **Remove item** | Remove at index from `cart.items` (or decrement to 0) |
| **Increment quantity** | `cart.items[index].quantity += 1` via stepper on product card |
| **Decrement quantity** | If quantity is 1, remove item; otherwise `cart.items[index].quantity -= 1` |
| **Update quantity** | Set `cart.items[index].quantity` directly; if < 1, remove item |

### Persistence Pipeline

```
Any mutation
    │
    ▼
debounceSave() called
├── Cancel any in-flight saveTask
└── Start new Task with delay:
    ├── Sleep 800ms (iOS) / 1000ms (Android)
    ├── Check cancellation → abort if cancelled
    └── CartRepository.saveCart(cart)
        ├── If cart.id is empty → create new document
        │   └── Firestore addDocument to /users/{uid}/carts
        │       → returns generated ID → update cart.id
        └── If cart.id exists → update existing document
            └── Firestore setData on /users/{uid}/carts/{cartId}
```

**Why debounce saves?** Without debouncing, rapid quantity changes (user tapping stepper repeatedly) would fire a Firestore write on every increment. At $0.18/100K writes (Firestore pricing), this adds up and creates unnecessary network traffic. The 800ms–1000ms debounce batches rapid mutations into a single write while keeping the perceived save latency under 1 second for isolated changes.

---

## Route Optimization Pipeline

This is the most complex subsystem in the app. The route computation is orchestrated by `RouteMapViewModel` and delegated to `RouteOptimizer` for the algorithm itself.

### Orchestration (RouteMapViewModel)

```
computeRoute() [called on ViewModel init]
    │
    ├── 1. Load cart: CartRepository.getActiveCart()
    │   └── Firestore query: /users/{uid}/carts where status == "active" limit 1
    │
    ├── 2. Get location: LocationService.getCurrentLocation()
    │   ├── iOS: CLLocationManager with async continuation
    │   └── Android: FusedLocationProviderClient.lastLocation
    │
    ├── 3. Find stores: KrogerService.searchLocations(lat, lon, radius=10, limit=10)
    │   └── Returns up to 10 nearest Kroger-family stores
    │
    ├── 4. Build availability matrix:
    │   for each store:
    │       for each unique productId in cart (primary + substitutes):
    │           KrogerService.searchProducts(term=productId, locationId=store.locationId, limit=1)
    │           if exact productId match found → add to store's availableProducts map
    │   └── Result: [StoreAvailability(store, {productId: KrogerProduct})]
    │
    ├── 5. Optimize: RouteOptimizer.optimize(cartItems, storeAvailabilities, userLocation, getDriveTime)
    │   └── getDriveTime callback:
    │       DirectionsService.getDirections(origin, destination, waypoints=[intermediate stores])
    │       └── Google Directions API with optimize:true
    │       → returns (totalDurationSeconds, encodedPolyline)
    │
    └── 6. Result: OptimizedRoute(stops: [StoreStop], totalDriveTimeSeconds, encodedPolyline)
        └── routeState = .computed(route, userLocation)
```

### Algorithm Detail (RouteOptimizer)

**Input:**
- `cartItems: [CartItem]` — items to purchase
- `storeAvailabilities: [StoreAvailability]` — per-store product maps
- `userLocation` — GPS coordinates
- `getDriveTime: (origin, stores) → (seconds, polyline)` — injected callback

**Step 1: Coverage Matrix**

For each cart item index *i*, determine which store indices can fulfill it:

```
coverage[i] = { j | any product in [item.productId, item.substitutes.map(s.productId)]
                    exists in storeAvailabilities[j].availableProducts }
```

**Step 2: Feasibility Check**

If any `coverage[i]` is empty, that item can't be purchased anywhere — throw an error with the uncovered item indices.

**Step 3: Minimum Cardinality Subsets**

Generate all C(m, k) store index combinations for k = 1, 2, 3, …:

```
for k in 1..m:
    feasible = combinations(m, k).filter(subset → coverage.all(stores → stores ∩ subset ≠ ∅))
    if feasible.isNotEmpty(): break
```

The `combinations` function uses **recursive backtracking** to generate subsets without materializing all C(m, k) at once:

```swift
func backtrack(start: Int, current: inout Set<Int>) {
    if current.count == size {
        result.append(current)
        return
    }
    for i in start..<count {
        current.insert(i)
        backtrack(start: i + 1, current: &current)
        current.remove(i)
    }
}
```

**Step 4: Drive Time Evaluation**

For each feasible subset, invoke `getDriveTime` which calls the Google Directions API. Track the minimum. If a particular Directions call fails (network error, invalid coordinates), skip that subset — this graceful degradation ensures one bad API response doesn't fail the entire optimization.

**Step 5: Item Assignment**

For the winning subset, assign each cart item to the first store (in visit order) that carries it:

```
for each cartItem:
    candidateProductIds = [cartItem.productId] + cartItem.substitutes.map(s.productId)
    for each storeIndex in winningSubset (visit order):
        if any candidateProductId in store's availableProducts:
            assign item to this store
            break
```

This greedy first-fit assignment respects the visit order (earlier stores get priority) and product priority (primary preferred over substitutes). The result is `[StoreStop]` where each stop contains its assigned items with prices.

---

## Map Rendering & Navigation Handoff

### Polyline Decoding

The Google Directions API returns routes as [encoded polylines](https://developers.google.com/maps/documentation/utilities/polylinealgorithm) — a compact string representation of a sequence of coordinates.

**iOS** decodes polylines using a manual bit-shifting implementation in `RouteMapView`:

```swift
// Algorithm: decode 5-bit chunks from ASCII, accumulate signed deltas
var index = polyline.startIndex
var lat = 0, lng = 0
while index < polyline.endIndex {
    // Read 5-bit chunks until continuation bit is 0
    // Apply sign inversion for negative deltas
    // Accumulate and divide by 1e5 for coordinate
}
```

**Android** uses the Google Maps SDK's utility for polyline decoding, converted to `LatLng` objects for the `Polyline` composable.

### Map Components

| Component | iOS | Android |
|-----------|-----|---------|
| Map widget | `GMSMapView` via `UIViewRepresentable` | `GoogleMap` composable (Maps Compose) |
| Route polyline | `GMSPolyline` with coordinate path | `Polyline` composable with `LatLng` list |
| Store markers | `GMSMarker` with numbered labels (1, 2, 3…) | `Marker` composable with numbered `BitmapDescriptor` |
| User location | `GMSMarker` at user coordinates | `Marker` with default icon at user coordinates |
| Camera | `GMSCameraUpdate.fit(bounds, padding)` | `CameraUpdateFactory.newLatLngBounds(bounds, padding)` |

### Navigation Handoff

**iOS:**
```
Primary:   comgooglemaps://?saddr={userLat},{userLng}&daddr={destLat},{destLng}+to:{wp1}+to:{wp2}&directionsmode=driving
Fallback:  https://www.google.com/maps/dir/?api=1&origin={...}&destination={...}&travelmode=driving
```

**Android:**
```kotlin
val intent = Intent(Intent.ACTION_VIEW, uri).apply {
    setPackage("com.google.android.apps.maps")
}
// If Google Maps installed → launch directly
// Otherwise → fallback to browser with same URI
```

Both platforms prefer the Google Maps app for native turn-by-turn navigation and fall back to the web version if the app isn't installed.

---

## Community Feed & Sharing

### Feed Query

```
Firestore query:
  collection("runs")
  .orderBy("completedAt", descending)
  .limit(20)
```

All authenticated users can read from `/runs` (per security rules). The feed displays:
- User avatar (from `photoUrl`) and display name
- Relative timestamp ("2 hours ago")
- Store badges (visual tags for each store in the route)
- Summary stats: item count, total cost, drive time

### Client-Side Search Filtering

Rather than server-side full-text search (which Firestore doesn't natively support without extensions), the feed implements **client-side filtering**:

```kotlin
// Android: Flow combination
searchQuery.debounce(300).combine(allRuns) { query, runs ->
    runs.filter { run ->
        run.displayName.contains(query, ignoreCase = true) ||
        run.stores.any { it.storeName.contains(query, ignoreCase = true) } ||
        run.stores.any { store -> store.items.any { it.name.contains(query, ignoreCase = true) } }
    }
}
```

This works well for the current scale (20 items loaded). For larger datasets, server-side search (Algolia, Elasticsearch, or Firestore full-text search extensions) would be needed.

### Share Card Architecture

| | iOS | Android |
|--|-----|---------|
| **Technology** | SwiftUI `ImageRenderer` | Android `Canvas` + `Paint` |
| **Input** | `CompletedRun` model | `CompletedRun` model |
| **Output** | `UIImage?` (optional) | `Bitmap` |
| **Layout** | Declarative SwiftUI view (`ShareCardView`) | Imperative canvas drawing with calculated Y positions |
| **Dimensions** | 400pt wide, intrinsic height | 1080px wide, dynamically calculated height |
| **Text truncation** | SwiftUI handles with `.lineLimit` | Manual `Paint.measureText()` + character trimming |
| **Share mechanism** | `UIActivityViewController` via `UIViewControllerRepresentable` | `Intent.ACTION_SEND` + `FileProvider` URI |

The **iOS approach** is more maintainable (the share card is a regular SwiftUI view, easy to iterate on), while the **Android approach** gives pixel-precise control (important for consistent rendering across device configurations and densities).

---

## Cross-Platform Comparison Matrix

| Aspect | iOS | Android |
|--------|-----|---------|
| **Language** | Swift 5.9+ | Kotlin 2.0 |
| **UI Framework** | SwiftUI | Jetpack Compose |
| **State Observation** | `@Observable` macro | `StateFlow` + `collectAsState()` |
| **ViewModel base** | Plain `@Observable` class | `AndroidViewModel` (lifecycle-aware) |
| **Async model** | Swift `async/await` + `Task` | Kotlin `suspend` + `viewModelScope.launch` |
| **Task cancellation** | `Task.cancel()` + `Task.isCancelled` | `viewModelScope` auto-cancel on ViewModel clear |
| **Thread safety** | `NSLock` | Kotlin `Mutex` |
| **HTTP client** | `URLSession` (built-in) | Retrofit + OkHttp |
| **JSON parsing** | `Codable` + `JSONSerialization` | Retrofit GSON converter + manual `JSONObject` |
| **Image loading** | `AsyncImage` (built-in SwiftUI) | Coil (`AsyncImage` composable) |
| **Location** | `CLLocationManager` + continuation | `FusedLocationProviderClient` |
| **Maps** | Google Maps iOS SDK (`GMSMapView`) | Maps Compose (`GoogleMap`) |
| **Navigation** | `NavigationStack` + `NavigationLink` | Navigation Compose + sealed `Screen` class |
| **Auth (Google)** | GoogleSignIn-iOS (pending) | Credential Manager API |
| **Share** | `ImageRenderer` → `UIActivityViewController` | `Canvas` → `Bitmap` → `FileProvider` → `Intent` |
| **Secrets** | `.xcconfig` → Build Settings | `.properties` → Gradle `buildConfigField` |
| **Build system** | Xcode + SPM | Gradle Kotlin DSL + version catalogs |
| **Min version** | iOS 17 | SDK 24 (Android 7.0) |

---

## Concurrency Model

### iOS: Structured Concurrency

Swift's structured concurrency is used throughout:

- **`Task { }` in ViewModel init** — launches async work tied to the ViewModel's lifetime
- **`Task.sleep(for:)`** — non-blocking sleep for debouncing (doesn't hold a thread)
- **`Task.cancel()` + `Task.isCancelled`** — cooperative cancellation for search/save tasks
- **`async throws`** — all service and repository methods are async, errors propagate naturally
- **`[weak self]` in closures** — prevents retain cycles in `getDriveTime` callback passed to the optimizer

The Kroger service uses `NSLock` for token synchronization because token refresh involves an `await` call — true actor isolation would require the entire service to be an actor, which complicates usage from non-isolated contexts. The lock scope is minimal (read check + write after refresh).

### Android: Coroutine Scoping

Kotlin coroutines with `viewModelScope`:

- **`viewModelScope.launch { }`** — all ViewModel work runs in this scope, auto-cancelled on ViewModel clear
- **`Dispatchers.IO`** — OkHttp synchronous calls (`execute()`) are wrapped in `withContext(Dispatchers.IO)` to avoid blocking the main thread
- **`Mutex.withLock { }`** — token refresh in `KrogerAuthManager` is guarded by a coroutine-aware mutex (suspending, not blocking)
- **`Flow.debounce()`** — built-in operator for search query debouncing in the feed ViewModel
- **`combine()`** — merges search query and runs list flows for reactive filtering

---

## Error Handling Taxonomy

### Route Optimization Errors

| Error | Cause | User-Facing Message | Recovery |
|-------|-------|---------------------|----------|
| `emptyCart` / `IllegalArgumentException("Cart is empty")` | User navigated to route with no items | "Cart is empty or not found." | Navigate back, add items |
| `noStoresAvailable` / `IllegalStateException("No stores available")` | No Kroger stores within 10-mile radius | "No stores found nearby." | Change location |
| `uncoveredItems(indices)` | Some items not available at any nearby store | "Items at indices [X] cannot be found at any store" | Remove items or add substitutes |
| `cannotCoverAll` | Coverage check passed but no subset can cover all (shouldn't happen if coverage check is correct) | "Cannot cover all items with available stores" | Bug — coverage matrix inconsistency |
| `noRouteFound` | All Directions API calls failed for every feasible subset | "Could not compute route for any store combination" | Retry (transient network issue) |

### Network Errors

| Layer | Error Type | Handling |
|-------|-----------|----------|
| Kroger product search | `URLError` / OkHttp exception | Per-product `try/catch` — skip product, continue to next |
| Kroger store query | `URLError` / OkHttp exception | Propagates to ViewModel → error state |
| Directions API | HTTP error / JSON parse failure | Per-subset `try/catch` → skip subset, try next |
| Firestore | Generic `Error` / `Exception` | ViewModel catches, displays localized message |

The per-product and per-subset error handling is intentionally lenient — a single failed API call shouldn't prevent route computation if other stores/subsets still produce valid routes.

### Auth Errors

Both platforms display auth errors to the user via alerts (iOS) or snackbars (Android). Firebase Auth provides localized error messages for common cases (invalid email, weak password, user not found, wrong password).

---

## Networking Layer Details

### iOS: URLSession (No Third-Party HTTP Library)

The iOS app uses `URLSession.shared` directly for all HTTP requests. This is a deliberate choice:
- Kroger API and Directions API are simple REST endpoints — no need for Retrofit-style interface abstraction
- `URLSession`'s `async data(for:)` integrates cleanly with Swift concurrency
- `Codable` handles JSON decoding without additional dependencies
- One less dependency to manage and keep updated

The token refresh flow in `KrogerService` manually constructs a `URLRequest` with Basic auth and form-encoded body, using `JSONSerialization` for the token response (which has a simple structure not worth defining a `Codable` model for).

### Android: Retrofit + OkHttp

The Android app uses Retrofit for the Kroger API (declarative interface → implementation) and raw OkHttp for the Directions API and OAuth token refresh:

```kotlin
// Retrofit interface — clean declarative API
interface KrogerApiService {
    @GET("v1/products")
    suspend fun searchProducts(
        @Header("Authorization") auth: String,
        @Query("filter.term") term: String,
        @Query("filter.locationId") locationId: String,
        @Query("filter.limit") limit: Int = 50
    ): KrogerProductResponse

    companion object {
        fun create(): KrogerApiService = Retrofit.Builder()
            .baseUrl("https://api.kroger.com/")
            .addConverterFactory(GsonConverterFactory.create())
            .client(OkHttpClient.Builder().addInterceptor(logging).build())
            .build()
            .create(KrogerApiService::class.java)
    }
}
```

**Why Retrofit for Kroger but OkHttp for Directions?** Retrofit excels when you have multiple endpoints with shared base URL, authentication, and serialization — exactly the Kroger API case. The Directions API is a single endpoint with simpler JSON parsing needs, where raw OkHttp avoids defining a Retrofit interface for a single method. The `KrogerAuthManager` also uses raw OkHttp because the OAuth token endpoint has different content types and serialization from the main API.
