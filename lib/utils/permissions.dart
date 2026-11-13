/// نظام الصلاحيات والأدوار المحدث في تطبيق أوركا
enum AppRole {
  admin, // مدير النظام - صلاحيات كاملة
  manager, // مدير - صلاحيات تشغيلية وإدارية محددة
  accountant, // محاسب - مالي وكشوفات وتقارير
  warehouse, // موظف مستودع - مخزون وتحضير وشحن
  salesperson, // مندوب مبيعات - بيع نقدي ومتابعة فواتيره
  customer, // عميل - طلباته وكشف حسابه
  user, // موظف مبيعات/مستخدم عادي
}

/// مجموعة الصلاحيات المتاحة في التطبيق
enum AppPermission {
  // الطلبات
  viewOrders,
  createOrder,
  createCashSale,
  viewOwnSales,
  editOrder,
  deleteOrder,
  approveOrder,
  priceOrder,
  cancelOrder,
  prepareOrder,
  shipOrder,
  viewAllOrders,
  viewPreparationOrdersOnly,
  editInvoiceItems,
  markUnavailable,

  // المنتجات
  viewProducts,
  viewProductPrices,
  viewProductQuantities,
  manageProducts, // إضافة/تعديل/استيراد
  viewSellingPriceOnly,

  // كشف الحساب
  viewAllStatements,
  viewOwnStatement,
  manageFinancialData,

  // الإدارة والإعدادات
  viewReports,
  viewFinancials,
  managePayments,
  viewInventory,
  manageInventory,
  manageUsers,
  viewSettings,
  viewAuditLog,
  manageBackup,
  manageSystemSettings,

  // الزبون
  viewAddresses,
  viewSupport,
}

class PermissionHelper {
  static final Map<AppRole, Set<AppPermission>> _rolePermissions = {
    AppRole.admin: Set.from(AppPermission.values),
    AppRole.manager: {
      AppPermission.viewOrders,
      AppPermission.createOrder,
      AppPermission.editOrder,
      AppPermission.deleteOrder,
      AppPermission.approveOrder,
      AppPermission.priceOrder,
      AppPermission.cancelOrder,
      AppPermission.prepareOrder,
      AppPermission.shipOrder,
      AppPermission.viewAllOrders,
      AppPermission.editInvoiceItems,
      AppPermission.markUnavailable,
      AppPermission.viewProducts,
      AppPermission.viewProductPrices,
      AppPermission.viewProductQuantities,
      AppPermission.viewAllStatements,
      AppPermission.manageFinancialData,
      AppPermission.viewReports,
      AppPermission.viewFinancials,
      AppPermission.managePayments,
      AppPermission.viewInventory,
      AppPermission.viewSettings,
    },
    AppRole.accountant: {
      AppPermission.viewOrders,
      AppPermission.createOrder,
      AppPermission.editOrder,
      AppPermission.approveOrder,
      AppPermission.priceOrder,
      AppPermission.viewAllOrders,
      AppPermission.editInvoiceItems,
      AppPermission.markUnavailable,
      AppPermission.viewProducts,
      AppPermission.viewProductPrices,
      AppPermission.viewProductQuantities,
      AppPermission.viewAllStatements,
      AppPermission.manageFinancialData,
      AppPermission.viewReports,
      AppPermission.viewFinancials,
      AppPermission.managePayments,
      AppPermission.viewInventory,
      AppPermission.viewSettings,
      AppPermission.manageUsers,
    },
    AppRole.warehouse: {
      AppPermission.viewOrders,
      AppPermission.viewPreparationOrdersOnly,
      AppPermission.prepareOrder,
      AppPermission.shipOrder,
      AppPermission.viewProducts,
      AppPermission.viewInventory,
      AppPermission.manageInventory,
      AppPermission.viewAuditLog,
    },
    AppRole.salesperson: {
      AppPermission.viewProducts,
      AppPermission.viewProductPrices,
      AppPermission.viewProductQuantities,
      AppPermission.viewSellingPriceOnly,
      AppPermission.createCashSale,
      AppPermission.viewOwnSales,
    },
    AppRole.customer: {
      AppPermission.viewOrders,
      AppPermission.createOrder,
      AppPermission.editOrder,
      AppPermission.viewOwnStatement,
      AppPermission.viewProducts,
      AppPermission.viewSellingPriceOnly,
      AppPermission.viewAddresses,
      AppPermission.viewSupport,
    },
    AppRole.user: {},
  };

  static bool hasPermission(AppRole role, AppPermission permission) =>
      _rolePermissions[role]?.contains(permission) ?? false;

  static bool hasAnyPermission(AppRole role, Set<AppPermission> permissions) =>
      permissions.any((p) => _rolePermissions[role]?.contains(p) ?? false);

  static bool hasAllPermissions(AppRole role, Set<AppPermission> permissions) =>
      permissions.every((p) => _rolePermissions[role]?.contains(p) ?? false);

  static AppRole fromString(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
      case 'مدير':
      case 'المدير العام':
        return AppRole.admin;
      case 'manager':
      case 'مدير فرع':
        return AppRole.manager;
      case 'accountant':
      case 'محاسب':
      case 'المحاسب':
        return AppRole.accountant;
      case 'warehouse':
      case 'مستودع':
      case 'أمين المستودع':
        return AppRole.warehouse;
      case 'salesperson':
      case 'sales':
      case 'مندوب مبيعات':
      case 'مندوب':
      case 'موظف مبيعات':
      case 'user':
        return AppRole.salesperson;
      case 'customer':
      case 'عميل':
      case 'زبون':
        return AppRole.customer;
      default:
        return AppRole.user;
    }
  }

  static String getRoleNameAr(AppRole role) {
    switch (role) {
      case AppRole.admin:
        return 'المدير العام';
      case AppRole.manager:
        return 'مدير';
      case AppRole.accountant:
        return 'المحاسب';
      case AppRole.warehouse:
        return 'أمين المستودع';
      case AppRole.salesperson:
        return 'مندوب مبيعات';
      case AppRole.customer:
        return 'عميل';
      case AppRole.user:
        return 'موظف مبيعات';
    }
  }

  static String getRoleDescriptionAr(AppRole role) {
    switch (role) {
      case AppRole.admin:
        return 'صلاحيات كاملة على جميع أقسام النظام';
      case AppRole.manager:
        return 'إدارة تشغيلية وفق الصلاحيات المخصصة';
      case AppRole.accountant:
        return 'إدارة العمليات المالية والتقارير والمخزون';
      case AppRole.warehouse:
        return 'إدارة المنتجات والمخزون وتحضير الطلبات';
      case AppRole.salesperson:
        return 'بيع نقدي من المخزون المخصص ومتابعة فواتيرك';
      case AppRole.customer:
        return 'تصفح المنتجات وطلبها ومتابعة الحساب الشخصي';
      case AppRole.user:
        return 'صلاحيات البيع الأساسية ومتابعة الطلبات';
    }
  }
}
