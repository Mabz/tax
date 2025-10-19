import 'package:flutter/material.dart';
import '../services/border_forecast_service.dart';

/// Test utility to demonstrate forecast functionality with sample data
class TestForecastData extends StatefulWidget {
  final String borderId;

  const TestForecastData({
    super.key,
    required this.borderId,
  });

  @override
  State<TestForecastData> createState() => _TestForecastDataState();
}

class _TestForecastDataState extends State<TestForecastData> {
  ForecastData? _forecastData;
  bool _isLoading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Forecast Data'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Forecast Data Test',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Border ID: ${widget.borderId}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      children: [
                        ElevatedButton(
                          onPressed:
                              _isLoading ? null : () => _testForecast('today'),
                          child: const Text('Test Today'),
                        ),
                        ElevatedButton(
                          onPressed: _isLoading
                              ? null
                              : () => _testForecast('tomorrow'),
                          child: const Text('Test Tomorrow'),
                        ),
                        ElevatedButton(
                          onPressed: _isLoading
                              ? null
                              : () => _testForecast('next_week'),
                          child: const Text('Test Next Week'),
                        ),
                        ElevatedButton(
                          onPressed: _isLoading
                              ? null
                              : () => _testForecast('next_month'),
                          child: const Text('Test Next Month'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_error != null)
              Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.error, color: Colors.red.shade700),
                          const SizedBox(width: 8),
                          Text(
                            'Error',
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(_error!),
                    ],
                  ),
                ),
              )
            else if (_forecastData != null)
              Expanded(child: _buildForecastResults())
            else
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                      'Click a button above to test forecast data retrieval'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _testForecast(String dateFilter) async {
    setState(() {
      _isLoading = true;
      _error = null;
      _forecastData = null;
    });

    try {
      final forecastData = await BorderForecastService.getForecastData(
        widget.borderId,
        dateFilter,
      );

      setState(() {
        _forecastData = forecastData;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Widget _buildForecastResults() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Forecast Results',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  _buildResultRow('Expected Check-ins',
                      _forecastData!.expectedCheckIns.toString()),
                  _buildResultRow('Expected Check-outs',
                      _forecastData!.expectedCheckOuts.toString()),
                  _buildResultRow('Expected Revenue',
                      '\$${_forecastData!.expectedRevenue.toStringAsFixed(2)}'),
                  _buildResultRow('Total Upcoming Passes',
                      _forecastData!.totalUpcomingPasses.toString()),
                  _buildResultRow(
                      'Top Vehicle Type', _forecastData!.topVehicleType),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_forecastData!.vehicleTypeBreakdown.isNotEmpty) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vehicle Type Breakdown',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 12),
                    ..._forecastData!.vehicleTypeBreakdown.entries.map((entry) {
                      final forecast = entry.value;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                forecast.vehicleType,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                            Expanded(
                              child: Text('In: ${forecast.expectedCheckIns}'),
                            ),
                            Expanded(
                              child: Text('Out: ${forecast.expectedCheckOuts}'),
                            ),
                            Expanded(
                              child: Text(
                                  '\$${forecast.expectedRevenue.toStringAsFixed(0)}'),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (_forecastData!.upcomingPasses.isNotEmpty) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Upcoming Passes (First 5)',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 12),
                    ..._forecastData!.upcomingPasses.take(5).map((pass) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(
                              '${pass.passType} - ${pass.vehicleDescription}'),
                          subtitle: Text(
                            pass.willCheckIn
                                ? 'Check-in: ${_formatDate(pass.activationDate)}'
                                : 'Check-out: ${_formatDate(pass.expirationDate)}',
                          ),
                          trailing: Text(
                            '\$${pass.amount.toStringAsFixed(0)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ),
          ] else ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade600),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                          'No upcoming passes found for the selected period'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResultRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
