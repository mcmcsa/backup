# PSU Maintenance System - Project Structure

## 📁 Project Organization

This project is organized to separate platform-specific screens (mobile and web) while keeping shared functionalities in a common location.

## 🗂️ Directory Structure

```
lib/
├── main.dart                          # Application entry point with platform detection
├── screens/                           # Screen files organized by platform and feature
│   ├── mobile/                        # Mobile-specific screens
│   │   ├── auth/                      # Authentication screens
│   │   │   ├── splash_screen_mobile.dart
│   │   │   └── login_screen_mobile.dart
│   │   └── dashboard/                 # Dashboard screens
│   │       └── dashboard_page_mobile.dart
│   ├── web/                          # Web-specific screens
│   │   ├── auth/                      # Authentication screens
│   │   │   ├── splash_screen_web.dart
│   │   │   └── login_screen_web.dart
│   │   └── dashboard/                 # Dashboard screens
│   │       └── dashboard_page_web.dart
│   ├── splash_screen.dart            # [LEGACY - Can be removed]
│   ├── loading_screen.dart           # [LEGACY - Moved to shared]
│   └── dashboard_page.dart           # [LEGACY - Split into mobile/web]
├── shared/                           # Shared code across platforms
│   ├── widgets/                      # Reusable widgets
│   │   └── loading_screen.dart
│   ├── models/                       # Data models
│   ├── services/                     # Business logic and services
│   │   └── supabase_service.dart
│   └── utils/                        # Utility functions and helpers
├── authorization/                     # [LEGACY - Can be removed]
│   ├── loginForm_mobile.dart
│   └── loginForm_web.dart
└── config/                           # [LEGACY - Moved to shared/services]
    ├── supabase_config.dart
    └── supabase_service.dart
```

## 🎯 Organization Principles

### 1. **Platform-Specific Screens** (`screens/mobile/` and `screens/web/`)
- Contains UI implementations optimized for each platform
- Mobile: Bottom navigation, mobile-optimized layouts
- Web: Side navigation rail, desktop-optimized layouts
- Each platform has its own splash, login, and dashboard screens

### 2. **Shared Folder** (`shared/`)
Centralized location for code used across platforms:

#### `shared/widgets/`
- Reusable UI components
- Example: `LoadingScreen` widget used by both mobile and web

#### `shared/services/`
- Business logic and API integrations
- Example: `SupabaseService` for authentication and database operations

#### `shared/models/`
- Data models and entities
- DTOs (Data Transfer Objects)

#### `shared/utils/`
- Helper functions
- Constants
- Extension methods

## 🚀 Usage

### Platform Detection
The app automatically detects the platform in `main.dart`:

```dart
home: kIsWeb ? const SplashScreenWeb() : const SplashScreenMobile(),
```

### Import Paths
When importing shared code, use relative paths:

```dart
// From mobile/web screens
import '../../shared/services/supabase_service.dart';
import '../../shared/widgets/loading_screen.dart';
import '../../shared/models/user_model.dart';
```

### Adding New Features
1. **Platform-specific UI**: Add to `screens/mobile/` or `screens/web/`
2. **Shared functionality**: Add to appropriate `shared/` subfolder
3. **Both platforms need it**: Create in `shared/` and import in both

## 📝 Migration Notes

### Legacy Files (Can be Safely Removed)
The following files have been reorganized and can be removed after verification:
- `screens/splash_screen.dart` → Split into mobile/web versions
- `screens/loading_screen.dart` → Moved to `shared/widgets/`
- `screens/dashboard_page.dart` → Split into mobile/web versions
- `authorization/loginForm_mobile.dart` → Moved to `screens/mobile/`
- `authorization/loginForm_web.dart` → Moved to `screens/web/`
- `config/supabase_service.dart` → Moved to `shared/services/`

## 🎨 Design Patterns

### Separation of Concerns
- **UI Layer**: Platform-specific screens handle presentation
- **Business Logic**: Shared services handle data and operations
- **Data Layer**: Shared models define structure

### Code Reusability
- Write business logic once in `shared/`
- Use across all platforms
- Customize UI per platform as needed

## 🛠️ Development Tips

1. **Keep UI separate**: Mobile and web UIs should be fully independent
2. **Share logic**: Authentication, API calls, data processing go in `shared/`
3. **Models in shared**: All data models should be in `shared/models/`
4. **Utilities in shared**: Helper functions, constants, extensions in `shared/utils/`

## 📦 Benefits of This Structure

✅ **Clear separation** between mobile and web implementations  
✅ **Easy maintenance** - find files quickly by platform  
✅ **Code reusability** - shared logic in one place  
✅ **Scalability** - easy to add new features or platforms  
✅ **Team collaboration** - developers can work on specific platforms without conflicts  

## 🔄 Future Enhancements

Consider adding:
- `shared/constants/` - App-wide constants
- `shared/theme/` - Theme configurations
- `shared/providers/` - State management providers
- `shared/repositories/` - Data repositories pattern
