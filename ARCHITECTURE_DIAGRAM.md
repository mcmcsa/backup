# Project Architecture Diagram

## 📱 Application Flow

```
main.dart
    ↓
Platform Detection (kIsWeb)
    ↓
    ├─────────────────┬─────────────────┐
    ↓                 ↓                 ↓
  MOBILE             WEB            SHARED
    ↓                 ↓                 ↓
```

## 🏗️ Detailed Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                           main.dart                              │
│                   (Platform Detection)                           │
└────────────────────────────┬────────────────────────────────────┘
                             │
                ┌────────────┴────────────┐
                ↓                         ↓
    ┌───────────────────┐     ┌───────────────────┐
    │   MOBILE ROUTE    │     │    WEB ROUTE      │
    └───────────────────┘     └───────────────────┘
                │                         │
                ↓                         ↓
    ┌───────────────────┐     ┌───────────────────┐
    │  Splash Mobile    │     │   Splash Web      │
    └───────────────────┘     └───────────────────┘
                │                         │
                ↓                         ↓
    ┌───────────────────┐     ┌───────────────────┐
    │  Login Mobile     │     │   Login Web       │
    │  - Mobile UI      │     │   - Desktop UI    │
    │  - Bottom Nav     │     │   - Split Layout  │
    └───────────────────┘     └───────────────────┘
                │                         │
                ↓                         ↓
    ┌───────────────────┐     ┌───────────────────┐
    │ Dashboard Mobile  │     │  Dashboard Web    │
    │  - Mobile Layout  │     │   - Sidebar Nav   │
    │  - Bottom Nav Bar │     │   - Grid Layout   │
    └───────────────────┘     └───────────────────┘
                │                         │
                └────────────┬────────────┘
                             ↓
                ┌────────────────────────┐
                │   SHARED RESOURCES     │
                │                        │
                │  • Services            │
                │    - SupabaseService   │
                │                        │
                │  • Widgets             │
                │    - LoadingScreen     │
                │                        │
                │  • Models              │
                │    - (Future)          │
                │                        │
                │  • Utils               │
                │    - (Future)          │
                └────────────────────────┘
```

## 🗂️ Folder Structure Tree

```
lib/
│
├── 📄 main.dart                           # Entry point + platform detection
│
├── 📁 screens/                            # All screen files
│   │
│   ├── 📁 mobile/                         # Mobile-specific screens
│   │   │
│   │   ├── 📁 auth/                       # Authentication module
│   │   │   ├── 📄 splash_screen_mobile.dart
│   │   │   └── 📄 login_screen_mobile.dart
│   │   │
│   │   └── 📁 dashboard/                  # Dashboard module
│   │       └── 📄 dashboard_page_mobile.dart
│   │
│   ├── 📁 web/                            # Web-specific screens
│   │   │
│   │   ├── 📁 auth/                       # Authentication module
│   │   │   ├── 📄 splash_screen_web.dart
│   │   │   └── 📄 login_screen_web.dart
│   │   │
│   │   └── 📁 dashboard/                  # Dashboard module
│   │       └── 📄 dashboard_page_web.dart
│   │
│   └── 🗑️  [Legacy files - can be removed]
│       ├── splash_screen_mobile.dart
│       ├── login_screen_mobile.dart
│       ├── dashboard_page_mobile.dart
│       ├── splash_screen_web.dart
│       ├── login_screen_web.dart
│       ├── dashboard_page_web.dart
│       ├── splash_screen.dart
│       ├── loading_screen.dart
│       └── dashboard_page.dart
│
├── 📁 shared/                             # Shared code across platforms
│   │
│   ├── 📁 widgets/                        # Reusable widgets
│   │   └── 📄 loading_screen.dart         # Shared loading screen widget
│   │
│   ├── 📁 services/                       # Business logic & services
│   │   └── 📄 supabase_service.dart       # Database & auth service
│   │
│   ├── 📁 models/                         # Data models (ready for use)
│   │   └── (Add your models here)
│   │
│   └── 📁 utils/                          # Utilities & helpers (ready for use)
│       └── (Add your utilities here)
│
├── 🗑️  authorization/                     # [Legacy - can be removed]
│   ├── loginForm_mobile.dart
│   └── loginForm_web.dart
│
└── 🗑️  config/                            # [Legacy - moved to shared/services]
    ├── supabase_config.dart
    └── supabase_service.dart
