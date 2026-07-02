import 'package:flutter_test/flutter_test.dart';
import 'package:psu_maintsystem/authentication/models/user_model.dart';
import 'package:psu_maintsystem/router/app_router.dart';

AppUser _testUser(UserRole role) {
  return AppUser(
    id: 'test-${role.name}',
    email: '${role.name}@test.psu.edu.ph',
    name: 'Test ${role.name}',
    role: role,
    isActive: true,
  );
}

String? _redirectFor(AppUser user, String location) {
  return resolveAuthRedirect(
    location: location,
    isSessionInitialized: true,
    isPostLoginSplashActive: false,
    user: user,
    consumeLoginRedirectPause: () => false,
  );
}

void main() {
  test('system admin dashboard route is /system-admin/dashboard', () {
    expect(_testUser(UserRole.admin).dashboardRoute, '/system-admin/dashboard');
  });

  test('campus admin dashboard route is /admin/dashboard', () {
    expect(_testUser(UserRole.campadmin).dashboardRoute, '/admin/dashboard');
  });

  test('system admin is redirected away from campus admin routes', () {
    expect(
      _redirectFor(_testUser(UserRole.admin), '/admin/dashboard'),
      '/system-admin/dashboard',
    );
  });

  test('campus admin is redirected away from system admin routes', () {
    expect(
      _redirectFor(_testUser(UserRole.campadmin), '/system-admin/dashboard'),
      '/admin/dashboard',
    );
  });

  test('campus admin can stay on campus admin routes', () {
    expect(_redirectFor(_testUser(UserRole.campadmin), '/admin/dashboard'), isNull);
  });

  test('system admin can stay on system admin routes', () {
    expect(
      _redirectFor(_testUser(UserRole.admin), '/system-admin/dashboard'),
      isNull,
    );
  });

  test('teacher cannot access either admin route', () {
    final teacher = _testUser(UserRole.teacher);

    expect(_redirectFor(teacher, '/admin/dashboard'), '/teacher/dashboard');
    expect(
      _redirectFor(teacher, '/system-admin/dashboard'),
      '/teacher/dashboard',
    );
  });

  test('startup sends each role to its own dashboard', () {
    expect(
      resolveAuthRedirect(
        location: appStartupRoute,
        isSessionInitialized: true,
        isPostLoginSplashActive: false,
        user: _testUser(UserRole.admin),
        consumeLoginRedirectPause: () => false,
      ),
      '/system-admin/dashboard',
    );

    expect(
      resolveAuthRedirect(
        location: appStartupRoute,
        isSessionInitialized: true,
        isPostLoginSplashActive: false,
        user: _testUser(UserRole.campadmin),
        consumeLoginRedirectPause: () => false,
      ),
      '/admin/dashboard',
    );
  });
}
