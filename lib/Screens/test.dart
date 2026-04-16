// Widget _buildSearchPanel({bool mobile = false}) {
//   final filtered = allProducts
//       .where((p) =>
//           p.itemName.toLowerCase().contains(searchQuery.toLowerCase()))
//       .toList();

//   return Container(
//     decoration: BoxDecoration(
//       color: Colors.white,
//       border: Border.all(color: Colors.grey.shade400),
//       borderRadius: BorderRadius.circular(4),
//     ),
//     child: Column(children: [
//       Container(
//         decoration: const BoxDecoration(
//           color: Color(0xFFD3D3D3),
//           borderRadius: BorderRadius.only(
//             topLeft: Radius.circular(4),
//             topRight: Radius.circular(4),
//           ),
//         ),
//         padding: const EdgeInsets.symmetric(vertical: 10),
//         child: const Center(
//           child: Text(
//             'Search Item (↑↓ Arrow Keys)',
//             style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
//           ),
//         ),
//       ),
//       Expanded(
//         child: Container(
//           color: const Color(0xFFD3D3D3),
//           padding: const EdgeInsets.all(10),
//           child: Column(children: [
//             Focus(
//               onKeyEvent: _handleSearchKey,
//               child: TextField(
//                 controller: searchController,
//                 focusNode: searchFocusNode,
//                 autofocus: !mobile,
//                 onChanged: (value) => setState(() {
//                   searchQuery = value;
//                   selectedSearchIndex = value.isNotEmpty ? 0 : -1;
//                   isNavigatingCart = false;
//                 }),
//                 decoration: InputDecoration(
//                   hintText: 'Type to search…',
//                   prefixIcon: const Icon(Icons.search, size: 18),
//                   filled: true,
//                   fillColor: Colors.white,
//                   isDense: true,
//                   contentPadding:
//                       const EdgeInsets.symmetric(vertical: 7),
//                   border: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(4),
//                     borderSide:
//                         BorderSide(color: Colors.grey.shade400),
//                   ),
//                 ),
//               ),
//             ),
//             const SizedBox(height: 8),
//             Expanded(
//               child: filtered.isEmpty
//                   ? Center(
//                       child: Text(
//                         searchQuery.isEmpty
//                             ? 'Start typing to search…'
//                             : 'No products found',
//                         style: const TextStyle(color: Colors.grey),
//                       ),
//                     )
//                   : ListView.builder(
//                       itemCount: filtered.length,
//                       itemBuilder: (context, index) {
//                         final product = filtered[index];
//                         final isSelected =
//                             index == selectedSearchIndex;

//                         final tierCount =
//                             product.conversionTiers?.length ??
//                                 (product.hasUnitConversion ? 2 : 0);

//                         return MouseRegion(
//                           onEnter: (_) =>
//                               setState(() => _hoveredProduct = product),
//                           onExit: (_) =>
//                               setState(() => _hoveredProduct = null),
//                           child: Card(
//                             margin:
//                                 const EdgeInsets.only(bottom: 6),
//                             color: isSelected
//                                 ? Colors.blue.shade100
//                                 : Colors.white,
//                             elevation: isSelected ? 3 : 1,
//                             child: ListTile(
//                               dense: true,
//                               leading: isSelected
//                                   ? const Icon(
//                                       Icons.arrow_right,
//                                       color: Colors.blue,
//                                     )
//                                   : null,
//                               title: Row(children: [
//                                 Expanded(
//                                   child: Text(
//                                     product.itemName,
//                                     style: TextStyle(
//                                       fontSize: 12,
//                                       fontWeight: isSelected
//                                           ? FontWeight.bold
//                                           : FontWeight.normal,
//                                     ),
//                                   ),
//                                 ),
//                                 if (product.hasUnitConversion)
//                                   Container(
//                                     padding:
//                                         const EdgeInsets.symmetric(
//                                             horizontal: 4,
//                                             vertical: 1),
//                                     decoration: BoxDecoration(
//                                       gradient:
//                                           const LinearGradient(
//                                         colors: [
//                                           Color(0xFF3B82F6),
//                                           Color(0xFF8B5CF6),
//                                         ],
//                                       ),
//                                       borderRadius:
//                                           BorderRadius.circular(4),
//                                     ),
//                                     child: Text(
//                                       '${tierCount + 1}T',
//                                       style: const TextStyle(
//                                         fontSize: 8,
//                                         color: Colors.white,
//                                         fontWeight:
//                                             FontWeight.bold,
//                                       ),
//                                     ),
//                                   ),
//                               ]),
//                               subtitle: Text(
//                                 '${product.issueUnit ?? '-'} • ${currencyFormat.format(product.retailPrice)} • Stk: ${product.stock}',
//                                 style:
//                                     const TextStyle(fontSize: 10),
//                               ),
//                               trailing: isSelected
//                                   ? Container(
//                                       padding:
//                                           const EdgeInsets.symmetric(
//                                               horizontal: 6,
//                                               vertical: 3),
//                                       decoration: BoxDecoration(
//                                         color: Colors.blue,
//                                         borderRadius:
//                                             BorderRadius.circular(4),
//                                       ),
//                                       child: const Text(
//                                         'Enter ⏎',
//                                         style: TextStyle(
//                                           color: Colors.white,
//                                           fontSize: 9,
//                                         ),
//                                       ),
//                                     )
//                                   : null,
//                               onTap: () {
//                                 _addToCartAndFocusQty(product);
//                                 if (mobile) {
//                                   setState(() =>
//                                       _searchPanelExpanded =
//                                           false);
//                                 }
//                               },
//                             ),
//                           ),
//                         );
//                       },
//                     ),
//             ),
//           ]),
//         ),
//       ),
//     ]),
//   );
// }