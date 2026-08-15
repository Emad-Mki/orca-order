import 'package:flutter/material.dart';

/// نظام الصلاحيات والأدوار في التطبيق
enum AppRole {
  admin,      // مدير النظام - صلاحيات كاملة
  manager,    // مدير - صلاحيات واسعة
  supervisor, // مشرف - صلاحيات متوسطة
  user,       // مستخدم عادي - صلاحيات محدودة
  customer,   // عميل - صلاحيات أساسية
}

/// مجموعة الصلاحيات المتاحة في التطبيق
enum AppPermission {
  // الطلبات
  viewOrders,
  createOrder,
  editOrder,
  deleteOrder,
  approveOrder,
  
  // العملاء
  viewCustomers,
  manageCustomers,
  viewCustomerStatements,
  
  // المنتجات والمخزون
  viewProducts,
  manageProducts,
  viewInventory,
  manageInventory,
  
  // التقارير
  viewReports,
  exportData,
  
  // الإعدادات والنظام
  viewSettings,
  manageUsers,
  manageSystemSettings,
  viewAuditLog,
  manageBackup,
  
  // أخرى
  viewNotifications,
  viewProfile,
  managePricing,
  viewShipping,
}

/// فئة مساعدة للتعامل مع الصلاحيات
class PermissionHelper {
  /// الصلاحيات لكل دور
  static const Map<AppRole, Set<AppPermission>> _rolePermissions = {
    AppRole.admin: {
      // جميع الصلاحيات
      ...AppPermission.values,
    },
    AppRole.manager: {
      AppPermission.viewOrders,
      AppPermission.createOrder,
      AppPermission.editOrder,
      AppPermission.approveOrder,
      AppPermission.viewCustomers,
      AppPermission.manageCustomers,
      AppPermission.viewCustomerStatements,
      AppPermission.viewProducts,
      AppPermission.manageProducts,
      AppPermission.viewInventory,
      AppPermission.manageInventory,
      AppPermission.viewReports,
      AppPermission.exportData,
      AppPermission.viewSettings,
      AppPermission.viewNotifications,
      AppPermission.viewProfile,
      AppPermission.managePricing,
      AppPermission.viewShipping,
    },
    AppRole.supervisor: {
      AppPermission.viewOrders,
      AppPermission.createOrder,
      AppPermission.editOrder,
      AppPermission.viewCustomers,
      AppPermission.viewCustomerStatements,
      AppPermission.viewProducts,
      AppPermission.viewInventory,
      AppPermission.viewReports,
      AppPermission.viewSettings,
      AppPermission.viewNotifications,
      AppPermission.viewProfile,
    },
    AppRole.user: {
      AppPermission.viewOrders,
      AppPermission.createOrder,
      AppPermission.viewCustomers,
      AppPermission.viewProducts,
      AppPermission.viewInventory,
      AppPermission.viewNotifications,
      AppPermission.viewProfile,
    },
    AppRole.customer: {
      AppPermission.viewOrders,
      AppPermission.createOrder,
      AppPermission.viewProfile,
      AppPermission.viewNotifications,
    },
  };

  /// التحقق مما إذا كان الدور يملك صلاحية معينة
  static bool hasPermission(AppRole role, AppPermission permission) {
    return _rolePermissions[role]?.contains(permission) ?? false;
  }

  /// التحقق مما إذا كان الدور يملك مجموعة من الصلاحيات
  static bool hasAnyPermission(AppRole role, Set<AppPermission> permissions) {
    final rolePerms = _rolePermissions[role] ?? {};
    return permissions.any((p) => rolePerms.contains(p));
  }

  /// التحقق مما إذا كان الدور يملك جميع الصلاحيات المطلوبة
  static bool hasAllPermissions(AppRole role, Set<AppPermission> permissions) {
    final rolePerms = _rolePermissions[role] ?? {};
    return permissions.every((p) => rolePerms.contains(p));
  }

  /// تحويل نص الدور إلى enum
  static AppRole fromString(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
      case 'مدير_النظام':
      case 'مدير النظام':
        return AppRole.admin;
      case 'manager':
      case 'مدير':
        return AppRole.manager;
      case 'supervisor':
      case 'مشرف':
        return AppRole.supervisor;
      case 'user':
      case 'مستخدم':
        return AppRole.user;
      case 'customer':
      case 'عميل':
        return AppRole.customer;
      default:
        return AppRole.user;
    }
  }

  /// الحصول على اسم الدور بالعربية
  static String getRoleNameAr(AppRole role) {
    switch (role) {
      case AppRole.admin:
        return 'مدير النظام';
      case AppRole.manager:
        return 'مدير';
      case AppRole.supervisor:
        return 'مشرف';
      case AppRole.user:
        return 'مستخدم';
      case AppRole.customer:
        return 'عميل';
    }
  }

  /// الحصول على وصف مختصر للدور
  static String getRoleDescriptionAr(AppRole role) {
    switch (role) {
      case AppRole.admin:
        return 'صلاحيات كاملة على جميع أقسام النظام';
      case AppRole.manager:
        return 'إدارة الطلبات والعملاء والمخزون';
      case AppRole.supervisor:
        return 'متابعة ومراقبة العمليات';
      case AppRole.user:
        return 'إنشاء ومتابعة الطلبات';
      case AppRole.customer:
        return 'تصفح وإنشاء الطلبات الشخصية';
    }
  }
}
