import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String unit = 'Feet'; // Default value is Feet
  String? selectedName; // Holds the currently selected product name
  double? selectedPrice; // Holds the price of the selected product
  double? selectedOffcutPrice; // Holds the offcut price of the selected product
  String? selectedRoll; // Holds the currently selected roll
  String? rollCompatibilityError; // Holds error message for roll compatibility

  TextEditingController widthController = TextEditingController();
  TextEditingController heightController = TextEditingController();

  // Firebase Database reference
  final DatabaseReference _databaseRef =
      FirebaseDatabase.instance.ref(); // Reference to the root of the database
  List<Map<String, dynamic>> databaseArray = []; // Array to store full database data
  List<String> productNames = []; // List to hold product names for selection
  List<String> availableRolls = []; // List to hold rolls for the selected product

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  /// Fetch all data from the database and store in databaseArray
  void _fetchData() {
    _databaseRef.onValue.listen((DatabaseEvent event) {
      final dataSnapshot = event.snapshot.value;
      if (dataSnapshot != null) {
        final fetchedData = Map<String, dynamic>.from(dataSnapshot as Map);

        // Convert the fetched data to a list of maps
        List<Map<String, dynamic>> dataList = fetchedData.entries
            .map((entry) => {entry.key: entry.value})
            .toList();

        // Extract product names from the database
        final products = dataList
            .where((map) => map.containsKey('Products'))
            .expand((map) => map['Products'] as List<dynamic>)
            .map((product) => product['name'] as String)
            .toList();

        setState(() {
          databaseArray = dataList;
          productNames = products;
        });
      }
    });
  }

  /// Converts inches to feet
  double convertInchToFeet(double valueInInches) {
    return valueInInches / 12.0; // 12 inches in 1 foot
  }

  /// Converts the input to feet based on the current unit
  double getValueInFeet(String input) {
    if (input.isEmpty) return 0.0;
    double value = double.tryParse(input) ?? 0.0;
    return unit == 'Inch' ? convertInchToFeet(value) : value;
  }

  /// Updates the price, offcut price, and available rolls based on the selected product
  void updateProductDetails(String selectedProductName) {
    for (var map in databaseArray) {
      if (map.containsKey('Products')) {
        final products = map['Products'] as List<dynamic>;
        for (var product in products) {
          if (product['name'] == selectedProductName) {
            setState(() {
              selectedPrice = product['price']?.toDouble();
              selectedOffcutPrice = product['offcutprice']?.toDouble();
              availableRolls = (product['rolls'] as List<dynamic>)
                  .map((roll) => roll.toString())
                  .toList();
              selectedRoll = null; // Reset roll selection
              rollCompatibilityError = null; // Clear any existing error
            });
            return;
          }
        }
      }
    }
    setState(() {
      selectedPrice = null;
      selectedOffcutPrice = null;
      availableRolls = [];
      selectedRoll = null;
      rollCompatibilityError = null;
    });
  }

  /// Validates roll compatibility with user input width
  void validateRollCompatibility() {
    if (selectedRoll == null) return;

    double rollWidth = double.tryParse(selectedRoll!) ?? 0.0; // Parse roll width
    double userWidth = getValueInFeet(widthController.text); // Get user width in feet

    setState(() {
      if (userWidth > rollWidth) {
        rollCompatibilityError =
            "Roll is not compatible for this width"; // Set error message
      } else {
        rollCompatibilityError = null; // Clear error if compatible
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Store the converted values in feet
    double widthInFeet = getValueInFeet(widthController.text);
    double heightInFeet = getValueInFeet(heightController.text);

    return Scaffold(
      appBar: AppBar(
        title: Text('Width, Height & Firebase Data'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Dropdown for selecting between Feet or Inch
              DropdownButton<String>(
                value: unit,
                onChanged: (String? newValue) {
                  setState(() {
                    unit = newValue!;
                  });
                },
                items: <String>['Feet', 'Inch']
                    .map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
              ),

              SizedBox(height: 20),

              // Dropdown for selecting product name
              DropdownButton<String>(
                value: selectedName,
                hint: Text("Select a product"),
                onChanged: (String? newName) {
                  setState(() {
                    selectedName = newName!;
                    updateProductDetails(newName);
                  });
                },
                items: productNames.map<DropdownMenuItem<String>>((String name) {
                  return DropdownMenuItem<String>(
                    value: name,
                    child: Text(name),
                  );
                }).toList(),
              ),

              SizedBox(height: 20),

              // Width input field
              TextField(
                controller: widthController,
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  setState(() {
                    validateRollCompatibility(); // Re-validate on input change
                  });
                },
                decoration: InputDecoration(
                  labelText: 'Width (${unit})',
                  border: OutlineInputBorder(),
                ),
              ),

              SizedBox(height: 20),

              // Height input field
              TextField(
                controller: heightController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Height (${unit})',
                  border: OutlineInputBorder(),
                ),
              ),

              SizedBox(height: 20),

              // Dropdown for selecting rolls
              if (availableRolls.isNotEmpty)
                DropdownButton<String>(
                  value: selectedRoll,
                  hint: Text("Select a roll"),
                  onChanged: (String? newRoll) {
                    setState(() {
                      selectedRoll = newRoll!;
                      validateRollCompatibility(); // Validate on roll selection
                    });
                  },
                  items: availableRolls
                      .map<DropdownMenuItem<String>>((String roll) {
                    return DropdownMenuItem<String>(
                      value: roll,
                      child: Text(roll),
                    );
                  }).toList(),
                ),

              // Display roll compatibility error
              if (rollCompatibilityError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10.0),
                  child: Text(
                    rollCompatibilityError!,
                    style: TextStyle(color: Colors.red, fontSize: 14),
                  ),
                ),

              SizedBox(height: 20),

              // Display current state values
              Text(
                'Width: ${widthInFeet.toStringAsFixed(2)} Feet',
                style: TextStyle(fontSize: 16),
              ),
              Text(
                'Height: ${heightInFeet.toStringAsFixed(2)} Feet',
                style: TextStyle(fontSize: 16),
              ),
              Text(
                'Unit: $unit',
                style: TextStyle(fontSize: 16),
              ),
              Text(
                'Selected Product: ${selectedName ?? "None"}',
                style: TextStyle(fontSize: 16),
              ),
              Text(
                'Selected Roll: ${selectedRoll ?? "None"}',
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
