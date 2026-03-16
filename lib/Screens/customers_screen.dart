// // lib/screens/customers_screen.dart

// import 'package:flutter/material.dart';
// import 'package:medical_app/models/customer.dart';
// import 'package:medical_app/screens/add_customer_screen.dart';
// import 'package:medical_app/services/database_helper.dart';

// class CustomersScreen extends StatefulWidget {
//   const CustomersScreen({super.key});

//   @override
//   State<CustomersScreen> createState() => _CustomersScreenState();
// }

// class _CustomersScreenState extends State<CustomersScreen> {
//   List<Customer> customers = [];
//   bool isLoading = true;

//   @override
//   void initState() {
//     super.initState();
//     _loadCustomers();
//   }

//   Future<void> _loadCustomers() async {
//     final data = await DatabaseHelper.instance.getAllCustomers();
//     setState(() {
//       customers = data;
//       isLoading = false;
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFFF5F7FA),
//       appBar: AppBar(
//         title: const Text('Customers'),
//         backgroundColor: const Color(0xFF0D47A1),
//         foregroundColor: Colors.white,
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.add),
//             onPressed: () async {
//               final result = await Navigator.push(
//                 context,
//                 MaterialPageRoute(builder: (context) => const AddCustomerScreen()),
//               );
//               if (result == true) _loadCustomers();
//             },
//           ),
//         ],
//       ),
//       body: isLoading
//           ? const Center(child: CircularProgressIndicator())
//           : customers.isEmpty
//               ? const Center(child: Text('No customers yet. Add one!'))
//               : ListView.builder(
//                   itemCount: customers.length,
//                   itemBuilder: (context, index) {
//                     final customer = customers[index];
//                     return Card(
//                       margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//                       child: ListTile(
//                         title: Text(customer.name, style: const TextStyle(fontWeight: FontWeight.bold)),
//                         subtitle: Text('${customer.phone}\nBalance: ₹${customer.openingBalance}'),
//                         isThreeLine: true,
//                         trailing: Row(
//                           mainAxisSize: MainAxisSize.min,
//                           children: [
//                             IconButton(
//                               icon: const Icon(Icons.edit, color: Colors.blue),
//                               onPressed: () async {
//                                 final result = await Navigator.push(
//                                   context,
//                                   MaterialPageRoute(
//                                     builder: (context) => AddCustomerScreen(customer: customer),
//                                   ),
//                                 );
//                                 if (result == true) _loadCustomers();
//                               },
//                             ),
//                             IconButton(
//                               icon: const Icon(Icons.delete, color: Colors.red),
//                               onPressed: () async {
//                                 final confirm = await showDialog(
//                                   context: context,
//                                   builder: (context) => AlertDialog(
//                                     title: const Text('Delete Customer?'),
//                                     content: Text('Delete ${customer.name}?'),
//                                     actions: [
//                                       TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
//                                       TextButton(
//                                         onPressed: () => Navigator.pop(context, true),
//                                         child: const Text('Delete'),
//                                       ),
//                                     ],
//                                   ),
//                                 );
//                                 if (confirm == true) {
//                                   await DatabaseHelper.instance.deleteCustomer(customer.id!);
//                                   _loadCustomers();
//                                 }
//                               },
//                             ),
//                           ],
//                         ),
//                       ),
//                     );
//                   },
//                 ),
//     );
//   }
// }