```

## 🔄 Component Relationships

### Mobile Flow
```
SplashScreenMobile
    ↓
LoginScreenMobile ← SupabaseService (shared)
    ↓
LoadingScreen (shared)
    ↓
DashboardPageMobile
```

### Web Flow
```
SplashScreenWeb
    ↓
LoginScreenWeb ← SupabaseService (shared)
    ↓
DashboardPageWeb
```

## 💡 Import Patterns

### From Mobile Screens
```dart
// Importing shared services (from auth/ or dashboard/)
import '../../../shared/services/supabase_service.dart';

// Importing shared widgets
import '../../../shared/widgets/loading_screen.dart';

// Importing other mobile screens in same feature
import 'login_screen_mobile.dart';

// Importing other mobile screens from different feature
import '../dashboard/dashboard_page_mobile.dart';
```

### From Web Screens
```dart
// Importing shared services (from auth/ or dashboard/)
import '../../../shared/services/supabase_service.dart';

// Importing shared widgets
import '../../../shared/widgets/loading_screen.dart';

// Importing other web screens in same feature
import 'login_screen_web.dart';

// Importing other web screens from different feature
import '../dashboard/dashboard_page_web.dart';
```

### From Shared Components
```dart
// Shared components import from shared/
import '../services/supabase_service.dart';
import '../models/user_model.dart';
import '../utils/validators.dart';
```

## 🎨 Design Philosophy

```
┌─────────────────────────────────────────┐
│           PRESENTATION LAYER            │
│  (Platform-Specific UI & Navigation)    │
│                                         │
│    Mobile               Web             │
│  ┌──────────┐      ┌──────────┐       │
│  │  Mobile  │      │   Web    │       │
│  │ Screens  │      │ Screens  │       │
│  └──────────┘      └──────────┘       │
└─────────────────────────────────────────┘
                 ↓
┌─────────────────────────────────────────┐
│          BUSINESS LOGIC LAYER           │
│       (Shared Services & Logic)         │
│                                         │
│  ┌──────────┐  ┌──────────┐           │
│  │ Services │  │  Models  │           │
│  └──────────┘  └──────────┘           │
└─────────────────────────────────────────┘
                 ↓
┌─────────────────────────────────────────┐
│            DATA LAYER                   │
│     (Supabase, Storage, APIs)           │
└─────────────────────────────────────────┘
```

## ✨ Benefits Summary

| Aspect | Before | After |
|--------|--------|-------|
| Organization | Mixed files | Clear separation |
| Platform Support | Conditional rendering | Independent screens |
| Code Sharing | Duplicated logic | Centralized in shared/ |
| Maintainability | Difficult | Easy to navigate |
| Scalability | Limited | Easy to extend |
| Team Work | Conflicts | Parallel development |

## 🚀 Usage Examples

### Adding a New Mobile Screen
```
1. Determine the feature: auth, dashboard, tickets, etc.
2. Create file: lib/screens/mobile/[feature]/screen_name_mobile.dart
3. Import shared services: import '../../../shared/services/...'
4. Use mobile-specific UI patterns
```

### Adding a New Web Screen
```
1. Determine the feature: auth, dashboard, tickets, etc.
2. Create file: lib/screens/web/[feature]/screen_name_web.dart
3. Import shared services: import '../../../shared/services/...'
4. Use web-specific UI patterns
```

### Adding a New Feature Module
```
1. Create folders: lib/screens/mobile/[feature]/ and lib/screens/web/[feature]/
2. Add platform-specific screens in each folder
3. Share business logic in lib/shared/services/
4. Update navigation as needed
```

---

This architecture ensures:
- ✅ Clean separation of concerns
- ✅ Maximum code reuse
- ✅ Platform-specific optimizations
- ✅ Easy maintenance and scaling
- ✅ Better team collaboration
