import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/purchased_pass.dart';
import '../services/vehicle_search_service.dart';

class ImprovedVehicleSearchWidget extends StatefulWidget {
  final Function(PurchasedPass) onPassSelected;
  final String? initialSearchTerm;

  const ImprovedVehicleSearchWidget({
    super.key,
    required this.onPassSelected,
    this.initialSearchTerm,
  });

  @override
  State<ImprovedVehicleSearchWidget> createState() =>
      _ImprovedVehicleSearchWidgetState();
}

class _ImprovedVehicleSearchWidgetState
    extends State<ImprovedVehicleSearchWidget> {
  final TextEditingController _numberPlateController = TextEditingController();
  final TextEditingController _vinController = TextEditingController();
  final FocusNode _numberPlateFocus = FocusNode();
  final FocusNode _vinFocus = FocusNode();

  List<PurchasedPass> _searchResults = [];
  bool _isSearching = false;
  String? _errorMessage;
  bool _hasSearched = false;
  String _searchType = 'number_plate'; // 'number_plate' or 'vin'

  @override
  void initState() {
    super.initState();
    if (widget.initialSearchTerm != null) {
      // Try to determine if it's a VIN (17 characters) or number plate
      if (widget.initialSearchTerm!.length == 17) {
        _vinController.text = widget.initialSearchTerm!;
        _searchType = 'vin';
      } else {
        _numberPlateController.text = widget.initialSearchTerm!;
        _searchType = 'number_plate';
      }
      _performSearch();
    }
  }

  @override
  void dispose() {
    _numberPlateController.dispose();
    _vinController.dispose();
    _numberPlateFocus.dispose();
    _vinFocus.dispose();
    super.dispose();
  }

  Future<void> _performSearch() async {
    String searchTerm;

    if (_searchType == 'vin') {
      searchTerm = _vinController.text.trim();
      if (searchTerm.isNotEmpty && searchTerm.length != 17) {
        setState(() {
          _errorMessage = 'VIN must be exactly 17 characters';
          _isSearching = false;
          _searchResults = [];
          _hasSearched = true;
        });
        return;
      }
    } else {
      searchTerm = _numberPlateController.text.trim();
    }

    if (searchTerm.isEmpty) {
      setState(() {
        _searchResults = [];
        _hasSearched = false;
        _errorMessage = null;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _errorMessage = null;
      _hasSearched = true;
    });

    try {
      final results =
          await VehicleSearchService.searchPassesByVehicle(searchTerm);

      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isSearching = false;
        _searchResults = [];
      });
    }
  }

  void _clearSearch() {
    _numberPlateController.clear();
    _vinController.clear();
    setState(() {
      _searchResults = [];
      _hasSearched = false;
      _errorMessage = null;
    });
    if (_searchType == 'number_plate') {
      _numberPlateFocus.requestFocus();
    } else {
      _vinFocus.requestFocus();
    }
  }

  void _switchSearchType(String type) {
    setState(() {
      _searchType = type;
      _searchResults = [];
      _hasSearched = false;
      _errorMessage = null;
    });

    // Clear the other field and focus on the selected one
    if (type == 'number_plate') {
      _vinController.clear();
      _numberPlateFocus.requestFocus();
    } else {
      _numberPlateController.clear();
      _vinFocus.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Search Header
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.search,
                      color: Colors.blue.shade600,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Search by Vehicle',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose search method and enter vehicle details',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),

          // Search Type Selector
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _switchSearchType('number_plate'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _searchType == 'number_plate'
                            ? Colors.blue.shade600
                            : Colors.grey.shade200,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          bottomLeft: Radius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.confirmation_num,
                            color: _searchType == 'number_plate'
                                ? Colors.white
                                : Colors.grey.shade600,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Number Plate',
                            style: TextStyle(
                              color: _searchType == 'number_plate'
                                  ? Colors.white
                                  : Colors.grey.shade600,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _switchSearchType('vin'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _searchType == 'vin'
                            ? Colors.blue.shade600
                            : Colors.grey.shade200,
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(12),
                          bottomRight: Radius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.fingerprint,
                            color: _searchType == 'vin'
                                ? Colors.white
                                : Colors.grey.shade600,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'VIN',
                            style: TextStyle(
                              color: _searchType == 'vin'
                                  ? Colors.white
                                  : Colors.grey.shade600,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Search Input Fields
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _searchType == 'number_plate'
                  ? _buildNumberPlateField()
                  : _buildVinField(),
            ),
          ),

          const SizedBox(height: 16),

          // Search Results
          Container(
            height: MediaQuery.of(context).size.height *
                0.5, // Fixed height to prevent overflow
            child: _buildSearchResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildNumberPlateField() {
    return TextField(
      key: const ValueKey('number_plate'),
      controller: _numberPlateController,
      focusNode: _numberPlateFocus,
      decoration: InputDecoration(
        labelText: 'Number Plate',
        hintText: 'e.g., ABC123, LX25TLGT',
        prefixIcon: const Icon(Icons.confirmation_num),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_numberPlateController.text.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.clear),
                onPressed: _clearSearch,
              ),
            IconButton(
              icon: _isSearching
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.search),
              onPressed: _isSearching ? null : _performSearch,
            ),
          ],
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        helperText: 'Enter the vehicle registration number',
        counterText: '',
      ),
      textCapitalization: TextCapitalization.characters,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9\-\s]')),
        LengthLimitingTextInputFormatter(
            15), // Reasonable limit for number plates
      ],
      onChanged: (value) {
        setState(() {}); // Update UI for clear button
      },
      onSubmitted: (_) => _performSearch(),
    );
  }

  Widget _buildVinField() {
    return TextField(
      key: const ValueKey('vin'),
      controller: _vinController,
      focusNode: _vinFocus,
      decoration: InputDecoration(
        labelText: 'VIN (Vehicle Identification Number)',
        hintText: '17-character VIN',
        prefixIcon: const Icon(Icons.fingerprint),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_vinController.text.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.clear),
                onPressed: _clearSearch,
              ),
            IconButton(
              icon: _isSearching
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.search),
              onPressed: _isSearching ? null : _performSearch,
            ),
          ],
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: _vinController.text.isNotEmpty &&
                    _vinController.text.length != 17
                ? Colors.red
                : Colors.grey,
          ),
        ),
        helperText: 'VIN must be exactly 17 characters',
        helperStyle: TextStyle(
          color:
              _vinController.text.isNotEmpty && _vinController.text.length != 17
                  ? Colors.red
                  : Colors.grey.shade600,
        ),
        counterText: '${_vinController.text.length}/17',
        counterStyle: TextStyle(
          color: _vinController.text.length == 17
              ? Colors.green
              : _vinController.text.isNotEmpty
                  ? Colors.red
                  : Colors.grey.shade600,
        ),
      ),
      textCapitalization: TextCapitalization.characters,
      inputFormatters: [
        FilteringTextInputFormatter.allow(
            RegExp(r'[A-Z0-9]')), // VINs don't have spaces or dashes
        LengthLimitingTextInputFormatter(17), // VIN is exactly 17 characters
      ],
      onChanged: (value) {
        setState(() {}); // Update UI for validation and clear button
      },
      onSubmitted: (_) => _performSearch(),
    );
  }

  Widget _buildSearchResults() {
    if (_isSearching) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Searching for passes...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                color: Colors.red.shade600,
                size: 48,
              ),
              const SizedBox(height: 12),
              Text(
                'Search Error',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: TextStyle(
                  color: Colors.red.shade600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _performSearch,
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (!_hasSearched) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _searchType == 'vin' ? Icons.fingerprint : Icons.confirmation_num,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              _searchType == 'vin' ? 'Search by VIN' : 'Search by Number Plate',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchType == 'vin'
                  ? 'Enter a 17-character VIN to find\nassociated passes'
                  : 'Enter a number plate to find\nassociated passes',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      final searchTerm = _searchType == 'vin'
          ? _vinController.text
          : _numberPlateController.text;

      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No Passes Found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No active passes found for\n"$searchTerm"',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _clearSearch,
              icon: const Icon(Icons.refresh),
              label: const Text('Search Again'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final pass = _searchResults[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: Card(
            elevation: 4,
            shadowColor: Colors.black.withOpacity(0.15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => widget.onPassSelected(pass),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white,
                      Colors.grey.shade50,
                    ],
                  ),
                  border: Border.all(
                    color:
                        _getStatusColor(pass.statusColorName).withOpacity(0.2),
                    width: 2,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Pass summary with select button
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  pass.authorityName ?? 'Border Authority',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  pass.displayVehicleDescription,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () => widget.onPassSelected(pass),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade600,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Select'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Color _getStatusColor(String colorName) {
    switch (colorName.toLowerCase()) {
      case 'green':
        return Colors.green;
      case 'red':
        return Colors.red;
      case 'yellow':
        return Colors.orange;
      case 'blue':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}
