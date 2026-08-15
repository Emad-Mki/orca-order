import 'package:flutter/material.dart';
import '../utils/permissions.dart';

/// Widget للتحقق من الصلاحيات وعرض المحتوى فقط إذا كان المستخدم يملك الصلاحية
class PermissionGuard extends StatelessWidget {
  final AppPermission permission;
  final AppRole userRole;
  final Widget child;
  final Widget? fallback;
  
  const PermissionGuard({
    super.key,
    required this.permission,
    required this.userRole,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    if (PermissionHelper.hasPermission(userRole, permission)) {
      return child;
    }
    return fallback ?? const SizedBox.shrink();
  }
}

/// Widget للتحقق من مجموعة صلاحيات (أي منها)
class AnyPermissionGuard extends StatelessWidget {
  final Set<AppPermission> permissions;
  final AppRole userRole;
  final Widget child;
  final Widget? fallback;
  
  const AnyPermissionGuard({
    super.key,
    required this.permissions,
    required this.userRole,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    if (PermissionHelper.hasAnyPermission(userRole, permissions)) {
      return child;
    }
    return fallback ?? const SizedBox.shrink();
  }
}

/// Widget للتحقق من جميع الصلاحيات المطلوبة
class AllPermissionsGuard extends StatelessWidget {
  final Set<AppPermission> permissions;
  final AppRole userRole;
  final Widget child;
  final Widget? fallback;
  
  const AllPermissionsGuard({
    super.key,
    required this.permissions,
    required this.userRole,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    if (PermissionHelper.hasAllPermissions(userRole, permissions)) {
      return child;
    }
    return fallback ?? const SizedBox.shrink();
  }
}

/// Extension لتحسين سهولة الاستخدام
extension PermissionGuardExtension on AppRole {
  bool can(AppPermission permission) {
    return PermissionHelper.hasPermission(this, permission);
  }
  
  bool canAny(Set<AppPermission> permissions) {
    return PermissionHelper.hasAnyPermission(this, permissions);
  }
  
  bool canAll(Set<AppPermission> permissions) {
    return PermissionHelper.hasAllPermissions(this, permissions);
  }
}
