import 'package:medical_app/services/customerDatabase.dart';
import 'package:medical_app/services/expenseDatbase.dart';
import 'package:medical_app/services/productDatabase.dart';
import 'package:medical_app/services/purchase_database.dart';
import 'package:medical_app/services/saleDatabase.dart';
import 'database_helper.dart';


/// Repository for dashboard statistics and summary data
class DashboardRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final ProductRepository _productRepo = ProductRepository();
  final CustomerRepository _customerRepo = CustomerRepository();
  final SalesRepository _salesRepo = SalesRepository();
  final PurchaseRepository _purchaseRepo = PurchaseRepository();
  final ExpenseRepository _expenseRepo = ExpenseRepository();

  /// Get comprehensive dashboard summary with all key metrics
  Future<Map<String, dynamic>> getDashboardSummary() async {
    return {
      'todaySales': await _salesRepo.getTodaySalesTotal(),
      'todayOrders': await _salesRepo.getTodayOrdersCount(),
      'totalCustomers': await _customerRepo.getTotalCustomers(),
      'lowStockCount': await _productRepo.getLowStockCount(),
      'todayPurchases': await _purchaseRepo.getTodayPurchasesTotal(),
      'todayExpenses': await _expenseRepo.getTodayExpensesTotal(),
    };
  }
}